---
description: Bootstrap hallucination-reduction and context engineering layers for the current project — creates a lean CLAUDE.md and .claude/rules/ files scoped to load only when relevant
---

You are setting up the hallucination-reduction and context engineering stack for this project. Work through the following steps in order.

## Step 1 — Detect project type

Scan the working directory for these files and record what you find:

- `package.json` → Node/TypeScript/JavaScript
- `Cargo.toml` → Rust
- `go.mod` → Go
- `pyproject.toml` / `setup.py` / `pytest.ini` → Python
- `*.sln` / `*.csproj` → .NET
- None found → generic (leave test/build commands blank for the user to fill in)

For the detected type, identify:
- Test command (`npm test`, `cargo test`, `go test ./...`, `pytest`, `dotnet test`)
- Build command (`npm run build`, `cargo build`, `go build ./...`, etc.)
- Lint command (`npx eslint`, `cargo clippy`, `golangci-lint run`, `ruff check .`, etc.)
- Source file glob (`src/**/*.{ts,tsx}`, `src/**/*.rs`, `**/*.go`, `**/*.py`, etc.)

## Step 2 — Check for existing files

Before creating anything:

- Check if `CLAUDE.md` or `.claude/CLAUDE.md` exists. If it does, read it and merge new sections without duplicating what's already there.
- Check if `.claude/rules/` exists. If it does, only create the files that don't already exist.
- Check if `.claude/settings.json` exists. If it does, merge — do not overwrite.

Report what you found and what you'll be creating vs. merging.

## Step 3 — Create lean project CLAUDE.md

Create `CLAUDE.md` at the project root (or merge into the existing one). Target: ≤40 lines. Only include what's true on every single turn — nothing project-specific that only applies sometimes (that goes in `.claude/rules/` in Step 4).

Use this template, filling in detected values:

```markdown
# CLAUDE.md — [project name or directory name]

## Project
[1-2 sentences: what this project does. Leave blank if unknown — user will fill in.]

## Commands
test:  [detected test command, or blank]
build: [detected build command, or blank]
lint:  [detected lint command, or blank]

## Hard Rules
[Non-negotiable constraints for this project. Leave as comment if unknown.]
[Example: Never modify migration files once shipped.]
[Example: No TypeScript `any` — use `unknown` and narrow.]

## Standing Workflows
- Bug fix: write a failing test that reproduces the bug first. Show it fail. Fix it. Show it pass. Run full suite.
- Feature: run full test suite before and after.
- Refactor: confirm all tests pass before touching anything; confirm they still pass after.

## Known Hallucination Patterns
@.claude/rules/hallucination-patterns.md
```

The `@.claude/rules/hallucination-patterns.md` import pulls in captured patterns on demand. It starts empty — the user fills it in over time using `/ce-compound` after any hallucination slips through.

## Step 4 — Create .claude/rules/ files

Create the `.claude/rules/` directory and the following four files. These are lazy-loaded — they only enter context when relevant, saving tokens on every unrelated turn.

**`.claude/rules/testing.md`** — no `paths:` frontmatter, loads with every session for this project:

```markdown
# Testing Rules

Test runner: [detected, e.g. npm test / pytest / cargo test / go test ./...]
Test file locations: [detected, e.g. __tests__/, tests/, src/**/*.test.ts]

- Write tests before implementation (TDD Guard enforces this globally)
- Sacred tests: never rewrite a test to make it pass — fix the implementation
- After fixing a bug: the regression test must exist before the fix is applied
```

**`.claude/rules/domain-language.md`** — no `paths:` frontmatter, always loaded:

```markdown
# Domain Language

[Fill in as you work. One line per term.]
[Format: "term" = what it means specifically in this codebase, NOT the generic meaning]
[Example: "job" = a background task entry in the queue table, not a generic concept]
[Example: "user" = an authenticated customer; admins are "operators"]

Run /common-ground at the start of each session to surface assumptions about this domain.
```

**`.claude/rules/code-style.md`** — WITH `paths:` frontmatter for the detected language, lazy-loaded only when Claude reads matching files:

```markdown
---
paths:
  - "[detected source glob, e.g. src/**/*.{ts,tsx} or **/*.py or src/**/*.rs]"
  - "[detected test glob, e.g. tests/**/*.test.ts or tests/**/*.py]"
---

# Code Style — [detected language]

[Fill in project-specific style rules.]
[Example for TypeScript: strict mode on, no any, zod for runtime validation, named exports only]
[Example for Python: black formatting, type annotations required, no bare except]
[Example for Rust: clippy::all enabled, no unwrap() in library code]
```

**`.claude/rules/hallucination-patterns.md`** — no `paths:` frontmatter, imported by CLAUDE.md:

```markdown
# Hallucination Patterns

[This file captures recurring mistakes so future sessions don't repeat them.]
[Run /ce-compound after any hallucination slips through to add entries here.]
[Format: "Claude assumes X — reality is Y. Trigger: when doing Z."]

[Empty until patterns emerge — that's correct.]
```

## Step 5 — Create project .claude/settings.json

Create `.claude/settings.json` if it doesn't exist, or merge into it if it does. This adds project-level hooks on top of the global ones — it does not replace them.

Base template:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/test-changed.sh"
          }
        ]
      }
    ]
  }
}
```

If the project is TypeScript/JavaScript, also add the typecheck hook:

```json
{
  "type": "command",
  "command": "$HOME/.claude/hooks/typecheck-changed.sh"
}
```

## Step 6 — Report

Print a summary:

1. **Project type detected:** [what you found]
2. **Files created:** list each file and one sentence on what it does
3. **Files merged:** list each file and what you added vs. left alone
4. **Next steps for the user:**
   - Fill in `CLAUDE.md` → Project section (what the project does)
   - Fill in `CLAUDE.md` → Hard Rules (non-negotiable constraints)
   - Fill in `.claude/rules/domain-language.md` as terms emerge
   - Fill in `.claude/rules/code-style.md` with project style rules
   - Run `/common-ground` now to surface Claude's current assumptions about the project
   - Run `/ce-compound` after any hallucination slips through to populate `hallucination-patterns.md`
