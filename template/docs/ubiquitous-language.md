# Ubiquitous language

Shared vocabulary across code, tests, conversation, and documentation. When a term is used in your domain code, it lives here with a precise meaning.

Reference: [vault: wiki/concepts/Ubiquitous Language.md], [vault: wiki/concepts/Domain-Driven Design.md] (if you have the software-architecture-design vault MCP connected).

## Rules

1. **One term, one meaning.** If a word means two different things in two contexts, name them differently (`UserPlaylist` vs. `SmartPlaylist`).
2. **Code matches glossary.** Class names, method names, variable names use these terms verbatim. The `terminology-drift` hook flags drift.
3. **Glossary entries match code.** If a term appears here but not in the code, either delete it (premature) or build the type (overdue).
4. **Defined per bounded context** when a term diverges. Most terms are global; some need context-qualified entries.

## Adding a term

When `/feature-spec` or domain modeling introduces a new term:
1. Add it here in the same commit.
2. Use the format below.
3. If the term overrides a global definition in a specific context, add a "Per-context overrides" entry.

## Format

```
- **TermName** — definition in 1–3 sentences. Cross-link to vault if applicable.
```

---

## Glossary

_(empty — populated as the domain model develops)_

---

## Per-context overrides

When the same term means different things in different contexts, define each:

```
- **TermName** (in <Context>) — context-specific meaning.
```

_(empty)_

---

## Anti-patterns

- **Synonyms drift** — two words used interchangeably. Pick one; ban the other.
- **Implementation leakage** — "FooRow" or "FooDTO" in glossary. Those are infrastructure, not domain.
- **Vague entries** — "User: a person who uses the app." Useless. Earn the spot with a precise definition.
- **Stale entries** — terms once in the code but renamed/removed. Delete or mark deprecated.

## Banned terms

_(empty — add words you've decided NOT to use in this project so the terminology-drift hook can catch them.)_

Example:
- **<oldName>** — synonym of `<newName>`. Banned. See ADR-NNNN for the rename rationale.
