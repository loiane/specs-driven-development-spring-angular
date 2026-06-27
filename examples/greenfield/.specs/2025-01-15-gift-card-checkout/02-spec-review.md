# Spec review: gift-card-checkout

| Field         | Value                                  |
|---------------|----------------------------------------|
| Reviewer      | spec-author (review hat)        |
| Reviewed      | `01-spec.md` rev 2                     |
| Verdict       | **PASS**                               |
| ACs total     | 6                                      |
| ACs failed    | 0                                      |
| Open questions | 0                                     |
| Next command  | `/plan 2025-01-15-gift-card-checkout`  |

## Checklist

| # | Item                                                                | Verdict | Note |
|---|---------------------------------------------------------------------|---------|------|
| 1 | Business goal stated in one paragraph, includes user benefit         | pass    | "Lift conversion … as a tender type." |
| 2 | Primary actor named                                                  | pass    | Authenticated customer at /checkout. |
| 3 | In-scope and out-of-scope are explicit and disjoint                  | pass    | Multi-card explicitly deferred. |
| 4 | Every AC follows an EARS form                                        | pass    | AC-001 state-driven; AC-002..004 event-driven; AC-005 state-driven; AC-006 event-driven. |
| 5 | Every AC is independently testable                                   | pass    | Note added to AC-005 to justify split from AC-001. |
| 6 | No compound ACs (no "and shall also …")                              | pass    |        |
| 7 | Non-functional requirements have concrete numbers                    | pass    | p95, RPS, hashing algo specified. |
| 8 | Security touches called out                                          | pass    | Code is PII-class; hashed at rest. |
| 9 | Observability signals listed                                         | pass    | Two metrics + one structured log line. |
| 10 | No invented answers; all assumptions are Open Questions or resolved | pass    | Both Qs resolved with decisions captured. |
| 11 | Idempotency is addressed where retries are possible                  | pass    | AC-006 covers it. |
| 12 | Error model is explicit (codes, status)                              | pass    | 422 + `gift_card.{unknown,expired,depleted}`. |

## Findings

None blocking. Minor observation (not a fail): AC-005 partially overlaps AC-001
by design; the duplicated coverage is acceptable because it isolates the
remaining-balance accounting test from the apply-to-cart test.

## Verdict

**PASS** — proceed to `/plan`.
