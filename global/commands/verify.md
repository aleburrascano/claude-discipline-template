---
description: Pre-completion verification ritual — what changed, what was tested, what could break, what wasn't checked
---

Before declaring this work done, complete the following verification steps. Do not skip any.

## What changed
List every file you modified, every function/class added or changed, every config or dependency touched. Be exhaustive — surface anything I might have missed in review.

## What was tested
For each change, state the verification you ran:
- **Unit tests** — which suites? did they pass?
- **Type / lint / build** — did they succeed cleanly, or were there warnings?
- **Manual verification** — what specifically did you try? what input/output did you observe?
- **Cross-model or subagent review** — if you ran one, what did it find or miss?

If a verification mode is not applicable, say so explicitly. Don't omit it silently.

## What could break
List the risks these changes introduce:
- Backwards-incompatible API or schema changes
- Performance regressions or new resource costs
- Edge cases not covered (empty / large / malformed / concurrent inputs)
- Side effects on other modules or callers
- Async / ordering / race-condition behavior changes

## What you didn't check
Be honest about gaps. List:
- Anything you suspect should be verified but didn't
- Anything you assumed without confirming
- Anything outside the codebase (downstream consumers, deployment configs, runtime environment)

## Verdict
Based on the above:
- **Ready** — confident; all critical verification passed
- **Conditional** — ready IF the user confirms specific items (list them)
- **Not ready** — name what's blocking

Do not claim "ready" if any item in *What you didn't check* is load-bearing. Per Anthropic's best practices, verification is the single highest-leverage discipline; skipping it costs more than running it.
