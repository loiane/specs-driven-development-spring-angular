---
name: adr-authoring
description: Author MADR-style Architecture Decision Records under `.specs/<feature-id>/adr/`. Use whenever a non-obvious technical decision is made, a default is overridden, or a waiver is granted.
when_to_use:
  - Phase 3 (Plan) — capturing every design decision that has alternatives.
  - Phase 6 (Validate) — when waiving a harness gate.
  - Phase 7 (Code review) — when accepting a finding without fixing it.
authoritative_references:
  - https://adr.github.io/madr/
  - .github/templates/adr.template.md
---

# ADR authoring

## When to write one

Write an ADR if **any** of:

- The decision has plausible alternatives a future engineer might prefer.
- The decision overrides a default in this toolkit (skill says X, we do Y).
- The decision waives a harness gate (mutation, coverage, OpenAPI breaking, CVE).
- The decision constrains future work (e.g. "we will not use Kafka in this module").

Do **not** write an ADR for:

- Choices uniquely forced by the source ticket.
- Trivial mechanical decisions (variable naming).

## File layout

`.specs/<feature-id>/adr/NNN-<slug>.md` where `NNN` is zero-padded and unique per feature.

## Required sections (MADR)

- **Title** — short, decision-shaped: "Use Liquibase for schema migrations".
- **Status** — `proposed` | `accepted` | `rejected` | `superseded by NNN` | `deprecated`.
- **Context** — what problem, what constraints, what we know.
- **Decision drivers** — the forces (perf, team familiarity, cost, security).
- **Considered options** — at least two.
- **Decision outcome** — chosen option and one-paragraph justification.
- **Consequences** — positive AND negative.
- **Pros and cons of each option** — symmetric table.
- **Links** — back to `01-spec.md`, `03-design.md` section, related ADRs, external references.

## Naming examples

```text
.specs/shop-1422-gift-card-checkout/adr/
├── 001-use-liquibase-for-migrations.md
├── 002-redeem-balance-stored-as-cents-int.md
├── 003-waive-mutation-on-config-classes.md
└── 004-breaking-api-change-error-envelope.md
```

## Anti-patterns

- ADR with one option (it's a memo, not a decision).
- ADR with no `Consequences` section, especially no negatives.
- "We chose X because it's better" — give a driver and a measurable reason.
- ADR written **after** the code is merged — write it during Plan, refine during Validate.
- Editing an `accepted` ADR. Mark it `superseded by NNN` and write a new one instead.

## Status flow

```text
proposed → accepted → (later) superseded
                ↓
              rejected
```

A `proposed` ADR is fine to merge; it documents the current direction. A `rejected` ADR is also valuable — it records why the obvious option was not chosen, saving the next person from re-asking.
