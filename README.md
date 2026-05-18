# zh-complete

Pinyin-based shell path completion for Chinese filenames. Type `gong<Tab>` to
complete `工作/` — no need to switch to a Chinese input method.

## Quick start

```sh
# Build and install
cargo install --path .

# Add to ~/.zshrc
eval "$(zhc init zsh)"
```

## How it works

`zh-complete` hooks into zsh's completion system via a custom completer
(`_zh_pinyin_completer`) that runs after `_complete`. When the built-in file
completion finds nothing (e.g. no file literally named `gong*`), the pinyin
completer converts the query to pinyin and adds matching Chinese filenames via
`compadd`. Results participate in zsh's native completion menu with full color,
highlighting, and cycling.

```text
Tab press
    │
    ▼
_complete          ← native file/directory completion runs first
    │ (no native match → return 1)
    ▼
_zh_pinyin_completer ← pinyin matching kicks in
    │                   ┌─ zhc path (Rust): scan dir, pinyin convert, match
    │                   └─ compadd: add Chinese results to completion pool
    ▼
_ignored
    │
    ▼
zsh completion menu ← native colors, cycling, /-to-enter-dir
```

## Matching rules

| Input     | Matches        | Mechanism              |
|-----------|----------------|------------------------|
| `gong`    | `工作`         | Full pinyin prefix     |
| `gongzuo` | `工作`         | Full pinyin prefix     |
| `gz`      | `工作`         | Pinyin initials        |
| `gzbg`    | `工作报告`     | Pinyin initials        |
| `rustxx`  | `Rust学习`     | Mixed ASCII + pinyin   |

Scoring (higher is better):

- Exact full-pinyin match: 1000
- Exact initials match: 900
- Full-pinyin prefix: 200 + query length
- Initials prefix: 100 + query length
- Results sorted by score, then name length, then alphabetically.
- Pure ASCII names (e.g. `compiler`) are excluded — the shell handles them
  natively.

## zhc CLI

The `zhc` binary is the main entry point. `pinyin-path` is kept for
backward compatibility.

```sh
# Pinyin path matching
zhc path --dirs gongzuo
# → /home/me/工作

# List all candidates
zhc path --dirs --list gong
# → /home/me/工作
# → /home/me/工作报告

# JSON output
zhc path --dirs --list --json gong
# → [{"file_name":"工作","path":"...","is_dir":true,...}]

# Generate zsh integration (add to ~/.zshrc)
eval "$(zhc init zsh)"

# With options
eval "$(zhc init zsh --no-header --debug)"

# Scan a specific directory
zhc path --cwd /some/where gongzuo
```

Directory scan results are cached to `$TMPDIR` (invalidated when the
directory's mtime changes). The first Tab press scans the directory;
subsequent presses for the same directory reuse the cache.

Exit codes: `0` single match, `1` no match, `2` ambiguous.

## Supported commands

- **Directories only:** `cd`, `pcd`, `z`, `j`, `pushd`
- **Files + directories:** `ls`, `cat`, `vim`, `nvim`, `vi`, `code`, `open`,
  `rm`, `cp`, `mv`, `less`, `head`, `tail`, `bat`, `nano`, `emacs`

The completer hooks into `_path_files` at the lowest level, so any command
that completes file paths inherits pinyin support automatically.

## Configuration

Configuration is passed to `zhc init`:

```sh
# Default (header shown, no debug)
eval "$(zhc init zsh)"

# Hide the [zh] header
eval "$(zhc init zsh --no-header)"

# Enable diagnostic logging
eval "$(zhc init zsh --debug)"
```

If sourcing `shell/zh-complete.zsh` directly instead, set these before sourcing:

```zsh
zstyle ':zh-complete:*' show-header false   # hide [zh] header
export ZH_COMPLETE_DEBUG=1                  # enable debug logging
```

## Project layout

```text
Cargo.toml
src/
  lib.rs              # Scanning, pinyin conversion, scoring, matching, caching
  main.rs             # pinyin-path binary (backward compat)
  bin/zhc.rs          # zhc binary (zhc path, zhc init zsh)
tests/
  cli.rs              # 18 integration tests
shell/
  pcd.zsh             # pcd zsh wrapper
  zh-complete.zsh     # zsh completer (also embedded in zhc init zsh)
install.sh            # One-command installer
README.md
```

## Roadmap

- [x] Basic pinyin matching (full pinyin + initials)
- [x] `pcd` zsh function
- [x] Candidate scoring and ranking
- [x] JSON output mode
- [x] zsh completer integration (native menu / colors / cycling)
- [x] Integration tests
- [x] Multi-level directory completion (`cd 工作/ce<Tab>`)
- [x] Configurable header and debug logging
- [x] Unified `zhc` binary (`zhc path`, `zhc init zsh`)
- [x] Directory scan caching (mtime-based, per-directory)
- [x] Install script (`install.sh`)
- [ ] `fzf` integration for interactive selection
- [ ] bash / fish support
- [ ] Polyphonic character dictionary (e.g. 重庆 → chongqing)
- [ ] Homebrew formula
- [ ] GitHub Actions release builds

## License

MIT
