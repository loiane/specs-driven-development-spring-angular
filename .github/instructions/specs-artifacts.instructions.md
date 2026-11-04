---
applyTo: ".specs/**/*.md"
description: "Spec artifact guardrails — no invention, stable IDs, phase ordering."
---

# Spec artifact guardrails

You are editing a file under `.specs/`. These artifacts ARE the contract between phases — treat them with the same rigor as production code.

## Identity rules

- AC IDs (`AC-NNN`) and task IDs (`T-NNN`) are stable. Never renumber. Insertions take the next number, even if it breaks reading order.
- `Q-NNN` open questions move from `## Open Questions` to `## Resolved Questions` with the answer + date — they are not deleted.
- ADR file names (`adr/NNN-<slug>.md`) are immutable once committed.

## No-invention

If a section requires information you don't have:

- Add a `Q-NNN` to `## Open Questions`.
- Halt and ask the user.
- Do **not** fill the section with a plausible default.

## Phase ordering

You may not edit a higher-numbered artifact (e.g. `04-tasks.md`) while a lower-numbered artifact (e.g. `02-spec-review.md`) is still in `request-changes` or has unresolved `Q-NNN`. The methodology document explains the gates.

## Traceability

- Every task in `04-tasks.md` lists `AC-IDs` and `Test-IDs`.
- Every test in `src/test/**` referenced by a task must use `@Tag("AC-NNN")` and `@DisplayName("AC-NNN: …")`.
- `07a-traceability.md` enforces zero uncovered ACs and zero orphan tests.

Apply `.github/skills/ears-spec-authoring/SKILL.md`, `.github/skills/spring-task-decomposition/SKILL.md`, `.github/skills/requirements-traceability/SKILL.md`.
