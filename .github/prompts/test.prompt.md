---
mode: agent
description: Run /test — see .github/prompts/test.prompt.md for the authoritative spec.
tools: ['codebase', 'editFiles', 'search', 'runCommands', 'runTests']
model: GPT-5
---
# /test

**Phase:** 4 (meta) — test plan + targeted test authoring
**Owning agent:** `.github/chatmodes/spring-test-engineer.chatmode.md`
**Skills used:** `junit5-testcontainers-patterns`, `requirements-traceability`, `pit-mutation-tuning`, `archunit-rules`

## Purpose
Author or extend `06-test-plan.md` and add tests that close coverage or mutation gaps without doing production work.

## Inputs
- `<feature-id>` (positional). Optional `--gap` flag to read the latest `target/harness-summary.json` and target uncovered lines / surviving mutants.

## Reads
- `01-spec.md`, `03-design.md`, `04-tasks.md`.
- `target/harness-summary.json`, `target/site/jacoco/jacoco.xml`, `target/pit-reports/mutations.xml` (if present).
- `.github/templates/test-plan.template.md`.

## Writes
- `.specs/<feature-id>/06-test-plan.md`.
- New or extended files under `src/test/**` only. Never modifies `src/main/**`.

## Process
1. Build/refresh `06-test-plan.md`: matrix of AC × test type (unit, slice, integration, contract, mutation-targeted), plus Testcontainers requirements.
2. If `--gap` was passed, read `harness-summary.json` and JaCoCo/PIT reports; list uncovered lines and surviving mutants as `Gap-NNN` with proposed tests.
3. Write the proposed tests with `@Tag("AC-NNN")` and descriptive `@DisplayName("AC-NNN: ...")`.
4. Run `mvn test` (or `mvn verify` if integration tests changed) and quote the result tail.
5. Update the traceability matrix by running `.github/scripts/traceability.sh <feature-id>`.

## Refuse if
- Asked to modify any file under `src/main/**` (delegate to `/build`).
- The active feature has no `04-tasks.md`.

## Done when
- `06-test-plan.md` is up to date.
- Any `Gap-NNN` items have either a closing test or an explicit `Won't fix` rationale.
- Traceability matrix is regenerated.
