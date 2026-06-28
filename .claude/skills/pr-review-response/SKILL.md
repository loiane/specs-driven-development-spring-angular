---
name: pr-review-response
description: Resolve actionable human review comments on a GitHub PR until none remain and the gates stay green — make the change, push, reply, repeat. The end of the pipeline. Triages each thread, escalates disagreements, and never merges or resolves a reviewer's thread.
when_to_use:
  - A green PR is under human review and the comments need to be worked to zero.
  - After the ship loop (`pr-quality-gate`) has driven the PR to all-green and a reviewer has left feedback.
  - Run as a loop polled on review activity: `/loop 15m /pr-review-response <pr-number>` in Claude Code, or re-invoke this skill as new comments arrive on Copilot/Windsurf.
authoritative_references:
  - docs/loop-engineering.md
  - .claude/skills/loop-engineering/SKILL.md
  - .claude/skills/pr-quality-gate/SKILL.md
  - .claude/skills/spring-code-review-rubric/SKILL.md
---

# PR review-response loop (end of the pipeline)

> Loop shape: **queue** — drain the unresolved review threads one at a time.
> The mirror image of the ship loop: that one converges the PR on CI, this one
> converges it on the humans.
> Cadence: **polled on review activity** (reviewers comment over hours, not
> seconds).
> Budget: escalate on disagreement or ambiguity; never argue in a thread.

You are responding to human review on PR **#$1**. Do exactly **one pass** per
invocation.

## Sensors

- `gh pr view $1 --json reviews,comments,reviewThreads` — list every
  **UNRESOLVED** thread.
- `gh pr checks $1` — current gate status.

## Triage each unresolved thread

- **CHANGE REQUESTED** ("do X", "rename Y", "handle case Z"): make the smallest
  correct change, commit, push, and reply in the thread linking the commit. Do
  NOT resolve the thread — the reviewer does that.
- **QUESTION** ("why did you…?"): reply in the thread with an explanation. Change
  code only if the honest answer is "you're right, fixing it".
- **DISAGREEMENT or ambiguous intent**: STOP and escalate to your human. Do not
  argue in the thread, and do not silently comply.

After any code change, re-run the ship-loop gates (`pr-quality-gate`) so a review
fix does not re-break CI.

## Success criteria (the goal)

No unresolved actionable threads remain AND all gates are green. Then STOP. Do not
merge.

## Guardrails — non-negotiable

- NEVER merge, approve, or resolve a reviewer's thread.
- NEVER push back on a reviewer; escalate disagreements to your human.
- One logical change per commit; never force-push.
- If a comment needs a product or architecture decision, escalate instead of
  deciding it inside the loop.

## Cadence (the loop wrapper)

Poll on an interval, because the sensor is human review activity:

```text
/loop 15m /pr-review-response 1234
```

The hard part is not the editing, it is the **triage**. A loop that treats every
comment as "change requested" will rewrite code in response to a reviewer who was
only asking a question; a loop that treats every comment as a question will ignore
real change requests. Spelling out the difference, and forcing an escalation on
disagreement, is what keeps the loop from arguing with your reviewer on your
behalf. On Copilot or Windsurf, re-invoke this skill as new comments arrive.
