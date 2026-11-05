---
agent: agent
description: Run /epic-plan — see .github/prompts/epic-plan.prompt.md for the authoritative spec.
tools: ['read', 'edit', 'search', 'execute', 'todo']
---
# /epic-plan

**Phase:** 3a — Epic planning
**Owning agent:** `.github/agents/spring-architect.agent.md`
**Skills used:** `epic-slicing-planning`, `spring-boot-4-conventions`, `openapi-contract-first`, `adr-authoring`, `performance-optimization`

## Purpose

Create high-level Epic planning artifacts before detailed slice-level tasks.

## Inputs

- `<feature-id>`.

## Reads

- `.specs/<feature-id>/01-spec.md`
- `.specs/<feature-id>/02-spec-review.md` (verdict must be `PASS`)
- `.specs/_stack.json`
- `.github/templates/epic-design.template.md`
- `.github/templates/epic-roadmap.template.md`

## Writes

- `.specs/<feature-id>/03-epic-design.md`
- `.specs/<feature-id>/03a-epic-roadmap.md`
- `.specs/<feature-id>/adr/NNN-*.md` (if needed)

## Process

1. Refuse if spec review is not `PASS`.
2. Refuse if `01-spec.md` has unresolved `Q-NNN`.
3. Produce `03-epic-design.md`: boundaries, shared architecture decisions, integration points, risks, and ADR links.
4. Produce `03a-epic-roadmap.md`: vertical slices, dependency order, milestone intent, and rollout strategy.
5. Raise `Q-NNN` for any unresolved Epic-level decision and halt before detailed task decomposition.

## Refuse if

- `02-spec-review.md` verdict is not `PASS`.
- Any AC in `01-spec.md` is unaccounted for in Epic design/roadmap.
- Epic-level `Q-NNN` remains unresolved at handoff.

## Done when

`03-epic-design.md` and `03a-epic-roadmap.md` exist, are internally consistent, and the next recommended command is `/plan`.
