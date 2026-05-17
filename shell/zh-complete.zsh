# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Usage:
#   cd gong<Tab>         # pinyin completion
#   cd 工作/<Tab>         # native completion kicks in automatically
#   cd 工作/bao<Tab>      # pinyin inside subdirectory
#
# Only cd / pushd / z / j / pcd filter to directories.
# All other commands match both files and directories.

autoload -U colors && colors

# ---- helpers ---------------------------------------------------------

typeset -ga _zh_dirs_only=(cd pcd z j pushd)
typeset -ga _zh_all=(ls cat vim nvim vi code open rm cp mv less head tail bat nano emacs)

# Cycle state.
typeset -ga _zh_cycle_candidates
typeset -g  _zh_cycle_index=0
typeset -g  _zh_cycle_lbuffer=""
typeset -g  _zh_cycle_orig_lbuf=""

# ---- formatting ------------------------------------------------------

_zh_format_replacement() {
  # $1 = full path → string to insert (quoted + / for dirs)
  local fullpath="$1" name="${1##*/}"
  name="${(q)name}"
  [[ -d "$fullpath" ]] && name="${name}/"
  printf '%s' "$name"
}

_zh_show_list() {
  # $@ = full paths of candidates; $1 = current index (1-based)
  local idx="$1"; shift
  local -a disp=()
  local i=1 c
  for c in "$@"; do
    local marker=" "
    (( i == idx )) && marker="→"
    if [[ -d "$c" ]]; then
      disp+=("  ${marker} ${fg[blue]}${c##*/}/${reset_color}")
    else
      disp+=("  ${marker} ${c##*/}")
    fi
    (( i++ ))
  done
  zle -M "${(j:  :)disp}"
}

# ---- word extraction ------------------------------------------------

_zh_extract_word() {
  # Figures out the word to complete, its directory context, and the
  # pinyin query.  Returns answers in global vars:
  #   _zh_replace_from   — the substring in LBUFFER to replace
  #   _zh_cwd            — directory to scan
  #   _zh_query          — pinyin query (may be empty → no match)

  _zh_replace_from=""
  _zh_cwd="$PWD"
  _zh_query=""

  local word="${LBUFFER##* }"
  [[ -z "$word" ]] && return

  if [[ "$word" == */* ]]; then
    # Word has a path separator, e.g. "工作/bao".
    local dir_part="${word%/*}"
    local query_part="${word##*/}"

    # If dir_part exists as a real directory, set it as cwd and only
    # replace the query part (keep the directory prefix).
    if [[ -d "$dir_part" ]]; then
      _zh_cwd="$dir_part"
      _zh_replace_from="$query_part"
      _zh_query="$query_part"
      return
    fi
    # If dir_part doesn't exist, fall through: treat the whole word
    # as a query (won't match pinyin regex anyway).
  fi

  _zh_replace_from="$word"
  _zh_query="$word"
}

# ---- widget ----------------------------------------------------------

_zh_complete_widget() {
  # === cycle mode: repeated Tab on previous multi-match result ===
  if (( ${#_zh_cycle_candidates} )) && [[ "$LBUFFER" == "$_zh_cycle_lbuffer" ]]; then
    _zh_cycle_index=$(( (_zh_cycle_index % ${#_zh_cycle_candidates}) + 1 ))
    local fullpath="${_zh_cycle_candidates[$_zh_cycle_index]}"
    LBUFFER="${_zh_cycle_orig_lbuf}"
    local repl; repl=$(_zh_format_replacement "$fullpath")
    LBUFFER="${LBUFFER}${repl}"
    _zh_cycle_lbuffer="$LBUFFER"
    _zh_show_list "$_zh_cycle_index" "${_zh_cycle_candidates[@]}"
    return
  fi

  # Clear stale cycle state.
  _zh_cycle_candidates=()
  _zh_cycle_index=0
  _zh_cycle_lbuffer=""
  _zh_cycle_orig_lbuf=""

  # === guards ===
  (( CURSOR == ${#BUFFER} )) || { zle _zh_orig_tab; return }

  _zh_extract_word
  local query="$_zh_query"
  if [[ -z "$query" ]] || [[ ! "$query" =~ ^[a-z][a-z0-9]*$ ]]; then
    zle _zh_orig_tab
    return
  fi
  local replace_from="$_zh_replace_from"
  local cwd="$_zh_cwd"

  # === determine filter ===
  local cmd="${${(z)BUFFER}[1]}"
  local filter=""
  if (( _zh_dirs_only[(Ie)$cmd] )); then
    filter="--dirs"
  elif (( _zh_all[(Ie)$cmd] )); then
    filter=""
  else
    zle _zh_orig_tab
    return
  fi

  # === run pinyin-path ===
  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --cwd "$cwd" --list "$query" 2>/dev/null)"})

  # === no match → native fallback ===
  if (( ${#candidates} == 0 )); then
    zle _zh_orig_tab
    return
  fi

  # === single match ===
  if (( ${#candidates} == 1 )); then
    local repl; repl=$(_zh_format_replacement "${candidates[1]}")
    LBUFFER="${LBUFFER%"$replace_from"}${repl}"
    return
  fi

  # === multiple matches → insert first, arm cycling ===
  _zh_cycle_candidates=("${candidates[@]}")
  _zh_cycle_index=1
  _zh_cycle_orig_lbuf="${LBUFFER%"$replace_from"}"
  local repl; repl=$(_zh_format_replacement "${candidates[1]}")
  LBUFFER="${_zh_cycle_orig_lbuf}${repl}"
  _zh_cycle_lbuffer="$LBUFFER"
  _zh_show_list 1 "${candidates[@]}"
}

# ---- install ---------------------------------------------------------

(( ${+_zh_orig_tab} )) && return 0

local orig="${${$(bindkey '^I')##* }:-expand-or-complete}"
zle -A "$orig" _zh_orig_tab
zle -N _zh_complete_widget
bindkey '^I' _zh_complete_widget
