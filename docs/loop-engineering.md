# Loop Engineering — Driving an Issue to Merged

Prompting an agent to fix a failing test is easy. Designing a system where one
loop sharpens the spec, another builds the feature to a clean reviewed branch, a
human makes the two calls that matter, and two more loops drive the pull request
through CI and human review — that is the engineering.

**Loop engineering** is designing agentic loops that converge on a goal instead of
running forever or giving up too early. This toolkit ships the pattern as the
[`loop-engineering`](../.claude/skills/loop-engineering/SKILL.md) skill, plus four
concrete loops that wrap the existing SDD commands.

## What an agentic loop actually is

A loop is not "run the agent again." A loop is a control system: the agent
observes the world, compares it to a goal, acts to close the gap, then observes
again. The skill is not in the acting — coding agents are already good at acting.
The skill is in defining *what the agent observes* and *when it is allowed to
stop*.

Every loop worth building has six parts. If you can name all six for your task,
you have a loop. If you cannot, you have a prompt you are running by hand.

- **Goal / success criteria** — a precise, checkable definition of "done".
- **Sensors** — how the agent observes current state.
- **Action** — what the agent changes when state does not match the goal.
- **Cadence** — how often the loop runs.
- **Bounded budget** — the escape hatch: max iterations, a deadline, a token cap.
- **Guardrails** — the rules about what the agent must *not* do.

Most failed loops have a clear goal and good sensors, then run away because nobody
defined the budget or the guardrails.

## Four loop shapes

The outer structure is always the same; the definition of *progress* differs.

| Shape | "Done" means | Failure mode to watch |
| --- | --- | --- |
| Converge-to-green | every binary check passes | oscillating: fixing A breaks B |
| Incremental-to-a-number | a metric crosses a threshold | gaming the metric |
| Queue / batch | the work queue is empty | one hard item blocks the rest |
| Repeat-until-confident | confidence over many runs | declaring victory after one run |

See the [`loop-engineering`](../.claude/skills/loop-engineering/SKILL.md) skill for
the detail on each shape and its tuning.

## The four SDD loops

Each loop wraps SDD commands that already supply the sensors. They map one-to-one
onto Claude Code's `/loop` command and Skills; on Copilot and Windsurf you drive
the same cadence by re-invoking the skill.

| Loop | Skill | Wraps | Shape | Cadence |
| --- | --- | --- | --- | --- |
| 3 — Spec-sharpen | [`spec-sharpen-loop`](../.claude/skills/spec-sharpen-loop/SKILL.md) | `/spec`, `/spec-review` | converge-to-green | human-paced |
| 2 — Build | [`sdd-build-loop`](../.claude/skills/sdd-build-loop/SKILL.md) | `/plan`, `/build`, `/validate`, `/review` | queue + converge | self-paced |
| 1 — Ship | [`pr-quality-gate`](../.claude/skills/pr-quality-gate/SKILL.md) | CI gates on a PR | converge + climber | polled on CI |
| 4 — Review-response | [`pr-review-response`](../.claude/skills/pr-review-response/SKILL.md) | human review threads | queue | polled on review |

## Composing them: issue → merged

```text
  issue
    │  LOOP 3: spec-sharpen    (human-paced)   → escalate product decisions
    ▼  sharp spec
    │  LOOP 2: build           (self-paced)    → auto-commit on a feature branch
    ▼  clean branch
    │  HUMAN GATE: run the app, read the diff, decide — open the PR?
    ▼  pull request
    │  LOOP 1: ship            (polled on CI)  → all gates green
    ▼  green PR, under review
    │  LOOP 4: review-response (polled on review) → no threads remain
    ▼
  human merges
```

Human judgment lands at exactly two points: answering genuine product questions at
the front, and deciding a branch is worth a PR in the middle. Everything else is a
loop converging on a checkable goal. Each loop's cadence is dictated by how fast
the thing it watches can actually change — match cadence to your sensors and you
never pay for a check that cannot tell you anything new.

## The trust you have to earn

The build loop is the one to be careful with, because it writes the feature
instead of polishing it. It does not *remove* human review — it **relocates** it,
replacing the per-task checkpoint with automated sensors (`/validate`, `/review`)
and one deliberate human validation round at the end. That trade is only safe once
the sensors are trustworthy enough to stand in for you on the small stuff. You
graduate into this loop; you do not start here. The trust checklist lives in the
[`sdd-build-loop`](../.claude/skills/sdd-build-loop/SKILL.md) skill.

## Guardrails for any loop

- **Bound everything** — a maximum iteration count, ideally a wall-clock deadline.
- **Never let a loop merge** — loops drive to merge-*ready* and stop.
- **Forbid metric-gaming explicitly** — spell out the forbidden shortcuts.
- **Make every action reviewable and reversible** — one change per commit, branch
  only, never force-push.
- **Escalate on low confidence** — stopping and saying so beats a tenth desperate
  commit.
- **Match cadence to your sensors** — poll only when waiting on something slow.

## When to use a loop, and when not to

Use a loop when the goal is **objectively checkable**, progress is
**incremental**, and the work is **tedious enough** that convergence dominates the
thinking. A loop is the wrong tool when the goal is subjective, when there is no
reliable sensor, or when the hard part is a single decision. If you cannot write
the "are we done?" check as something that returns a boolean, you do not have a
loop yet — you have a conversation, and you should just have the conversation.
