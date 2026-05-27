---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---

# TypeScript / Expo frontend rules

## Type strictness

- `strict: true`, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true` are non-negotiable.
- **No `any`** — use `unknown` + narrowing, or define the type. The `post-tool-typecheck` hook surfaces violations.
- Prefer **discriminated unions** for state machines (loading / loaded / error). Never represent state as nullable fields.
- Use `satisfies` for object literals that must conform to a type without widening.

## React Native / Expo conventions

- Functional components only. Hooks for state.
- Navigation: Expo Router (file-based). Route files live under `<your-app>/src/app/`.
- Side effects only in `useEffect` / event handlers — never in render.
- Memoize **deliberately**, not preemptively. `useMemo`/`useCallback` only with a measured reason (referenced by deps in another hook, or expensive computation).
- Lists: `FlatList` / `SectionList`. Never `.map()` over large arrays in render.

## Feature slice (vertical) rules

A feature folder at `<your-app>/src/features/<feat>/` owns:
- `ui/` — screens and feature-specific components
- `hooks/` — React hooks scoped to this feature
- `api/` — client calls to backend (typed, via the generated client in `shared/api-client/`)
- `types.ts` — types shared *within* this feature
- `__tests__/` — unit tests for this feature's logic

**A feature MUST NOT import from another feature's folder.** Cross-feature reuse goes via `shared/`. The `architecture-reviewer` subagent enforces this.

## Shared rules

`<your-app>/src/shared/` holds **only** items used by 2+ features:
- `ui/` — design system: `Button`, `Text`, theme tokens, spacing scale
- `api-client/` — generated/typed HTTP client + interceptors (auth, retry, error mapping)
- `lib/` — pure utility functions (no React, no API calls)

If a candidate has one consumer, it stays in the feature. Promote on the second consumer (YAGNI).

## Theming

- Theme tokens (`color`, `spacing`, `radius`, `typography`) live in `shared/ui/theme/`.
- Components **must** consume tokens via theme hook, never hardcoded values.
- Dark mode considered from day 1 — every color token has light + dark variant.

## Errors

- Backend errors come through `shared/api-client/` already mapped to typed `ApiError` discriminated union.
- Display via the feature's own error UI (don't share a generic error toast).
- Network errors → retry policy in the client, not the screen.

## Testing (frontend specifics)

- Unit tests for hooks and pure logic → Jest + `@testing-library/react-native`.
- Component tests render with `<ThemeProvider>` and an in-memory API client.
- E2E flows in `<your-app>/e2e/` using Maestro (preferred) or Detox.
- The `test-author` subagent writes the failing test before `tdd-red-green-refactor` implements.

## Do not

- Install global state libraries (Redux/MobX/Zustand) without an ADR. React Query for server state + hooks for local state is the default.
- Add a new top-level dependency without `/brainstorm-tech-choice` first.
- Use class components.
- Use `console.log` in committed code — the `post-tool-check-comment-churn` hook flags additions.
