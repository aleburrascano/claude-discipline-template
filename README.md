# claude-discipline

Two distribution paths for a single coherent Claude-Code-first development discipline:

1. **Global (`~/.claude/`) overlay** — universal hallucination-reduction + context-engineering hooks/commands/CLAUDE.md that load on **every** session in **every** project. Install via `bash install-global.sh`.
2. **Project bootstrap plugin** — interactive scaffolder that asks about your stack + architecture + rigor, then writes a tailored `.claude/` + `docs/` setup for **a single new project**. Install via `/plugin marketplace add` then `/plugin install`.

The two layers compose:

- **Global** handles *how Claude works*: citation discipline, common-ground at session start, claim audit at session end, multi-language static check on every Write, context-utilization warnings, thinking-level routing.
- **Project plugin** handles *what this codebase is*: chosen architecture (hexagonal / layered / vertical-slice), stack-specific rules (Python / TypeScript), feature workflow (spec → plan → TDD → verify → 6-aspect review → compound), 13 skills, 10–13 subagents, 12 hooks.

Neither replaces the other.

---

## Path 1 — Global `~/.claude/` overlay

The overlay that catches hallucinations and enforces citations across every Claude Code session.

### Install

```bash
git clone https://github.com/aleburrascano/claude-discipline-template.git
cd claude-discipline-template
bash install-global.sh          # Linux / macOS / Git Bash on Windows
# or:
.\install-global.ps1            # PowerShell on Windows
```

The installer:

- Backs up your existing `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`, `~/.claude/hooks/`, `~/.claude/commands/` per-file to `~/.claude/backup-<timestamp>/` (only files that would be overwritten).
- For each file: **missing** → copies and reports "added"; **identical** → reports "identical"; **differs** → shows a diff and asks `[i]nstall · [s]kip · [v]iew full diff · [k]eep both as .new`.
- Never touches private dirs: `projects/`, `sessions/`, `handoffs/`, `plans/`, `file-history/`, `shell-snapshots/`, `logs/`, `cache/`, `backups/`, `session-env/`, `tdd-guard/`, `chrome/`, `downloads/`, `ide/`, or `.credentials.json`.
- Writes `settings.json.template` rather than `settings.json` — you merge it into yours manually, so your plugin enablements aren't overwritten.

### What gets installed (23 files)

- `CLAUDE.md` — universal 4-principles (Think · Simple · Surgical · Goal-Driven) + sacred-tests + accountability contract + brevity
- `RTK.md` — Rust Token Killer proxy reference
- `settings.json.template` — starter hook wiring; merge into your real `settings.json`
- `hooks/` — 16 hooks across 10 defense layers (claim-audit, multi-lang langcheck, common-ground, citation reminder, context-threshold, etc.)
- `commands/` — 5 custom commands (`/common-ground`, `/grill-me`, `/handoff`, `/setup-project-defenses`, `/verify`)

See [`global/README.md`](global/README.md) for the layer-by-layer breakdown.

### Optional: install RTK (Rust Token Killer)

RTK is a separate CLI binary (not a Claude Code component) that compresses Bash output before it reaches the LLM context — **60–90% token savings** on dev operations. The discipline overlay works without it; RTK is purely an optimization.

`install-global.sh` asks if you want to install RTK at the end. Or run separately:

```bash
bash install-rtk.sh        # cargo install --git https://github.com/rtk-ai/rtk + rtk init -g
# or:
.\install-rtk.ps1
```

