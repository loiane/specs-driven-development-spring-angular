---
name: shipping-and-launch
description: Pre-deploy hygiene for a Spring Boot 4 feature — verify gates, capture rollback plan, sign off observability, generate release notes, and stage the rollout. Used by `/ship` after `/review` approves the diff. The agent never deploys; it produces the plan a human executes.
when_to_use:
  - Phase 8 (Ship) — `/ship` command, after `/review` verdict is approve.
  - Pre-deploy review on a brownfield repo where the toolkit is being adopted and the team wants a structured launch plan.
authoritative_references:
  - .github/prompts/ship.prompt.md
  - .github/templates/ship-plan.template.md
  - .github/skills/spring-security-baseline/SKILL.md
  - .github/skills/flyway-or-liquibase-detection/SKILL.md
---

# Shipping and launch

> Faster is safer. Small, reversible, observable changes ship more often and break less.

## What this skill produces

The artifact `.specs/<feature-id>/09-ship-plan.md`, populated from `.github/templates/ship-plan.template.md`, with these sections filled in:

1. Pre-ship gate results (PASS/FAIL per gate; FAIL = halt).
2. Feature-flag posture (flag name, default, kill-switch, owner).
3. Migration safety (Flyway/Liquibase script list, expand-vs-contract classification, rollback procedure).
4. Observability sign-off (new metrics, structured-log keys, alert rules, dashboard link).
5. Rollback plan (revert commit; DB rollback or contract-step procedure; on-call escalation).
6. Staged rollout plan (canary → percentage steps → 100%).
7. Release notes (user-facing changelog excerpt + internal notes).

## Pre-ship gates (must all be green)

| Gate | Source of truth | Halt if |
|---|---|---|
| Validation | `07-validation-report.md` verdict | not `PASS` |
| Code review | `08-code-review.md` verdict | not `Approve` (or `Approve with waivers` linking ADRs) |
| Open questions | `01-spec.md`, `03-design.md` `## Open Questions` | any unresolved `Q-NNN` |
| Baseline regression | `.specs/_baseline.json` vs latest harness | any new failure not in baseline |
| Diff scope | `git diff origin/main...HEAD` | files outside any task's `files_in_scope` |

If any gate halts, **stop and tell the user which command to run** (`/build`, `/test`, `/validate`, or `/review`). Do not write a partial ship plan.

## Feature flags

For any change that adds or alters a runtime path, decide:

- **Flag required?** Yes if the change is risky, irreversible, or touches a hot path. No if it's a pure bug fix or strictly additive.
- **Default?** Off in production until the canary clears. On in non-prod.
- **Kill-switch?** A documented config knob (env var or remote config key) that disables the new path without a redeploy.
- **Owner?** A named human (not "the team").

Record this in the ship plan even if the answer is "no flag" — with the reasoning.

## Migration safety

Detect the migration tool with `.github/skills/flyway-or-liquibase-detection/SKILL.md`. For each migration script in the diff:

| Classification | Definition | Required action |
|---|---|---|
| **Forward-only safe** | Adds nullable column, new table, new index, new view | Proceed |
| **Expand step** | First half of an expand-then-contract: write to old + new, read old | Proceed; record contract-step ticket |
| **Contract step** | Second half: read new, drop old | Verify expand step is in production for at least one full release cycle (or the period the team agreed to) |
| **Breaking** | Drops/renames a column, narrows a type, removes a table | Halt unless an ADR documents the migration plan, the feature flag gating it, and the rollback |

**No edits to a previously-released migration script.** New script, always.

Record the rollback procedure: revert commit alone is not enough when a migration ran. Spell out the SQL or contract step that reverses the schema change.

## Observability sign-off

For each new endpoint, message handler, or background task, verify:

- A `MeterRegistry` counter or timer with a stable, low-cardinality name (e.g. `gift_card.redeemed`, `gift_card.rejected`).
- A structured log line at the boundary with the feature-id and the AC-NNN it covers.
- An alert rule (or explicit "no alert needed" with reasoning).
- A dashboard link or panel reference.
- For HTTP endpoints: response-time histogram (p50/p95/p99) bucketed via Micrometer.

