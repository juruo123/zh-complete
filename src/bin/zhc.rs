use clap::{Parser, Subcommand, ValueEnum};
use std::path::PathBuf;
use std::process::ExitCode;
use zh_complete::{run_path_query, zsh_init_script, PathQuery};

#[derive(Debug, Parser)]
#[command(name = "zhc")]
#[command(about = "zh-complete: pinyin-based shell path completion for Chinese filenames")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Pinyin-based path matching (alias for pinyin-path).
    Path {
        /// Match directories only.
        #[arg(long, conflicts_with = "files")]
        dirs: bool,

        /// Match files only.
        #[arg(long, conflicts_with = "dirs")]
        files: bool,

        /// Print all matching candidates.
        #[arg(long)]
        list: bool,

        /// Output results as JSON.
        #[arg(long)]
        json: bool,

        /// Directory to scan. Defaults to current directory.
        #[arg(long, value_name = "DIR")]
        cwd: Option<PathBuf>,

        /// Pinyin query (e.g. gong, gongzuo, gz, gzbg).
        query: String,
    },

    /// Output shell integration code.
    Init {
        /// Target shell.
        #[arg(value_enum)]
        shell: Shell,

        /// Hide the [zh] header in completion menus.
        #[arg(long)]
        no_header: bool,

        /// Enable diagnostic logging to /tmp/_zh_diag.log.
        #[arg(long)]
        debug: bool,
    },
}

#[derive(Debug, Clone, ValueEnum)]
enum Shell {
    /// Z shell.
    Zsh,
}

fn main() -> ExitCode {
    let cli = Cli::parse();

    match cli.command {
        Command::Path {
            dirs,
            files,
            list,
            json,
            cwd,
            query,
        } => match run_path_query(PathQuery {
            dirs,
            files,
            list,
            json,
            cwd,
            query,
            program_name: "zhc".into(),
        }) {
            Ok(()) => ExitCode::SUCCESS,
            Err(code) => code,
        },

        Command::Init {
            shell,
            no_header,
            debug,
        } => match shell {
            Shell::Zsh => {
                print!(
                    "{}",
                    zsh_init_script("zhc path", !no_header, debug)
                );
                ExitCode::SUCCESS
            }
        },
    }
}
