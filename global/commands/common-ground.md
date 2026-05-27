---
description: Surface Claude's hidden assumptions about this project, classify them by confidence tier, and validate before any work begins
---

Before we proceed with any work on this project, make your hidden assumptions explicit and classify each by confidence tier. This is context engineering — making your mental model legible before it drives any code.

## Step 1 — Surface

State, with maximum specificity, your beliefs about:

1. **Architecture** — entry points, directory structure, layering, build/run/test commands
2. **Tooling and dependencies** — frameworks, libraries, language versions, package manager, test runner, linter, formatter
3. **Constraints** — performance targets, deployment environment, runtime requirements, supported platforms, team conventions
4. **Domain** — terminology, business rules, data shapes, user model, vocabulary
5. **Things you're inferring rather than verifying** — extrapolations from filenames, README snippets, framework conventions

## Step 2 — Classify each item by tier

Tag every assumption with one of:

- **`[ESTABLISHED]`** — direct evidence from files you've read. High confidence. Treat as ground truth going forward.
- **`[WORKING]`** — reasonable defaults from convention or partial signal. Medium confidence. Mention when you're about to deviate or rely on it heavily.
- **`[OPEN]`** — not yet validated. Low confidence. Must be confirmed before any work that depends on it.

Also tag the **origin**: `(stated)` if I told you directly, `(inferred)` if extrapolated from code/files, `(assumed)` if framework-default, `(uncertain)` if you're flagging because something seems off.

## Step 3 — Wait for correction

Do NOT propose any changes yet. I will:
- Promote `[OPEN]` items to `[ESTABLISHED]` or `[WORKING]` as I confirm them
- Demote anything you got wrong
- Add anything missing

## Step 4 — Persist

Once corrections are in, write the agreed understanding to `common-ground.md` at the project root using this structure:

```markdown
# Common Ground — <project name>

_Last validated: <date>_

## Established
- ...

## Working
- ...

## Open
- ...
```

This is the project's source of truth for shared understanding. Reference it before non-trivial work; refresh it (run `/common-ground` again) after major architecture changes, framework upgrades, or when assumptions feel stale.
