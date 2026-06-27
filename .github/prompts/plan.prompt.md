---
mode: agent
description: Run /plan — see .github/prompts/plan.prompt.md for the authoritative spec.
tools: ['codebase', 'editFiles', 'search', 'runCommands', 'runTests']
model: GPT-5
---
# /plan

**Phase:** 3 — plan
**Owning agent:** `.github/chatmodes/spring-architect.chatmode.md`
**Skills used:** `epic-slicing-planning`, `spring-task-decomposition`, `spring-boot-4-conventions`, `openapi-contract-first`, `flyway-or-liquibase-detection`, `archunit-rules`, `adr-authoring`, `performance-optimization`

## Stack routing

| Feature scope | Agent |
|---|---|
| Backend-only or full-stack (Spring) | `spring-architect` (this agent) |
| Frontend-only (Angular) | `angular-architect` |
| Full-stack | Run both: `spring-architect` for backend tasks, `angular-architect` for frontend tasks |

If the feature's `01-spec.md` ACs reference only Angular/UI concerns (components, routes, templates, styles), delegate entirely to `angular-architect`. If ACs span both stacks, produce a unified `03-design.md` but decompose `04-tasks.md` into backend tasks (owned by `spring-architect`) and frontend tasks (owned by `angular-architect`).

## Purpose
Translate a `PASS`-verdict spec into planning artifacts:

- Non-Epic mode: `03-design.md` + `04-tasks.md`
- Epic mode: `03-epic-design.md` + `03a-epic-roadmap.md`, then slice-level `03-design.md` + `04-tasks.md`

Then initialize `.tdd-state.json`.

## Inputs
- `<feature-id>`.
- Optional `--epic` to force Epic mode.

## Reads
- `01-spec.md`, `02-spec-review.md` (verdict must be `PASS`).
- `.specs/_stack.json`.
- `.github/templates/design.template.md`, `.github/templates/tasks.template.md`, `.github/templates/adr.template.md`.
- Epic mode: `.github/templates/epic-design.template.md`, `.github/templates/epic-roadmap.template.md`.
- All design/architecture skills above.

## Writes
- `.specs/<feature-id>/03-epic-design.md` (Epic mode)
- `.specs/<feature-id>/03a-epic-roadmap.md` (Epic mode)
- `.specs/<feature-id>/03-design.md`
- `.specs/<feature-id>/04-tasks.md`
- `.specs/<feature-id>/.tdd-state.json` (initial: no `active_task`, every task `phase: "pending"`)
- `.specs/<feature-id>/adr/ADR-NNN-*.md` for any architecturally significant decision.

## Process
1. Refuse if `02-spec-review.md` is missing or its verdict is not `PASS`.
2. Refuse if `01-spec.md` still has any `Q-NNN`.
3. Detect planning mode. Use Epic mode if `--epic` is present or the feature spans multiple vertical slices/shared cross-cutting decisions.
4. In Epic mode, write `03-epic-design.md` and `03a-epic-roadmap.md` first. Refuse to continue if either Epic artifact has unresolved `Q-NNN`.
5. Produce `03-design.md`: module map, public API, REST contract sketch (or full OpenAPI), data model, migration plan (Flyway/Liquibase per `_stack.json`), error model, observability, security touch points, ArchUnit rule additions.
6. For each architecturally-significant choice, write an ADR.
7. Decompose into tasks `T-001`, `T-002`, ... Each task must list:
   - `id`, `title`, `acs_covered: [AC-NNN, ...]`, `files_in_scope: [paths]`, `depends_on`, `estimated_phases: [red, green, refactor, simplify]`.
   - Tasks that touch `src/main/**` MUST list at least one file under `src/test/**` in `files_in_scope`.
8. Validate AC coverage: every AC from `01-spec.md` must appear in at least one task. If not, FAIL the plan and surface the gap.
9. Initialize `.tdd-state.json`:
   ```json
   { "active_task": null, "tasks": { "T-001": { "phase": "pending", "files_in_scope": [...], "acs_covered": [...] }, ... } }
   ```

## Refuse if
- Spec review verdict is not `PASS`.
- Epic mode is active and either Epic artifact is missing.
- Any AC has no covering task.
- Any task touches `src/main/**` without a corresponding `src/test/**` file in scope.

## Done when
Design, tasks, ADRs, and `.tdd-state.json` are written. Point the user to `/build T-001`.
