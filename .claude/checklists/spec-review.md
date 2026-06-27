# Spec Review Checklist

Used by `spec-author` to gate exit from Phase 2.

## Source & framing

- [ ] Source recorded (tracker, ID, URL, snapshot date) OR explicitly marked `ad-hoc`.
- [ ] Goal is one paragraph and describes a user-visible outcome.
- [ ] Non-goals are present and explicit.
- [ ] Glossary covers every domain term used in AC.
- [ ] `## Domain Entities and Relationships` is present.
- [ ] Entities are described in business terms (no class/table/library leakage).
- [ ] Relationships include clear cardinality and business meaning.

## Acceptance criteria

- [ ] Every AC has a stable ID `AC-NNN` (zero-padded, monotonically increasing).
- [ ] Every AC follows an EARS-lite shape (ubiquitous / event / state / optional / unwanted).
- [ ] Every AC is atomic (one condition, one outcome).
- [ ] Every AC is testable (the agent can describe a Given/When/Then test for it).
- [ ] No AC contains implementation choices (class names, libraries, columns, defaults).
- [ ] Vague NFRs ("fast", "secure", "scalable") have been replaced with measurable conditions OR demoted to `Q-NNN`.

## No-invention

- [ ] Assumptions list contains only user/source-stated items.
- [ ] No silent defaults (DB engine, auth scheme, pagination, error envelope, …).
- [ ] All `Q-NNN` items are resolved or explicitly deferred-with-rationale.

## Completeness

- [ ] Source ticket's stated AC are all reflected (or explicitly excluded as non-goals).
- [ ] Out-of-band inputs (chat clarifications, screenshots) recorded under `## Out-of-Band Inputs`.

## Cutover safety

- [ ] Any user-visible cutover (migration, behavior swap, UI change) either has a feature flag with a documented rollback procedure OR carries an explicit waiver with user sign-off.

## Sign-off

- [ ] Reviewed by user.
- [ ] Verdict recorded in `02-spec-review.md` (`approve` or `request-changes`).
