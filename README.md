# claude-discipline

A **Claude Code plugin** that interactively scaffolds production-grade discipline into a new project: skills, agents, hooks, path-scoped rules, workflows, doc templates, ADRs — all tailored to your specific stack + architecture + rigor level.

You answer ~6 questions in chat; the plugin writes ~50–80 files customized to your picks. No TODO stubs for covered stacks.

## Install

```
# In Claude Code, in any directory:
/plugin marketplace add aleburrascano/claude-discipline-template
/plugin install claude-discipline@aleburrascano/claude-discipline-template
```

## Use

```
cd ~/projects/my-new-thing      # empty directory where the new project will live
/bootstrap-project              # plugin's only user-facing skill — kicks off Q&A
```

The skill asks you about:

1. **Project name + description** (free text)
2. **Backend language** — Python · TypeScript/Node · Go · Rust · None
3. **Frontend** — Expo · Next.js · Vite + React · None
4. **Database** — Postgres · SQLite · MongoDB · None / decide later
5. **Architecture pattern** — Hexagonal · Layered · Vertical-slice · None / manual
6. **Rigor level** — Maximum (TDD-Guard blocks) · Pragmatic (TDD-Guard warns) · Lean (no TDD-Guard)

Then it writes:

- `CLAUDE.md` (project constitution, tailored to your architecture)
- `.claude/{settings.json, skill-rules.json}` (hooks wired to your rigor level)
- `.claude/rules/` (vault-consultation + tests, plus stack-specific + architecture-specific rules)
- `.claude/skills/` (13 generic skills: feature-spec, feature-plan, TDD, verify, 6-aspect review, ADR, common-ground, brainstorm-tech-choice, compound-learning, git-commit, audit-docs, doc-freshness, nested-CLAUDE.md updater)
- `.claude/agents/` (10 generic reviewers + stack-specific expert if applicable + domain-modeler if architecture is hexagonal/DDD)
- `.claude/hooks/` (12 hooks; typecheck/lint/test filled in with your stack's commands — `pnpm exec tsc`, `uv run mypy`, etc.)
- `.husky/{commit-msg, pre-commit}` (commit-msg strips `Co-Authored-By: Claude` lines; pre-commit blocks secrets)
- `commitlint.config.js` (with scope-enum prepopulated for your chosen architecture's layer names)
- `docs/architecture.md` (real content reflecting your architecture choice, not a stub)
- `docs/adr/0001-<arch>.md` (Accepted, with rationale + alternatives + vault references)
- `docs/adr/000N-deferred-<topic>.md` (Proposed, for any "decide-later" choices like DB or auth)
- `docs/{ubiquitous-language, claude-md-map, workflows/{new-feature,bug-fix,refactor}, specs/_template, adr/_template, solutions/{_template,INDEX.md}, brainstorms/, notes/}` (the full docs scaffold)

After it finishes, run `git init` (or it does for you), `pnpm install` to wire husky, and start your first feature with `/feature-spec`.

## What this plugin distributes (top-level)

```
claude-discipline-template/
├── .claude-plugin/
│   └── plugin.json                  # plugin manifest
├── skills/
│   └── bootstrap-project/SKILL.md   # the one user-facing skill; runs Q&A then writes
├── content/                         # raw templates the bootstrap skill reads from
│   ├── core/                        # always-written discipline (61 files)
│   ├── stacks/
│   │   ├── typescript/              # TS rules + expert agent + filled-in hooks
│   │   └── python/                  # Python rules + expert agent + filled-in hooks
│   └── architectures/
│       ├── hexagonal/               # layer rules + domain-modeler agent + ADR-0001 + architecture.md
│       ├── layered/                 # ADR-0001 + (TODO: layer rules)
│       └── vertical-slice/          # ADR-0001 + (TODO: layer rules)
├── README.md, LICENSE, .gitignore
```

## Coverage matrix (v0.2)

| Stack \ Arch | Hexagonal | Layered | Vertical-slice | None / manual |
|---|---|---|---|---|
| **Python** | ✅ Full | ⚠️ Partial (ADR only) | ⚠️ Partial (ADR only) | ✅ Full |
| **TypeScript** | ✅ Full | ⚠️ Partial (ADR only) | ⚠️ Partial (ADR only) | ✅ Full |
| **Go** | 🚧 Stubs only | 🚧 | 🚧 | 🚧 |
| **Rust** | 🚧 Stubs only | 🚧 | 🚧 | 🚧 |

**Full** = stack-specific rules + language-expert subagent + filled-in hooks (no TODOs) + tailored ADR.
**Partial** = ADR + generic discipline; some hook stubs remain.
**Stubs only** = generic discipline + TODO stubs you fill in for your stack.

Pull requests adding Go / Rust / more frontend frameworks welcome.

## Universal coding discipline lives outside this plugin

The four Karpathy principles, sacred-tests rule, verification ritual, cited-claim format, brevity, and knowledge-sources discipline belong in your **user-level** `~/.claude/CLAUDE.md`, not in any project.

The plugin assumes you have that. If you don't: see the [Karpathy CLAUDE.md](https://github.com/forrestchang/andrej-karpathy-skills) as a starting point.

## Why a plugin (not a bulk-copy script)

The earlier version of this repo was a `bootstrap.sh` script that copied a fixed scaffold. Problem: the scaffold was either over-generic (every file ended with TODO stubs) or over-specific (full of altune-specific Expo + Python + hexagonal assumptions).

The plugin asks first, generates second. You get:

- **TS-specific hooks** wired with `pnpm exec tsc`, `pnpm exec eslint`, `pnpm exec jest` (not generic stubs).
- **Python-specific hooks** wired with `uv run mypy`, `uv run ruff`, `uv run pytest`.
- **Hexagonal**, **layered**, or **vertical-slice** architecture rules + ADR-0001, depending on what you picked. Not all three loaded as conflicting suggestions.
- **Rigor-tailored** TDD-Guard: blocking, warning, or removed entirely.
- **Deferred-decision ADRs** auto-written for choices you marked "decide later" (DB, auth, etc.), so you don't forget to come back to them.

## Background

Extracted from the [Altune](https://github.com/aleburrascano/altune) music-manager project (Expo + Python + hexagonal). The discipline + workflow patterns are the reusable core; the Altune-specific choices became the "TypeScript + Python + Hexagonal" path through this plugin.

Universal coding-discipline patterns: drawn from the Claude-Code wiki MCP — Karpathy principles, spec-driven development, TDD with Claude, hooks-as-guardrails, 6-aspect parallel review, compound engineering. Architectural patterns: drawn from the software-architecture-design wiki MCP — SOLID, DDD, hexagonal, vertical-slice, Repository, DI.

## License

MIT.
