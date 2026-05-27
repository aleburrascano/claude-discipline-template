# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

## Working in this repo

This repo is set up for Claude-first development. The shape:

- Every feature follows `spec → plan → TDD → verify → review → compound` (see [`docs/workflows/new-feature.md`](docs/workflows/new-feature.md))
- Specs live in `docs/specs/<feature>/`, ADRs in `docs/adr/`, learnings in `docs/solutions/`
- Skills/agents/hooks under `.claude/` enforce discipline (see [`docs/claude-md-map.md`](docs/claude-md-map.md))

## Quick reference

| Goal | Where |
|---|---|
| Add a new feature | `/feature-spec <name>` then follow [`docs/workflows/new-feature.md`](docs/workflows/new-feature.md) |
| Fix a bug | [`docs/workflows/bug-fix.md`](docs/workflows/bug-fix.md) |
| Refactor | [`docs/workflows/refactor.md`](docs/workflows/refactor.md) |
| Decide an architecture question | `/brainstorm-tech-choice` → ADR in `docs/adr/` |

## Conventions

- Commits: [Conventional Commits](https://www.conventionalcommits.org/) (template in `.gitmessage`, enforced by commitlint)
- No `Co-Authored-By: Claude` lines — stripped by `.husky/commit-msg`
- Tests are **sacred** — fix implementation to match tests, not the reverse
- Document decisions in [`docs/adr/`](docs/adr/)
- Capture learnings in [`docs/solutions/`](docs/solutions/) via `/compound-learning`

## Layout

```
.
├── CLAUDE.md                  # project constitution (lean — see ~/.claude/CLAUDE.md for universal rules)
├── .claude/                   # skills · agents · hooks · path-scoped rules
├── docs/
│   ├── architecture.md
│   ├── ubiquitous-language.md
│   ├── workflows/             # new-feature, bug-fix, refactor playbooks
│   ├── specs/                 # one folder per feature
│   ├── adr/                   # architecture decision records
│   ├── solutions/             # compound-engineering learnings
│   ├── brainstorms/           # expirable exploration (30d TTL)
│   └── notes/                 # permanent (won't auto-prune)
└── (your stack lives here — apps/, services/, src/, whatever fits)
```

## Status

`v0.0.0` — scaffolded from claude-discipline-template. No features yet.

## Next steps

1. **Define your stack.** Add `apps/` or `services/` (or `src/`, `pkg/`, whatever your stack uses) — there's no opinion baked in.
2. **Adapt `.claude/rules/`.** The template includes `vault-consultation.md` (generic) and `tests.md` (generic). Add language-specific rules (`typescript.md`, `python.md`, etc.) with `paths:` frontmatter so they only load when Claude reads matching files.
3. **Wire stack-specific commands** in the hooks marked `TODO:` — `post-tool-typecheck.sh`, `post-tool-lint.sh`, `post-tool-test-changed.sh`, `verify-end-to-end` skill.
4. **Pick your architectural ADR (ADR-0001).** Document the layering / pattern you're committing to so the `architecture-reviewer` subagent knows what to grade against.
5. **`/feature-spec`** your first feature when ready.
