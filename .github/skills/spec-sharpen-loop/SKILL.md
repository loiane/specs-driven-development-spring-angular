---
name: spec-sharpen-loop
description: Turn a raw GitHub issue into a spec that passes `/spec-review` with zero open questions — resolving what it can from existing material and escalating genuine product decisions to a human. The front of the pipeline. Produces a spec and nothing else.
when_to_use:
  - A GitHub issue needs to become a sharp spec before `/plan` and the build loop.
  - Whenever `/spec` surfaces open questions and you want them triaged and driven to zero in rounds.
  - Run as a human-paced loop: `/loop /spec-sharpen-loop <issue-number>` in Claude Code, or re-invoke this skill each time you answer the product questions on Copilot/Windsurf.
authoritative_references:
  - docs/loop-engineering.md
  - .github/skills/loop-engineering/SKILL.md
  - .github/skills/ears-spec-authoring/SKILL.md
  - .github/skills/issue-tracker-ingestion/SKILL.md
---

# Spec-sharpen loop (front of the pipeline)

> Loop shape: **converge-to-green** on the `/spec-review` verdict, gated by a human triage step. Cadence: **human-paced** — *you* are the sensor it waits on. It advances a round each time you answer the product questions it surfaces, then blocks again. Budget: escalate if the same question reappears after being answered.

You are turning issue **#$1** into a spec that passes `/spec-review` with zero open questions. Work in rounds. The build loop downstream is only safe if the spec going in is sharp: a vague spec does not produce vague code, it produces confident, wrong code, faster.

## Sensors

- The open-question list `/spec` surfaces for this issue.
- The `/spec-review` verdict (PASS/FAIL) and its findings.

## Each round

1. Run `/spec` for the issue (or re-run after answers have been added).
2. Triage **every** open question into one of two buckets:
   - **RESOLVABLE** from the issue, linked tickets, or existing specs — atomic acceptance criteria, missing non-goals, ambiguous wording, contract or format gaps. Resolve these and update the spec.
   - **PRODUCT DECISION** you cannot ground in existing material — pricing, policy, UX intent, scope trade-offs. Collect these.
3. If any PRODUCT DECISION questions remain, **STOP** and post them to the human as a numbered list. Wait for answers; do not invent them.
4. Run `/spec-review`. If FAIL, address the structural findings and start another round.

## Success criteria (the goal)

`/spec-review` returns **PASS** with zero open questions remaining. Then STOP — the spec is ready for `/plan` and the build loop. This loop produces a spec and nothing else.

## Guardrails — non-negotiable

- NEVER answer a product-decision question yourself to force a PASS. A clean spec built on guessed intent is the most expensive failure in the whole pipeline — every downstream loop trusts this spec, and will build, test, and ship the wrong thing with great efficiency.
- NEVER start design or code. No `/plan`, no `/build`.
- If the same question reappears after being answered, escalate; the issue itself may be underspecified.

## Cadence (the loop wrapper)

This is the one loop that pauses inside itself for a human on purpose:

```text
/loop /spec-sharpen-loop 1
```

It is human-paced by design. You are not waiting on a clock or on CI; the loop is waiting on *your* product decisions. Answer them, and it advances a round; until you do, it blocks. On Copilot or Windsurf, the cadence is the same — re-invoke the skill after you have answered the questions it raised.
