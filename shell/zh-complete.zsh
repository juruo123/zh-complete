# Source this file from ~/.zshrc after installing pinyin-path:
#
#   source /path/to/zh-complete/shell/zh-complete.zsh
#
# Then type pinyin queries and press Tab.  For directories with Chinese
# names, pinyin queries work alongside native completion:
#
#   cd gong<Tab>       # -> cd 工作/
#   vim baogao<Tab>    # -> vim 报告.txt
#   cd com<Tab>        # still completes to "compiler/" natively
#
# How it works:
#   We register _pinyin_completer in zsh's completion chain *after*
#   the built-in _complete.  For pure-ASCII queries that match real
#   filenames, zsh's native completion handles them.  When there is
#   no native match (e.g. "gong" won't match any file literally),
#   our completer converts the query to pinyin and finds Chinese
#   filenames.  Results from both run in parallel if needed.

# ---- pinyin completer ------------------------------------------------

_pinyin_completer() {
  # Word prefix before the cursor — what the user typed.
  local word="${PREFIX}"

  # Bail if it doesn't look like a potential pinyin query.
  if [[ -z "$word" ]] || [[ ! "$word" =~ ^[a-z][a-z0-9]*$ ]]; then
    return 1
  fi

  # Determine filter based on the command name.
  local cmd filter=""
  cmd="${words[1]}"

  case "$cmd" in
    cd|pcd|z|j|pushd)              filter="--dirs"  ;;
    cat|vim|nvim|vi|less|head|tail|bat|nano|emacs) filter="--files"  ;;
    ls|code|open|rm|cp|mv)          filter=""        ;;
    *)                              return 1         ;;
  esac

  local candidates
  candidates=(${(f)"$(pinyin-path ${filter:+"$filter"} --list "$word" 2>/dev/null)"})
  (( ${#candidates} )) || return 1

  local -a matches
  local c name
  for c in "$candidates[@]}"; do
    name="${c##*/}"
    if [[ -d "$c" ]]; then
      matches+=("${name}/")
    else
      matches+=("$name")
    fi
  done

  compadd -Q -X "  [zh-complete]" -a matches
  return 0
}

# ---- Installation ----------------------------------------------------

# Guard against double-sourcing.
if zle -l | grep -q '_zh_complete_loaded' 2>/dev/null; then
  return 0
fi

# Read the current completer chain so we don't clobber user settings
# (e.g. someone who already added _approximate for fuzzy matching).
local -a existing
zstyle -a ':completion:*' completer existing 2>/dev/null || true
if (( ! ${#existing} )); then
  existing=(_complete _ignored)
fi

# Append our completer if not already present.
if (( ! ${existing[(Ie)_pinyin_completer]} )); then
  zstyle ':completion:*' completer "${existing[@]}" _pinyin_completer
fi

zle -N _zh_complete_loaded
