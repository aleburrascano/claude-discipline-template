#!/usr/bin/env bash
# install-rtk.sh — install the RTK (Rust Token Killer) CLI proxy + wire it into Claude Code.
#
# What this does:
#   1. Detects whether the RIGHT `rtk` is already on PATH (rtk-ai/rtk, not the Rust Type Kit
#      crate of the same name). Skips if so.
#   2. Installs via `cargo install --git https://github.com/rtk-ai/rtk` if cargo is available.
#      Falls back to the official `curl ... | sh` installer.
#   3. Runs `rtk init -g --auto-patch --hook-only` to wire the PreToolUse:Bash hook into
#      ~/.claude/settings.json without touching anything else.
#   4. Verifies with `rtk gain`.
#
# Off switch: pass --skip-init to install without wiring the hook.
#             pass --uninstall to remove instead.

set -euo pipefail

SKIP_INIT=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --skip-init) SKIP_INIT=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \?//'
      exit 0 ;;
  esac
done

REPO="https://github.com/rtk-ai/rtk"

# ---------- detect existing rtk ----------
rtk_is_correct() {
  # The wrong `rtk` (Rust Type Kit, crates.io 0.1.0) has no `gain` subcommand.
  # The right one (rtk-ai/rtk) reports usage when invoked without args and has `gain`.
  if ! command -v rtk >/dev/null 2>&1; then
    return 1
  fi
  if rtk gain >/dev/null 2>&1 || rtk --help 2>&1 | grep -qi 'token'; then
    return 0
  fi
  return 1
}

# ---------- uninstall branch ----------
if [[ "$UNINSTALL" -eq 1 ]]; then
  echo "Uninstalling rtk..."
  if command -v cargo >/dev/null 2>&1; then
    cargo uninstall rtk 2>&1 | head -3 || true
    cargo uninstall rtk-registry 2>&1 | head -3 || true
    cargo uninstall rtk-tui 2>&1 | head -3 || true
  fi
  echo "Done. You may still need to manually remove the rtk hook entry from ~/.claude/settings.json."
  exit 0
fi

# ---------- already installed ----------
if rtk_is_correct; then
  VERSION="$(rtk --version 2>&1 | head -1 || echo unknown)"
  echo "✓ rtk already installed: $VERSION"
else
  # ---------- install ----------
  echo "Installing rtk-ai/rtk..."
  if command -v cargo >/dev/null 2>&1; then
    echo "  using: cargo install --git $REPO"
    cargo install --git "$REPO" --force
  elif command -v curl >/dev/null 2>&1; then
    echo "  cargo not found; using official installer (curl | sh)"
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh
  else
    cat <<EOF >&2
ERROR: neither 'cargo' nor 'curl' is on PATH. Install one of:
  - Rust toolchain (cargo):  https://rustup.rs
  - curl (most systems have it; on Windows install via Scoop or use Git Bash)
Then re-run this script.
EOF
    exit 1
  fi

  # Verify
  if ! rtk_is_correct; then
    cat <<EOF >&2
ERROR: rtk install completed but 'rtk gain' doesn't work. Possible causes:
  - PATH doesn't include the cargo bin dir. Add: export PATH="\$HOME/.cargo/bin:\$PATH"
  - Name collision with the Rust Type Kit 'rtk' crate. Run:
      cargo uninstall rtk
      cargo install --git $REPO --force
EOF
    exit 1
  fi
  echo "✓ rtk installed: $(rtk --version 2>&1 | head -1)"
fi

# ---------- wire into Claude Code ----------
if [[ "$SKIP_INIT" -eq 1 ]]; then
  echo
  echo "Skipping rtk init (--skip-init). To wire RTK into Claude Code later, run:"
  echo "    rtk init -g                  # full setup"
  echo "    rtk init -g --hook-only      # just the PreToolUse:Bash hook"
  exit 0
fi

echo
echo "Wiring rtk into ~/.claude/settings.json (PreToolUse:Bash hook)..."
echo "  command: rtk init -g --auto-patch --hook-only"
if rtk init -g --auto-patch --hook-only 2>&1; then
  echo "✓ rtk wired."
else
  cat <<EOF >&2
WARNING: 'rtk init' returned non-zero. The binary works but the hook may not be wired.
You can manually add this to ~/.claude/settings.json under hooks.PreToolUse:
  {
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "rtk hook claude"}]
  }
EOF
fi

echo
echo "Verify:"
echo "    rtk gain          # show token-savings analytics"
echo "    rtk gain --history"
