# Design: <FEATURE-ID>

> Owner: `spring-architect` · Phase 3 · Template: `.windsurf/templates/design.template.md`
>
> **No invention.** If a decision is required and not stated by the user or codebase, log a `Q-NNN` and ask. ADRs capture decisions explicitly.

## Inputs

- `01-spec.md` revision: <git-sha or timestamp>
- Stack snapshot from `.github/scripts/detect-stack.sh`:
  - Build tool: <maven | gradle>
  - Java version: <25>
  - Spring Boot version: <4.x>
  - DB engine: <postgres | mysql | h2 | …>
  - Migration tool: <flyway | liquibase | none>
  - Testcontainers: <present | absent>
  - MCP servers available: <jira | github | linear | …>

## Architecture Overview

<3–6 sentences describing the shape of the change at a high level. Reference modules and ADRs.>

## ADRs

> MADR-style. Each ADR lives at `.specs/<feature-id>/adr/NNN-<slug>.md`.

- ADR-001: <title> — status: <proposed | accepted | superseded>
- ADR-002: …

## Spring Component Map

> Components are grouped **by feature** (top-level package). Within each feature, classes live under `api` (published) or `internal` (private). Do not introduce top-level `controller`/`service`/`repository`/`model` packages.

| Feature | Visibility | Component | Responsibility |
|---|---|---|---|
| `<feature>` | api        | `<feature>.api.XService` (interface) | published surface |
| `<feature>` | api        | `<feature>.api.XEvent`               | domain event |
| `<feature>` | internal   | `<feature>.internal.XController`     | HTTP adapter |
| `<feature>` | internal   | `<feature>.internal.XServiceImpl`    | business logic |
| `<feature>` | internal   | `<feature>.internal.XRepository`     | persistence |

## Module Boundaries

> Each top-level package is a module. List the modules this change touches and the directional dependencies between them. Boundaries are enforced by ArchUnit (see `archunit-rules` skill): `..internal..` packages are private, no cycles between top-level packages.

- `<module>` — public API package: `<...api>`; depends on: `<other modules>`; published events: `<events>`

## Entity Relationship Model

> Map conceptual entities from `01-spec.md` to design-level persistence decisions.

| Entity | Purpose | Key attributes | Relationships (cardinality) | Persistence notes |
|---|---|---|---|---|
| `<entity>` | `<business purpose>` | `<attrs>` | `<A 1..* B, A 0..1 C>` | `<aggregate root / ownership / cascade rules>` |

## OpenAPI Sketch

```yaml
paths:
  /<resource>:
    post:
      summary: ...
      requestBody: { ... }
      responses:
        '201': { ... }
        '400': { description: invalid input, ... }
        '409': { description: conflict, ... }
```

## Data Model + Migrations

- Tables/collections affected: <list>
- Migration tool: <flyway | liquibase>
- Migration files: `db/migration/V<N>__<slug>.sql` (Flyway) or `db/changelog/<slug>.xml` (Liquibase)
- Reversibility: <reversible | forward-only with reason>

## Security Posture

- AuthN: <none | JWT | session | OAuth2 resource server>
- AuthZ rules: <which roles/scopes>
- PII handled: <fields>
- Secrets: <where stored>

## Risks + Rollback

| Risk | Likelihood | Impact | Mitigation | Rollback |
|---|---|---|---|---|

## Non-Functional Requirements

> Only NFRs explicitly stated by the user/source. Otherwise log `Q-NNN`.

- (none)

## Open Questions

- Q-001: …

## Resolved Questions

- (none yet)

## Sign-off

- [ ] Every AC from `01-spec.md` is addressed by at least one component or task.
- [ ] All `Q-NNN` resolved or deferred-with-rationale.
- [ ] Reviewed by user on <YYYY-MM-DD>.
