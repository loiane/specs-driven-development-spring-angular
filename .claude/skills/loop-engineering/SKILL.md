---
name: loop-engineering
description: Design bounded agentic loops that converge on a checkable goal instead of running forever or giving up too early. Use when wrapping any repetitive "drive this artifact to a desired state" task in a loop, and to compose the four SDD loops (spec-sharpen, build, ship, review-response) into an issue-to-merged pipeline.
when_to_use:
  - Before building any loop — to name the six parts and pick the right shape.
  - When composing the spec-sharpen, build, ship, and review-response loops into one pipeline.
  - When a hand-run sequence (re-run `/spec` until clean, fix-push-wait until CI is green) is begging to be automated.
authoritative_references:
  - docs/loop-engineering.md
  - .claude/skills/spec-sharpen-loop/SKILL.md
  - .claude/skills/sdd-build-loop/SKILL.md
  - .claude/skills/pr-quality-gate/SKILL.md
  - .claude/skills/pr-review-response/SKILL.md
---

# Loop engineering

> A loop is not "run the agent again." A loop is a control system: observe the
> world, compare it to a goal, act to close the gap, observe again. The skill is
> not in the acting — agents are already good at acting. The skill is in defining
> *what the agent observes* and *when it is allowed to stop*.

## The six parts of every loop

If you can name all six for your task, you have a loop. If you cannot, you have a
prompt you are running by hand.

- **Goal / success criteria.** A precise, checkable definition of "done" that a
  script could answer yes or no to. Not "make the PR good" — "all checks green,
  coverage ≥ 90%, zero new static-analysis issues".
- **Sensors.** How the agent observes current state. This is the part people skip
  and the part that matters most; a loop is only as good as what it can measure.
  CI status, a coverage report, a Sonar API response, the output of a test run
  repeated twenty times.
- **Action.** What the agent changes when state does not match the goal. Fix the
  code, write the missing test, bump the dependency, commit, push.
- **Cadence.** How often the loop runs. Event-driven (wait for CI), self-paced
  (drain a local queue as fast as the work allows), or human-paced (wait on an
  answer). The wrong cadence either wastes money or misses the signal.
- **Bounded budget.** The escape hatch: maximum iterations, a wall-clock
  deadline, or a token cap. This is what prevents a loop from grinding forever on
  a problem it cannot solve.
- **Guardrails.** The rules about what the agent must *not* do. Never merge.
  Never force-push. Never touch files outside the change. Never disable a failing
  test to make it pass.

Most failed loops have a clear goal and good sensors, then run away because nobody
defined the **budget** or the **guardrails**. Those last two are non-negotiable.

## The shape of a loop

```text
            ┌──────────────────────┐
            │ Start: artifact open │
            └──────────┬───────────┘
                       ▼
         ┌──────────────────────────┐
   ┌────▶│ OBSERVE (run sensors)    │
   │     └────────────┬─────────────┘
   │                  ▼
   │           ┌─────────────┐  yes  ┌─────────────────────┐
   │           │ goal met?   │──────▶│ STOP: done ✅        │
   │           └──────┬──────┘       └─────────────────────┘
   │               no │
   │                  ▼
   │         ┌──────────────────┐
   │         │ ACT: smallest    │
   │         │ correct change   │
   │         └────────┬─────────┘
   │                  ▼
   │           ┌─────────────┐  no   ┌─────────────────────┐
   │           │ budget left?│──────▶│ STOP: escalate 🚩   │
   │           └──────┬──────┘       └─────────────────────┘
   │              yes │
   │                  ▼
   │         ┌──────────────────┐
   └─────────│ WAIT (cadence)   │
             └──────────────────┘
```

The escalation branch is not a failure — it is the loop doing its job. A loop
that knows when to hand the problem back is more useful than one that pretends it
can solve everything.

## Four loop shapes

The outer structure (observe → compare → act → check budget → repeat) is the
same. What differs is the definition of *progress*. Tune each shape to its own
failure mode.

