# Ship Plan: <FEATURE-ID>

> Owner: `spring-code-reviewer` · Phase 8 · Skills: `shipping-and-launch`, `spring-security-baseline`, `flyway-or-liquibase-detection`
>
> Pre-deploy hygiene. The agent never deploys; it produces this plan and prints the deploy command for the user.

## Inputs

- Spec: `01-spec.md`
- Design: `03-design.md`, ADRs under `adr/`
- Tasks: `04-tasks.md`
- Validation: `07-validation-report.md` (verdict must be `PASS`)
- Code review: `08-code-review.md` (verdict must be `Approve` or `Approve with waivers`)
- Diff: <git range, e.g. `origin/main...HEAD`>

## 1. Pre-ship gates

| Gate | Source | Result | Notes |
|---|---|---|---|
| Validation | `07-validation-report.md` | PASS / FAIL | <link> |
| Code review | `08-code-review.md` | Approve / Approve-with-waivers / FAIL | <link> |
| Open questions | spec + design `## Open Questions` | 0 / N | <list any> |
| Baseline regression | `.specs/_baseline.json` vs harness | none / N | <list any> |
| Diff scope | `files_in_scope` per task | in-scope / drift | <list any out-of-scope files> |

If any row is FAIL, **stop**. Do not fill the rest of this template.

## 2. Feature-flag posture

- **Flag name:** <name or `none — reason: ...`>
- **Default in production:** off / on
- **Kill-switch:** <env var or remote config key>
- **Owner:** <named human, not "the team">
- **Removal plan:** <date or condition for retiring the flag>

If `none`, justify in one line (e.g. "pure bug fix, additive only, covered by existing alert").

## 3. Migration safety

| Script | Class | Rollback procedure |
|---|---|---|
| `Vxxx__name.sql` | forward-only / expand / contract / breaking | <SQL or contract step> |

Constraints:

- [ ] No previously-released migration script was renamed or edited.
- [ ] Every `breaking` script has a covering ADR.
- [ ] Every `contract` step's matching `expand` has been in production for the agreed period.

## 4. Observability sign-off

For each new endpoint, handler, or scheduled task:

| Surface | Metric (Micrometer) | Structured-log key | Alert | Dashboard |
|---|---|---|---|---|
| `<METHOD> <path>` | `<metric.name>` (Timer w/ histogram) | `feature_id`, `ac_id` | <alert name + threshold> | <link> |

If a row has no alert, record the explicit reason in the row.

## 5. Rollback plan

1. **Detection.** How do we know it's broken? <alert name + threshold; user-report channel; metric anomaly>
2. **Stop the bleeding (≤ 5 min).** <flag flip; revert; scale-down; circuit breaker>
3. **State recovery.** <revert commit; replay events from offset N; reconcile job; manual SQL>

A `revert the commit` answer to (3) is incomplete when a migration ran — spell out the contract step or SQL.

## 6. Staged rollout

| Step | Cohort | Entry criteria | Abort criteria | Observation window | Watcher |
|---|---|---|---|---|---|
| Canary | ~1% (1 instance) | gates green | error rate > X%, p95 > Y ms | 30 min | <on-call> |
| Step 1 | 10% | canary clean for window | same | 1 hr | <on-call> |
| Step 2 | 50% | step 1 clean | same | 4 hr | <on-call> |
| Full | 100% | step 2 clean | same | steady state | <on-call> |

For flag-gated changes, "cohort" is the flag's user/tenant slice. Adjust the table accordingly; the shape stays the same.

## 7. Release notes

### External (user-facing)

- <plain English bullet 1>
- <plain English bullet 2>
- <plain English bullet 3, optional>

### Internal (engineering)

- **AC covered:** <AC-NNN, AC-NNN, ...>
- **Diff summary:** <one paragraph>
- **ADRs:** <links>
- **Migration class:** <forward-only / expand / contract / breaking>
- **Flag name:** <name or `none`>
- **Dashboard:** <link>
- **Commits:** `git log <base>..HEAD --oneline`

## 8. Deploy command (for the user to run)

```text
<suggested command, e.g. team release-pipeline trigger, kubectl rollout, mvn deploy>
```

The agent does not execute this. The user runs it.

## Sign-off

- [ ] All gates PASS.
- [ ] Flag owner, alert thresholds, and rollout cohorts confirmed by a human.
- [ ] External release notes edited by a human.
- [ ] On-call notified and ack'd the deploy window.

Date: <YYYY-MM-DD> · Approved-by: <name>
