---
name: tdd-red-green-refactor
description: Strict red/green/refactor/simplify discipline for the `/build <task-id>` command. Use when implementing any task in Phase 4. The agent must NOT write production code without a failing test recorded in `.tdd-state.json`.
when_to_use:
  - Phase 4 — every task, every time.
  - Whenever the agent is about to edit `src/main/**`.
authoritative_references:
  - .claude/checklists/implementation-dod.md
  - .claude/templates/implementation-log.template.md
---

# TDD: red / green / refactor / simplify

## The four phases (per task)

### 1. RED — write a failing test

- Read the task entry in `04-tasks.md`. Confirm `Test-IDs` and `AC-IDs`.
- Write the smallest possible test that asserts the behavior described by the AC.
  - **Annotation block on every `@Test` method is non-negotiable: `@Test` → `@Tag("AC-NNN")` → `@DisplayName("...")`.** Write the `@DisplayName` *before* the test body — the act of articulating the display name forces clarity about what the test verifies. Format for AC-traced tests: `"<T-ID>: given <precondition>, when <action>, then <outcome>"`. Short BDD-style sentence is acceptable for utility/regression tests not tied to a specific AC. (Project rule: `feedback_displayname_on_every_test.md`.)
- Run only that test (`mvn -Dtest=ClassName#method test`).
- The test **must fail**, and the failure must be **for the right reason** (the asserted behavior is missing, not a typo or compilation error).
- Append a `red` block to `05-implementation-log.md` with the failing command and the **first 10 lines** of the failure output.
- Update `.specs/<id>/.tdd-state.json`:

  ```json
  { "active_task": "T-001", "tasks": { "T-001": { "phase": "red", "red_at": "2026-04-18T10:00:00Z", "red_test_signature": "...", "red_failure_excerpt": "..." } } }
  ```

The `block-impl-without-failing-test` hook reads this file. **No production-code edit (`src/main/**`, or an Angular source file other than `*.spec.ts`) is allowed unless the active task has a recorded failing test (`red_at` set and `red_failure_excerpt` non-empty) and its `phase` is `red`, `green`, `refactor`, or `simplify`.**

### 2. GREEN — minimum production code

- Edit only files in the task's `Files in scope`. The hook enforces this.
- Write **the minimum code** to make the failing test pass. No speculative features. No "while I'm here" cleanups.
- Re-run the test (`mvn -Dtest=...`). It must pass.
- Run the **module's full Surefire suite** to ensure no regression (`mvn -q test -pl <module>`).
- Append a `green` block to `05-implementation-log.md`.
- Set `.tdd-state.json` `phase` to `green`.

### 3. REFACTOR — improve internals, hold behavior

- Eliminate duplication, extract helpers, rename for clarity, push logic to the right layer.
- Run the **full module suite** after **every** edit. Suite must stay green.
- Allowed: extract method, extract class, inline variable, rename, move to module-internal package.
- Forbidden: changing public signatures (breaks the test), changing behavior, adding features.
- Append a `refactor` block per substantive change.

### 4. SIMPLIFY — `/code-simplify` pass

- Apply the `clarity-over-cleverness` skill: if there's a simpler way to express the same logic that a junior engineer would understand at a glance, use it.
- Specifically watch for: nested ternaries, clever streams when a `for` loop is clearer, premature abstraction, dead options, "options bag" parameters with one used field, helper methods with one caller.
- Also scan for repeated literals: any string or number appearing 2+ times in the same class (production OR test) must be extracted to a `private static final` constant at the top of the class with a domain-meaningful name. Avoids SonarQube `java:S1192` (string literal duplicated). Single-use literals are fine inline. (Rule: `feedback_extract_repeated_literals.md`.)
- **Audit every newly-authored or modified test method in the diff for `@DisplayName`.** Any `@Test` or `@ParameterizedTest` without one gets it added here. This is the safety net for the red-phase rule — if a test slipped through without it, simplify is the last chance to catch it before the task is `done`. Pre-existing legacy tests in the same file that were not touched by this task are NOT retroactively rewritten (scope-creep guard). (Rule: `feedback_displayname_on_every_test.md`.)
- Suite must stay green.
- Append a `simplify` block. Set `phase` to `done`.

### 5. COMMIT — surface stopping report

When `phase` reaches `done`, **STOP**. Do not auto-start the next task.

Surface a stopping report:

- Files changed (`git status`)
- Tests passing (module suite green)
- Suggested commit message (e.g., `feat(gift-card): T-001 apply gift card to order`)

Recommend the 3-step follow-up:

```text
git status               # review what changed
git commit               # commit the task
/build <next-task-id>    # start the next task
```

If the user asks the agent to run `git commit`, the agent must ask for explicit permission immediately before that specific commit. Permission is single-use and never carries forward to later commits.

Next `/build` includes a **pre-flight commit check**: if uncommitted changes from a prior task are detected, refuse to start and surface this reminder.

**Exception:** The user can explicitly request task chaining (e.g., "chain to T-002", "continue without committing") — respect the explicit instruction.

## Logging format

Each block in `05-implementation-log.md`:

```markdown
### T-001 · red · 2026-04-18T10:00:00Z
**Command:** `mvn -q -Dtest=ApplyGiftCardRequestTest#rejectsBlankCode test`
**Result:** FAIL (expected)
**Excerpt:**
```

[ERROR] ApplyGiftCardRequestTest.rejectsBlankCode:23 expected ConstraintViolationException but nothing was thrown

```text
```

## What "minimum code" means

- Hardcoding a constant to make the test pass is OK if there's only one test. The next test will force generalization.
- Don't introduce an interface for a single implementation.
- Don't introduce a config option for a single caller.
- Don't add a parameter "for future use".

This pressure to triangulate is the entire point of TDD.

## Anti-patterns the hook will block

- Writing a test that already passes (no actual red).
- Deleting a test to make CI green.
- Editing files outside `Files in scope`.
- Skipping the red step ("I'll add the test after").
- Modifying an existing test's assertion to match new (wrong) behavior.
- Marking a task `done` without all four blocks logged.
- **Don't add a method without a real consumer.** A tautological test that asserts a method returns a fixed value is not a real consumer. If no genuine API boundary exists for the method, surface a `Q-NNN` design gap instead of writing the method.
- **Auto-starting the next task without giving the user a chance to commit.** Always stop at `phase: done` and surface the commit reminder (Step 5). Only chain tasks when the user explicitly requests it.
