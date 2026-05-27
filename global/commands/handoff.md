---
description: Write a session-end handoff document so the next session can pick up cold without losing context
---

Before this session ends, produce a handoff document the next session can read to recover full context — work shipped, work in flight, dangling state, and a concrete next action.

## Step 1 — Inventory

Walk back through this session and list:

1. **Files written or modified** — every file you touched, with one sentence on what changed and why. Group by purpose.
2. **External state changes** — wiring added to any `settings.json`, new hooks registered, packages installed, environment variables set, etc.
3. **Tests run** — what test harnesses or commands you ran, and the result (counts, pass/fail).

## Step 2 — Surface dangling state

For every external state change in Step 1, verify the target exists. Specifically:

- Hook entries in any `settings.json` → confirm the script file is on disk (use Read or Glob)
- File imports / `@includes` → confirm the imported path resolves
- Symlinks / aliases → confirm targets resolve
- Test fixtures referenced → confirm they exist

Anything that doesn't resolve is **dangling** and goes in the handoff under "BROKEN STATE — fix before continuing." Do not skip this step. The most expensive failure mode is wiring that points at a script you never finished — the next session will find out the hard way.

## Step 3 — Decisions and deferrals

List every decision made this session:

- **Decisions** — what was chosen and why; what alternatives were rejected
- **Deferrals** — what was explicitly NOT done this session, with the trigger that would resurface it (e.g., "X deferred until Y becomes a concern")
- **Open questions** — anything flagged as uncertain or asked the user about that wasn't fully answered

## Step 4 — Write the handoff document

Write to `~/.claude/handoffs/<YYYY-MM-DD>-<short-slug>.md`. Create the directory if it doesn't exist. Use this structure:

```markdown
# Handoff — <one-line topic> (<YYYY-MM-DD>)

## Status
<one paragraph: what shipped, what didn't, what's broken>

## Shipped
- <file or capability> — <one sentence>

## In flight
- <thing started but not finished> — <where it stopped>

## Broken state — fix before continuing
- <dangling reference> — <how to fix>

## Decisions
- <decision> — <reason>

## Deferred
- <thing> — <resurface trigger>

## Open questions
- <unresolved question>

## Resume here
<concrete first action for the next session — file to open, command to run, or question to answer>
```

Pick the slug from the dominant work topic (e.g. `claim-audit-layer9`, `auth-refactor`). If a file under `~/.claude/plans/` framed this session, append a one-line pointer to it: `See plan: <path>`.

## Step 5 — Surface to the user

Print the handoff path, then quote back the **Broken state** and **Resume here** sections so the user can verify nothing was missed before the session closes. If "Broken state" is non-empty, recommend resolving it now rather than at next session-start.

---

A handoff that omits dangling state is worse than no handoff — it gives the next session false confidence. Be exhaustive in Step 2.
