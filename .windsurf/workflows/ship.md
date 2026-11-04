---
description: Run /ship — see .windsurf/workflows/ship.md for the authoritative spec.
---
# /ship

**Phase:** 8 — ship (post-commit, pre-deploy hygiene)
**Owning agent:** `.windsurf/workflows/spring-code-reviewer.md` (reused; no new persona)
**Skills used:** `shipping-and-launch`, `spring-security-baseline`, `flyway-or-liquibase-detection`

## Purpose

After `/review` approves the diff and the user commits, produce a structured ship plan that verifies pre-deploy gates, captures rollback + observability + flag posture, plans the staged rollout, and drafts release notes. The agent **never deploys** — it prints the deploy command for the user to run.

## Inputs

- `<feature-id>` (optional). Defaults to the most recent feature with an `08-code-review.md` verdict of `Approve` or `Approve with waivers`.
- Optional `--base <ref>` (defaults to `origin/main`) for diff and release-note generation.

## Reads

- `.specs/<feature-id>/01-spec.md` — `## Goal`, AC list, any open `Q-NNN`.
- `.specs/<feature-id>/03-design.md` — migration plan, security posture, any open `Q-NNN`.
- `.specs/<feature-id>/04-tasks.md` — `files_in_scope` for diff-scope check.
- `.specs/<feature-id>/07-validation-report.md` — verdict must be `PASS`.
- `.specs/<feature-id>/08-code-review.md` — verdict must be `Approve` or `Approve with waivers`.
- `.specs/_baseline.json` — for regression check.
- `git diff <base>...HEAD` and `git log <base>..HEAD` — for migration classification, new-endpoint detection, release-note drafting.
- `.windsurf/skills/shipping-and-launch/SKILL.md` (authoritative behavior).
- `.windsurf/templates/ship-plan.template.md`.

## Writes

- `.specs/<feature-id>/09-ship-plan.md`.

## Process

1. **Resolve feature.** If no `<feature-id>`, pick the most recent feature with `08-code-review.md` verdict `Approve*`. Refuse if none.
2. **Verify pre-ship gates** (per `shipping-and-launch` skill): validation `PASS`, review `Approve*`, zero unresolved `Q-NNN`, no baseline regression, every changed file is in some task's `files_in_scope`. Halt at the first FAIL with the specific recovery command.
3. **Classify migrations.** Walk `src/main/resources/db/migration/**` (Flyway) or the changelog (Liquibase) hunks in the diff. Tag each script: forward-only safe / expand / contract / breaking. Halt on `breaking` without an ADR.
4. **Inventory new surface.** New REST endpoints, message handlers, scheduled tasks, external HTTP clients. For each, verify a `MeterRegistry` registration exists in the diff. Halt on missing metric.
5. **Render the ship plan.** Fill `.windsurf/templates/ship-plan.template.md` — every section non-empty (`n/a` allowed only with a one-line reason).
6. **Surface human-required inputs as `Q-NNN`.** Flag owner, alert thresholds, rollout cohorts. Halt until the user answers; do not invent.
7. **Draft release notes.** Two sections: external (plain English, ≤ 3 bullets, edited by the user before publishing) and internal (diff summary, AC list, ADR links, migration class, flag name, dashboard).
8. **Print deploy command.** Suggest the team's release-pipeline trigger or `kubectl rollout` / `mvn deploy` line. The agent never executes it.

## Refuse if

- `07-validation-report.md` verdict is not `PASS`.
- `08-code-review.md` verdict is not `Approve` or `Approve with waivers`.
- Any `Q-NNN` is unresolved in the spec or design.
- A migration script in the diff is `breaking` and there is no covering ADR.
- A new endpoint, handler, or scheduled task has no `MeterRegistry` registration in the diff.
- The diff edits a previously-released migration script (Flyway: file rename or hash change for an applied script).
- The diff is empty (nothing to ship).

## Done when

`09-ship-plan.md` exists with all seven sections filled, every gate in the pre-ship table is `PASS`, migrations are classified with named rollback steps, every new endpoint has at least one named metric and one alert (or a documented "no alert" reason), and release notes have both external and internal sections. The agent then prints the suggested deploy command for the user to execute manually.
