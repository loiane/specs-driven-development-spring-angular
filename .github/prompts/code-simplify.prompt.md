---
mode: agent
description: Run /code-simplify — see .github/prompts/code-simplify.prompt.md for the authoritative spec.
tools: ['codebase', 'editFiles', 'search', 'runCommands', 'runTests']
model: GPT-5
---
# /code-simplify

**Phase:** 6 (meta) — clarity sweep
**Owning agent:** `.github/chatmodes/spring-code-reviewer.chatmode.md`
**Skills used:** `clarity-over-cleverness`, `tdd-red-green-refactor`

## Purpose

Apply the clarity-over-cleverness rules to a single file or a directory while keeping tests green. This is the same pass `/build`'s simplify phase performs, but on demand.

## Inputs

- `<path>` (positional). A file under `src/main/**` or a directory.
- Optional `--dry-run` to print proposed edits without writing.

## Reads

- `<path>` (the target file/directory).
- `.github/skills/clarity-over-cleverness/SKILL.md` (authoritative checklist).

## Writes

- The targeted files (in place).
- A diff summary appended to `.specs/<feature-id>/05-implementation-log.md` under a `### simplify-pass` block, or to a fresh `clarity-pass-<date>.md` if no active feature.

## Process

1. Refuse if `mvn test` is not green right now (run it first; abort on failure).
2. For each file in scope, apply the 7 rewrite targets in order:
   1. Untangle nested ternaries → if/else.
   2. Streams only when clearer than a loop; otherwise loop.
   3. Inline once-used helpers.
   4. Kill option flags (split into two methods).
   5. Name domain concepts (no `data`, `info`, `manager`, `helper`, `util`).
   6. Remove premature abstraction (interface with one impl, factory with one product).
   7. Prefer early returns over deep nesting.
3. Re-run `mvn test` after each file. If anything goes red, revert that file's edits and record it as a Skipped item.
4. Emit a summary: files touched, rewrites applied per category, tests run, regressions encountered.

## Refuse if

- Tests are not green at start.
- The path is under `src/test/**` (test clarity is governed by `/test`, not this command).

## Done when

All in-scope files are either simplified or explicitly skipped, and tests are green.
