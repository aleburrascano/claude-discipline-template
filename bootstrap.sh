#!/usr/bin/env bash
# bootstrap.sh — copy claude-discipline-template/template/ into a new project directory,
# parameterize {{PROJECT_NAME}}/{{PROJECT_NAME_SLUG}}/{{PROJECT_DESCRIPTION}}, init git.
#
# Usage:
#   bash bootstrap.sh <target-dir> "<Project Name>" ["<description>"]
#
# Example:
#   bash bootstrap.sh ../my-cool-app "My Cool App" "An app that does cool things."

set -euo pipefail

# ---- args ----
if [[ $# -lt 2 ]]; then
  echo "Usage: bash bootstrap.sh <target-dir> \"<Project Name>\" [\"<description>\"]"
  echo
  echo "  target-dir   path where the new project will live (must not exist or must be empty)"
  echo "  Project Name human-readable name (e.g., \"My Cool App\"); becomes {{PROJECT_NAME}}"
  echo "  description  optional one-line summary; becomes {{PROJECT_DESCRIPTION}}"
  exit 1
fi

TARGET_DIR="$1"
PROJECT_NAME="$2"
DESCRIPTION="${3:-A new project bootstrapped from claude-discipline-template.}"

# Compute kebab-case slug from project name (lowercase, spaces/underscores → dashes, strip non-alnum-dash)
PROJECT_SLUG="$(echo "$PROJECT_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9 _-]//g; s/[ _]/-/g; s/-\+/-/g; s/^-//; s/-$//')"

if [[ -z "$PROJECT_SLUG" ]]; then
  echo "Error: could not derive a valid slug from project name \"$PROJECT_NAME\""
  exit 1
fi

# ---- locate template/ relative to this script ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "Error: template/ not found at $TEMPLATE_DIR"
  exit 1
fi

# ---- validate target ----
if [[ -e "$TARGET_DIR" ]]; then
  if [[ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]]; then
    echo "Error: target $TARGET_DIR exists and is not empty."
    exit 1
  fi
else
  mkdir -p "$TARGET_DIR"
fi

TARGET_ABS="$(cd "$TARGET_DIR" && pwd)"

echo "Bootstrapping into: $TARGET_ABS"
echo "  PROJECT_NAME = $PROJECT_NAME"
echo "  PROJECT_NAME_SLUG = $PROJECT_SLUG"
echo "  PROJECT_DESCRIPTION = $DESCRIPTION"
echo

# ---- copy template ----
echo "Copying template files..."
# cp -r template/. preserves the dot-files
cp -r "$TEMPLATE_DIR/." "$TARGET_ABS/"

# ---- substitute placeholders ----
echo "Substituting placeholders..."
python - "$TARGET_ABS" "$PROJECT_NAME" "$PROJECT_SLUG" "$DESCRIPTION" <<'PYEOF'
import os, re, sys, pathlib

target, name, slug, desc = sys.argv[1:5]
EXTS = ('.md', '.json', '.sh', '.ts', '.tsx', '.py', '.js', '.cjs', '.toml', '.yaml', '.yml')

subs = [
    (r'\{\{PROJECT_NAME_SLUG\}\}', slug),
    (r'\{\{PROJECT_NAME\}\}', name),
    (r'\{\{PROJECT_DESCRIPTION\}\}', desc),
]

count = 0
for root, _, files in os.walk(target):
    if os.sep + '.git' + os.sep in root + os.sep: continue
    for f in files:
        if not f.endswith(EXTS): continue
        p = pathlib.Path(root) / f
        try:
            text = p.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            continue
        new = text
        for pat, repl in subs:
            new = re.sub(pat, repl, new)
        if new != text:
            p.write_text(new, encoding='utf-8')
            count += 1
print(f"  patched {count} files")
PYEOF

# ---- make hooks executable ----
echo "Making hooks executable..."
chmod +x "$TARGET_ABS/.claude/hooks/"*.sh 2>/dev/null || true
chmod +x "$TARGET_ABS/.husky/"* 2>/dev/null || true

# ---- git init ----
echo "Initializing git repo..."
cd "$TARGET_ABS"
git init -b main >/dev/null 2>&1 || git init >/dev/null 2>&1

# ---- print next steps ----
cat <<EOF

✓ Bootstrap complete.

Next steps:

  cd "$TARGET_ABS"

  # 1. Set git identity if needed:
  git config user.name "Your Name"
  git config user.email "you@example.com"

  # 2. Configure your stack:
  #    - Replace docs/architecture.md template content with your actual architecture
  #    - Write ADR-0001 documenting your foundational layer/pattern choice
  #    - Add language-specific rules to .claude/rules/ (e.g., typescript.md, python.md)
  #      with 'paths:' frontmatter
  #    - Wire stack-specific commands in .claude/hooks/post-tool-typecheck.sh,
  #      post-tool-lint.sh, post-tool-test-changed.sh — they're TODO stubs
  #    - Wire stack-specific commands in .claude/skills/verify-end-to-end/SKILL.md

  # 3. Install commit hooks (when ready):
  pnpm install   # or npm/yarn — installs husky's commit-msg + pre-commit
  # husky's prepare script wires .husky/* into .git/hooks/

  # 4. First commit:
  git add -A
  git commit -m "chore(release): initial scaffold from claude-discipline-template"

  # 5. Your first feature:
  #    Open Claude Code in this directory, type "let's spec out <feature>"
  #    -> /feature-spec auto-fires (per .claude/skill-rules.json)

EOF
