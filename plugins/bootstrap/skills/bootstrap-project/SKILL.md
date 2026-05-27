---
name: bootstrap-project
description: |
  ALWAYS fires when the user invokes /bootstrap-project, /scaffold, /init-project, or asks
  "set up a new project with this discipline", "scaffold a new <something>", "let's start a
  fresh project". Drives an interactive Q&A flow (project name, stack, architecture, rigor)
  then writes a tailored .claude/ + docs/ + root-config scaffold to the current working
  directory. End state: a project that runs the spec→plan→TDD→verify→review→compound loop
  out of the box, with stack-specific rules + hooks already filled in (zero TODO stubs for
  covered stacks).
when_to_use: |
  Use ONCE per new project, at init time. Run from inside an empty directory (where the new
  project should live). The skill writes files to the cwd; it does not create the directory.
disable-model-invocation: false
allowed-tools: Read, Write, Edit, Glob, Bash, AskUserQuestion
---

# bootstrap-project

Interactive scaffolder. Asks the user about their project (name, stack, architecture, rigor), then writes a fully-tailored Claude-discipline scaffold to the current working directory.

## Pre-flight

Before asking any questions, verify and report:

1. **`cwd` is empty (or only contains `.git/`).** If not, STOP and tell the user: "This directory contains files. Bootstrap into an empty directory (or remove existing files first)." List the conflicting top-level entries.
2. **`cwd` is a real path** (not a temp/scratch dir Claude is running from). Confirm with the user: "Bootstrapping into `<absolute-path>`. Correct?" Wait for confirmation.

Skip pre-flight only if the user has explicitly said "yes, overwrite" or "I know what I'm doing — proceed".

## Q&A flow

Use `AskUserQuestion` for each step. **Ask ONE question per `AskUserQuestion` call** (max 4 questions per call, but each step is conceptually one decision). Don't bundle unrelated questions.

### Step 1 — Project identity (no AskUserQuestion needed if user already provided in invocation)

Ask the user for, in a single message:
- **Project name** (human-readable, e.g., "My Cool App")
- **One-line description**

If the user invoked the skill with these already inline ("/bootstrap-project for a music manager called Altune"), parse and confirm rather than re-asking.

Compute slug: lowercase, kebab-case, alnum + dashes only.

### Step 2 — Backend language

```
question: "What's the primary backend language?"
header: "Backend"
options:
  - "Python (FastAPI + uv + ruff + mypy + pytest)"
  - "TypeScript / Node (Fastify or Hono + tsx + ESLint + Vitest)"
  - "Go (stdlib + go vet + golangci-lint + go test)"           # v0.1: TODO-stub fallback
  - "Rust (axum or actix + cargo clippy + cargo test)"         # v0.1: TODO-stub fallback
  - "None / frontend-only project"
```

Note in your reasoning which stacks are **fully covered** (Python, TypeScript) vs **stub-only** (Go, Rust) in this v0.1. Tell the user when you fill in the stub case that some hooks will have TODOs they'll need to wire later.

### Step 3 — Frontend

```
question: "Frontend?"
header: "Frontend"
options:
  - "Expo (React Native + TypeScript)"
  - "Next.js (React + TypeScript)"
  - "Vite + React"
  - "None / backend-only project"
```

### Step 4 — Database (if backend ≠ frontend-only)

```
question: "Database?"
header: "Database"
options:
  - "Postgres (recommended for prod)"
  - "SQLite (recommended for solo / local-first)"
  - "MongoDB"
  - "None / decide later (writes a deferred-decision ADR)"
```

### Step 5 — Architecture pattern

Skip if backend is "None / frontend-only".

```
question: "Backend architecture pattern?"
header: "Architecture"
options:
  - "Hexagonal / Ports & Adapters (Recommended for production-grade)"
  - "Layered (Controller → Service → Repository)"
  - "Vertical-slice (feature folders end-to-end)"
  - "None / decide manually (I'll write ADR-0001 myself)"
```

Pull the recommendation text from `[vault: wiki/concepts/Hexagonal Architecture.md]` if the user has the software-architecture-design vault MCP connected.

### Step 6 — Rigor level

```
question: "How strict should the workflow guardrails be?"
header: "Rigor"
options:
  - "Maximum (TDD-Guard hook BLOCKS edits without failing test; mandatory plan mode for non-trivial work)"
  - "Pragmatic (TDD-Guard WARNS but doesn't block; plan mode encouraged not forced) (Recommended)"
  - "Lean (no TDD-Guard, no plan-mode pressure; just spec → implement → verify)"
```

### Step 7 — Confirmation

Summarize all answers back to the user as a single confirmation: "Going to write a `<name>` project with `<stack>` backend, `<frontend>`, `<db>`, `<arch>` layout, `<rigor>` rigor. Total files: ~X. Proceed? (yes / change Y to Z)"

