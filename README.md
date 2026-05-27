# claude-discipline-template

A **Claude-Code-first** project scaffold: skills, agents, hooks, path-scoped rules, workflows, and doc templates that enforce production-grade discipline from line one.

Stack-agnostic core. You bring your own languages and frameworks. The discipline is shape-only — it just expects you to ship features through a `spec → plan → TDD → verify → review → compound` loop.

## Quick start

```bash
# Clone this repo
git clone https://github.com/<you>/claude-discipline-template.git
cd claude-discipline-template

# Bootstrap a new project
bash bootstrap.sh ../my-new-project "My New Project" "What the project does."
# or on Windows:
.\bootstrap.ps1 -TargetDir ..\my-new-project -ProjectName "My New Project" -Description "What the project does."

# Then:
cd ../my-new-project
# 1. Replace docs/architecture.md template content with your real architecture
# 2. Write ADR-0001 documenting your layer / pattern choice
# 3. Wire stack-specific commands in .claude/hooks/ (typecheck, lint, test) — they're TODO stubs
# 4. pnpm install (when ready, installs husky's commit-msg attribution-stripper)
# 5. git add -A && git commit -m "chore(release): initial scaffold"
```

## What you get

```
my-new-project/
├── CLAUDE.md                  # project constitution (lean — universal rules live in ~/.claude/CLAUDE.md)
├── README.md                  # parameterized
├── .gitignore .gitattributes .editorconfig .gitmessage
├── commitlint.config.js       # Conventional Commits validation
├── package.json               # husky wiring
├── .husky/
│   ├── commit-msg             # STRIPS "Co-Authored-By: Claude/AI/Anthropic" lines
│   └── pre-commit             # blocks secret commits
├── .claude/
│   ├── settings.json          # hook wiring
│   ├── skill-rules.json       # which skills fire on which prompts/cwd
│   ├── rules/
│   │   ├── vault-consultation.md   # how to use the software-architecture-design vault MCP (if connected)
│   │   └── tests.md                # sacred-tests rule, AAA, doubles, coverage targets
│   ├── skills/                # 13 skills (see below)
│   ├── agents/                # 10 stack-agnostic subagents (see below)
│   └── hooks/                 # 12 hooks (see below)
└── docs/
    ├── architecture.md        # TEMPLATE — replace with your real architecture
    ├── ubiquitous-language.md # empty glossary template
    ├── claude-md-map.md       # index of CLAUDE.md files
    ├── workflows/             # new-feature, bug-fix, refactor playbooks
    ├── specs/_template/       # spec template
    ├── adr/_template/         # ADR template (Proposed/Accepted/Deprecated/Superseded)
    ├── solutions/             # compound-engineering learnings
    │   ├── _template.md
    │   └── INDEX.md
    ├── brainstorms/           # 30-day TTL exploration
    └── notes/                 # permanent (escape from brainstorm TTL)
```

## What's inside `.claude/`

### Skills (13)

User-facing slash-commands; auto-fire on context per `skill-rules.json`.

| Skill | Triggers on |
|---|---|
| `feature-spec` | "spec out", "let's spec", "write a spec for", "design a feature" |
| `feature-plan` | "plan this feature", "how should we build", "break this down" |
| `tdd-red-green-refactor` | "implement", "build the", "let's code" |
| `verify-end-to-end` | "verify", "make sure it works", "did that break anything", "test that" |
| `code-review-6-aspect` | "review this", "pre-merge review" |
| `compound-learning` | "capture what we learned", "lesson here", "gotcha" |
| `adr-write` | "document this decision", "ADR for X" |
| `common-ground` | session start; "what are you assuming", "surface assumptions" |
| `brainstorm-tech-choice` | "should we use", "X vs Y", "which library/database/auth" |
| `update-docs-freshness` | doc-drift hook flags drift |
| `update-nested-claude-md` | after every 3rd commit affecting a feature folder |
| `git-commit` | "commit", "stage and commit", "ship this" |
| `audit-docs` | "audit the docs", "stale docs", "clean up brainstorms" |

### Subagents (10)

Specialist contexts dispatched in parallel by `/code-review-6-aspect` or invoked directly.

- `spec-reviewer` — clarify-gate on specs
- `plan-reviewer` — slice quality on plans
- `architecture-reviewer` — hexagonal/layer/pattern grading
- `security-reviewer` — OWASP, auth, secrets, prompt injection
- `perf-reviewer` — N+1, async, render perf
- `testing-reviewer` — coverage, weak assertions, sacred-tests violations
- `quality-reviewer` — SOLID, DRY, KISS, YAGNI, naming
- `docs-reviewer` — spec/ADR/glossary alignment, AIDEV-anchor preservation
- `ux-reviewer` — interaction states, a11y, design-system consistency
- `test-author` — RED-phase test author

