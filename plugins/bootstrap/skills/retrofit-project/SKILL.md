---
name: retrofit-project
description: |
  ALWAYS fires when the user invokes /retrofit-project, /setup-discipline, or says
  "add discipline to this existing project", "retrofit this project", "set up Claude
  discipline here", "wire the spec workflow into this codebase", or any variant
  meaning *the cwd already has a project, add the discipline non-destructively*.

  Sibling to /bootstrap-project. Difference: bootstrap assumes EMPTY cwd and writes
  fresh; retrofit assumes a LIVE project and merges additively. Auto-detects stack
  (Next.js / Expo / Vite / FastAPI / Django / Go / Rust / etc.) from package.json /
  pyproject.toml / go.mod / Cargo.toml and uses the detections to pre-fill Q&A
  answers. Never overwrites existing files without asking. Ends with the same
  spec→plan→TDD→verify→review→compound workflow available, tailored to what's there.
when_to_use: |
  Use ONCE per existing project, at retrofit time. If cwd is empty (no package.json,
  pyproject.toml, etc.), STOP and tell the user to use /bootstrap-project instead.
disable-model-invocation: false
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# retrofit-project

Add Claude-discipline to an **existing** project. Auto-detect stack from files, confirm with user, then additively merge skills + agents + hooks + docs scaffold without clobbering the friend's work.

## Pre-flight

1. **`cwd` has a real project.** Look for one of: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml`, `*.csproj`. If NONE found → STOP and say: "This directory doesn't look like a project. Use /bootstrap-project for a fresh start, or `cd` into the actual project root."

2. **Confirm cwd.** Print absolute path. "Retrofitting into `<path>`. Correct?" Wait for yes.

3. **Inventory what already exists.** Glob for: `CLAUDE.md`, `.claude/`, `docs/`, `.husky/`, `commitlint.config.*`, `.gitmessage`. List what's present. Don't be alarmed — that's the point of retrofit.

## Step 1 — Auto-detect

Read files in parallel; build an inferred-stack picture:

| Detection target | How |
|---|---|
| Project name | `package.json#name` or `pyproject.toml#[project].name` or `go.mod`'s module path or `Cargo.toml#[package].name` |
| Project description | `package.json#description` or `pyproject.toml#[project].description` |
| Backend lang | Presence of `pyproject.toml`/`setup.py` → Python · `go.mod` → Go · `Cargo.toml` → Rust · `package.json` with server framework dep → TS/Node |
| Backend framework | Dependency names in package.json/pyproject.toml: `fastapi`, `django`, `flask` (Python); `fastify`, `hono`, `express`, `nestjs` (Node) |
| Frontend framework | `next` → Next.js · `expo` → Expo · `vite` → Vite · `react` w/o others → CRA-style |
| TypeScript | `tsconfig.json` exists |
| Test framework | `jest.config.*` → Jest · `vitest.config.*` → Vitest · `pyproject.toml#[tool.pytest]` → pytest · `go.mod` → go test |
| Linter | `eslint.config.*` / `.eslintrc.*` → ESLint · `pyproject.toml#[tool.ruff]` → Ruff |
| Typechecker | `tsconfig.json` → tsc · `pyproject.toml#[tool.mypy]` → mypy |
| Package manager | `pnpm-lock.yaml` → pnpm · `yarn.lock` → yarn · `package-lock.json` → npm · `uv.lock` → uv · `poetry.lock` → poetry |
| Architecture hint | Look for dirs `domain/` + `application/` + `adapters/` → likely hexagonal; `features/<x>/` slices → vertical-slice; `controllers/`+`services/`+`models/` → layered |
| Database | Dependencies: `pg`/`postgres` → Postgres; `better-sqlite3`/`sqlite` → SQLite; `@supabase/supabase-js` → Supabase; `mongodb`/`mongoose` → MongoDB; `prisma` → Prisma (note: ORM, not DB) |

Surface all detections as a single block:

```
Detected:
  name:              <name>
  description:       <desc>
  backend:           <lang/framework | none>
  frontend:          <framework | none>
  package manager:   <pm>
  test framework:    <tf>
  linter:            <lint>
  typechecker:       <tc>
  architecture hint: <hex|vs|layered|unclear>
  database hint:     <db|none|orm-only>
```

## Step 2 — Confirm + override

Use AskUserQuestion to confirm detections OR override. Don't ask anew if confident; just confirm the bundle. Example:

```
question: "Detected: Next.js + TypeScript + Vitest + ESLint + Supabase. Architecture not auto-detectable. Confirm & continue, or override?"
options:
  - "Confirm + ask remaining (architecture, rigor)"
  - "Override one or more (will ask which)"
  - "Cancel — I'll fix files first"
```

If "Override": ask which fields (multiSelect) and re-ask each.

## Step 3 — Architecture choice

