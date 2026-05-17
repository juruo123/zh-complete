use clap::Parser;
use std::env;
use std::io::{self, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use zh_complete::{find_matches, find_one, EntryKind, MatchError};

#[derive(Debug, Parser)]
#[command(name = "pinyin-path")]
#[command(about = "Find Chinese paths by typing pinyin")]
struct Args {
    /// Match directories only, useful for pcd/cd.
    #[arg(long, conflicts_with = "files")]
    dirs: bool,

    /// Match files only.
    #[arg(long, conflicts_with = "dirs")]
    files: bool,

    /// Print all matching candidates instead of requiring a single match.
    #[arg(long)]
    list: bool,

    /// Output results as JSON (candidate objects or array).
    #[arg(long)]
    json: bool,

    /// Directory to scan. Defaults to the current directory.
    #[arg(long, value_name = "DIR")]
    cwd: Option<PathBuf>,

    /// Pinyin query, for example gong, gongzuo, gz, or gzbg.
    query: String,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(code) => code,
    }
}

fn run() -> Result<(), ExitCode> {
    let args = Args::parse();
    let cwd = args
        .cwd
        .unwrap_or_else(|| env::current_dir().unwrap_or_else(|_| PathBuf::from(".")));
    let kind = if args.dirs {
        EntryKind::DirsOnly
    } else if args.files {
        EntryKind::FilesOnly
    } else {
        EntryKind::Any
    };

    if args.list {
        let matches = find_matches(&cwd, &args.query, kind).map_err(print_io_error)?;
        if args.json {
            serde_json::to_writer_pretty(io::stdout().lock(), &matches).map_err(|e| {
                let _ = writeln!(io::stderr(), "pinyin-path: {e}");
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

    match find_one(&cwd, &args.query, kind).map_err(print_io_error)? {
        Ok(candidate) => {
            if args.json {
                serde_json::to_writer_pretty(io::stdout().lock(), &candidate).map_err(|e| {
                    let _ = writeln!(io::stderr(), "pinyin-path: {e}");
                    ExitCode::from(1)
                })?;
                println!();
            } else {
                println!("{}", candidate.path.to_string_lossy());
            }
            Ok(())
        }
        Err(MatchError::NoMatch) => {
            let msg = format!("pinyin-path: no match for {:?}", args.query);
            if args.json {
                println!("null");
            }
            eprintln!("{msg}");
            Err(ExitCode::from(1))
        }
        Err(MatchError::Ambiguous(candidates)) => {
            if args.json {
                serde_json::to_writer_pretty(io::stdout().lock(), &candidates).map_err(|e| {
                    let _ = writeln!(io::stderr(), "pinyin-path: {e}");
                    ExitCode::from(1)
                })?;
                println!();
            } else {
                eprintln!(
                    "pinyin-path: multiple matches for {:?}:",
                    args.query
                );
                for candidate in &candidates {
                    eprintln!("  {}", candidate.path.to_string_lossy());
                }
            }
            Err(ExitCode::from(2))
        }
    }
}

fn print_io_error(err: io::Error) -> ExitCode {
    let _ = writeln!(io::stderr(), "pinyin-path: {err}");
    ExitCode::from(1)
}
