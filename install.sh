#!/usr/bin/env zsh
set -euo pipefail

BOLD="$(tput bold 2>/dev/null || echo "")"
GREEN="$(tput setaf 2 2>/dev/null || echo "")"
YELLOW="$(tput setaf 3 2>/dev/null || echo "")"
RESET="$(tput sgr0 2>/dev/null || echo "")"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="zhc"

say()  { printf "%b\n" "$@"; }
info() { say "${BOLD}→${RESET} $1"; }
ok()   { say "  ${GREEN}✓${RESET} $1"; }
warn() { say "  ${YELLOW}!${RESET} $1"; }

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
say ""
say "${BOLD}zh-complete installer${RESET}"
say "========================"
say ""

if ! command -v cargo &>/dev/null; then
  if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  else
    warn "Rust / Cargo not found."
    say "  Install it first: ${BOLD}curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh${RESET}"
    exit 1
  fi
fi

info "Rust toolchain: $(rustc --version 2>/dev/null || echo "found")"

# ---------------------------------------------------------------------------
# 2. Build and install
# ---------------------------------------------------------------------------
info "Building ${BIN}..."
cd "$PROJECT_DIR"
cargo install --path . --force 2>&1 | while IFS= read -r line; do
  say "  $line"
done

if ! command -v "$BIN" &>/dev/null; then
  if [[ -x "$HOME/.cargo/bin/$BIN" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  else
    warn "${BIN} not found after install. Check \$HOME/.cargo/bin/"
    exit 1
  fi
fi
ok "${BIN} installed ($(which "$BIN"))"

# ---------------------------------------------------------------------------
# 3. Shell integration
# ---------------------------------------------------------------------------
ZHRC="${ZDOTDIR:-$HOME}/.zshrc"
INIT_LINE='eval "$(zhc init zsh)"'

add_init_line() {
  if grep -qF 'zhc init' "$ZHRC" 2>/dev/null; then
    ok "zh-complete already configured in ${ZHRC}"
  else
    info "Adding zh-complete to ${ZHRC}..."
    printf "\n# zh-complete: pinyin-based path completion\n%s\n" "$INIT_LINE" >> "$ZHRC"
    ok "added"
  fi
}

if [[ -f "$ZHRC" ]]; then
  add_init_line
else
  warn "${ZHRC} not found. Add this line manually:"
  say "  ${INIT_LINE}"
fi

# ---------------------------------------------------------------------------
# 4. Smoke test
# ---------------------------------------------------------------------------
info "Smoke test..."
TESTDIR="$(mktemp -d)"
mkdir -p "$TESTDIR/工作"
RESULT=$("$BIN" path --dirs --cwd "$TESTDIR" gongzuo 2>&1) || true
if [[ "$RESULT" == *"工作"* ]]; then
  ok "Smoke test passed"
else
  warn "Smoke test returned unexpected output: $RESULT"
fi
rm -rf "$TESTDIR"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
say ""
say "${GREEN}${BOLD}Install complete!${RESET}"
say ""
say "  Start a new shell or run:"
say "    ${BOLD}source ~/.zshrc${RESET}"
say ""
say "  Try it out:"
say "    ${BOLD}mkdir 工作 && cd gong<Tab>${RESET}"
say ""
