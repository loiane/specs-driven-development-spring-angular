---
name: pr-quality-gate
description: Drive one GitHub PR to merge-ready by checking every quality gate and fixing whatever is red, then committing, pushing, and waiting for the next CI run. The ship loop. Stops when the PR is fully green or the iteration budget runs out. Never merges.
when_to_use:
  - A PR is open and you want it driven to all-green without babysitting each CI round.
  - After the build loop hands you a feature branch and you have opened the PR.
  - Run as a recurring loop: `/loop 10m /pr-quality-gate <pr-number>` in Claude Code, or re-invoke this skill each CI cycle on Copilot/Windsurf.
authoritative_references:
  - docs/loop-engineering.md
  - .claude/skills/loop-engineering/SKILL.md
  - .claude/skills/jacoco-coverage-policy/SKILL.md
  - .claude/skills/pr-review-response/SKILL.md
---

# PR quality gate (the ship loop)

> Loop shape: **converge-to-green**, with a **coverage climber** nested inside. Cadence: **polled on CI** (the sensor only changes once per CI run). Budget: **10 iterations**, then escalate.

You are driving pull request **#$1** to merge-ready. Do exactly **one pass** per invocation. The loop runner (`/loop`) supplies the cadence and the budget; this skill supplies the goal, the sensors, the action, and the guardrails.

## Sensors — gather current state first

Re-run *all* of these every pass, not just the gate you fixed last time, so you catch a fix that traded one red for another:

- `gh pr checks $1` — CI check status (unit, integration, architecture tests).
- `gh pr view $1 --json statusCheckRollup,mergeable` — the rollup and mergeability.
- The coverage report from the latest CI run artifacts (or `./.github/scripts/check-new-code-coverage.sh` locally).
- The static-analysis report (Checkstyle / SpotBugs / Sonar) for **new** issues introduced by this PR.

## Success criteria (the goal)

The PR is merge-ready ONLY when ALL of these are true:

- Every CI check is passing.
- Checkstyle / static analysis reports zero new violations on this PR.
- Line coverage on new code is at or above the project threshold (see `jacoco-coverage-policy`).
- Sonar (if configured) reports zero new issues on this PR.

When all are true, post a comment `✅ All gates green — ready to merge` and **STOP**. Do not merge the PR yourself.

## Action — fix exactly what is failing

For each failing gate, make the **smallest correct change that fixes the root cause**, then commit with a conventional-commit message and push to the PR branch.

- **Tests / Checkstyle / Sonar** (converge-to-green): fix the code, then re-run *all* sensors so a fix for one gate has not broken another.
- **Coverage** (incremental-to-a-number): find the class furthest below the line, write *meaningful* tests for its uncovered branches, re-check the number, repeat with the next-lowest file. Tests must assert behavior, not just execute lines.

## Guardrails — non-negotiable

- NEVER merge, approve, or close the PR.
- NEVER force-push or rewrite history.
- NEVER disable, skip, `@Disabled`, or delete a test to make a gate pass.
- NEVER lower a coverage threshold or add a Checkstyle/SpotBugs suppression to silence a finding instead of fixing it.
- NEVER touch files unrelated to this PR's diff.
- If a failure is ambiguous, or you are not confident in the fix, post a comment explaining what you observed and what you tried, then STOP for a human.

## Cadence and budget (the loop wrapper)

Poll roughly as often as CI returns — there is no point checking every thirty seconds when the signal only changes once per CI run:

```text
/loop 10m /pr-quality-gate 1234
```

Stop when the PR posts the "ready to merge" comment, **or** after **10 iterations**, whichever comes first. On the tenth iteration without success, summarize what is still failing and what you tried, then stop and escalate.

On Copilot or Windsurf (no native `/loop`), drive the cadence yourself: invoke this skill once per CI cycle and stop on the same two conditions.

## Handoff

A green PR is the input the `pr-review-response` loop wants. When a human reviewer leaves comments, switch to that loop to work them to zero.
