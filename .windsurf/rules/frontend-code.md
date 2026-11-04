---
trigger: glob
globs: ["**/src/**/*.ts", "**/src/**/*.html", "**/src/**/*.scss", "**/src/**/*.css"]
description: "Frontend code rule — TDD precondition, Angular conventions, and accessibility."
---

# Frontend code rule (Angular)

When about to edit an Angular source file (`*.ts`, `*.html`, `*.scss`, `*.css` under `src/`):

1. **Read** `.specs/<active-feature>/.tdd-state.json`.
2. For production files (anything except `*.spec.ts`), **verify** `tasks[<active-task>].phase` is `red`, `green`, `refactor`, or `simplify`, `red_at` is set, `red_failure_excerpt` is non-empty, AND the file appears in `files_in_scope`.
3. For `*.spec.ts` files, **verify** the file appears in `files_in_scope`.
4. If verification fails, **stop** and tell the user: "No failing test for task `<task-id>`. Invoke `/build <task-id>` to write the test first."

## Build-phase rules (TDD)

- Test-first: write/extend failing tests before implementing behavior.
- Never skip frontend tests to force green.
- Never remove assertions from existing tests.

## Angular implementation rules

Apply skills: `.windsurf/skills/angular-developer/SKILL.md`, `.windsurf/skills/clarity-over-cleverness/SKILL.md`.

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
