#!/usr/bin/env zsh
set -euo pipefail

BOLD="$(tput bold 2>/dev/null || echo "")"
GREEN="$(tput setaf 2 2>/dev/null || echo "")"
YELLOW="$(tput setaf 3 2>/dev/null || echo "")"
RESET="$(tput sgr0 2>/dev/null || echo "")"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_NAME="pinyin-path"

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

if ! command -v zsh &>/dev/null; then
  warn "zsh not found. This tool is designed for zsh. Proceeding anyway..."
fi

info "Rust toolchain: $(rustc --version 2>/dev/null || echo "found")"

# ---------------------------------------------------------------------------
# 2. Build and install the binary
# ---------------------------------------------------------------------------
info "Building ${BIN_NAME}..."
cd "$PROJECT_DIR"
cargo install --path . --force 2>&1 | while IFS= read -r line; do
  say "  $line"
done

if ! command -v "$BIN_NAME" &>/dev/null; then
  if [[ -x "$HOME/.cargo/bin/$BIN_NAME" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
  else
    warn "Binary not found after install. Check \$HOME/.cargo/bin/"
    exit 1
  fi
fi
ok "${BIN_NAME} installed ($(which "$BIN_NAME"))"

# ---------------------------------------------------------------------------
# 3. Shell integration
# ---------------------------------------------------------------------------
ZHRC="${ZDOTDIR:-$HOME}/.zshrc"

SOURCE_PCD="source ${PROJECT_DIR}/shell/pcd.zsh"
SOURCE_TAB="source ${PROJECT_DIR}/shell/zh-complete.zsh"

add_source_line() {
  local line="$1"
  local label="$2"
  if grep -qF "$line" "$ZHRC" 2>/dev/null; then
    ok "${label} already sourced in ${ZHRC}"
  else
    info "Adding ${label} to ${ZHRC}..."
    printf "\n# zh-complete: %s\n%s\n" "$label" "$line" >> "$ZHRC"
    ok "${label} added"
  fi
}

if [[ -f "$ZHRC" ]]; then
  add_source_line "$SOURCE_PCD" "pcd function"
  add_source_line "$SOURCE_TAB" "pinyin Tab completion"
else
  warn "${ZHRC} not found. Add these lines manually:"
  say "  ${SOURCE_PCD}"
  say "  ${SOURCE_TAB}"
fi

# ---------------------------------------------------------------------------
# 4. Quick smoke test
# ---------------------------------------------------------------------------
info "Smoke test..."
TESTDIR="$(mktemp -d)"
mkdir -p "$TESTDIR/工作" "$TESTDIR/工作报告"
RESULT=$("$BIN_NAME" --dirs --cwd "$TESTDIR" gongzuo 2>&1) || true
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
say "    ${BOLD}mkdir 工作 && pcd gongzuo${RESET}"
say "    ${BOLD}cd gong<Tab>${RESET}"
say ""
