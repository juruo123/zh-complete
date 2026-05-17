# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
#   cd gong<Tab>          # -> 工作/
#   cd 工作/bao<Tab>       # -> 工作/报告.txt
#
# Pinyin completions participate in the native zsh completion menu
# with full color, highlighting, and cycling.

# ---- guard -----------------------------------------------------------

# Only skip if our completer is already in the chain.
local -a _zh_check
zstyle -a ':completion:*' completer _zh_check 2>/dev/null || true
(( ${_zh_check[(Ie)_zh_pinyin_completer]} )) && return 0

# ---- pinyin completer -------------------------------------------------

_zh_pinyin_completer() {
  echo "$(date +%H:%M:%S) completer called, PREFIX=[$PREFIX]" >> /tmp/_zh_diag.log

  local word="${(Q)PREFIX}"
  [[ -n "$word" ]] && [[ "$word" =~ ^[a-z][a-z0-9]*$ ]] || return 1

  local cmd="${words[1]}" filter=""
  case "$cmd" in
    cd|pcd|z|j|pushd) filter="--dirs" ;;
    *)                filter=""        ;;
  esac

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

  # _description sets up the tag; unlike _wanted it doesn't check
  # whether the tag is requested by the calling completion function.
  local expl
  _description pinyin expl 'pinyin match'
  compadd "$expl[@]" -Q -a matches
  echo "  compadd exit=$?, matches=${#matches}" >> /tmp/_zh_diag.log

  return 1
}

# ---- install: prepend our completer before _complete ------------------

# The completer chain tries each function in order.  We prepend ours
# so it runs first.  Our completer adds pinyin matches via compadd
# and always returns 1 (non-zero), so the chain continues to _complete
# which adds native file/directory matches.  Both sets participate in
# the same completion menu with full color / highlighting / cycling.

local -a existing
zstyle -a ':completion:*' completer existing 2>/dev/null || true
(( ${#existing} )) || existing=(_complete _ignored)

if (( ! ${existing[(Ie)_zh_pinyin_completer]} )); then
  # Place our completer AFTER _complete so the completion context
  # (tags, styles, etc.) is fully initialized before we try compadd.
  zstyle ':completion:*' completer _complete _zh_pinyin_completer _ignored
fi
