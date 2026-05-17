# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab:
#
#   cd gong<Tab>       # -> cd 工作/
#   vim baogao<Tab>    # -> vim 报告.txt
#
# With multiple matches, repeated Tab cycles through candidates.
# Typing anything else clears the cycle and starts a new query.

# ---- helpers ---------------------------------------------------------

typeset -ga _zh_dirs_cmds=(cd pcd z j pushd)
typeset -ga _zh_files_cmds=(cat vim nvim vi less head tail bat nano emacs)
typeset -ga _zh_any_cmds=(ls code open rm cp mv)

# Cycle state (cleared when the user modifies the buffer).
typeset -ga _zh_cycle_candidates
typeset -g  _zh_cycle_index=0
typeset -g  _zh_cycle_lbuffer=""    # LBUFFER after insertion
typeset -g  _zh_cycle_orig_lbuf=""  # LBUFFER before insertion (with pinyin word)

_zh_format_replacement() {
  # $1 = full path, returns the string to insert (quoted, with / for dirs)
  local fullpath="$1" name="${1##*/}"
  name="${(q)name}"        # (q) only adds quoting when needed
  if [[ -d "$fullpath" ]]; then
    name="${name}/"
  fi
  printf '%s' "$name"
}

_zh_show_list() {
  local -a displayed=()
  local c
  for c in "$@"; do
    if [[ -d "$c" ]]; then
      displayed+=("${c##*/}/")
    else
      displayed+=("${c##*/}")
    fi
  done
  zle -M "  ${(j:  :)displayed}"
}

# ---- widget ----------------------------------------------------------

_zh_complete_widget() {
  # --- cycle mode: user pressed Tab again without changing the buffer ---
  if (( ${#_zh_cycle_candidates} )) && [[ "$LBUFFER" == "$_zh_cycle_lbuffer" ]]; then
    _zh_cycle_index=$(( (_zh_cycle_index % ${#_zh_cycle_candidates}) + 1 ))
    local fullpath="${_zh_cycle_candidates[$_zh_cycle_index]}"
    # Revert to the original pinyin word, then insert the next candidate.
    LBUFFER="${_zh_cycle_orig_lbuf}"
    local repl
    repl=$(_zh_format_replacement "$fullpath")
    LBUFFER="${LBUFFER}${repl}"
    _zh_cycle_lbuffer="$LBUFFER"
    _zh_show_list "${_zh_cycle_candidates[@]}"
    return
  fi

  # Not in a cycle — clear any stale state.
  _zh_cycle_candidates=()
  _zh_cycle_index=0
  _zh_cycle_lbuffer=""
  _zh_cycle_orig_lbuf=""

  # --- guard: only complete when cursor is at end ---
  if (( CURSOR != ${#BUFFER} )); then
    zle _zh_orig_tab
    return
  fi

  local word="${LBUFFER##* }"
  if [[ -z "$word" ]] || [[ ! "$word" =~ ^[a-z][a-z0-9]*$ ]]; then
    zle _zh_orig_tab
    return
  fi

  # --- determine filter from command ---
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

  # --- no pinyin match → fall back to native Tab ---
  if (( ${#candidates} == 0 )); then
    zle _zh_orig_tab
    return
  fi

  # --- single match → insert directly ---
  if (( ${#candidates} == 1 )); then
    local repl
    repl=$(_zh_format_replacement "${candidates[1]}")
    LBUFFER="${LBUFFER%"$word"}${repl}"
    return
  fi

  # --- multiple matches → insert first, save state for cycling ---
  _zh_cycle_candidates=("${candidates[@]}")
  _zh_cycle_index=1
  _zh_cycle_orig_lbuf="${LBUFFER%"$word"}"   # "cd "
  local repl
  repl=$(_zh_format_replacement "${candidates[1]}")
  LBUFFER="${_zh_cycle_orig_lbuf}${repl}"    # "cd 工作1/"
  _zh_cycle_lbuffer="$LBUFFER"
  _zh_show_list "${candidates[@]}"
}

# ---- install ---------------------------------------------------------

# Guard against double-sourcing.
(( ${+_zh_orig_tab} )) && return 0

local orig="${${$(bindkey '^I')##* }:-expand-or-complete}"
zle -A "$orig" _zh_orig_tab
zle -N _zh_complete_widget
bindkey '^I' _zh_complete_widget
