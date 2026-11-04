# Design Review Checklist

Used by `spring-architect` to gate exit from Phase 3 (`03-design.md` + `04-tasks.md`).

## Architecture

- [ ] Component map present (controllers, services, repositories, events).
- [ ] Components are grouped by feature/domain (top-level package = bounded context with `api`/`internal`); no top-level `controller`/`service`/`repository`/`model` packages introduced.
- [ ] Module boundaries documented (top-level packages with `internal` sub-packages, enforced by ArchUnit).
- [ ] Layer rules respected (no controller → repository skip; no inversion).
- [ ] OpenAPI sketch present for every new/changed endpoint.

## Data

- [ ] Entity relationship model is present and aligns with `01-spec.md` entities/relationships.
- [ ] Relationship cardinalities are explicit and consistent across API, data model, and tasks.
- [ ] Migration tool detected and consistent (Flyway OR Liquibase, never both).
- [ ] Migrations forward-only with reason, OR reversible.
- [ ] PII fields identified.

## Security

- [ ] AuthN approach stated.
- [ ] AuthZ rules stated for each AC that requires them.
- [ ] Secrets storage stated.

## Tasks

- [ ] Every AC from `01-spec.md` is covered by ≥1 task.
- [ ] Every task has `Test-IDs` and `Files in scope`.
- [ ] Every task lists the gates it must run.
- [ ] Tasks are sized at roughly 1–4 hours.
- [ ] Cross-cutting tests are noted as Phase 5 (not duplicated in tasks).

## Epic mode (when applicable)

- [ ] `03-epic-design.md` exists and captures shared cross-cutting decisions.
- [ ] `03a-epic-roadmap.md` exists and sequences vertical slices with dependencies.
- [ ] Slice boundaries are vertical (user-visible outcomes), not layer-by-layer slices.
- [ ] Detailed `04-tasks.md` decomposition starts only after Epic artifacts are approved.

## ADRs

- [ ] Every non-obvious design decision has an ADR (status `proposed` is fine).
- [ ] ADRs link back to the design section that triggered them.

## No-invention

- [ ] No NFR or behavior introduced that is not in `01-spec.md` or codebase.
- [ ] All `Q-NNN` resolved or deferred-with-rationale.

## Sign-off

- [ ] Reviewed by user.
- [ ] Verdict recorded.
