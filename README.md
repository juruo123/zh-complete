# zh-complete

Pinyin-based shell path completion for Chinese filenames. Type `gong<Tab>` to
complete `工作/` — no need to switch to a Chinese input method.

## Quick start

```sh
# Build and install the helper binary
cargo install --path .

# Enable zsh integration
source shell/zh-complete.zsh

# Try it
mkdir 工作 工作报告
cd gong<Tab>        # completes to 工作/
pcd gongzuo         # jumps into 工作/
```

Or use the installer:

```sh
./install.sh
```

## What you get

| File | Purpose |
|---|---|
| `src/lib.rs` | Pinyin matching engine |
| `src/main.rs` | `pinyin-path` CLI |
| `shell/pcd.zsh` | `pcd` function — pinyin `cd` |
| `shell/zh-complete.zsh` | Tab-completion widget for zsh |
| `install.sh` | One-command installer |

## Matching rules

| Input | Matches | Mechanism |
|---|---|---|
| `gong` | `工作` | Full pinyin prefix |
| `gongzuo` | `工作` | Full pinyin prefix |
| `gz` | `工作` | Pinyin initials |
| `gzbg` | `工作报告` | Pinyin initials |
| `rustxx` | `Rust学习` | Mixed ASCII + pinyin |

Scoring (higher is better):

- Exact full-pinyin match: 1000
- Exact initials match: 900
- Full-pinyin prefix: 200 + query length
- Initials prefix: 100 + query length
- Results sorted by score, then name length, then alphabetically.

## pinyin-path CLI

```sh
# Single match — prints the real path
pinyin-path --dirs gongzuo
# → /home/me/工作

# List all candidates
pinyin-path --dirs --list gong
# → /home/me/工作
# → /home/me/工作报告

# JSON output
pinyin-path --dirs --list --json gong
# → [{"file_name":"工作","path":"...","is_dir":true,...}]

# Scan a specific directory
pinyin-path --cwd /some/where gongzuo
```

Exit codes: `0` single match, `1` no match, `2` ambiguous (multiple matches).

## Tab completion (zsh)

Source `shell/zh-complete.zsh` from your `~/.zshrc`. It overrides the Tab key
for these commands:

- **Directories only:** `cd`, `pcd`, `z`, `j`, `pushd`
- **Files only:** `cat`, `vim`, `nvim`, `vi`, `less`, `head`, `tail`, `bat`, `nano`, `emacs`
- **Both:** `ls`, `code`, `open`, `rm`, `cp`, `mv`

When the word under the cursor looks like a pinyin query (lowercase ASCII),
Tab triggers pinyin matching. Otherwise it falls through to zsh's built-in
completion.

A single match replaces the word and adds a trailing `/` for directories.
Multiple matches are displayed above the prompt.

## Project layout

```text
Cargo.toml
src/
  lib.rs            # Scanning, pinyin conversion, scoring, matching
  main.rs           # CLI (pinyin-path)
tests/
  cli.rs            # Integration tests
shell/
  pcd.zsh           # pcd zsh wrapper
  zh-complete.zsh   # Tab-completion widget
install.sh          # Installer
```

## Roadmap

- [x] Basic pinyin matching (full pinyin + initials)
- [x] `pcd` zsh function
- [x] Candidate scoring and ranking
- [x] JSON output mode
- [x] Tab-completion zsh widget
- [x] Integration tests
- [ ] `fzf` integration for interactive selection
- [ ] bash / fish support
- [ ] Directory-aware completion (resolve `subdir/gong` against `subdir/`)
- [ ] Cache support for large directories
- [ ] Polyphonic character dictionary (e.g. 重庆 → chongqing)
- [ ] Fuzzy / tolerant matching
- [ ] Config file (custom scoring, excluded patterns)
- [ ] Homebrew formula
- [ ] GitHub Actions release builds

## License

MIT
