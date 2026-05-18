use pinyin::ToPinyin;
use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::ffi::OsString;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::time::SystemTime;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EntryKind {
    Any,
    DirsOnly,
    FilesOnly,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Candidate {
    #[serde(serialize_with = "serialize_os_string")]
    pub file_name: OsString,
    #[serde(serialize_with = "serialize_path_buf")]
    pub path: PathBuf,
    pub is_dir: bool,
    pub full_pinyin: String,
    pub initials: String,
    #[serde(skip)]
    pub ascii_folded: String,
}

fn serialize_os_string<S: serde::Serializer>(
    v: &OsString,
    s: S,
) -> Result<S::Ok, S::Error> {
    s.serialize_str(&v.to_string_lossy())
}

fn serialize_path_buf<S: serde::Serializer>(
    v: &PathBuf,
    s: S,
) -> Result<S::Ok, S::Error> {
    s.serialize_str(&v.to_string_lossy())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MatchError {
    NoMatch,
    Ambiguous(Vec<Candidate>),
}

// ---- directory scan cache --------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
struct CacheData {
    mtime_secs: u64,
    entries: Vec<CachedEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct CachedEntry {
    file_name: String,
    is_dir: bool,
    full_pinyin: String,
    initials: String,
    ascii_folded: String,
}

fn cache_path(cwd: &Path, kind: EntryKind) -> PathBuf {
    let mut h = DefaultHasher::new();
    cwd.hash(&mut h);
    (kind as u8).hash(&mut h);
    std::env::temp_dir().join(format!("zhc_{:016x}.json", h.finish()))
}

fn cache_load(cwd: &Path, kind: EntryKind) -> Option<Vec<Candidate>> {
    let path = cache_path(cwd, kind);
    let data = fs::read_to_string(&path).ok()?;
    let cached: CacheData = serde_json::from_str(&data).ok()?;

    // Invalidate if directory modification time changed.
    let current = fs::metadata(cwd)
        .ok()?
        .modified()
        .ok()?
        .duration_since(SystemTime::UNIX_EPOCH)
        .ok()?
        .as_secs();
    if current != cached.mtime_secs {
        let _ = fs::remove_file(&path);
        return None;
    }

    Some(
        cached
            .entries
            .into_iter()
            .map(|e| Candidate {
                file_name: OsString::from(&e.file_name),
                path: cwd.join(&e.file_name),
                is_dir: e.is_dir,
                full_pinyin: e.full_pinyin,
                initials: e.initials,
                ascii_folded: e.ascii_folded,
            })
            .collect(),
    )
}

fn cache_save(cwd: &Path, kind: EntryKind, candidates: &[Candidate]) {
    let current = match fs::metadata(cwd).and_then(|m| m.modified()) {
        Ok(t) => t.duration_since(SystemTime::UNIX_EPOCH).unwrap_or_default().as_secs(),
        Err(_) => return,
    };

    let data = CacheData {
        mtime_secs: current,
        entries: candidates
            .iter()
            .map(|c| CachedEntry {
                file_name: c.file_name.to_string_lossy().into_owned(),
                is_dir: c.is_dir,
                full_pinyin: c.full_pinyin.clone(),
                initials: c.initials.clone(),
                ascii_folded: c.ascii_folded.clone(),
            })
            .collect(),
    };

    if let Ok(json) = serde_json::to_string(&data) {
        let _ = fs::write(cache_path(cwd, kind), json);
    }
}

pub fn find_one(
    cwd: &Path,
    query: &str,
    kind: EntryKind,
) -> io::Result<Result<Candidate, MatchError>> {
    let query = normalize_query(query);
    let matches = find_matches_normalized(cwd, &query, kind)?;

    let exact_matches: Vec<_> = matches
        .iter()
        .filter(|candidate| candidate.is_exact_match(&query))
        .cloned()
        .collect();

    match (matches.len(), exact_matches.len()) {
        (0, _) => Ok(Err(MatchError::NoMatch)),
        (_, 1) => Ok(Ok(exact_matches.into_iter().next().expect("one exact match"))),
        (1, _) => Ok(Ok(matches.into_iter().next().expect("one match"))),
        _ => Ok(Err(MatchError::Ambiguous(matches))),
    }
}

pub fn find_matches(cwd: &Path, query: &str, kind: EntryKind) -> io::Result<Vec<Candidate>> {
    let query = normalize_query(query);
    find_matches_normalized(cwd, &query, kind)
}

fn find_matches_normalized(
    cwd: &Path,
    query: &str,
    kind: EntryKind,
) -> io::Result<Vec<Candidate>> {
    // Try cache first — avoids rescanning the directory on every Tab press.
    let all_candidates: Vec<Candidate> = if let Some(cached) = cache_load(cwd, kind) {
        cached
    } else {
        let mut all = Vec::new();
        for entry in fs::read_dir(cwd)? {
            let entry = entry?;
            let file_type = entry.file_type()?;
            let is_dir = file_type.is_dir();

            if !matches_kind(is_dir, kind) {
                continue;
            }

            let file_name = entry.file_name();
            let display_name = file_name.to_string_lossy();
            let candidate = build_candidate(file_name.clone(), entry.path(), is_dir, &display_name);

            // Skip pure-ASCII entries — shell handles them natively.
            if candidate.full_pinyin == candidate.ascii_folded {
                continue;
            }

            all.push(candidate);
        }
        cache_save(cwd, kind, &all);
        all
    };

    // Filter and score against the query.
    let mut matches: Vec<(usize, Candidate)> = all_candidates
        .into_iter()
        .filter_map(|c| c.match_score(query).map(|s| (s, c)))
        .collect();

    matches.sort_by(|(a_score, a), (b_score, b)| {
        b_score
            .cmp(a_score)
            .then_with(|| a.file_name.len().cmp(&b.file_name.len()))
            .then_with(|| {
                a.file_name
                    .to_string_lossy()
                    .cmp(&b.file_name.to_string_lossy())
            })
    });

    Ok(matches.into_iter().map(|(_, c)| c).collect())
}

fn build_candidate(
    file_name: OsString,
    path: PathBuf,
    is_dir: bool,
    display_name: &str,
) -> Candidate {
    let (full_pinyin, initials) = pinyin_keys(display_name);

    Candidate {
        file_name,
        path,
        is_dir,
        full_pinyin,
        initials,
        ascii_folded: normalize_query(display_name),
    }
}

impl Candidate {
    fn match_score(&self, query: &str) -> Option<usize> {
        if query.is_empty() {
            return None;
        }

        if self.full_pinyin == query {
            return Some(1000);
        }
        if self.initials == query {
            return Some(900);
        }
        if self.ascii_folded == query {
            return Some(800);
        }
        if self.full_pinyin.starts_with(query) {
            return Some(200 + query.len());
        }
        if self.initials.starts_with(query) {
            return Some(100 + query.len());
        }
        if self.ascii_folded.starts_with(query) {
            return Some(query.len());
        }
        None
    }

    fn is_exact_match(&self, query: &str) -> bool {
        self.full_pinyin == query || self.initials == query || self.ascii_folded == query
    }
}

fn pinyin_keys(input: &str) -> (String, String) {
    let mut full = String::new();
    let mut initials = String::new();

    for ch in input.chars() {
        if let Some(pinyin) = ch.to_pinyin() {
            full.push_str(pinyin.plain());
            initials.push_str(pinyin.first_letter());
            continue;
        }

        if ch.is_ascii_alphanumeric() {
            full.push(ch.to_ascii_lowercase());
            initials.push(ch.to_ascii_lowercase());
        }
    }

    (full, initials)
}

fn normalize_query(input: &str) -> String {
    input
        .chars()
        .filter_map(|ch| {
            if ch.is_ascii_alphanumeric() {
                Some(ch.to_ascii_lowercase())
            } else {
                None
            }
        })
        .collect()
}

fn matches_kind(is_dir: bool, kind: EntryKind) -> bool {
    match kind {
        EntryKind::Any => true,
        EntryKind::DirsOnly => is_dir,
        EntryKind::FilesOnly => !is_dir,
    }
}

// ---- CLI helper ------------------------------------------------------

pub struct PathQuery {
    pub dirs: bool,
    pub files: bool,
    pub list: bool,
    pub json: bool,
    pub cwd: Option<PathBuf>,
    pub query: String,
    pub program_name: String,
}

pub fn run_path_query(q: PathQuery) -> Result<(), ExitCode> {
    let cwd = q
        .cwd
        .unwrap_or_else(|| std::env::current_dir().unwrap_or_else(|_| PathBuf::from(".")));
    let kind = if q.dirs {
        EntryKind::DirsOnly
    } else if q.files {
        EntryKind::FilesOnly
    } else {
        EntryKind::Any
    };

    if q.list {
        let matches = find_matches(&cwd, &q.query, kind).map_err(|e| print_io_error(&q.program_name, e))?;
        if q.json {
            serde_json::to_writer_pretty(io::stdout().lock(), &matches).map_err(|e| {
                let _ = writeln!(io::stderr(), "{}: {e}", q.program_name);
                ExitCode::from(1)
            })?;
            println!();
        } else {
            for candidate in matches {
                println!("{}", candidate.path.to_string_lossy());
            }
        }
        return Ok(());
    }

    match find_one(&cwd, &q.query, kind).map_err(|e| print_io_error(&q.program_name, e))? {
        Ok(candidate) => {
            if q.json {
                serde_json::to_writer_pretty(io::stdout().lock(), &candidate).map_err(|e| {
                    let _ = writeln!(io::stderr(), "{}: {e}", q.program_name);
                    ExitCode::from(1)
                })?;
                println!();
            } else {
                println!("{}", candidate.path.to_string_lossy());
            }
            Ok(())
        }
        Err(MatchError::NoMatch) => {
            let msg = format!("{}: no match for {:?}", q.program_name, q.query);
            if q.json {
                println!("null");
            }
            eprintln!("{msg}");
            Err(ExitCode::from(1))
        }
        Err(MatchError::Ambiguous(candidates)) => {
            if q.json {
                serde_json::to_writer_pretty(io::stdout().lock(), &candidates).map_err(|e| {
                    let _ = writeln!(io::stderr(), "{}: {e}", q.program_name);
                    ExitCode::from(1)
                })?;
                println!();
            } else {
                eprintln!(
                    "{}: multiple matches for {:?}:",
                    q.program_name, q.query
                );
                for candidate in &candidates {
                    eprintln!("  {}", candidate.path.to_string_lossy());
                }
            }
            Err(ExitCode::from(2))
        }
    }
}

fn print_io_error(program_name: &str, err: io::Error) -> ExitCode {
    let _ = writeln!(io::stderr(), "{program_name}: {err}");
    ExitCode::from(1)
}

// ---- zsh init template -----------------------------------------------

/// Returns the zsh completer source.
/// `cmd` is the shell command for path matching, e.g. "zhc path" or "pinyin-path".
pub fn zsh_init_script(cmd: &str, show_header: bool, debug: bool) -> String {
    let header_line = if show_header {
        ""
    } else {
        "zstyle ':zh-complete:*' show-header false\n"
    };
    let debug_line = if debug { "export ZH_COMPLETE_DEBUG=1\n" } else { "" };

    format!(
        "{}export __ZH_CMD__='{}'\n{}{}",
        debug_line,
        cmd,
        header_line,
        include_str!("../shell/zh-complete.zsh")
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_chinese_to_full_pinyin_and_initials() {
        let (full, initials) = pinyin_keys("工作报告");

        assert_eq!(full, "gongzuobaogao");
        assert_eq!(initials, "gzbg");
    }

    #[test]
    fn keeps_ascii_parts_in_mixed_names() {
        let (full, initials) = pinyin_keys("Rust学习01");

        assert_eq!(full, "rustxuexi01");
        assert_eq!(initials, "rustxx01");
    }

    #[test]
    fn scores_full_pinyin_initials_and_ascii_prefix() {
        let candidate = build_candidate(
            OsString::from("工作报告"),
            PathBuf::from("工作报告"),
            true,
            "工作报告",
        );

        assert!(candidate.match_score("gong").is_some());
        assert!(candidate.match_score("gongzuo").is_some());
        assert!(candidate.match_score("gzbg").is_some());
        assert!(candidate.match_score("bg").is_none());
    }

    #[test]
    fn exact_match_scores_higher_than_prefix() {
        let candidate = build_candidate(
            OsString::from("工作报告"),
            PathBuf::from("工作报告"),
            true,
            "工作报告",
        );

        let exact = candidate.match_score("gongzuobaogao").unwrap();
        let prefix = candidate.match_score("gong").unwrap();
        assert!(exact > prefix, "exact {exact} should beat prefix {prefix}");
    }

    #[test]
    fn finds_single_directory_match() {
        let temp = tempfile::tempdir().expect("tempdir");
        fs::create_dir(temp.path().join("工作")).expect("create dir");
        fs::write(temp.path().join("工作.txt"), "").expect("create file");

        let found = find_one(temp.path(), "gong", EntryKind::DirsOnly)
            .expect("scan")
            .expect("single match");

        assert_eq!(found.file_name, OsString::from("工作"));
        assert!(found.is_dir);
    }

    #[test]
    fn reports_ambiguous_matches() {
        let temp = tempfile::tempdir().expect("tempdir");
        fs::create_dir(temp.path().join("工作")).expect("create dir");
        fs::create_dir(temp.path().join("工作报告")).expect("create dir");

        let result = find_one(temp.path(), "gong", EntryKind::DirsOnly).expect("scan");

        assert!(matches!(result, Err(MatchError::Ambiguous(matches)) if matches.len() == 2));
    }

    #[test]
    fn prefers_a_single_exact_key_over_prefix_matches() {
        let temp = tempfile::tempdir().expect("tempdir");
        fs::create_dir(temp.path().join("工作")).expect("create dir");
        fs::create_dir(temp.path().join("工作报告")).expect("create dir");

        let found = find_one(temp.path(), "gongzuo", EntryKind::DirsOnly)
            .expect("scan")
            .expect("single exact match");

        assert_eq!(found.file_name, OsString::from("工作"));
    }

    #[test]
    fn keeps_original_path_for_special_characters() {
        let temp = tempfile::tempdir().expect("tempdir");
        let name = "工作 报告(2026)";
        fs::create_dir(temp.path().join(name)).expect("create dir");

        let found = find_one(temp.path(), "gzbg2026", EntryKind::DirsOnly)
            .expect("scan")
            .expect("single match");

        assert_eq!(found.file_name, OsString::from(name));
        assert_eq!(found.path, temp.path().join(name));
    }
}
