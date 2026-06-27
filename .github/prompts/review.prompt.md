---
mode: agent
description: Run /review — see .github/prompts/review.prompt.md for the authoritative spec.
tools: ['codebase', 'editFiles', 'search', 'runCommands', 'runTests']
model: GPT-5
---
# /review

**Phase:** 6 — pre-commit code review
**Owning agent:** `.github/chatmodes/spring-code-reviewer.chatmode.md`
**Skills used:** `spring-code-review-rubric`, `clarity-over-cleverness`, `spring-boot-4-conventions`, `spring-security-baseline`, `performance-optimization`

## Stack routing

| Changed files in diff | Agent |
|---|---|
| Java/Kotlin/POM/SQL only | `spring-code-reviewer` (this agent) |
| Angular (`.ts`, `.html`, `.scss`) only | `angular-code-reviewer` |
| Both | Run both reviewers; merge findings into a single `08-code-review.md` |

Inspect the diff file list (`git diff --name-only <base>...HEAD`). If it contains only frontend files, delegate entirely to `angular-code-reviewer`.

## Purpose
Run a structured self-review of the diff before the user commits. Produces `08-code-review.md` with categorized findings.

## Inputs
- `<feature-id>` (optional). Defaults to the most recent feature.
- Optional `--base <ref>` (defaults to `origin/main`).

## Reads
- `git diff <base>...HEAD` for changed Java/test/POM/SQL files.
- `01-spec.md`, `03-design.md`, `07-validation-report.md`.
- `.github/skills/spring-code-review-rubric/SKILL.md` (the rubric is authoritative).

## Writes
- `.specs/<feature-id>/08-code-review.md`.

## Process
1. Refuse if `07-validation-report.md` verdict is not `PASS`.
2. Walk every changed file. For each, evaluate against the rubric categories: correctness, security, design, testing, observability, performance, clarity, conventions.
3. Classify findings as `must-fix`, `should-fix`, `nit`, or `praise`. Include file + line range + suggested change for `must-fix` and `should-fix`.
4. Cross-check: every AC mentioned in `01-spec.md` is exercised by at least one test in the diff (or already merged).
5. If any `must-fix` exists, recommend `/build` or `/code-simplify`. Do NOT auto-apply fixes.
6. Emit summary line: counts by severity + recommended next action.

## Refuse if
- Validation report is missing or `FAIL`.
- The diff is empty.

## Done when
`08-code-review.md` exists. If zero `must-fix`, the agent prints the suggested commit message and tells the user to run `git commit` themselves (the agent never commits).
