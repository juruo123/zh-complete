use pinyin::ToPinyin;
use serde::Serialize;
use std::ffi::OsString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

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
    let mut matches = Vec::new();

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

        // Skip entries with no Chinese characters — the shell's built-in
        // completion already handles pure-ASCII names perfectly well.
        if candidate.full_pinyin == candidate.ascii_folded {
            continue;
        }

        if let Some(score) = candidate.match_score(&query) {
            matches.push((score, candidate));
        }
    }

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