Wait for explicit "yes" / "proceed" / "go". If user wants to change something, return to that step.

## Generation flow

After confirmation, write files in this order:

1. **Root configs** (`CLAUDE.md`, `README.md`, `.gitignore`, `.gitattributes`, `.editorconfig`, `.gitmessage`, `commitlint.config.js`, `package.json`, `.husky/{commit-msg,pre-commit}`).
2. **`.claude/` core** (`settings.json`, `skill-rules.json`, generic rules: `vault-consultation.md` + `tests.md`).
3. **`.claude/skills/`** — all 13 generic skills.
4. **`.claude/agents/`** — all 10 generic agents.
5. **`.claude/hooks/`** — all generic hooks + the stack-specific hooks (typecheck/lint/test) filled in for the chosen language.
6. **Stack-specific overlay** (if covered):
   - Add `.claude/rules/{language}-frontend.md` or `{language}-backend.md`.
   - Add `.claude/agents/{language}-expert.md`.
   - Adjust `.claude/hooks/post-tool-typecheck.sh`, `post-tool-lint.sh`, `post-tool-test-changed.sh` with real commands.
7. **Architecture overlay** (if chosen ≠ None):
   - Add layer-specific rules (`.claude/rules/{domain,application,adapters}-layer.md` for hexagonal; equivalents for other patterns).
   - Add `.claude/agents/domain-modeler.md` for hexagonal/DDD-friendly architectures.
   - Write `docs/architecture.md` reflecting the chosen pattern (not the template stub).
   - Write `docs/adr/0001-<pattern-name>.md` documenting the choice with rationale.
8. **Rigor overlay**:
   - If "Maximum": ensure `.claude/hooks/pre-tool-tdd-guard.sh` is wired to BLOCK (exit 2).
   - If "Pragmatic": switch the same hook to warn-only (exit 0 with `additionalContext`).
   - If "Lean": exclude `pre-tool-tdd-guard.sh` entirely.
9. **`docs/`** — workflows, templates, glossary stub, brainstorm/notes placeholders.
10. **Optional deferred-decision ADRs** for any "decide-later" choices (DB, auth, etc.). Each as `docs/adr/000N-deferred-<topic>.md`.
11. **`commitlint.config.js`** — pre-populate `scope-enum` with layer scopes from the chosen architecture (e.g., `domain`, `application`, `adapters`, `platform` for hexagonal).

After writing, run `git init` and `chmod +x` on hooks if on Unix-like.

## Template paths

Templates live in this skill's bundle at `${CLAUDE_PLUGIN_ROOT}/content/`:

- `${CLAUDE_PLUGIN_ROOT}/content/core/` — always-copied
- `${CLAUDE_PLUGIN_ROOT}/content/stacks/<stack>/` — stack-specific overlay
- `${CLAUDE_PLUGIN_ROOT}/content/architectures/<pattern>/` — architecture-specific overlay
- `${CLAUDE_PLUGIN_ROOT}/content/rigor/<level>/` — rigor-specific overlay

Use `Read` to read each template file, substitute placeholders (`{{PROJECT_NAME}}`, `{{PROJECT_NAME_SLUG}}`, `{{PROJECT_DESCRIPTION}}`, plus stack/arch-specific ones like `{{LANG_TYPECHECK_CMD}}`), then `Write` to the user's cwd.

## Report

After all writes:

```
✓ Bootstrap complete.

Created: <total> files across <core / stack / arch / rigor> overlays
Stack:        <chosen>
Architecture: <chosen>
Rigor:        <chosen>

Deferred decisions logged as ADRs:
  - docs/adr/0001-<pattern>.md (Accepted)
  - docs/adr/0002-deferred-database.md (Proposed)  [if applicable]
  - docs/adr/0003-deferred-auth.md (Proposed)      [if applicable]

Next steps:
1. Review and customize docs/architecture.md
2. Set git identity: git config user.name "..." && git config user.email "..."
3. Install: pnpm install (wires husky hooks)
4. First commit: git add -A && git commit
5. Your first feature: type "let's spec out <feature-name>" → /feature-spec auto-fires
```

## Anti-patterns

- **Bulk-asking everything at once.** Use the Q&A flow above; let the user think one decision at a time.
- **Writing files before confirmation.** Always summarize and confirm before generation.
- **Generating into a non-empty directory** without explicit user override.
- **Skipping the architecture ADR** for non-trivial picks. The ADR documents WHY the chosen pattern is correct for this project; it's the most reusable artifact.
- **Pretending Go/Rust are covered in v0.1.** Be honest: tell the user when hooks will have TODOs they need to fill in for their stack.
