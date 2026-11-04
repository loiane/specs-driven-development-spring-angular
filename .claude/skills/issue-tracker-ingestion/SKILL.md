---
name: issue-tracker-ingestion
description: Pull issue/PR/ticket details from Jira, GitHub Issues, Linear, or Azure Boards via MCP into `01-spec.md` `## Source`. Use at the start of `/spec` whenever the user references an external ticket.
when_to_use:
  - Phase 1 (Specify) — converting a tracker ID into a spec.
  - Verifying that a spec's `## Source` accurately reflects the ticket.
authoritative_references:
  - docs/platform-mapping.md (MCP wiring)
  - .claude/templates/spec.template.md
---

# Issue tracker ingestion

## Supported sources

| Source | MCP server | Identifier shape |
|---|---|---|
| Jira (Atlassian) | `atlassian` | `SHOP-1422` |
| GitHub Issues | `github` | `owner/repo#42` or URL |
| GitHub Pull Requests | `github` | `owner/repo!42` or URL |
| Linear | `linear` | `ENG-123` |
| Azure Boards | `azure-devops` | `AB#54321` |

If no MCP is configured, fall back to user-provided text. Never invent a ticket.

## Recipe (per source)

1. Resolve identifier → MCP fetch.
2. Capture: title, description, status, labels, assignee, comments (last 10), attachments (filenames only), URL, fetched-at timestamp.
3. Write a verbatim block in `01-spec.md`:

   ```markdown
   ## Source

   - **System:** Jira
   - **ID:** SHOP-1422
   - **URL:** https://example.atlassian.net/browse/SHOP-1422
   - **Title:** Apply gift card at checkout
   - **Status:** In Progress
   - **Fetched:** 2026-04-18T10:00:00Z

   ### Description (verbatim)
   > Users should be able to apply a gift card during checkout. It should reduce the order total. If the card has been used, show an error.

   ### Comments (last N, verbatim)
   > [PM, 2026-04-15]: Confirmed only authenticated buyers in scope.
   > [Eng lead, 2026-04-16]: Use existing error envelope.
   ```

4. Extract candidate ACs **only from the verbatim text**. Do not paraphrase requirements; quote the source line and put your AC under it. If a candidate AC has no source line, it goes to `## Open Questions` as a `Q-NNN`.

## No-invention enforcement

If a source field is missing (e.g. no acceptance criteria in the ticket), the agent does **not** fill it from imagination. It writes:

```markdown
- Q-001: Source ticket has no explicit acceptance criteria. Need user to confirm AC list before proceeding to AC drafting.
```

`/spec` then halts and asks the user.

## Updating after the ticket changes

If the user re-runs `/spec` and the ticket has changed:

- Re-fetch.
- Diff old vs new in `## Out-of-Band Inputs` ("ticket updated 2026-04-19; description gained paragraph about partial redemption").
- Add `Q-NNN` for any new requirement not yet in AC.

## Anti-patterns

- "The ticket says X" without quoting it.
- Summarizing comments instead of quoting.
- Pulling AC from the ticket title alone.
- Silently ignoring an unread comment that contradicts the description.
- Assuming the ticket assignee = the spec author.
