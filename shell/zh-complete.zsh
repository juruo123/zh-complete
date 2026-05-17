# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab:
#
#   cd gong<Tab>       # -> cd 工作/
#   vim baogao<Tab>    # -> vim 报告.txt
#
# Multiple matches participate in zsh's completion menu — repeated Tab
# cycles through candidates just like native completion.

# ---- shared completion helper ----------------------------------------

_zh_path_complete() {
  # $1 = filter: "--dirs", "--files", or ""
  local filter="$1"
  local ret=1
  local expl

  # Native path completion via zsh's built-in _path_files.
  case "$filter" in
    --dirs)
      _description directories expl 'directory'
      _path_files -/ && ret=0
      ;;
    --files)
      _description files expl 'file'
      _path_files && ret=0
      ;;
    *)
      _path_files && ret=0
      ;;
  esac

  # Pinyin extras: only when the word prefix looks like a pinyin query.
  local word="${(Q)PREFIX}"
  if [[ -n "$word" ]] && [[ "$word" =~ ^[a-z][a-z0-9]*$ ]]; then
    local candidates
    candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --list "$word" 2>/dev/null)"})
    if (( ${#candidates} )); then
      local -a matches
      local c
      for c in "${candidates[@]}"; do
        matches+=("${c##*/}")
      done
      compadd -Q -X "  %B[zh]%b" -a matches && ret=0
    fi
  fi

  return ret
}

# ---- per-command wrappers --------------------------------------------

_zh_cd()   { _zh_path_complete "--dirs" }
_zh_cat()  { _zh_path_complete "--files" }
_zh_vim()  { _zh_path_complete "--files" }
_zh_ls()   { _zh_path_complete "" }

# ---- register with zsh completion system ------------------------------

# Guard against double-sourcing.
(( ${+_zh_registered} )) && return 0
typeset -gA _zh_registered
_zh_registered=1

# compdef is loaded by compinit; ensure it is available.
autoload -Uz compdef

compdef _zh_cd  cd pcd z j pushd
compdef _zh_cat cat less head tail bat nano
compdef _zh_vim vim nvim vi emacs
compdef _zh_ls  ls code open rm cp mv
