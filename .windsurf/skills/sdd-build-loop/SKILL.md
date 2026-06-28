---
name: sdd-build-loop
description: Drive an SDD feature from its task queue to a clean, reviewed branch — drain every `/build` task, then converge `/validate` and `/review` to green, auto-committing on the feature branch. The build loop. Trust-gated; runs only on a feature branch and never opens a PR or merges.
when_to_use:
  - A feature has a sharp spec, `/plan` has produced `.tdd-state.json`, and you want the task queue driven to a reviewed branch.
  - Only after you have earned trust in the harness (see the trust checklist below). Otherwise run `/build` task-by-task with your eyes on every diff.
  - Run as a self-paced loop: `/loop /sdd-build-loop <feature-id>` in Claude Code, or re-invoke this skill until the success criteria are met on Copilot/Windsurf.
authoritative_references:
  - docs/loop-engineering.md
  - .windsurf/skills/loop-engineering/SKILL.md
  - .windsurf/skills/tdd-red-green-refactor/SKILL.md
  - .windsurf/skills/harness-report-parsing/SKILL.md
  - .windsurf/skills/spring-code-review-rubric/SKILL.md
---

# SDD build loop (the build loop)

> Loop shape: a **queue** (drain `/build` tasks) wrapping a **converge-to-green**
> (fix until `/validate` and `/review` are clean).
> Cadence: **self-paced** — no CI to wait on; run the next step the moment the
> last one finishes.
> Budget: a cap on review-fix rounds, then escalate.

You are building the feature in `.specs/$1` to a reviewed, committable state on
the **current feature branch**. Confirm you are **NOT on `main`** before doing
anything. The framework *is* the sensor layer here: `.tdd-state.json`, the
`/validate` output, and the `/review` verdict.

## Phase 1 — drain the task queue (queue shape)

1. Read `.specs/$1/.tdd-state.json` for the next task whose phase is `pending`.
2. Run `/build` for that task. Let it move `pending → red → green → refactor →
   done` and commit on completion (one task per commit).
3. Repeat until no `pending` tasks remain.
4. If one task fails its gates **twice in a row**, STOP and escalate. Do not skip
   it silently — a missing task is not a done feature.

## Phase 2 — validate and review (converge-to-green)

1. Run `/validate`. If anything fails (tests, coverage, lint, traceability), fix
   the root cause, commit, and run `/validate` again.
2. Run `/review`. If the verdict has ANY must-fix findings, fix each with the
   smallest correct change, commit, and run `/review` again.
3. Stop Phase 2 when `/validate` is clean AND `/review` returns APPROVE with zero
   must-fix findings. Leave should-fix and nit findings in the handoff summary for
   the human — do not gold-plate.

## Success criteria (the goal)

All tasks done, `/validate` clean, `/review` APPROVE with zero must-fix. Then STOP
and write a handoff summary listing the should-fix and nit items you deliberately
left. **DO NOT open a PR or merge** — that is the human's call.

## Guardrails — non-negotiable

- Work ONLY on the feature branch. NEVER commit to `main`.
- NEVER merge, and NEVER open the PR.
- NEVER edit the spec, weaken a test, lower a threshold, or add a suppression to
  make a gate pass.
- One logical change per commit; conventional messages; never force-push.
- After **5 review-fix rounds** without reaching APPROVE, STOP and escalate with
  what is still failing and what you tried.

## The trust you have to earn

This loop does not *remove* human review — it **relocates** it. It replaces the
per-task checkpoint with automated sensors (`/validate`, `/review`) on the small
stuff and one deliberate human validation round at the end. That trade is only
safe once the sensors are trustworthy enough to stand in for you. A feature is
allowed through this loop only when:

- You have shipped enough features with the framework that `/review` rarely
  surfaces something you disagree with.
- Your skills, agents, and review rubric encode *your* team's standards.
- Your coverage threshold, lint rules, and `/review` checklist fail loudly on the
  mistakes you care about — a green `/validate` actually *means* something.
- The spec passed `/spec-review` with no open questions. The loop amplifies
  whatever the spec says; a vague spec produces confident, wrong code faster.
- The feature is a pattern you have done before (a CRUD slice with a clear
  contract), not a novel architectural decision.

If those conditions are not met, run the framework the normal way, task by task.
The loop is an optimization for the cases you already understand.

## Cadence and handoff (the loop wrapper)

Because there is no CI to wait on, this loop self-paces:

```text
/loop /sdd-build-loop 2026-05-09-create-new-customer
```

When it stops you have a feature branch with a drained task queue, a clean
`/validate`, an `APPROVE` from `/review`, and a handoff summary — exactly the
input the human PR gate wants. The human runs the app, reads the diff, and
decides whether to open the PR. Once the PR exists, the `pr-quality-gate` loop
takes over.
