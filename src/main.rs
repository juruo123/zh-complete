use clap::Parser;
use std::path::PathBuf;
use std::process::ExitCode;
use zh_complete::{run_path_query, PathQuery};

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
    let args = Args::parse();
    match run_path_query(PathQuery {
        dirs: args.dirs,
        files: args.files,
        list: args.list,
        json: args.json,
        cwd: args.cwd,
        query: args.query,
        program_name: "pinyin-path".into(),
    }) {
        Ok(()) => ExitCode::SUCCESS,
        Err(code) => code,
    }
}
