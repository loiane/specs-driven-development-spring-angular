# Spec Format — EARS-lite

The toolkit uses **EARS-lite** (Easy Approach to Requirements Syntax, simplified) for acceptance criteria. Specs are short, testable, and traceable.

## Why EARS-lite

- **Atomic.** One condition, one outcome — easy to map to one test.
- **Testable.** The shape of each clause maps directly to a Given/When/Then test or a property-based assertion.
- **Traceable.** Each AC has a stable ID (`AC-001`) referenced from tasks, tests, code, and the validation report.

We use a *lite* subset of EARS — five clause shapes, no formal grammar, no tooling lock-in.

## The five shapes

```
Ubiquitous:     The system shall <action>.
Event-driven:   When <trigger>, the system shall <action>.
State-driven:   While <state>, the system shall <action>.
Optional:       Where <feature>, the system shall <action>.
Unwanted:       If <unwanted condition>, then the system shall <mitigation>.
```

## AC ID convention

- Format: `AC-NNN` (zero-padded 3-digit, monotonically increasing within a feature).
- IDs are **never reused** even if the AC is removed; deletion leaves a tombstone.
- Tests reference the AC via either `@DisplayName("AC-007: rejects expired card")` or `@Tag("AC-007")`. The traceability matrix consumes both.

## Canonical line format

Tooling parses specs line by line, so ACs and open questions must use these exact shapes:

| Item | Format | Parsed by |
| --- | --- | --- |
| Acceptance criterion | `- AC-001: <EARS sentence>` (one bullet; continuation lines indented) | `.github/scripts/traceability.sh` |
| Open question | `- Q-001: <question>` under `## Open Questions`, with indented sub-bullets | `.claude/hooks/block-progress-on-open-questions.sh` |
| Question status | `  - Status: open` · `  - Status: deferred — <rationale>` · `  - Status: resolved <YYYY-MM-DD> — <answer>` | same hook — `deferred`/`resolved` entries do not block |

Resolved questions move to `## Resolved Questions`. For backward compatibility the parsers also accept `- **AC-001** — …` and `### AC-001: …`, but new specs should use the canonical form.

## Spec template

See the platform copy of `spec.template.md` (e.g. [.claude/templates/spec.template.md](../.claude/templates/spec.template.md)). Skeleton:

```markdown
# Spec: <feature-id> — <short title>

## Source
- Tracker: <Jira/GitHub/Linear/Azure/ad-hoc>
- ID: <FEATURE-123>
- URL: <link>
- Snapshot date: <YYYY-MM-DD>

## Goal
<one paragraph>

## Acceptance Criteria
- AC-001: When <trigger>, the system shall <action>.
- AC-002: While <state>, the system shall <action>.
- AC-003: If <unwanted condition>, then the system shall <mitigation>.

## Non-Goals
- ...

## Glossary
- **Term** — definition.

## Open Questions
- Q-001: <question>
  - Why it matters: <impact>
  - Candidate options: <option-A>, <option-B>
  - Status: open

## Resolved Questions
<empty>
```

## Worked example

```markdown
# Spec: GIFT-CARD-001 — Apply gift card at checkout

## Source
- Tracker: Jira
- ID: SHOP-1422
- URL: https://example.atlassian.net/browse/SHOP-1422
- Snapshot date: 2026-04-18

## Goal
Allow a customer to redeem a gift card during checkout, reducing the order total by the redeemed amount, never below zero, and exposing the redemption in the order receipt.

## Acceptance Criteria
- AC-001: When the customer applies a valid, non-expired gift card with positive balance, the system shall reduce the order total by min(card balance, order total).
- AC-002: When the redemption succeeds, the system shall record the redeemed amount and remaining balance in the order receipt.
- AC-003: If the gift card code is unknown, expired, or has zero balance, then the system shall reject the redemption with error code GC_INVALID and leave the order total unchanged.
- AC-004: While the order is in PAID state, the system shall reject any further gift-card redemption with error code GC_ORDER_LOCKED.
- AC-005: When two gift cards are applied to the same order, the system shall apply them in the order received and stop redeeming once the order total reaches zero.

## Non-Goals
- Issuing new gift cards.
- Refunding to gift cards.
- Multi-currency conversion.

## Glossary
- **Gift card** — a prepaid voucher identified by a 16-character code with a non-negative balance and an expiry date.
- **Redemption** — the act of subtracting from the gift card balance and reducing the order total.

## Open Questions
- Q-001: Should redemptions on a cancelled order be reversed automatically, or require a separate refund flow?
  - Why it matters: determines whether the redemption service needs to subscribe to order-cancelled events.
  - Candidate options: (a) auto-reverse on cancel, (b) manual refund flow, (c) reject cancel while gift card applied.
  - Status: open

## Resolved Questions
<empty>
```

## What does **not** belong in a spec

- Implementation choices (which class, which library, which DB column). Those go in `03-design.md`.
- Coverage thresholds, gate definitions. Those live in the harness.
- Time estimates. Tasks in `04-tasks.md` carry rough sizing only.
- Marketing copy or rationale beyond the `## Goal` paragraph.

## Anti-patterns the spec author refuses

- "The system shall be fast." → not testable. Either define a measurable NFR (`p95 latency ≤ 200 ms under N RPS`) or it is not an AC.
- "Probably we want…" → the agent never invents. Becomes a `Q-NNN`.
- A single AC that bundles multiple conditions → split into atomic ACs.
- Implementation leakage ("the system shall call PaymentService.charge()") → restate as observable behavior.
