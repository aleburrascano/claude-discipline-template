---
paths:
  - "**/tests/**"
  - "**/__tests__/**"
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.test.js"
  - "**/*.test.jsx"
  - "**/*_test.py"
  - "**/test_*.py"
  - "**/*_test.go"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
---

# Tests — sacred and load-bearing

## Sacred-tests rule

Tests are **read-only** unless the prompt explicitly says "modify the test." Default behavior on a failing test: **fix the implementation to match the test**, not the other way around.

If the test really is wrong, you must:
1. State explicitly: "the test is wrong because <reason>"
2. Ask the user to confirm before modifying
3. Include the rationale in the commit body (`fix(tests): <what> — <why test was wrong>`)

The `pre-tool-file-guard` hook blocks edits to test files unless the active prompt contains `[ALLOW-TEST-EDIT: <reason>]`.

## Layout

Mirror the source structure. Examples:
- Python: `src/<pkg>/foo.py` → `tests/unit/<pkg>/test_foo.py`
- TypeScript: `src/features/<feat>/foo.ts` → `src/features/<feat>/__tests__/foo.test.ts`
- Go: `pkg/foo.go` → `pkg/foo_test.go` (same dir)

Use `tests/unit/`, `tests/integration/`, `tests/e2e/` (or your language's equivalent) so the verify pipeline can target each layer.

## Structure (AAA)

```
test_<thing>_<expected_behavior>:
  # Arrange — set up the state
  ...
  # Act — perform the operation
  ...
  # Assert — verify the outcome
  ...
```

One assertion concept per test (multiple assert lines OK if they're the same concept).

## Test doubles

Consult [vault: wiki/concepts/Test Double.md]. Choose the right kind:

- **Fake** — working implementation simpler than production (e.g., `InMemoryRepository`). **Default choice for unit tests.**
- **Stub** — returns canned data for a specific test scenario.
- **Mock** — verifies *interactions* (calls/args). Use sparingly — overuse couples tests to implementation.
- **Spy** — records calls + has real behavior. Niche.

## Coverage targets

Set these for YOUR project. Defaults to aim for:

- **Pure business logic (domain / model layer):** 90%+ line + branch
- **Application / use cases:** 90%+
- **Adapters / I/O layer:** 70%+ (integration tests cover most paths)
- **UI / view layer:** meaningful tests on interactive logic; don't chase coverage on pure presentational components

## Property-based testing

For invariant-heavy code, use a property-based testing library (Hypothesis for Python, fast-check for TS, proptest for Rust). See [vault: wiki/concepts/Property-Based Testing.md].

## Naming

- Names describe behavior, not implementation.
  - Good: `test_track_play_count_increments_on_register_play`
  - Bad: `test_register_play_method`

## Anti-patterns

- Testing the framework (don't write tests that just exercise the ORM's behavior).
- Vacuous assertions (`assert True`, `assert result is not None` and nothing else).
- Tests that mutate shared state without cleanup.
- Tests with `sleep(N)` waiting for async behavior — use proper awaits or event-driven sync.
- Snapshot tests for non-deterministic output.
