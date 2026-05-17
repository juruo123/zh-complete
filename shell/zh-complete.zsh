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
# How: wraps zsh's _files function, the central dispatcher for file
# completion.  Native completion runs first (with full color, menu,
# cycling).  When the prefix looks like a pinyin query, extra matches
# are added via compadd to the same completion pool.

# ---- guard -----------------------------------------------------------

(( ${+_zh_installed} )) && return 0
typeset -g _zh_installed=1

# ---- wrap _files -----------------------------------------------------

# Force-load the autoloadable _files function.
autoload +X _files 2>/dev/null

# If not available (e.g. broken fpath), bail without side effects.
(( ${+functions[_files]} )) || return 0

# Save the original.
functions -c _files _zh_orig_files

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

# ---- override _files -------------------------------------------------

_files() {
  local orig_prefix="$PREFIX" orig_iprefix="$IPREFIX"

  _zh_orig_files "$@"
  local ret=$?

  # Restore original prefix so pinyin matching sees the raw query,
  # then add extras to the same completion pool (both native and
  # pinyin matches participate in menu / colors / cycling).
  PREFIX="$orig_prefix"
  IPREFIX="$orig_iprefix"
  _zh_pinyin_add && ret=0

  return ret
}