If any item is missing, halt and recommend `/build` or `/test` to add it before shipping.

## Rollback plan

Every ship plan must answer three questions in writing:

1. **How do we know it's broken?** (Alert name + threshold; user-report channel; metric anomaly.)
2. **How do we stop the bleeding in under 5 minutes?** (Flag flip; revert; scale-down; circuit breaker.)
3. **How do we recover state?** (Revert commit; replay events from offset N; reconcile job; manual SQL.)

If any answer is "we'd figure it out", halt — that's not a rollback plan.

## Staged rollout

Default rollout shape (override only with an ADR):

```text
canary (1 instance, ~1%)  →  10%  →  50%  →  100%
   ↳ 30 min observation     ↳ 1 hr   ↳ 4 hr   ↳ steady state
```

For each step the plan records:

- Entry criteria (previous step green for the observation window, no SEV-2+ alerts, error rate within budget).
- Abort criteria (specific metric thresholds; named on-call decides).
- Who watches what.

For changes behind a flag with no schema impact, the rollout is "flip flag for cohort N → observe → expand cohort". Same shape, different lever.

## Release notes

Two audiences, two sections in the ship plan:

- **External / user-facing.** Plain English, one to three bullets. Links to docs if the API changed. No internal jargon.
- **Internal / engineering.** Diff summary, AC-NNN list, ADR links, migration class, flag name, dashboard.

Both are generated from `git log origin/main..HEAD` plus `01-spec.md` `## Goal` and `04-tasks.md` task titles. The agent drafts both; the user edits the external one before publishing.

## Anti-rationalizations

| Excuse | Counter |
|---|---|
| "Small change, skip the flag." | Small changes still cause incidents. The flag costs minutes; an incident costs hours. Add the flag, default off, flip after the canary. |
| "Forward-only migration, no rollback needed." | Forward-only refers to the script direction, not the feature. The feature still needs a rollback path (flag flip, contract step, or replay). Document it. |
| "We'll add metrics if it breaks." | If it breaks without metrics you won't know. Add the counter and the alert *before* shipping, not after. |
| "100% rollout is fine, this is a tiny endpoint." | "Tiny" endpoints fan out to dependencies you don't see. Canary first; 5 minutes of caution prevents 5 hours of recovery. |
| "Release notes are a Product thing." | Engineering writes the technical truth; Product edits the tone. Skipping the engineering draft means the notes are wrong. |
| "Validation is green so we're good to ship." | Green tests prove the code does what the tests say. Shipping also requires flag posture, rollback, observability, and a rollout plan. |

## Red flags (block the ship plan)

- A migration script is renamed or edited from a previous release.
- The diff edits a previously-deployed feature flag's default without an ADR.
- A new endpoint has no metric and no alert.
- The rollback "plan" is "revert the commit" with no migration recovery.
- The release notes are auto-generated commit subjects with no human pass.
- Any `Q-NNN` is still open in the spec or design.

## Process inside `/ship`

1. **Verify gates.** Walk the table above. Halt at the first FAIL with a specific recovery command.
2. **Inspect the diff.** `git diff origin/main...HEAD` — classify migrations, identify new endpoints, locate metric registrations.
3. **Fill the template.** Use `.github/templates/ship-plan.template.md`. Every section must have content; "n/a" is allowed only with a one-line reason.
4. **Surface required human inputs.** Flag owner, alert thresholds, and rollout cohorts often need a human decision; mark these `Q-NNN`-style and halt until answered. Never invent.
5. **Emit the deploy command for the user.** Print the suggested command (e.g. `kubectl rollout ...`, `mvn deploy`, the team's release pipeline trigger). The agent never executes it.

## Verification

A ship plan is complete when:

- All seven sections are filled (no placeholder text).
- Every gate row in the pre-ship table is `PASS`.
- Migration scripts are classified, with named rollback steps.
- Each new endpoint has at least one named metric and one alert (or a documented "no alert" reason).
- The release notes have both an external and an internal section.
- The user has confirmed the flag owner, the alert thresholds, and the rollout cohorts.
