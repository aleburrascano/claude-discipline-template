# Architecture — Hexagonal (Ports & Adapters)

{{PROJECT_NAME}} uses the **Hexagonal Architecture** (also called Ports & Adapters), introduced by Alistair Cockburn. Reference: [vault: wiki/concepts/Hexagonal Architecture.md].

## The shape

```
                  [ inbound adapters ]
                  HTTP · CLI · message consumers · test harnesses
                              ↓ (driving ports)
                  ┌─────────────────────────┐
                  │      application/       │  use cases + ports
                  │  ┌───────────────────┐  │
                  │  │     domain/       │  │  entities · value objects · events
                  │  └───────────────────┘  │
                  └─────────────────────────┘
                              ↓ (driven ports)
                  [ outbound adapters ]
                  DB repositories · external HTTP · publishers
```

## The dependency rule (load-bearing)

Dependencies point **inward only**:

```
adapters → application → domain
platform → everything (it wires)
```

- `domain/` imports nothing from `adapters/` or framework code. Pure language stdlib + other `domain/` modules only.
- `application/` imports `domain/` + stdlib. **Ports** are defined here. Adapters implement them.
- `adapters/` imports `application/` ports + `domain/` types + framework code.
- `platform/` (DI container, config, logging) wires concrete adapters to ports.

Path-scoped rules in `.claude/rules/domain-layer.md`, `application-layer.md`, `adapters-layer.md` enforce this; the `architecture-reviewer` subagent grades against it.

## Per-context layout

When you add a bounded context (e.g., `catalog`, `library`, `playback`):

```
<your-pkg>/
├── domain/<context>/
│   ├── __init__.py / mod.ts
│   ├── <aggregate>.py / .ts
│   ├── <value-objects>.py / .ts
│   ├── events.py / .ts
│   └── exceptions.py / .ts
├── application/<context>/
│   ├── __init__.py
│   ├── ports.py / .ts           # interfaces consumed by use cases here
│   └── <use-case>.py / .ts      # one file per use case
└── adapters/
    ├── inbound/http/<context>/
    │   └── router.py / .ts
    └── outbound/persistence/<context>/
        └── <aggregate>_repository.py / .ts
```

## Why hexagonal for this project

- **Testability.** Domain + application unit-tested without DB, network, or framework — use in-memory adapter implementations of the ports.
- **Swap-friendly.** Replacing Postgres with SQLite, or REST with GraphQL, only touches the adapter — domain stays untouched.
- **Boundary clarity.** Architectural review is mechanical: did the change cross a boundary? The hooks + `architecture-reviewer` subagent catch violations.

## Trade-offs we're accepting

- More indirection than a flat MVC for trivial CRUD endpoints. Worth it on anything non-trivial.
- Discipline to maintain the port/adapter distinction. The `.claude/rules/{domain,application,adapters}-layer.md` files codify this.
- Constructor injection boilerplate. Mitigated by `platform/container.py` centralizing wiring.

## Quality attributes (priority order)

When trade-offs arise, decide in this order:

1. **Correctness** — does it actually do the right thing? (Tests, vault-pattern alignment.)
2. **Maintainability** — can future-me change it without rework? (Layer discipline, ubiquitous-language consistency.)
3. **Testability** — can we test without I/O? (In-memory adapter implementations of ports.)
4. **Observability** — when production breaks, can we diagnose? (Structured logs, correlation ids.)
5. **Performance** — at expected scale, is it fast enough? (N+1 awareness; profile before optimizing.)
6. **Resilience** — does the right thing happen on partial failure? (Retries, idempotency where applicable.)

Don't optimize for performance at the cost of correctness or maintainability.

## See also

- ADR-0001 (this file's decision): `docs/adr/0001-hexagonal-architecture.md`
- Workflows: `docs/workflows/new-feature.md`
- [vault: wiki/concepts/Hexagonal Architecture.md], [vault: wiki/concepts/Domain-Driven Design.md], [vault: wiki/concepts/Repository Pattern.md], [vault: wiki/concepts/Dependency Injection.md]
