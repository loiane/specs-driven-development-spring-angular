---
description: Run /status — see .windsurf/workflows/status.md for the authoritative spec.
---
# /status

**Phase:** meta — read-only
**Owning agent:** none (pure reporting)

## Purpose

Show the user where every active feature stands. No writes, no side effects.

## Inputs

- Optional `<feature-id>`; without it, summarize all features under `.specs/`.

## Reads

- `.specs/*/01-spec.md`, `02-spec-review.md`, `03-epic-design.md`, `03a-epic-roadmap.md`, `03-design.md`, `04-tasks.md`, `.tdd-state.json`, `07-validation-report.md`.
- `target/harness-summary.json` if present.

## Writes

Nothing.

## Process

For each feature (or the supplied one), produce a one-row-per-feature table:

- `feature_id`
- `phase` — derived from which artifacts exist + verdicts (specify, spec-review, plan-epic, plan, build, test, validate, review, done).
- `acs_total`, `acs_with_tests`
- `tasks_done / tasks_total`
- `last_validate_verdict` and timestamp
- `active_task` from `.tdd-state.json` (if any) and its current `phase`

Then print a single sentence: "Recommended next action: …".

## Refuse if

Never. This command never refuses; if data is missing it shows `—`.

## Done when

Status table is printed and a recommended next command is suggested.