Requires `cargo` (Rust toolchain — install from https://rustup.rs if you don't have it).

The script:
1. Checks if the **correct** `rtk` is already installed (there's a name collision with a Rust Type Kit crate of the same name on crates.io).
2. Installs from `rtk-ai/rtk` via cargo if not present (falls back to the official `curl | sh` installer if cargo isn't available).
3. Runs `rtk init -g --auto-patch --hook-only` to wire the `PreToolUse:Bash` hook into `~/.claude/settings.json` non-destructively.
4. Verifies via `rtk gain`.

### Validate after install

```bash
bash ~/.claude/hooks/test-claim-audit.sh    # ~30 synthetic test cases
bash ~/.claude/hooks/test-langcheck.sh      # multi-language hook validation
```

Both should report `PASS` on every case.

---

## Path 2 — Project bootstrap plugin

Interactive scaffolder. Asks ~6 questions, writes ~50–80 files tailored to your picks. No TODO stubs for covered stacks.

### Install

```
# In Claude Code, in any directory:
/plugin marketplace add aleburrascano/claude-discipline-template
/plugin install bootstrap@claude-discipline
```

If the SSH-form clone fails with "host key not in known_hosts", use the HTTPS form:

```
/plugin marketplace add https://github.com/aleburrascano/claude-discipline-template
```

### Use

```
cd ~/projects/my-new-thing      # empty directory
/bootstrap-project              # plugin's only user-facing skill — kicks off Q&A
```

The skill asks about:

1. Project name + description
2. Backend language — Python · TypeScript/Node · Go · Rust · None
3. Frontend — Expo · Next.js · Vite + React · None
4. Database — Postgres · SQLite · MongoDB · decide-later
5. Architecture — Hexagonal · Layered · Vertical-slice · None/manual
6. Rigor level — Maximum (TDD-Guard blocks) · Pragmatic · Lean

Then it writes a `.claude/` + `docs/` scaffold tailored to your answers.

### Coverage matrix (v0.3.0)

| Stack × Arch | Hexagonal | Layered | Vertical-slice | None/manual |
|---|---|---|---|---|
| Python | ✅ Full | ⚠️ ADR-only | ⚠️ ADR-only | ✅ Full |
| TypeScript | ✅ Full | ⚠️ ADR-only | ⚠️ ADR-only | ✅ Full |
| Go / Rust | 🚧 Stubs | 🚧 | 🚧 | 🚧 |

**Full** = stack-specific rules + language-expert subagent + filled-in hooks (no TODOs) + tailored ADR.
**ADR-only** = generic discipline + arch ADR; hook stubs need filling.
**Stubs** = generic discipline + TODO stubs you fill in for your stack.

---

## Repo layout

```
claude-discipline-template/
├── README.md                          ← this file
├── LICENSE                            ← MIT
├── .gitignore
├── install-global.sh                  ← installs Path 1 (Linux/macOS/Git-Bash); offers RTK at end
├── install-global.ps1                 ← installs Path 1 (PowerShell); offers RTK at end
├── install-rtk.sh                     ← standalone RTK installer (cargo install + rtk init)
├── install-rtk.ps1                    ← standalone RTK installer (PowerShell)
├── .claude-plugin/
│   └── marketplace.json               ← declares the "bootstrap" plugin at plugins/bootstrap/
├── plugins/
│   └── bootstrap/                     ← Path 2 — the project-bootstrap plugin
│       ├── .claude-plugin/plugin.json
│       ├── skills/bootstrap-project/SKILL.md
│       └── content/                   ← raw templates the skill reads at runtime
│           ├── core/                  ← always-written (61 files)
│           ├── stacks/{typescript,python}/
│           └── architectures/{hexagonal,layered,vertical-slice}/
└── global/                            ← Path 1 — the ~/.claude/ overlay
    ├── README.md                      ← what's inside + which defense layer each hook serves
    ├── CLAUDE.md                      ← universal discipline
    ├── RTK.md
    ├── settings.json.template
    ├── hooks/                         (16 files)
    └── commands/                      (5 files)
```

## Both paths recommended for new collaborators

If a teammate is starting fresh:

1. Run `install-global.sh` (it'll also offer to install RTK at the end).
2. Install the `bootstrap` plugin: `/plugin marketplace add https://github.com/aleburrascano/claude-discipline-template` then `/plugin install bootstrap@claude-discipline`.
3. For each new project: `cd <empty-dir> && /bootstrap-project`.

After they're set up, the discipline applies automatically — hooks fire, skills auto-suggest, citations are enforced.

## License

MIT.
