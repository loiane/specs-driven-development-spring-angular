# Onboarding report: legacy-orders

| Field        | Value                                       |
|--------------|---------------------------------------------|
| Run          | 2025-01-20T09:14:02Z                        |
| Classifier   | **brownfield**                              |
| Java source  | 312 files / ~30k LoC under `com.legacy.orders` |
| Java tests   | 492 files (480 unit + 12 IT)                 |
| Modules      | 1 (single root package; no boundaries)      |

## Stack snapshot (`.specs/_stack.json`)

```json
{
  "java_version": "21",
  "spring_boot_version": "3.2.5",
  "db_engines": ["postgresql"],
  "migration": "none",
  "test": { "junit5": true, "testcontainers": false, "archunit": false },
  "openapi": { "springdoc": false, "spec_file": false },
  "harness_layers": {
    "spotless": false, "checkstyle": false, "spotbugs": false,
    "jacoco": false, "pit": false, "dependency_check": false
  }
}
```

## Baseline harness run (`.specs/_baseline.json` summary)

| Layer                          | Status   | Note                                                 |
|--------------------------------|----------|------------------------------------------------------|
| Spotless                       | skipped  | plugin not configured                                |
| Checkstyle                     | skipped  | plugin not configured                                |
| Compile + Error Prone          | partial  | compile passes; Error Prone not configured           |
| SpotBugs                       | skipped  | plugin not configured                                |
| ArchUnit                       | skipped  | dependency absent                                    |
| Surefire (unit)                | pass     | 480 tests, 0 failures, 0 errors, 7 skipped           |
| Failsafe (IT)                  | warn     | 12 tests pass against H2 in-memory (NOT prod engine) |
| JaCoCo (overall)               | n/a      | not configured                                       |
| PIT mutation                   | n/a      | not configured                                       |
| OWASP Dependency Check         | n/a      | not configured                                       |

> Coverage was measured ad-hoc by running JaCoCo CLI against the test JARs:
> **line 71%, branch 58%**. This is the de-facto baseline — the floor for any
> new code (95% on changed lines) still applies, but the project floor stays
> at 71% and is raised one step at a time.

## Findings

1. **Migration tool absent in a Postgres-backed service.** Schema drift is a
   live risk. *Action:* introduce Flyway (`flyway-core` + `db/migration/`),
   baseline `V1__baseline.sql` from `pg_dump --schema-only` of production.
2. **H2 in-memory used for integration tests against a Postgres app.** Tests
   cannot exercise Postgres-specific behavior (jsonb, partial indexes, ON
   CONFLICT). *Action:* swap to Testcontainers Postgres image matching prod
   minor version. Convert the 12 IT tests in one PR.
3. **No format/lint/static-analysis layers.** *Action:* copy
   `.claude/maven/parent-pom-fragment.xml` (or the `.github/` / `.windsurf/` copy) and adopt Spotless + Checkstyle
   immediately (low risk); add SpotBugs after the first format-only PR
   merges to keep diff size manageable.
4. **No coverage enforcement.** *Action:* wire JaCoCo at the **measured
   baseline** (line 71%, branch 58%), then raise the floor by 2pp each
   sprint until it hits the methodology's 90%/90%.
5. **No mutation testing.** *Action:* defer until coverage is at 80%/75%; PIT
   on a low-coverage codebase is noise.
6. **No module boundaries.** *Action:* introduce
   ArchUnit with a single "no cycles" rule first to catch regression while
   the team carves out bounded contexts.
7. **Spring Boot 3.2 vs the methodology's target Spring Boot 4 / Framework 7.**
   *Action:* track as a separate roadmap item; not blocking for `/spec`.
   The harness fragment supports both.

## Recommended next commands (in order)

1. Land the harness POM fragment (PR 1: Spotless + Checkstyle only).
2. Adopt Flyway and baseline against prod (PR 2).
3. Replace H2 IT with Testcontainers (PR 3).
4. Add JaCoCo at baseline floor (PR 4).
5. Add SpotBugs + Error Prone (PR 5).
6. Add OWASP Dependency Check (PR 6).
7. Add ArchUnit "no cycles" rule (PR 7).
8. **Only then** run `/spec` for the first new feature using this toolkit.

The agent will not run `/spec` until at least PR 1–4 are green; otherwise
`/validate` would always fail and the methodology becomes ceremony.

## Files written

- `.specs/_stack.json`
- `.specs/_baseline.json`
- `.specs/_onboarding.md` *(this file)*
