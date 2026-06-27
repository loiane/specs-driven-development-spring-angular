# Spec: <FEATURE-ID> — <short title>

> Owner: `spec-author` · Phase 1 · Template: `.windsurf/templates/spec.template.md`
>
> **No invention.** If something is not in the source ticket, the conversation, or the codebase, log it as a `Q-NNN` and ask the user.

## Source

- Tracker: <Jira | GitHub | Linear | Azure Boards | ad-hoc>
- ID: <e.g. SHOP-1422 or owner/repo#123>
- URL: <link>
- Snapshot date: <YYYY-MM-DD>
- Snapshot summary:
  > <verbatim or paraphrased title + description from the tracker>

## Goal

<one paragraph describing the user-visible outcome>

## Acceptance Criteria

Use EARS-lite shapes (see `docs/spec-format.md`). One condition per AC. IDs are stable and never reused.

- AC-001: <The system shall …> | <When …, the system shall …> | <If …, then the system shall …> | <While …, the system shall …> | <Where …, the system shall …>
- AC-002: …

## Non-Goals

- <explicitly out of scope>

## Glossary

- **Term** — definition.

## Assumptions

> Only assumptions explicitly stated by the user or the source ticket. The agent never adds assumptions silently.

- (none)

## Out-of-Band Inputs

> Anything provided by the user during the spec session that is not in the source ticket (e.g. screenshots pasted in chat, verbal clarifications). Recorded for traceability.

- (none)

## Open Questions

> Every uncertainty MUST be logged here. The agent does not pick a default.

- Q-001: <question>
  - Why it matters: <impact on design or behavior>
  - Candidate options identified: <option-A>, <option-B>
  - Status: open

## Resolved Questions

> Filled by the agent after the user answers. Verbatim user text + timestamp.

- (none yet)

## Sign-off

- [ ] All AC are atomic and testable.
- [ ] All `Q-NNN` are resolved or explicitly deferred-with-rationale.
- [ ] Source recorded.
- [ ] Reviewed by user on <YYYY-MM-DD>.
