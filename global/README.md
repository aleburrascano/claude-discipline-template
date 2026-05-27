# global/ — `~/.claude/` overlay

Universal hallucination-reduction + context-engineering layer that lives in your **user-level** `~/.claude/` directory. Loads on every Claude Code session, every project.

## What's in here (22 files)

```
global/
├── CLAUDE.md                          # universal 4-principles + sacred-tests + brevity + accountability
├── RTK.md                             # Rust Token Killer proxy reference (optional dependency)
├── settings.json.template             # starter settings — wires the hooks, leaves plugins empty
├── hooks/
│   ├── claim-audit.sh                 # Stop hook — blocks unverified content claims
│   ├── claim-patterns.json            # config for claim-audit
│   ├── external-entities.txt          # external-entity tokens triggering entity-tag rule
│   ├── context-threshold.sh           # UserPromptSubmit — warns at 85% context utilization
│   ├── thinking-level.sh              # UserPromptSubmit — routes thinking_level by prompt complexity
│   ├── source-prefetch-reminder.sh    # UserPromptSubmit — prompts mentioning URLs/paths get fetch reminder
│   ├── response-discipline-reminder.sh # UserPromptSubmit — citation + brevity reminder every turn
│   ├── session-common-ground.sh       # SessionStart — surfaces assumptions in code-project dirs
│   ├── post-write-langcheck.sh        # PostToolUse (Write/Edit) — multi-lang static check (py/go/rs/rb/sh)
│   ├── typecheck-changed.sh           # PostToolUse (Write) — tsc --noEmit on TS files
│   ├── test-changed.sh                # PostToolUse (Write) — runs npm test / pytest / cargo test / go test
│   ├── create-checkpoint.sh           # creates a git checkpoint commit (manual use)
│   ├── parry-guard-wrap.sh            # PreToolUse — wraps parry-guard prompt-injection scanner (fail-open)
│   ├── test-claim-audit.sh            # verification harness for claim-audit
│   └── test-langcheck.sh              # verification harness for post-write-langcheck
└── commands/
    ├── common-ground.md               # /common-ground — surface Claude's assumptions
    ├── grill-me.md                    # /grill-me — interview the user on a plan
    ├── handoff.md                     # /handoff — write a session-end handoff doc
    ├── setup-project-defenses.md      # /setup-project-defenses — bootstrap project-level CLAUDE.md + rules
    └── verify.md                      # /verify — pre-completion checklist
```

## Install

From the repo root:

```bash
# Linux / macOS / Git Bash:
bash install-global.sh

# Windows PowerShell:
.\install-global.ps1
```

The installer:

1. Backs up your existing `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`, `~/.claude/hooks/`, and `~/.claude/commands/` to `~/.claude/backup-<timestamp>/`.
2. For each file in this overlay:
   - **Missing** in your `~/.claude/` → copies it in, reports "added".
   - **Identical** to your existing version → skips, reports "identical".
   - **Differs** from your existing version → shows a diff and asks: install? skip? edit-merge?
3. Reports a summary at the end.

It does **NOT** touch any private dirs (`projects/`, `sessions/`, `handoffs/`, `plans/`, `file-history/`, etc.).

It does **NOT** copy `settings.json` — instead, it copies `settings.json.template` to `~/.claude/settings.json.template`. You merge it into your real `settings.json` manually so your plugin enablements aren't overwritten. (If you don't have a `settings.json` yet, just rename `.template` → `settings.json`.)

## What each layer does

| Layer | Mechanism | Defense against |
|---|---|---|
| 1 — Discipline | `CLAUDE.md` 4 principles | Wrong assumptions, overcomplication, sloppy surgery, vague success criteria |
| 2 — Pre-frame | `source-prefetch-reminder.sh` | Claim-without-fetch on URLs/paths the user mentioned |
| 3 — Per-turn discipline | `response-discipline-reminder.sh` | Drift on citation format + brevity |
| 4 — Common-ground | `session-common-ground.sh` | Implicit assumptions in fresh sessions |
| 5 — Citation audit | `claim-audit.sh` + `claim-patterns.json` | Bare claims about external content w/o tool calls |
| 6 — Entity tags | `external-entities.txt` | Claims about named vendors/SDKs without verification |
| 7 — Prompt injection | `parry-guard-wrap.sh` | Injection via tool inputs/outputs (requires parry-guard binary) |
| 8 — Reasoning depth | `thinking-level.sh` | Under-thinking complex problems, over-thinking trivial ones |
| 9 — Static check | `post-write-langcheck.sh`, `typecheck-changed.sh`, `test-changed.sh` | Code-gen hallucinations (invented APIs, type errors) caught at write time |
| 10 — Context drift | `context-threshold.sh` | Auto-compaction degrading reasoning silently |

The layers compose — each catches a different class of error. You don't have to use all of them; comment any out of `settings.json` you don't want.

## Off switches (env vars)

Every hook has a per-hook env-var off switch so you can disable individually:

- `CLAUDE_SKIP_CLAIM_AUDIT=1`
- `CLAUDE_SKIP_LANGCHECK=1` (plus per-language: `CLAUDE_SKIP_RUFF`, `CLAUDE_SKIP_MYPY`, `CLAUDE_SKIP_GOVET`, `CLAUDE_SKIP_CARGO`, `CLAUDE_SKIP_RUBYC`, `CLAUDE_SKIP_SHELLCHECK`)
- `CLAUDE_SKIP_CONTEXT_THRESHOLD=1`
- `CLAUDE_SKIP_COMMON_GROUND=1`
- `CLAUDE_SKIP_RESPONSE_DISCIPLINE=1`
- `CLAUDE_SKIP_PREFETCH_REMINDER=1`
- `CLAUDE_SKIP_PARRY=1`

Set in your shell rc or in `~/.claude/settings.json` under an `env:` key.

## Validating the hooks work

After install:

```bash
bash ~/.claude/hooks/test-claim-audit.sh   # ~30 synthetic test cases
bash ~/.claude/hooks/test-langcheck.sh     # multi-language hook test
```

Both should report `PASS` on every case. If anything fails, surface it as an issue — the hooks shouldn't ship broken.

## Universal-vs-project boundary

This `global/` is **per-user**, loaded on every project. For **per-project** discipline (architecture rules, stack-specific hooks, project skills + agents), use the `bootstrap` plugin in this same repo. Run `/plugin install bootstrap@aleburrascano/claude-discipline-template` then `/bootstrap-project` in a new project.

The two layers compose:
- Global handles **how Claude works** (citations, common-ground, thinking-level, claim-audit).
- Per-project handles **what this codebase is** (architecture, ubiquitous language, feature workflow).

Neither replaces the other.
