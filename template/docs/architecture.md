# Architecture

> **Template note:** this file is a stub. Replace it with your project's actual architecture. See the bottom of this file for prompts on what to include.

## Top-level layout

```
{{PROJECT_NAME_SLUG}}/
├── (your stack lives here)
```

## Dependency rule

Every architecture has *some* dependency rule. State yours explicitly. Examples:

- **Hexagonal / Ports & Adapters:** dependencies point inward. `domain → application → adapters`. Adapters depend on application (the ports); domain depends on nothing.
- **Layered:** higher layers depend on lower, never the reverse.
- **Vertical-slice:** features don't import from each other; cross-feature reuse goes through `shared/`.
- **MVC / MVVM:** view depends on model; controller orchestrates.

Whatever you pick, the `architecture-reviewer` subagent grades against this file. If a rule isn't written here, it can't enforce.

## Quality attributes (priority order)

When trade-offs arise, decide in this order. Default ordering — adjust to your project:

1. **Correctness** — does it do the right thing?
2. **Maintainability** — can future-you change it without rework?
3. **Testability** — can we test without I/O?
4. **Observability** — when production breaks, can we diagnose?
5. **Performance** — at the scale we expect, is it fast enough?
6. **Resilience** — does the right thing happen on partial failure?

Don't optimize for performance at the cost of correctness or maintainability.

## Decisions and learnings

- Architectural decisions live in `docs/adr/`. Status transitions: Proposed → Accepted → Deprecated/Superseded. Never delete.
- Compound learnings (patterns discovered, not bug instances) live in `docs/solutions/`. Auto-captured by `/compound-learning`; periodically consolidated by `/audit-docs`.
- Brainstorms (option-weighing not yet committed) live in `docs/brainstorms/` and auto-prune at 30 days untouched + not graduated.

---

## What to write here (delete this section once filled in)

When you replace this template with real content, cover:

1. **Top-level layout** — what directories exist, what each owns.
2. **The load-bearing rule** — the one dependency / boundary / convention rule that everything else stems from.
3. **Bounded contexts / feature groupings** — if you adopt DDD or feature-slicing, list the contexts/slices.
4. **Cross-cutting concerns** — auth, persistence, observability, configuration. Note "TBD via ADR" for anything not yet decided.
5. **Quality attribute priority** — explicit ordering for trade-off decisions.
6. **Workflow pointer** — link `docs/workflows/new-feature.md`.

Write ADR-0001 in the same pass to capture the foundational layout decision.
