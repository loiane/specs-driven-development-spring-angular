---
description: Run /onboard — see .windsurf/workflows/onboard.md for the authoritative spec.
---
# /onboard

**Phase:** 0 — bootstrap
**Owning agent:** `.windsurf/workflows/spring-onboarding.md`
**Skills used:** `brownfield-onboarding`, `maven-harness-pom`, `flyway-or-liquibase-detection`, `harness-report-parsing`, `archunit-rules`

## Purpose

Inspect the repository, classify it as greenfield or brownfield, capture a baseline harness run, and produce `.specs/_onboarding.md` so future commands know the stack.

## Inputs

None required. Optional argument: a path to constrain the scan.

- For a **single-project** repo: omit the argument; the script reads `./pom.xml`.
- For a **multi-module Maven** build: pass the submodule directory.
- For a **polyglot monorepo** (e.g. Spring Boot backend + Angular/React frontend in sibling top-level dirs): pass the Maven module directory (e.g. `shoply-api`). Sibling non-JVM apps are auto-detected and recorded under `siblings` in `_stack.json` and as context-only notes in `_onboarding.md`. The harness only validates the Maven module; frontend tooling is owned by its own pipeline.

## Reads

- `pom.xml` (root and any submodules)
- `src/main/**`, `src/test/**` (counts only)
- `db/migration/**`, `db/changelog/**`
- Existing `.specs/` if any

## Writes

- `.specs/_onboarding.md`
- `.specs/_stack.json` (output of `.github/scripts/detect-stack.sh`)
- `.specs/_baseline.json` (only if any test exists; output of `.github/scripts/harness.sh --baseline`)

## Process

1. Resolve the Maven module path (`MODULE` = optional arg, else `.`). Run `.github/scripts/detect-stack.sh "$MODULE/pom.xml" > .specs/_stack.json`. Refuse to proceed if `migration == "both"`.
2. Count source/test files under `$MODULE/src/`; classify:
   - **Greenfield** if no `src/main/java/**` or only the Spring Boot `Application.java` (auto-generated `*ApplicationTests.java` and `Testcontainers*.java` scaffolding do not change the classification).
   - **Brownfield** otherwise.
3. If brownfield, run `.github/scripts/harness.sh --module "$MODULE" --baseline` and capture results. Do NOT attempt to fix failures.
4. Diff `$MODULE/pom.xml` against `.windsurf/maven/parent-pom-fragment.xml`; list missing harness layers as Findings.
5. Write `.specs/_onboarding.md` covering: classification, module path, sibling apps (if any), stack JSON, baseline gate results (or “N/A — greenfield”), missing layers, recommended `/spec` starting point.

## Refuse if

- `migration == "both"` — fatal; ask the user to pick one.
- No `pom.xml` is found at the resolved module path. (In a polyglot monorepo the user must pass the Maven module directory.)

## Done when

`.specs/_onboarding.md` exists and the user has been shown a one-paragraph summary plus the next recommended command.
