# Spec Review: <FEATURE-ID>

> Owner: `spec-author` · Phase 2 · Checklist: `.windsurf/checklists/spec-review.md`

## Inputs

- `01-spec.md` revision: <git-sha or timestamp>

## Checklist

- [ ] Source recorded with tracker ID + URL + snapshot date.
- [ ] Goal is one paragraph and describes a user-visible outcome.
- [ ] Each AC follows an EARS-lite shape.
- [ ] Each AC is atomic (one condition, one outcome).
- [ ] Each AC is testable (the agent can describe a Given/When/Then test for it).
- [ ] No AC contains implementation choices (class names, libraries, columns).
- [ ] Non-goals are present and explicit.
- [ ] Glossary covers every domain term used in AC.
- [ ] Assumptions list contains only user/source-stated items.
- [ ] All `Q-NNN` items are resolved or explicitly deferred-with-rationale.
- [ ] No new `Q-NNN` discovered during this review remain open.

## Findings

> Each finding gets an ID and a severity (`blocker | major | minor | nit`). Blockers/majors must be resolved before exit.

- (none)

## New Questions Raised

> If review surfaces a new uncertainty, log it here and bounce back to phase 1 to add it to `01-spec.md`'s `## Open Questions`.

- (none)

## Verdict

- [ ] Approved — proceed to `/design`
- [ ] Changes requested — return to `spec-author`

Reviewer: <user>
Date: <YYYY-MM-DD>
