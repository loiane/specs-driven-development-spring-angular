# `.specs/<feature-id>/` Artifact Contract

Every feature produces these files, in order. Phase advance is gated on the prior file existing and its checklist passing.

```text
.specs/
├── _baseline.json                  # repo-wide; brownfield pre-existing failures
└── <feature-id>/
    ├── 01-spec.md                  # phase 1 — owner: spec-author
    ├── 02-spec-review.md           # phase 2 — owner: spec-author
    ├── 03-epic-design.md           # phase 3a (optional, Epic mode) — owner: spring-architect
    ├── 03a-epic-roadmap.md         # phase 3a (optional, Epic mode) — owner: spring-architect
    ├── 03-design.md                # phase 3 — owner: spring-architect
    ├── 04-tasks.md                 # phase 3 — owner: spring-architect
    ├── 05-implementation-log.md    # phase 4 — owners: spring-test-engineer + spring-implementer
    ├── 06-test-plan.md             # phase 5 — owner: spring-test-engineer
    ├── 07-validation-report.md     # phase 6 — owner: spring-validator
    ├── 07a-traceability.md         # phase 6 — owner: spring-validator
    ├── 08-code-review.md           # phase 7 — owner: spring-code-reviewer
    ├── 09-ship-plan.md             # phase 8 (optional) — owner: spring-code-reviewer
    ├── .tdd-state.json             # phase 4 — runtime state for block-impl-without-failing-test
    └── adr/
        └── NNN-<slug>.md           # MADR ADRs referenced from 03-design.md
```

## Naming rules

- `<feature-id>` is `kebab-case`, ≤ 40 chars, prefixed with the source tracker key when one exists (e.g. `shop-1422-gift-card-checkout`).
- All numbered files use the leading two-digit prefix (`01-…`, `02-…`); insertions get an `a/b/c` suffix (`07a-…`).

## Templates

Each artifact starts from the matching template under `templates/`:

| Artifact | Template |
| --- | --- |
| `01-spec.md` | `spec.template.md` |
| `02-spec-review.md` | `spec-review.template.md` |
| `03-epic-design.md` | `epic-design.template.md` |
| `03a-epic-roadmap.md` | `epic-roadmap.template.md` |
| `03-design.md` | `design.template.md` |
| `04-tasks.md` | `tasks.template.md` |
| `05-implementation-log.md` | `implementation-log.template.md` |
| `06-test-plan.md` | `test-plan.template.md` |
| `07-validation-report.md` | `validation-report.template.md` |
| `07a-traceability.md` | `traceability.template.md` |
| `08-code-review.md` | `code-review.template.md` |
| `09-ship-plan.md` | `ship-plan.template.md` |
| `adr/NNN-<slug>.md` | `adr.template.md` |

## `.tdd-state.json`

Runtime file maintained by `/build` and read by the `block-impl-without-failing-test` hook.

```json
{
  "feature_id": "shop-1422-gift-card-checkout",
  "active_task": "T-001",
  "tasks": {
    "T-001": {
      "phase": "red | green | refactor | simplify | done",
      "red_at": "2026-04-18T10:00:00Z",
      "red_test_signature": "com.example.X.shouldRejectExpiredCard",
      "red_failure_excerpt": "AssertionFailedError: expected 400 but was 200",
      "green_at": null,
      "files_in_scope": ["src/main/java/.../X.java", "src/test/java/.../XTest.java"]
    }
  }
}
```

A new `src/main/**` edit is allowed only when the active task's `phase` is `red` AND `red_at` is set AND `red_failure_excerpt` is non-empty.

## Forbidden

- Editing artifact files out of phase order.
- Skipping `02-spec-review.md` (sign-off required).
- In Epic mode, writing `04-tasks.md` before both `03-epic-design.md` and `03a-epic-roadmap.md` are approved.
- Beginning `04-tasks.md` while `03-design.md` has unresolved `Q-NNN`.
- Editing `08-code-review.md` by anyone other than `spring-code-reviewer`.

## Epic mode trigger

Epic mode is required when the feature has two or more planned vertical slices, shared cross-cutting architectural decisions, or multi-milestone delivery requirements. In Epic mode:

1. `03-epic-design.md` and `03a-epic-roadmap.md` must exist before detailed task decomposition.
2. Epic-level open questions (`Q-NNN`) must be resolved (or deferred with rationale) before `04-tasks.md` is finalized.
3. Slice-level detailed tasks are generated incrementally from the Epic roadmap.

## Cross-references

- Source ticket → `01-spec.md` `## Source`
- AC → tests via `@DisplayName("AC-NNN: …")` or `@Tag("AC-NNN")`
- AC → tasks via `04-tasks.md` task entry's `AC-IDs`
- Tasks → tests via `04-tasks.md` task entry's `Test-IDs`
- Findings → ADRs via the `Waivers` section of `08-code-review.md`
