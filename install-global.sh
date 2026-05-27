#!/usr/bin/env bash
# install-global.sh — install global/ overlay into the user's ~/.claude/
#
# Behavior per file:
#   - File missing in ~/.claude/         → COPY (no prompt). Reported as "added".
#   - File present + content identical   → SKIP. Reported as "identical".
#   - File present + content differs     → BACKUP existing → show diff → prompt:
#                                          [i]nstall (overwrite), [s]kip, [v]iew-full-diff, [k]eep-both
#
# Never touches: ~/.claude/projects/, sessions/, handoffs/, plans/, file-history/,
#                shell-snapshots/, logs/, cache/, backups/, session-env/, tdd-guard/,
#                chrome/, downloads/, ide/, .credentials.json, history.jsonl,
#                settings.local.json, settings.json (only writes settings.json.template).

set -euo pipefail

# ---------- locate source ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SRC="$SCRIPT_DIR/global"

if [[ ! -d "$GLOBAL_SRC" ]]; then
  echo "ERROR: $GLOBAL_SRC not found. Run this script from the claude-discipline-template repo root." >&2
  exit 1
fi

# ---------- target ----------
TARGET="${CLAUDE_HOME:-$HOME/.claude}"
TIMESTAMP="$(date +%Y-%m-%dT%H-%M-%S)"
BACKUP_DIR="$TARGET/backup-$TIMESTAMP"

echo "claude-discipline global install"
echo "  source: $GLOBAL_SRC"
echo "  target: $TARGET"
echo "  backup: $BACKUP_DIR (created on demand)"
echo

mkdir -p "$TARGET"

# ---------- counters ----------
ADDED=()
IDENTICAL=()
INSTALLED=()
SKIPPED=()
KEPT_BOTH=()

# ---------- per-file install helper ----------
install_file() {
  local src="$1"
  local rel="$2"   # path relative to ~/.claude/
  local dest="$TARGET/$rel"

  if [[ ! -f "$dest" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    ADDED+=("$rel")
    return
  fi

  if cmp -s "$src" "$dest"; then
    IDENTICAL+=("$rel")
    return
  fi

  # Differs — show diff snippet and prompt
  echo "═══ DIFFERS: $rel"
  echo "  Source (this repo, lines 1-20):"
  head -n 20 "$src" | sed 's/^/    | /'
  echo
  echo "  Your version (lines 1-20):"
  head -n 20 "$dest" | sed 's/^/    | /'
  echo
  echo "  diff -u summary:"
  diff -u "$dest" "$src" 2>/dev/null | head -n 30 | sed 's/^/    /' || true
  echo

  while true; do
    read -r -p "  [i]nstall (backup existing first) · [s]kip · [v]iew full diff · [k]eep both as .new: " choice </dev/tty
    case "$choice" in
      i|I)
        mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
        cp "$dest" "$BACKUP_DIR/$rel"
        cp "$src" "$dest"
        INSTALLED+=("$rel")
        echo "  → installed; original backed up to $BACKUP_DIR/$rel"
        break
        ;;
      s|S)
        SKIPPED+=("$rel")
        echo "  → skipped"
        break
        ;;
      v|V)
        diff -u "$dest" "$src" 2>/dev/null | less || diff -u "$dest" "$src" 2>/dev/null
        # loop back to re-prompt
        ;;
      k|K)
        cp "$src" "$dest.new"
        KEPT_BOTH+=("$rel (new at $dest.new)")
        echo "  → both kept; new version at $dest.new"
        break
        ;;
      *)
        echo "  (please answer i / s / v / k)"
        ;;
    esac
  done
  echo
}

# ---------- iterate over global/ files ----------
echo "Processing files..."
echo

# Special case: settings.json.template stays as a template — never overwrites a real settings.json
if [[ -f "$GLOBAL_SRC/settings.json.template" ]]; then
  install_file "$GLOBAL_SRC/settings.json.template" "settings.json.template"
fi

# CLAUDE.md, RTK.md
for f in CLAUDE.md RTK.md; do
  [[ -f "$GLOBAL_SRC/$f" ]] && install_file "$GLOBAL_SRC/$f" "$f"
done

# hooks/
if [[ -d "$GLOBAL_SRC/hooks" ]]; then
  while IFS= read -r -d '' src; do
    rel="${src#$GLOBAL_SRC/}"
    install_file "$src" "$rel"
  done < <(find "$GLOBAL_SRC/hooks" -type f -print0)
fi

# commands/
if [[ -d "$GLOBAL_SRC/commands" ]]; then
  while IFS= read -r -d '' src; do
    rel="${src#$GLOBAL_SRC/}"
    install_file "$src" "$rel"
  done < <(find "$GLOBAL_SRC/commands" -type f -print0)
fi

# ---------- chmod +x on hooks ----------
chmod +x "$TARGET/hooks/"*.sh 2>/dev/null || true

# ---------- report ----------
echo
echo "═══ SUMMARY ═══"
echo "Added (didn't exist):        ${#ADDED[@]}"
[[ ${#ADDED[@]} -gt 0 ]] && printf '  + %s\n' "${ADDED[@]}"
echo
echo "Installed (overwrote):       ${#INSTALLED[@]}"
[[ ${#INSTALLED[@]} -gt 0 ]] && printf '  ↻ %s\n' "${INSTALLED[@]}"
echo
echo "Identical (no change):       ${#IDENTICAL[@]}"
[[ ${#IDENTICAL[@]} -gt 0 ]] && printf '  = %s\n' "${IDENTICAL[@]}"
echo
echo "Skipped (you said no):       ${#SKIPPED[@]}"
[[ ${#SKIPPED[@]} -gt 0 ]] && printf '  - %s\n' "${SKIPPED[@]}"
echo
echo "Kept both as .new:           ${#KEPT_BOTH[@]}"
[[ ${#KEPT_BOTH[@]} -gt 0 ]] && printf '  ± %s\n' "${KEPT_BOTH[@]}"
echo

if [[ ${#INSTALLED[@]} -gt 0 ]]; then
  echo "Backups of overwritten files: $BACKUP_DIR"
fi

echo
echo "Next steps:"
echo "  1. If you don't have ~/.claude/settings.json yet:"
echo "       cp ~/.claude/settings.json.template ~/.claude/settings.json"
echo "     Otherwise: open both, merge the 'hooks' section into your existing settings.json."
echo
echo "  2. Validate the hooks:"
echo "       bash ~/.claude/hooks/test-claim-audit.sh"
echo "       bash ~/.claude/hooks/test-langcheck.sh"
echo
echo "  3. Optional: install the bootstrap plugin for project-level scaffolding:"
echo "       /plugin marketplace add aleburrascano/claude-discipline-template"
echo "       /plugin install bootstrap@aleburrascano/claude-discipline-template"
