# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab:
#
#   cd gong<Tab>       # -> cd 工作/
#   vim baogao<Tab>    # -> vim 报告.txt
#
# Only cd / pushd / z / j / pcd filter to directories.
# All other commands (ls, cat, vim, rm, ...) match both files and dirs.

# ---- shared completion function --------------------------------------

_zh_complete() {
  # $1 = pinyin-path filter: "--dirs" or ""
  local filter="$1"
  local word="${(Q)PREFIX}"
  local iprefix="${(Q)IPREFIX}"
  local ret=1

  # --- native path completion via zsh's built-in _path_files ----------
  if [[ "$filter" == "--dirs" ]]; then
    _path_files -/ && ret=0
  else
    _path_files && ret=0
  fi

  # --- pinyin extras ---------------------------------------------------
  if [[ -n "$word" ]] && [[ "$word" =~ ^[a-z][a-z0-9]*$ ]]; then
    # Determine the directory to scan.
    local cwd="$PWD"
    if [[ -n "$iprefix" ]] && [[ -d "$iprefix" ]]; then
      cwd="$iprefix"
    fi

    local candidates
    candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --cwd "$cwd" --list "$word" 2>/dev/null)"})
    if (( ${#candidates} )); then
      local -a matches
      local c
      for c in "${candidates[@]}"; do
        matches+=("${c##*/}")
      done
      compadd -a matches && ret=0
    fi
  fi

  return ret
}

# ---- per-command wrappers --------------------------------------------

_zh_cd()      { _zh_complete "--dirs" }
_zh_generic() { _zh_complete "" }

# ---- install ----------------------------------------------------------

# Guard against double-sourcing.
(( ${+_zh_installed} )) && return 0
typeset -g _zh_installed=1

autoload -Uz compdef

compdef _zh_cd      cd pcd z j pushd
compdef _zh_generic ls cat vim nvim vi code open rm cp mv \
                    less head tail bat nano emacs
