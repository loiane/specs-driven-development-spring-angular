# Spec: gift-card-checkout

| Field        | Value                                                    |
|--------------|----------------------------------------------------------|
| Feature ID   | `2025-01-15-gift-card-checkout`                          |
| Owner        | checkout-team                                            |
| Status       | `PASS` (validated 2025-01-22)                            |
| Source       | Free text from product: *"Let users redeem a gift card during checkout, applied before tax. Cards can be partially used."* |

## Business goal

Lift conversion on the checkout page by accepting gift cards as a tender type.
Gift cards must reduce the payable amount before tax is calculated and may be
partially redeemed across multiple orders.

## Primary actor

Authenticated customer at the `/checkout` page.

## In scope

- Accepting a 16-character gift card code at checkout.
- Validating the card (exists, active, has remaining balance).
- Applying the card balance to the order subtotal (before tax).
- Recording a partial redemption when the order subtotal is less than the card balance.
- Surfacing a domain error when the card is invalid, expired, or fully redeemed.

## Explicitly out of scope

- Gift card issuance or top-up (separate feature).
- Refunds back to a gift card (separate feature).
- Combining multiple gift cards on a single order (deferred to v2).

## Acceptance criteria (EARS)

- AC-001: While an authenticated customer is at checkout with a non-empty cart,
  when they submit a valid, active gift card code with sufficient balance, the
  system shall reduce the order subtotal by the order subtotal amount (card fully
  covers it) or by the full card balance (card does not fully cover it), recompute
  tax on the reduced subtotal, and persist a `GiftCardRedemption` record linking
  the order id, card id, and amount applied.
- AC-002: When a customer submits a code that does not match any issued gift card,
  the system shall reject the submission with HTTP 422 and error code
  `gift_card.unknown` and shall NOT modify the cart total.
- AC-003: When a customer submits a code matching a card whose `expires_at` is in
  the past, the system shall reject the submission with HTTP 422 and error code
  `gift_card.expired`.
- AC-004: When a customer submits a code matching a card whose remaining balance
  is zero, the system shall reject the submission with HTTP 422 and error code
  `gift_card.depleted`.
- AC-005: While a card has a remaining balance smaller than the order subtotal,
  when the redemption succeeds, the system shall debit the card by exactly the
  order subtotal and leave the difference as the new remaining balance.
  *(Note: this is the inverse of AC-001's partial path, restated here so the
  remaining-balance accounting has its own dedicated test.)*
- AC-006: When a customer submits the same gift card code twice with the same
  `Idempotency-Key` header within 24 hours, the system shall apply the card
  exactly once and return the same response on the second call.

## Non-functional requirements

- **Latency**: p95 ≤ 150 ms server-side at the redemption endpoint under 50 RPS.
- **Throughput**: ≥ 100 redemptions/sec sustained on a single 4-vCPU pod.
- **Security**: gift card codes are PII-class secrets; never logged in plaintext;
  hashed (SHA-256 with per-deployment salt) at rest in the lookup index.
- **Observability**: emit `gift_card.redeem.success` and `gift_card.redeem.failure{reason}`
  counters; one structured log line per redemption attempt at INFO with the
  card-id (not the code) and order-id.
- **Auditing**: every redemption row is append-only; no updates, no deletes.

## Open Questions

*(none — all resolved before spec was marked PASS)*

## Resolved Questions

- Q-001: Should multi-card redemption be supported?
  - Status: resolved 2025-01-15 — No, deferred to v2 per product. Captured
    under "Explicitly out of scope".
- Q-002: What happens to tax when a card brings the subtotal to zero?
  - Status: resolved 2025-01-15 — Tax is computed on the reduced subtotal, so it
    becomes 0. Captured in AC-001.
