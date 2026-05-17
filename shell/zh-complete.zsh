# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab:
#
#   cd gong<Tab>       # -> cd 工作/
#   vim baogao<Tab>    # -> vim 报告.txt
#
# To use a different key instead of Tab, change the bindkey line at the
# bottom of this file (e.g. ^F for Ctrl-F).

# Commands where we only complete directories.
_zh_complete_dirs_cmds=(cd pcd z j pushd)

# Commands where we only complete files.
_zh_complete_files_cmds=(cat vim nvim vi less head tail bat nano emacs)

# Commands where we complete both files and directories.
_zh_complete_any_cmds=(ls code open rm cp mv)

_zh_complete_needs_quoting() {
  local s="$1"
  # Needs quoting if it contains anything other than safe characters.
  [[ "$s" != "${s##[a-zA-Z0-9._/-]}" ]]
}

_zh_complete_tab_widget() {
  # Only trigger when cursor is at end of buffer.
  if (( CURSOR != ${#BUFFER} )); then
    zle .expand-or-complete
    return
  fi

  # Last space-delimited token in the buffer is the word being completed.
  local word="${LBUFFER##* }"
  if [[ -z "$word" ]] || [[ ! "$word" =~ ^[a-z][a-z0-9]*$ ]]; then
    zle .expand-or-complete
    return
  fi

  # Determine filter based on the command.
  local cmd="${${(z)BUFFER}[1]}"
  local filter=""
  if (( _zh_complete_dirs_cmds[(Ie)$cmd] )); then
    filter="--dirs"
  elif (( _zh_complete_files_cmds[(Ie)$cmd] )); then
    filter="--files"
  elif (( _zh_complete_any_cmds[(Ie)$cmd] )); then
    filter=""
  else
    zle .expand-or-complete
    return
  fi

  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --list "$word" 2>/dev/null)"})

  if (( ${#candidates} == 0 )); then
    zle .expand-or-complete
    return
  elif (( ${#candidates} == 1 )); then
    local replacement="${candidates[1]}"
    if _zh_complete_needs_quoting "$replacement"; then
      replacement="${(q)replacement}"
    fi
    # Add trailing / for directories so the user can immediately type sub-paths.
    if [[ -d "${candidates[1]}" ]]; then
      replacement="${replacement}/"
    fi
    LBUFFER="${LBUFFER%"$word"}${replacement}"
  else
    local displayed=()
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

# Replace the default Tab (expand-or-complete) widget.
# Comment out the next two lines and use a different key binding if you prefer
# to keep the default Tab behavior.
zle -N expand-or-complete _zh_complete_tab_widget
