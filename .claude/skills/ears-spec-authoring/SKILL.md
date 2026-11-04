---
name: ears-spec-authoring
description: Author acceptance criteria using EARS-lite shapes with stable AC-NNN IDs and explicit Q-NNN open questions. Use when drafting or editing `01-spec.md`, when transforming a tracker ticket into ACs, or when a user asks for a spec / requirements doc.
when_to_use:
  - Phase 1 (Specify) — converting a feature request into testable ACs.
  - Anywhere a vague requirement ("must be fast", "should be secure") needs to be made concrete.
authoritative_references:
  - https://alistairmavin.com/ears/  (EARS background, by its author Alistair Mavin)
  - .claude/templates/spec.template.md
  - docs/spec-format.md
---

# EARS-lite spec authoring

## The five shapes

Every AC is one of:

| Shape | Skeleton | Use when |
|---|---|---|
| **Ubiquitous** | The system shall `<response>`. | Always-true invariant. |
| **Event-driven** | When `<trigger>`, the system shall `<response>`. | An external event causes a behavior. |
| **State-driven** | While `<state>`, the system shall `<response>`. | Behavior holds throughout a state. |
| **Optional feature** | Where `<feature included>`, the system shall `<response>`. | Conditional on configuration. |
| **Unwanted behavior** | If `<unwanted condition>`, then the system shall `<mitigation>`. | Error / failure handling. |

## Rules (enforced by `spec-review.md`)

1. **One AC = one condition + one outcome.** Split anything with "and".
2. **Stable IDs.** Format `AC-NNN`. Never renumber. Insertions get the next number, even if it breaks reading order.
   Write each AC as one bullet `- AC-NNN: <EARS sentence>` and each open question as `- Q-NNN: <question>` (see `docs/spec-format.md` § Canonical line format). Hooks and `traceability.sh` parse this shape.
3. **No implementation.** No class names, no DB columns, no library names, no defaults.
4. **No vague NFRs.** "Fast" → `< 200 ms p95 under 50 RPS` OR demote to `Q-NNN`.
5. **No silent defaults.** If the user did not say which behavior to pick, write a `Q-NNN`.
6. **Feature-flag the risky cutovers.** For any cutover, migration, or behavior swap that is user-visible, raise a `Q-NNN` asking whether a feature flag with rollback procedure is required. Default to "yes, use a feature flag" unless the user explicitly waives it.

## The Q-NNN escape hatch

When you would otherwise invent something, write:

```markdown
## Open Questions
- Q-001: Source ticket says "users get a discount" but does not specify whether unauthenticated users qualify. Need decision before AC-005 can be written.
```

Resolve via direct user answer, then move it to `## Resolved Questions` with a `- Status: resolved <YYYY-MM-DD> — <answer>` sub-bullet. A question you explicitly defer may stay under `## Open Questions` with `- Status: deferred — <rationale>`; it no longer blocks later phases.

## Worked example

Source ticket:
> *Users should be able to apply a gift card during checkout. It should reduce the order total. If the card has been used, show an error.*

Bad (what to avoid):

> AC-001: The system uses a `GiftCard` entity with a `usedAt` timestamp and returns 400 when `usedAt != null`.

Why bad: invents a class name, invents a column, invents an HTTP status.

Good:

```markdown
## Acceptance Criteria

- AC-001: When an authenticated buyer submits a gift card code with their order, the system shall reduce the order total by the card's remaining balance, capped at the order subtotal.
- AC-002: When an authenticated buyer submits a gift card code that has already been fully redeemed, the system shall reject the request and inform the buyer that the card has no remaining balance.
- AC-003: When an authenticated buyer submits a gift card code that does not exist, the system shall reject the request and inform the buyer that the code is unknown.
- AC-004: While a gift card has remaining balance, the system shall allow it to be applied to multiple orders until the balance reaches zero.

## Open Questions
- Q-001: Should unauthenticated/guest checkouts be allowed to use gift cards? Source ticket only mentions "users".
- Q-002: Maximum number of gift cards per order? Default? (No source guidance.)
- Q-003: What user-facing error format does the buyer see? Banner? Inline field? (UI not specified.)
```

## Self-check before handing off to review

- [ ] Could a junior tester write a Given/When/Then for every AC without asking me a clarifying question?
- [ ] If I removed the AC, would something user-visible change?
- [ ] Does any AC contain "and" / "or" that should be two ACs?
- [ ] Are all invented details (defaults, error formats, limits) demoted to `Q-NNN`?
