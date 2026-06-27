---
mode: agent
description: Run /spec-review — see .github/prompts/spec-review.prompt.md for the authoritative spec.
tools: ['codebase', 'editFiles', 'search', 'runCommands', 'runTests']
model: GPT-5
---
# /spec-review

**Phase:** 2 — review
**Owning agent:** `.github/chatmodes/spec-author.chatmode.md` (review hat)
**Skills used:** `ears-spec-authoring`, `requirements-traceability`

## Purpose
Audit `01-spec.md` against the spec checklist and produce `02-spec-review.md` with a pass/fail verdict and a numbered list of required edits.

## Inputs
- `<feature-id>` (positional). If omitted, use the most recently modified `.specs/<id>/`.

## Reads
- `.specs/<feature-id>/01-spec.md`
- `.github/checklists/spec-review.md`
- `.github/templates/spec-review.template.md`

## Writes
- `.specs/<feature-id>/02-spec-review.md`

## Process
1. Walk every checklist item; for each, record `pass | fail | n/a` plus a one-line rationale.
2. For each `fail`, write a concrete edit (line + replacement) the spec author must apply.
3. Verify EARS form compliance for every AC.
4. Verify each AC is independently testable (no compound criteria).
5. Verify `## Open Questions` is empty before declaring overall verdict `PASS`.
6. Emit summary: `verdict`, `acs_total`, `acs_failed`, `open_questions`, `next_command`.

## Refuse if
- `01-spec.md` does not exist.
- Any `Q-NNN` is unresolved — verdict must be `FAIL` with the open question list quoted verbatim.

## Done when
`02-spec-review.md` exists. If verdict is `PASS`, point the user to `/plan`. If `FAIL`, point them back to editing `01-spec.md`.
