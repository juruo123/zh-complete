# zh-complete

`zh-complete` is a small Rust project for pinyin-based shell path completion.
The first MVP ships a `pinyin-path` helper and a zsh `pcd` function, so you can
enter Chinese directories by typing pinyin:

```sh
pcd gongzuo
```

If the current directory contains `工作/`, `pcd gongzuo` resolves it and runs:

```sh
cd 工作/
```

## MVP Scope

- Scan the current directory.
- Match directories, files, or both.
- Match full pinyin:
  - `gong` -> `工作`
  - `gongzuo` -> `工作`
- Match pinyin initials:
  - `gz` -> `工作`
  - `gzbg` -> `工作报告`
- Handle mixed Chinese and ASCII names:
  - `rustxx` -> `Rust学习`
- Let the shell handle spaces and special characters safely by capturing one
  result and passing it to `cd -- "$target"`.

## Install

Install Rust first if you do not have it:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Build and install the binary:

```sh
cargo install --path .
```

Enable the zsh helper:

```sh
source /path/to/zh-complete/shell/pcd.zsh
```

For daily use, add that `source` line to `~/.zshrc`.

## Usage

Create a sample directory:

```sh
mkdir 工作 工作报告 "Rust学习"
```

Resolve a single directory:

```sh
pinyin-path --dirs gongzuo
```

List candidates:

```sh
pinyin-path --dirs --list gz
```

Use the zsh wrapper:

```sh
pcd gongzuo
pcd gzbg
```

When there is exactly one match, `pinyin-path` prints the real path to stdout.
When there is no match, it exits with status `1`. When multiple candidates
match, it prints the candidate list to stderr and exits with status `2`.

## Project Layout

```text
Cargo.toml
src/
  lib.rs       # path scanning and pinyin matching
  main.rs      # pinyin-path CLI
shell/
  pcd.zsh      # zsh wrapper for cd
```

## Roadmap

1. Improve candidate ranking for ambiguous prefixes.
2. Add CLI integration tests around `pinyin-path`.
3. Add a real zsh Tab widget for `cd gong<Tab>`.
4. Add optional `fzf` selection for ambiguous matches.
5. Add bash/fish support.
6. Add cache support for large directories.
7. Add Homebrew and GitHub Actions release builds.
