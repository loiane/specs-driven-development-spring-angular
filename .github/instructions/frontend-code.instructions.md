---
applyTo: "**/src/**/*.{ts,html,scss,css}"
description: "Frontend code guardrails for Angular implementation, testing, and accessibility."
---

# Frontend code guardrails (Angular)

These rules apply when a task includes Angular source files (`*.ts`, `*.html`, `*.scss`, `*.css` under `src/`).

## Block: TDD precondition

Before writing or editing an Angular source file:

1. Read `.specs/<active-feature>/.tdd-state.json`.
2. For production files (anything except `*.spec.ts`), confirm `tasks[<active-task>].phase` is `red`, `green`, `refactor`, or `simplify` AND `red_at` is set AND `red_failure_excerpt` is non-empty.
3. Confirm the file path appears in `tasks[<active-task>].files_in_scope` (production and `*.spec.ts` files alike).

If any check fails, **refuse the edit** and tell the user:

> "Cannot edit frontend code: no failing test for task `<task-id>`. Run `/build <task-id>` so the test-engineer writes the failing test first."

## Build-phase rules (TDD)

- Test-first: write/extend failing tests before implementing behavior.
- Never skip frontend tests to force green.
- Never remove assertions from existing tests.

## Angular implementation rules

- Prefer standalone components and typed interfaces/models.
- Keep smart/container logic separate from presentational components where practical.
- Avoid hardcoded API URLs in components; route all calls through services.
- Keep templates accessible: semantic buttons/inputs, labels, and keyboard-operable controls.

## Test rules

- Add/maintain component/service tests for new behavior.
- Every user-input validation rule needs a negative-path test.
- For optimistic-update flows, test both success and rollback paths.

## Validate/review rules

- During `/validate` and `/review`, never modify production code or tests.
- Missing frontend validation outputs (lint/test/build for changed UI scope) is an error.
- Any waiver must reference an ADR.
