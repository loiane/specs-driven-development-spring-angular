---
name: epic-slicing-planning
description: Plan large features by defining high-level Epic architecture and a vertical slice roadmap before detailed implementation tasks. Use during Phase 3 for multi-slice initiatives.
when_to_use:
  - Feature spans multiple milestones or vertical slices.
  - Shared cross-cutting architecture decisions must be made before detailed tasks.
  - Team needs dependency-aware sequencing and controlled scope.
authoritative_references:
  - .github/templates/epic-design.template.md
  - .github/templates/epic-roadmap.template.md
  - .github/checklists/design-review.md
---

# Epic slicing planning

## Goal

Reduce planning risk for large features by separating:

1. Epic-level design decisions.
2. Slice-level detailed planning and task decomposition.

## Deliverables

1. `03-epic-design.md`:

   - boundaries
   - shared decisions
   - cross-cutting constraints
   - ADR links
   - Epic-level `Q-NNN`

2. `03a-epic-roadmap.md`:

   - vertical slice backlog
   - dependency order
   - milestone intent
   - rollout notes

## Slicing rules

- Prefer vertical, user-visible slices over horizontal layer slices.
- Keep each slice independently testable and releasable.
- Put shared infrastructure decisions in Epic design, not repeated per slice.
- Avoid planning every implementation task for the entire Epic up front.

## Anti-patterns

- A roadmap that is only backend layers then frontend layers.
- Slices that are not user-visible and cannot be validated end-to-end.
- Unresolved Epic decisions pushed down into many slice tasks.
- Giant slices that require multiple teams and have undefined boundaries.

## Handoff criteria

- Epic artifacts are approved.
- Epic-level `Q-NNN` are resolved or deferred with rationale.
- At least one first slice is ready for `/plan` detailed decomposition.
