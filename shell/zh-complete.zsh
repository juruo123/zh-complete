# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab — works for all commands that
# complete file paths (cd, ls, cat, vim, rm, ...):
#
#   cd gong<Tab>          # -> cd 工作/
#   vim 工作/bao<Tab>      # -> vim 工作/报告.txt
#
# How: wraps zsh's _path_files — the lowest-level file listing function
# that every completion (cd, ls, vim, ...) ultimately calls.  Native
# completion runs first, then pinyin results are added via compadd to
# the same pool, inheriting full color / menu / cycling for free.

# ---- guard -----------------------------------------------------------

(( ${+_zh_installed} )) && return 0
typeset -g _zh_installed=1

# ---- wrap _path_files ------------------------------------------------

# _path_files is the lowest-level file/directory listing function in
# the zsh completion system.  Every completion that lists files (cd,
# ls, vim, cat, rm, ...) ultimately calls _path_files.  Wrapping it
# at this level catches all of them.

# Force-load the autoloadable function.
autoload +X _path_files 2>/dev/null
(( ${+functions[_path_files]} )) || return 0

# Save the original.
functions -c _path_files _zh_orig_path_files

# ---- pinyin helper ---------------------------------------------------

_zh_pinyin_add() {
  local word="${(Q)PREFIX}"
  [[ -n "$word" ]] && [[ "$word" =~ ^[a-z][a-z0-9]*$ ]] || return 1

  # Only cd / pushd / z / j / pcd filter to directories.
  local cmd="${words[1]}" filter=""
  case "$cmd" in
    cd|pcd|z|j|pushd) filter="--dirs" ;;
    *)                filter=""        ;;
  esac

  # Directory part already resolved (e.g. "工作/" in "工作/bao").
  local iprefix="${(Q)IPREFIX}"
  local cwd="${iprefix:-$PWD}"
  [[ -n "$iprefix" ]] && [[ ! -d "$iprefix" ]] && cwd="$PWD"

  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --cwd "$cwd" --list "$word" 2>/dev/null)"})
  (( ${#candidates} )) || return 1

  local -a matches
  local c
  for c in "${candidates[@]}"; do
    matches+=("${c##*/}")
  done
  compadd -Q -a matches
}

# ---- override _path_files --------------------------------------------

_path_files() {
  local orig_prefix="$PREFIX" orig_iprefix="$IPREFIX"

  _zh_orig_path_files "$@"
  local ret=$?

  PREFIX="$orig_prefix"
  IPREFIX="$orig_iprefix"
  _zh_pinyin_add && ret=0

  return ret
}
