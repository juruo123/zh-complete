# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Configuration (set before sourcing):
#   ZH_COMPLETE_DEBUG=1      enable diagnostic logging to /tmp/_zh_diag.log
#   zstyle ':zh-complete:*' show-header false    hide the [pinyin] header
#
# Usage:
#   cd gong<Tab>          # -> 工作/
#   cd 工作/ce<Tab>       # -> 工作/测试/

# ---- guard -----------------------------------------------------------

local -a _zh_check
zstyle -a ':completion:*' completer _zh_check 2>/dev/null || true
(( ${_zh_check[(Ie)_zh_pinyin_completer]} )) && return 0

# ---- helpers ---------------------------------------------------------

_zh_debug() { [[ -n "$ZH_COMPLETE_DEBUG" ]] && echo "$@" >> /tmp/_zh_diag.log; }

_zh_show_header() {
  local val
  zstyle -s ':zh-complete:*' show-header val
  [[ "$val" != "false" ]]
}

# ---- pinyin completer -------------------------------------------------

_zh_pinyin_completer() {
  _zh_debug "== $(date +%H:%M:%S) PREFIX=[$PREFIX] IPREFIX=[$IPREFIX] words=[${words[@]}]"

  local word="${(Q)PREFIX}"
  [[ -n "$word" ]] || { _zh_debug "  A empty word"; return 1; }

  local cmd="${words[1]}" filter=""
  case "$cmd" in
    cd|pcd|z|j|pushd) filter="--dirs" ;;
    *)                filter=""        ;;
  esac

  local iprefix="${(Q)IPREFIX}"
  local cwd="${iprefix:-$PWD}"

  # Directory part to reattach after completion (for multi-level paths).
  local dir_prefix=""

  local query="$word"
  if [[ "$word" == */* ]]; then
    local dir_part="${word%/*}"
    local query_part="${word##*/}"
    _zh_debug "  B path-split dir=[$dir_part] query=[$query_part] exists=[$([[ -d "$dir_part" ]] && echo yes || echo no)]"
    if [[ -d "$dir_part" ]]; then
      cwd="$dir_part"
      query="$query_part"
      dir_prefix="${dir_part}/"
      _zh_debug "  C using cwd=[$cwd] query=[$query] dir_prefix=[$dir_prefix]"
    fi
  fi

  _zh_debug "  D filter=[$filter] cwd=[$cwd] query=[$query]"

  [[ "$query" =~ ^[a-z][a-z0-9]*$ ]] || { _zh_debug "  E not pinyin"; return 1; }

  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --cwd "$cwd" --list "$query" 2>/dev/null)"})
  _zh_debug "  F candidates=${#candidates}"
  (( ${#candidates} )) || { _zh_debug "  G no candidates"; return 1; }

  local -a matches displays
  local c fullpath
  for fullpath in "${candidates[@]}"; do
    local name="${fullpath##*/}"
    # Multi-level: real match includes dir prefix for correct PREFIX replacement.
    # Display shows only basename for a clean menu.
    displays+=("$name")
    matches+=("${dir_prefix}${name}")
  done
  _zh_debug "  H displays=[${displays[@]}] matches=[${matches[@]}]"

  local orig_prefix="$PREFIX" orig_iprefix="$IPREFIX"
  PREFIX=""

  local -a compadd_args=(-U -Q -S '')
  _zh_show_header && compadd_args+=(-X "%B[zh]%b")

  # -f: treat matches as files; zsh determines the type and adds "/"
  # for directories, enabling the "/" key to navigate into subdirs.
  compadd_args+=(-f)

  compadd "${compadd_args[@]}" -d displays -a matches 2>> /tmp/_zh_diag.log
  _zh_debug "  I compadd exit=$?"

  PREFIX="$orig_prefix"

  compstate[list]="list force"
  compstate[insert]="menu"
  _zh_debug "  J done"

  return 1
}

# ---- install ---------------------------------------------------------

local -a existing
zstyle -a ':completion:*' completer existing 2>/dev/null || true
(( ${#existing} )) || existing=(_complete _ignored)

if (( ! ${existing[(Ie)_zh_pinyin_completer]} )); then
  zstyle ':completion:*' completer _complete _zh_pinyin_completer _ignored
fi
