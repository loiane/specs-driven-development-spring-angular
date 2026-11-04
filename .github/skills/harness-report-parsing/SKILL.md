---
name: harness-report-parsing
description: Parse harness output (Surefire/Failsafe XML, JaCoCo XML, PIT XML, Checkstyle/SpotBugs XML, OpenAPI diff JSON, dependency-check JSON) into a single structured summary. Use when writing `07-validation-report.md` or when a CI run failed and the agent must explain why.
when_to_use:
  - Phase 6 (Validate) — `/validate` command runs the harness and parses every report.
  - Diagnosing a CI failure from log output.
authoritative_references:
  - https://maven.apache.org/surefire/maven-surefire-plugin/xsd/surefire-test-report.xsd
  - https://www.jacoco.org/jacoco/trunk/coverage/report.dtd
---

# Harness report parsing

## Input file map

| Layer | Path | Format |
|---|---|---|
| Spotless | `target/spotless/` (markers) | exit code |
| Checkstyle | `target/checkstyle-result.xml` | XML |
| SpotBugs | `target/spotbugsXml.xml` | XML |
| Error Prone | compiler stderr | text |
| ArchUnit | `target/surefire-reports/.../ArchitectureTest.xml` | Surefire XML |
| ArchUnit | `target/surefire-reports/.../ArchitectureTest.xml` | Surefire XML |
| Surefire (unit) | `target/surefire-reports/TEST-*.xml` | Surefire XML |
| Failsafe (IT) | `target/failsafe-reports/TEST-*.xml` | Surefire XML |
| JaCoCo | `target/site/jacoco/jacoco.xml` | JaCoCo XML |
| PIT | `target/pit-reports/mutations.xml` | PIT XML |
| OpenAPI diff | `target/openapi-diff.json` | JSON |
| Dependency-check | `target/dependency-check-report.json` | JSON |

## Output shape (`harness-summary.json`)

`.github/scripts/harness.sh --report` prints a single JSON document on stdout (build output goes to stderr) and also writes it to `target/harness-summary.json`. The script exits 0 when every gate is `pass` or `skipped`, 1 when any gate fails, and 2 when a prerequisite is missing.

```json
{
  "started_at": "2026-04-18T10:30:00Z",
  "finished_at": "2026-04-18T10:38:42Z",
  "git_sha": "abc1234",
  "stack": { "...": "output of detect-stack.sh" },
  "gates": {
    "build":    { "status": "pass", "exit_code": 0 },
    "unit":     { "status": "pass", "tests": 412, "failures": 0, "errors": 0, "skipped": 2 },
    "it":       { "status": "pass", "tests": 47, "failures": 0, "errors": 0, "skipped": 0 },
    "coverage": { "status": "pass", "line": 0.93, "branch": 0.91 },
    "mutation": { "status": "pass", "exit_code": 0, "kill_rate": 0.84, "killed": 84, "survived": 16, "no_coverage": 0, "total": 100 }
  },
  "overall": "pass"
}
```

- `build` is the result of `mvn verify`, which runs the format, compile, static-analysis, architecture and security layers. When it fails, read those layers' own reports (table above) to say which one broke.
- `mutation` is `skipped` when PIT is not configured or the build failed, and `fail` when PIT exits non-zero or writes no report.
- The contract (`target/openapi-diff.json`) and security (`target/dependency-check-report.json`) layers are not summarised here; parse their reports directly.
- New-code coverage comes from `.github/scripts/check-new-code-coverage.sh` (`target/new-code-coverage.json`), not from this summary.

## Parsing rules

- A **missing report** for a layer the project has configured = `error`, not `pass`.
- A **report with parse errors** = `error`.
- A test marked `skipped` with no `# DisabledReason:` comment in source = `error` (enforced by Checkstyle rule `RegexpSinglelineJava` looking for `@Disabled` without preceding comment).

## Surefire/Failsafe XML quick recipe

```xpath
/testsuite/@tests        -> total
/testsuite/@failures     -> assertion failures
/testsuite/@errors       -> exceptions
/testsuite/@skipped      -> skipped
/testsuite/testcase[skipped]/@name  -> list skipped tests
```

## JaCoCo new-code calculation

1. `git diff --unified=0 $(git merge-base origin/main HEAD) -- 'src/main/java/*.java'` (working tree, so uncommitted changes count) plus untracked files → list of `(file, line-range)`.
2. For each file, read `jacoco.xml` `<class name="...">/<sourcefilename>` matching.
3. Inside `<line nr="N" mi="X" ci="Y" mb="A" cb="B"/>`:
   - `mi` = missed instructions
   - `ci` = covered instructions
   - A line counts as "covered" if `ci > 0`. "Missed" if `mi > 0` and `ci == 0`.
4. New-code coverage = covered ÷ (covered + missed) over diff lines only. Lines with no `<line>` entry (comments, blank lines, imports) are not executable and are ignored. No executable new lines = `pass`.

## PIT mutants in changed packages

```xpath
/mutations/mutation[@status='SURVIVED' and contains(mutatedClass, 'changed.package')]
```

`changed.package` is derived by mapping diff file paths → fully qualified class names.

## Anti-patterns

- Emitting `pass` because the report file is empty (it's not — failures with 0 tests is a misconfiguration).
- Counting `skipped` as `pass`.
- Aggregating across modules without per-module breakdown.
- Hiding errors as warnings.
