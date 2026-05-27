# {{PROJECT_NAME}} — project constitution

Universal coding discipline (Karpathy 4 principles, sacred-tests, verification, cited claims, brevity, knowledge-sources) lives in `~/.claude/CLAUDE.md`. **This file is project-specific only.**

@docs/architecture.md
@docs/ubiquitous-language.md
@docs/workflows/new-feature.md

## Project

{{PROJECT_DESCRIPTION}}

## Architectural rules

<!--
Replace this section with rules specific to YOUR project. Examples:
- "Hexagonal: domain/ imports nothing from adapters/ or framework code."
- "Feature-folder rule: cross-feature imports forbidden; promote to shared/ on 2+ consumers."
- "All public functions are typed; lint blocks `any` / `Any`."
-->

- TBD — replace with project's load-bearing architectural invariants.
- **AIDEV-* anchors:** `# AIDEV-NOTE:`, `# AIDEV-DECISION:`, `# AIDEV-WARNING:` are durable — never strip them.

## Workflow

- Skills in `.claude/skills/` auto-fire on context; you do not need to invoke them by name unless overriding.
- If you have a software-architecture-design vault MCP connected, see `.claude/rules/vault-consultation.md`. Consult **before** any non-trivial design decision.

## Git

- Conventional Commits, scopes constrained by `commitlint.config.js`.
- **Never** append `Co-Authored-By: Claude` / `Co-Authored-By: AI` / `🤖 Generated with…`. The `commit-msg` hook strips them, but don't generate them in the first place.

## Nested context

Look for `CLAUDE.md` files closer to the file you're editing — feature- and layer-specific rules live near the code. See `docs/claude-md-map.md` for the index.