**Not included** (too stack-specific): `typescript-expert`, `python-expert`, `domain-modeler`. Add them in your own project if your stack/style fits.

### Hooks (12)

Event-triggered guardrails wired in `.claude/settings.json`.

| Event | Hook | What it does |
|---|---|---|
| `SessionStart` | `session-start-common-ground.sh` | Asks Claude to state its assumptions about the project |
| `UserPromptSubmit` | `user-prompt-skill-activator.sh` | Reads `skill-rules.json`, suggests applicable skills |
| `PreToolUse` (Write/Edit) | `pre-tool-file-guard.sh` | Blocks `.env`, secrets, test edits (sacred-tests rule) |
| `PreToolUse` (Write/Edit) | `pre-tool-tdd-guard.sh` | Blocks `src/` edits without companion failing test |
| `PostToolUse` (Write/Edit) | `post-tool-typecheck.sh` | Runs your typechecker (**TODO**: wire your stack's command) |
| `PostToolUse` (Write/Edit) | `post-tool-lint.sh` | Runs your linter (**TODO**: wire) |
| `PostToolUse` (Write/Edit) | `post-tool-test-changed.sh` | Runs related tests (**TODO**: wire) |
| `PostToolUse` (Edit) | `post-tool-check-comment-churn.sh` | Flags removal of `AIDEV-*` anchors |
| `PostToolUse` (Bash) | `post-tool-commit-doc-drift.sh` | Warns when commit touches code without related docs |
| `Stop` | `stop-self-review.sh` | Nudges /verify-end-to-end if uncommitted work exists |
| `Stop` | `stop-terminology-drift.sh` | Flags class names not in `docs/ubiquitous-language.md` |
| `Stop` | `stop-compound-learning-prompt.sh` | Asks if any pattern is worth recording in `docs/solutions/` |

### What's intentionally NOT in the template

The following are too stack-/architecture-specific and should be added in your own project after running ADR-0001:

- `.claude/rules/typescript-frontend.md`, `python-backend.md` (language rules)
- `.claude/rules/domain-layer.md`, `application-layer.md`, `adapters-layer.md` (hexagonal-specific)
- `.claude/rules/migrations.md` (DB-specific)
- `.claude/agents/typescript-expert.md`, `python-expert.md`, `domain-modeler.md` (stack/style specialists)

Reference: the source `altune` project (Expo + Python + hexagonal) is a worked example if you want to see how these were structured for one specific stack.

## Universal coding discipline lives outside this template

The four Karpathy principles, sacred-tests rule, verification ritual, cited-claim format, brevity, and knowledge-sources discipline belong in your **user-level** `~/.claude/CLAUDE.md`, not in any project. The template assumes you have that.

If you don't yet: see the [Karpathy CLAUDE.md](https://github.com/forrestchang/andrej-karpathy-skills) as a starting point.

## Why use this

- **Hallucination defense in depth.** Stack-of-defenses approach: discipline (CLAUDE.md) + verification (TDD) + structural (hooks) + multi-agent review (6-aspect parallel).
- **Doc-code drift is mechanical, not advisory.** Hooks detect drift; skills resolve it.
- **Every architectural decision is captured.** ADR system, with templates and supersede chains.
- **Compound knowledge.** `docs/solutions/` accumulates pattern-level learnings session-over-session.
- **Skills auto-fire.** You don't need to remember to invoke `/feature-spec` — the skill-activator hook surfaces it when your prompt matches.

## Customizing for your stack

Read [`docs/architecture.md`](template/docs/architecture.md) for the template's stub. Then:

1. **Pick your dependency rule** (hexagonal, layered, vertical-slice, MVC, etc.) and write `docs/adr/0001-<your-choice>.md`.
2. **Add language rules** under `.claude/rules/` with `paths:` frontmatter so they only load when Claude reads matching files.
3. **Wire the TODO hooks** — `post-tool-typecheck.sh`, `post-tool-lint.sh`, `post-tool-test-changed.sh` are stubs with examples for Python/TS/Go/Rust in comments.
4. **Fill in `verify-end-to-end`** — same TODO stubs in the skill's SKILL.md.
5. **Decide your bounded contexts / feature slices** as you spec features.

## Origin

Extracted from the [Altune](https://github.com/<you>/altune) music-manager project (Expo + Python, hexagonal). The discipline + workflow patterns are the reusable core; the stack-specific rules are documented in altune as a worked example.

Universal coding-discipline patterns: drawn from the Claude-Code wiki MCP — Karpathy principles, spec-driven development, TDD with Claude, hooks-as-guardrails, 6-aspect parallel review, compound engineering. Architectural patterns: drawn from the software-architecture-design wiki MCP — SOLID, DDD, hexagonal, vertical-slice, Repository, DI.

## License

MIT — use it however you like.
