# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Verification Before Completion

The Stop hook (`claim-audit.sh`) checks that every external-content claim is backed by a tool call before letting the turn end. Don't try to outrun it — verify first, then claim. For bug fixes specifically: write a failing test that reproduces the bug, show it fail, fix it, show it pass, run the full suite.

## 6. Sacred Tests Rule

Test files are read-only unless explicitly instructed to modify them. If a test is failing, fix the implementation — not the test. "The test was wrong" requires explicit human confirmation.

## 7. Token Discipline

Invoke skills explicitly by name — never rely on implicit activation. Each skill description costs tokens every turn. Use `/ce-compound` only after a hallucination slips through, not preventively.

## 8. The Accountability Contract

Cite inline as you write — the Stop hook is a backstop, not a worksheet. Two forms, chosen by intent. Use angle-bracket placeholders (`<path>`, `<url>`, `<n>`, `<m>`) when discussing this format in prose — bare literals like `path` will trigger the audit.

**Structural reference (anchor, no quote):**
- `[VERIFIED:Read@<path>#L<n>-L<m>]` — points at lines, no quote required
- `[VERIFIED:Grep@<path> lines <n>-<m>]` — legacy trailing-word form
- Allowed tools: Read, Grep, Glob, MultiEdit. Use when pointing AT code.

**Textual claim (literal quote):**
- `[VERIFIED:WebFetch@<url>] "exact phrase from the page"`
- `[VERIFIED:Bash@<output>] "error: connection refused"`
- Quote must be ≥30 chars / ≥5 words AND a literal substring of the tool result.
- Required for WebFetch, Bash, and Read/Grep when exact wording is the claim (rate limits, error messages, API contracts).

**Other tags:**
- `[INFERRED]` — prior knowledge, not verified this session
- `[ASSUMED]` — convention guess, user must confirm
- `[CONCLUSION from: <sources>]` — synthesis from multiple verified sources
- `[OPINION based on: <sources>]` — recommendation from multiple sources

Bare tags (no anchor and no quote) are blocked. Be specific. If you don't have evidence, use `[INFERRED]` / `[ASSUMED]` or just say "I don't know."

## 9. Knowledge Sources

For domain research, wiki lookups, or background context — check available vault MCPs first before spawning subagents or reading files directly. Use `search_notes` then `get_note` on top hits. Vault MCPs are registered globally; check what's available with `/mcp`.

## 10. Brevity

No preamble. No recap. No transition phrases ("Great question", "Now let's…", "Hopefully this helps", "Let me know if…"). No "I'll do X" before doing X — just do it. State the answer, cite inline, stop. Match length to the question's complexity, not to the visual weight of a complete-feeling block.

---

**These guidelines are working if:** Stop-hook blocks are rare (claims are tagged correctly first time), false-claim rates drop across models, responses fit the question's complexity, and clarifying questions come before implementation rather than after mistakes.

@RTK.md
