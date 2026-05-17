#!/usr/bin/env zsh
# zh-complete diagnostic tool
# Run: zsh diagnose.zsh

set -euo pipefail

BOLD="$(tput bold 2>/dev/null || echo "")"
GREEN="$(tput setaf 2 2>/dev/null || echo "")"
RED="$(tput setaf 1 2>/dev/null || echo "")"
RESET="$(tput sgr0 2>/dev/null || echo "")"

pass() { echo "  ${GREEN}PASS${RESET} $1"; }
fail() { echo "  ${RED}FAIL${RESET} $1"; }

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "${BOLD}zh-complete diagnostics${RESET}"
echo "========================"
echo ""

# 1. Binary check
echo "${BOLD}1. pinyin-path binary${RESET}"
if BIN=$(which pinyin-path 2>/dev/null); then
  pass "found at $BIN"
else
  BIN="$HOME/.cargo/bin/pinyin-path"
  if [[ -x "$BIN" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
    pass "found at $BIN"
  else
    fail "not found — run: cargo install --path $PROJECT_DIR"
  fi
fi

# 2. Pure ASCII exclusion
echo ""
echo "${BOLD}2. Pure-ASCII exclusion${RESET}"
TESTDIR=$(mktemp -d)
mkdir "$TESTDIR/compiler" "$TESTDIR/工作"
OUT=$("$BIN" --dirs --cwd "$TESTDIR" com 2>&1) || true
if [[ "$OUT" == *"no match"* ]]; then
  pass "pure ASCII 'compiler' is excluded"
else
  fail "pure ASCII still matching: $OUT"
fi
rm -rf "$TESTDIR"

# 3. zsh Tab binding
echo ""
echo "${BOLD}3. Tab key binding${RESET}"
TAB_BINDING="${$(bindkey '^I')##* }"
echo "  Tab (^I) is bound to: ${TAB_BINDING}"
if [[ "$TAB_BINDING" == "_zh_complete_tab_widget" ]]; then
  pass "our widget is active"
elif [[ "$TAB_BINDING" == "expand-or-complete" ]]; then
  echo "  → vanilla zsh Tab, should work with our override"
else
  echo "  → non-standard binding — our zle -N may not take effect"
  echo "  → we need to use bindkey instead of zle -N"
fi

# 4. Widget presence
echo ""
echo "${BOLD}4. Widget registration${RESET}"
if zle -l | grep -q '_zh_complete_tab_widget' 2>/dev/null; then
  pass "widget _zh_complete_tab_widget is registered"
else
  fail "widget not registered — source shell/zh-complete.zsh first"
fi

# 5. Test completion in clean zsh
echo ""
echo "${BOLD}5. End-to-end test (clean subshell)${RESET}"
TESTDIR=$(mktemp -d)
mkdir "$TESTDIR/compiler" "$TESTDIR/工作"
# Run a fresh zsh that sources only our widget and tests Tab behavior
OUT=$(zsh -fc '
  export PATH="'"$HOME"'/.cargo/bin:$PATH"
  source "'"$PROJECT_DIR"'/shell/zh-complete.zsh"
  cd "'"$TESTDIR"'"
  # Simulate typing "cd com" then Tab by using zle
  BUFFER="cd com"
  CURSOR=${#BUFFER}
  zle expand-or-complete
  echo "BUFFER=[$BUFFER]"
  echo "CURSOR=$CURSOR"
' 2>&1) || true
echo "$OUT"
if [[ "$OUT" == *"BUFFER=[cd compiler/]"* ]]; then
  pass "Tab completes 'com' → 'compiler/' via native fallback"
elif [[ "$OUT" == *"BUFFER=[cd com]"* ]]; then
  echo "  → word unchanged — completion did nothing (possible issue)"
else
  echo "  → see output above"
fi
rm -rf "$TESTDIR"

echo ""
echo "${BOLD}Summary${RESET}"
echo "If all PASS: the tool is working, try opening a fresh terminal."
echo "If FAIL at step 5: the widget fallback mechanism needs fixing."
echo ""
echo "Try this interactive test in your real zsh:"
echo ""
echo "  cd /tmp && mkdir -p compiler 工作 && cd /tmp"
echo "  cd <Tab>      # should list compiler/ and 工作/"
echo "  cd com<Tab>   # should complete compiler/"
echo "  cd gon<Tab>   # should complete 工作/"