Always ask (can't reliably auto-detect):

```
question: "What architecture pattern does this project use (or should adopt)?"
options:
  - "Hexagonal / Ports & Adapters"
  - "Layered (Controller → Service → Repository)"
  - "Vertical-slice (feature folders end-to-end)"
  - "MVC / standard framework default (Next.js routes, Django apps, etc.)"
  - "None / don't add architecture rules — just the workflow + skills"
```

If the auto-detect surfaced a hint, mark it `(detected)`.

## Step 4 — Rigor level

```
question: "Workflow rigor?"
options:
  - "Maximum (TDD-Guard hook BLOCKS writes without failing test)"
  - "Pragmatic (TDD-Guard WARNS only) (Recommended for retrofits)"
  - "Lean (no TDD-Guard; spec → implement → verify only)"
```

Pragmatic is recommended for retrofits because existing code rarely has the test coverage to back maximum-rigor.

## Step 5 — Inventory + per-file merge plan

Now read every target path the bootstrap would write to and classify:

| State | Action |
|---|---|
| **Missing** (target file doesn't exist) | Will WRITE (no prompt) |
| **Present + identical** | Will SKIP, report "identical" |
| **Present + differs** | Will PROMPT per-file: `[m]erge (show diff, you decide each section), [s]kip, [r]eplace (backup existing first), [k]eep both as .new` |

Build the list. Show summary BEFORE writing:

```
Retrofit plan:
  New files to add:                    34
  Files identical (no change):          2
  Files differing (will prompt each):   3
    - CLAUDE.md
    - .gitignore
    - tsconfig.json (skipping — yours stays)
  Backups go to: .claude-retrofit-backup-<timestamp>/

Proceed? (yes / cancel)
```

## Step 6 — Write

Same overlay logic as bootstrap-project:

1. **Core** (always) — `.claude/skills/` (13 skills), `.claude/agents/` (10 generic), `.claude/hooks/` (12 hooks), `docs/workflows/`, `docs/specs/_template/`, `docs/adr/_template/`, `docs/solutions/`, etc.
2. **Stack overlay** based on detected/confirmed stack — `.claude/rules/<lang>.md`, `.claude/agents/<lang>-expert.md`, fill in stack-specific hooks (typecheck/lint/test).
3. **Architecture overlay** based on choice — `.claude/rules/{domain,application,adapters}-layer.md` for hexagonal, etc.; `docs/architecture.md`; `docs/adr/0001-<arch>.md`.
4. **Rigor overlay** — adjust `pre-tool-tdd-guard.sh` block/warn behavior or remove from settings.

For each file that differs, prompt the user. The default (no answer) is SKIP (safest).

## Step 7 — Existing-file merge rules

**CLAUDE.md merge** — most fragile. Two cases:

- If their CLAUDE.md is **short** (≤30 lines) and looks like project info → APPEND our standard sections (Skill auto-activation pointer, Nested context pointer, Commit discipline reminder) below their content. Tell them what was added.
- If their CLAUDE.md is **long** (>30 lines) → don't auto-merge. Write our version to `CLAUDE.md.proposed` and tell them to diff manually.

**`.gitignore`** — append our entries that aren't already present (search line-by-line). Don't replace.

**`.gitattributes`, `.editorconfig`, `.gitmessage`** — if absent, write ours. If present, leave theirs alone (cosmetic; their choices stand). Note in report.

**`commitlint.config.js`** — if absent, write ours with their architecture's layer scopes. If present, don't touch — risks breaking their existing commit lint.

**`.husky/`** — install our hooks only if `.husky/` is absent OR add ours as additional husky files if present (without modifying their existing hooks). Report what we added.

**`package.json` / `pyproject.toml`** — NEVER modify. If we need a dependency for our hooks (husky, commitlint), tell the user the exact npm/uv command to run.

**`tsconfig.json` / framework configs** — NEVER modify. Their build setup is theirs.

## Step 8 — Report

```
✓ Retrofit complete.

Wrote: <N> new files
Skipped (identical): <N>
Merged: <N> files (.gitignore appended, CLAUDE.md appended)
Replaced (with backup): <N>
Kept both as .new: <N>

Backups: .claude-retrofit-backup-<timestamp>/

You'll need to:
1. Install husky + commitlint (if not already): pnpm add -D husky @commitlint/cli @commitlint/config-conventional
   Then: pnpm exec husky install
2. Review the proposed CLAUDE.md.proposed (if generated) and merge manually.
3. Some hooks have stack-specific commands that may need adjustment for your exact tooling:
   - .claude/hooks/post-tool-{typecheck,lint,test-changed}.sh
   - Generated by Q&A detections; check they match your `package.json scripts` / `pyproject.toml`.
4. Your first feature on the new workflow: type "let's spec out <feature>" — /feature-spec auto-fires.

Quick reference of what's now available:
  /feature-spec <name>          — write a spec for a new feature
  /feature-plan <name>          — decompose spec into vertical slices
  /tdd-red-green-refactor       — per-slice RED-GREEN-REFACTOR
  /verify-end-to-end            — typecheck + lint + test
  /code-review-6-aspect         — pre-merge 6-aspect parallel review
  /brainstorm-tech-choice       — vault-grounded option weighing
  /adr-write                    — architecture decision record
  /compound-learning            — capture session learnings
  /audit-docs                   — quarterly doc hygiene sweep
```

## Anti-patterns

- **Overwriting existing files silently.** Always prompt on diff.
- **Modifying `package.json` / `pyproject.toml` / framework configs.** The friend's build setup is theirs.
- **Assuming the user wants the same architecture they appear to already have.** Always ask in Step 3; the detection is a hint, not a verdict.
- **Forcing maximum rigor on a retrofit.** Existing code rarely passes; pragmatic is the safe default.
- **Skipping the inventory preview before writing.** The user needs to see the plan before files start landing.

## Template paths

Same as bootstrap-project: `${CLAUDE_PLUGIN_ROOT}/content/{core,stacks/<stack>,architectures/<pattern>}/`. The Read+Write+placeholder-substitution loop is identical — only the safety logic (per-file prompt on diff) differs.
