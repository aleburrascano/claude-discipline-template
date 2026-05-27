---
name: verify-end-to-end
description: |
  ALWAYS fires after writing or modifying production code. ALSO fires when the user says
  "verify", "make sure it works", "did that break anything", "test that", "run the tests",
  or any variant of "is X working". Runs the project's verification stack (typecheck + lint +
  unit + integration + slice-affecting e2e) and reports each phase's actual output. Does NOT
  claim "works" without showing test output. Also fires from the Stop hook self-review.
when_to_use: |
  Use after any non-trivial code change. Use before /code-review-6-aspect. Use as part of stop-self-review.
---

# Verify end-to-end

## What this skill does

Runs a layered verification stack and reports actual output per phase. Never claims a phase passed without showing the output.

## The phases

Run in this order; bail on first failure (but report what you bailed on, not silently).

### 1. Typecheck

<!-- TODO: replace with your project's typecheck command(s).
     Examples:
       Python (mypy):     uv run mypy src tests
       TypeScript (tsc):  pnpm tsc --noEmit
       Go (go vet):       go vet ./...
       Rust (cargo):      cargo check -->

| Stack | Command |
|---|---|
| (your stack) | `TODO` |

### 2. Lint

<!-- TODO:
       Python:     uv run ruff check src tests
       TypeScript: pnpm eslint src
       Go:         golangci-lint run
       Rust:       cargo clippy -->

| Stack | Command |
|---|---|
| (your stack) | `TODO` |

### 3. Format check (non-blocking warning if dirty)

<!-- TODO:
       Python:     uv run ruff format --check
       TypeScript: pnpm prettier --check
       Go:         gofmt -l .
       Rust:       cargo fmt --check -->

### 4. Unit tests

<!-- TODO:
       Python:     uv run pytest tests/unit -q
       TypeScript: pnpm jest
       Go:         go test ./...
       Rust:       cargo test -->

### 5. Integration tests (only if code touched I/O adapters / external services)

<!-- TODO: project-specific command. -->

### 6. E2E (only if code reaches an end-to-end path)

<!-- TODO: project-specific command, scoped to the affected slice. -->

E2E is scoped to the affected slice; we don't run the whole suite on every change (too slow).

## Output format

Report per phase:

```
✓ Typecheck: passed (0 errors)
✓ Lint:      passed (0 issues)
✗ Unit:      2 failures
  tests/unit/foo/test_bar.py::test_baz
  tests/unit/foo/test_bar.py::test_quux
  (full output below)
…
```

Always include full output for failures. Never paraphrase.

## When all green

State explicitly: **"All verification passed: typecheck · lint · unit · integration · e2e."**

When failing, do NOT continue to the next phase silently. Either:
- Fix and re-run, OR
- Report and ask user how to proceed.

## Anti-patterns

- "Looks right" / "should work" — banned unless backed by actual test output.
- Skipping integration tests when adapter code changed.
- Running tests but only showing the summary line. Failures need full traceback.
- Using this skill before filling in the TODOs above — the skill is template-only until you wire your stack's commands.