| Shape | "Done" means | Failure mode to watch |
| --- | --- | --- |
| Converge-to-green | every binary check passes | oscillating: fixing A breaks B |
| Incremental-to-a-number | a metric crosses a threshold | gaming the metric (assertion-free tests) |
| Queue / batch | the work queue is empty | one hard item blocks the rest |
| Repeat-until-confident | statistical confidence over many runs | declaring victory after one run |

### Converge-to-green

State is binary per check. Re-run **all** sensors after each change, not just the
one you were working on, so you notice when you traded one red for another.

### Incremental-to-a-number

Always attack the lowest-scoring item next. Demand *meaningful* change — an agent
told to "increase coverage" will write tests that execute code without asserting
anything, because that moves the metric. Your success criteria must forbid it.

### Queue / batch

Drain a work queue one item at a time; "done" is an empty queue. Give each item
its own small iteration cap. When an item exhausts it, **skip it, leave it in the
queue, and report it** — do not let one hard item block the easy ones.

### Repeat-until-confident

The signal is non-deterministic, so a single observation tells you almost
nothing. "Done" is *passed N consecutive runs*, where N grows with how
intermittent the original failure was. Never declare victory after one run.

## The four SDD loops

These wrap the existing SDD commands, which already supply the sensors:

1. **Spec-sharpen** (`spec-sharpen-loop`) — issue → a spec that passes
   `/spec-review` with zero open questions. Human-paced.
2. **Build** (`sdd-build-loop`) — sharp spec → a clean, `/review`-APPROVED
   feature branch. Self-paced. A queue (drain `/build` tasks) wrapping a
   converge-to-green (fix until `/validate` and `/review` are clean).
3. **Ship** (`pr-quality-gate`) — open PR → merge-ready. Polled on CI.
4. **Review-response** (`pr-review-response`) — green PR → every actionable
   reviewer thread addressed. Polled on review activity.

## Composing them: issue → merged

```text
  issue
    │  LOOP: spec-sharpen   (human-paced)   → escalate product decisions
    ▼  sharp spec
    │  LOOP: build          (self-paced)    → auto-commit on a feature branch
    ▼  clean branch
    │  HUMAN GATE: run the app, read the diff, decide — open the PR?
    ▼  pull request
    │  LOOP: ship           (polled on CI)  → all gates green
    ▼  green PR, under review
    │  LOOP: review-response (polled on review) → no threads remain
    ▼
  human merges
```

Human judgment lands at exactly two points: answering genuine product questions
at the front, and deciding a branch is worth a PR in the middle. Everything else
is a loop converging on a checkable goal. Each loop's cadence is dictated by how
fast the thing it watches can actually change — match cadence to your sensors and
you never pay for a check that cannot tell you anything new.

## Guardrails for any loop

- **Bound everything.** Every loop needs a maximum iteration count, ideally a
  wall-clock deadline too. A loop without a budget is a runaway process.
- **Never let a loop merge.** Loops drive to merge-*ready* and stop. A human owns
  the merge.
- **Forbid metric-gaming explicitly.** Any loop pointed at a number or a verdict
  will try the easy way — disabling a flaky test, writing assertion-free tests,
  editing the spec so `/review` stops complaining. Spell out the forbidden
  shortcuts; the agent will not infer them.
- **Make every action reviewable and reversible.** One logical change per commit,
  conventional messages, branch only, never force-push.
- **Escalate on low confidence.** "I tried these three fixes and none worked,
  here is what I observed" beats a tenth desperate commit.
- **Match cadence to your sensors.** Poll on an interval only when waiting on
  something slow like CI. When sensors are local, run as fast as the work allows.

## When to use a loop, and when not to

Use a loop when three things are true: the goal is **objectively checkable** (a
sensor returns yes/no), progress is **incremental** (each iteration gets
measurably closer), and the work is **tedious enough** that convergence dominates
the thinking.

A loop is the *wrong* tool when the goal is subjective ("make this API design
elegant"), when there is no reliable sensor, or when the hard part is a single
decision rather than a sequence of mechanical steps. If you cannot write the
"are we done?" check as something that returns a boolean, you do not have a loop
yet — you have a conversation, and you should just have the conversation.

The criteria *is* the work. Once you can state precisely what "done" means and how
a sensor would detect it, the loop almost writes itself.
