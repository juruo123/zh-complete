# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab:
#
#   cd gong<Tab>       # -> cd 工作/
#   vim baogao<Tab>    # -> vim 报告.txt
#   cd com<Tab>        # still completes natively to compiler/
#
# To use a different key, change the bindkey line at the bottom.

# Commands where we only complete directories.
typeset -ga _zh_dirs_cmds=(cd pcd z j pushd)

# Commands where we only complete files.
typeset -ga _zh_files_cmds=(cat vim nvim vi less head tail bat nano emacs)

# Commands where we complete both.
typeset -ga _zh_any_cmds=(ls code open rm cp mv)

_zh_needs_quoting() {
  [[ "$1" != "${1##[a-zA-Z0-9._/-]}" ]]
}

_zh_complete_widget() {
  # Only intervene when cursor is at end of buffer.
  if (( CURSOR != ${#BUFFER} )); then
    zle _zh_orig_tab
    return
  fi

  # Word under cursor = last space-delimited token before cursor.
  local word="${LBUFFER##* }"
  if [[ -z "$word" ]] || [[ ! "$word" =~ ^[a-z][a-z0-9]*$ ]]; then
    zle _zh_orig_tab
    return
  fi

  # Determine filter from the command name.
  local cmd="${${(z)BUFFER}[1]}"
  local filter=""
  if (( _zh_dirs_cmds[(Ie)$cmd] )); then
    filter="--dirs"
  elif (( _zh_files_cmds[(Ie)$cmd] )); then
    filter="--files"
  elif (( _zh_any_cmds[(Ie)$cmd] )); then
    filter=""
  else
    zle _zh_orig_tab
    return
  fi

  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --list "$word" 2>/dev/null)"})

  if (( ${#candidates} == 0 )); then
    zle _zh_orig_tab
    return
  elif (( ${#candidates} == 1 )); then
    local fullpath="${candidates[1]}"
    local replacement="${fullpath##*/}"
    if _zh_needs_quoting "$replacement"; then
      replacement="${(q)replacement}"
    fi
    if [[ -d "$fullpath" ]]; then
      replacement="${replacement}/"
    fi
    LBUFFER="${LBUFFER%"$word"}${replacement}"
  else
    local -a displayed=()
    local c
    for c in "${candidates[@]}"; do
      if [[ -d "$c" ]]; then
        displayed+=("${c##*/}/")
      else
        displayed+=("${c##*/}")
      fi
    done
    zle -M "  ${(j:  :)displayed}"
  fi
}

# ---- Install (guard against double-sourcing) ----
if zle -l | grep -q '_zh_orig_tab' 2>/dev/null; then
  return 0
fi

# Preserve whatever widget is currently bound to Tab (^I).
local orig
orig="${${$(bindkey '^I')##* }:-expand-or-complete}"
zle -A "$orig" _zh_orig_tab

zle -N _zh_complete_widget
bindkey '^I' _zh_complete_widget
