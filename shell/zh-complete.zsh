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
  # DIAGNOSTIC: log everything to see what's happening.
  echo "$(date +%H:%M:%S) completer called" >> /tmp/_zh_diag.log
  echo "  PREFIX=[$PREFIX]" >> /tmp/_zh_diag.log
  echo "  IPREFIX=[$IPREFIX]" >> /tmp/_zh_diag.log
  echo "  words=[${words[@]}]" >> /tmp/_zh_diag.log

  # Minimal test: add a static match to verify compadd works.
  compadd -Q "ZZ_TEST_PINYIN_MATCH"
  echo "  compadd exit: $?" >> /tmp/_zh_diag.log

  local word="${(Q)PREFIX}"
  [[ -n "$word" ]] && [[ "$word" =~ ^[a-z][a-z0-9]*$ ]] || { echo "  bail: word=[$word] no match" >> /tmp/_zh_diag.log; return 1 }

  local cmd="${words[1]}" filter=""
  case "$cmd" in
    cd|pcd|z|j|pushd) filter="--dirs" ;;
    *)                filter=""        ;;
  esac

  local iprefix="${(Q)IPREFIX}"
  local cwd="${iprefix:-$PWD}"
  [[ -n "$iprefix" ]] && [[ ! -d "$iprefix" ]] && cwd="$PWD"

  echo "  filter=[$filter] cwd=[$cwd] word=[$word]" >> /tmp/_zh_diag.log

  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --cwd "$cwd" --list "$word" 2>/dev/null)"})
  echo "  candidate count: ${#candidates}" >> /tmp/_zh_diag.log
  (( ${#candidates} )) || { echo "  bail: no candidates" >> /tmp/_zh_diag.log; return 1 }

  local -a matches
  local c
  for c in "${candidates[@]}"; do
    matches+=("${c##*/}")
  done
  compadd -Q -a matches
  echo "  matches added: ${#matches}" >> /tmp/_zh_diag.log

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
  zstyle ':completion:*' completer _zh_pinyin_completer "${existing[@]}"
fi
