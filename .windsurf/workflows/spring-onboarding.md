---
description: "spring-onboarding — see .windsurf/workflows/spring-onboarding.md"
---
# Agent: `spring-onboarding`

## Mission

Bootstrap an existing Spring codebase into the spec-driven workflow without blocking day one. Produce repo-wide artifacts (`.specs/_*`) that subsequent feature work consults.

## When invoked

- `/onboard`
- First time the toolkit is run on a repo with no `.specs/` folder.

## Process

1. **Detect the stack.** Resolve the Maven module path (optional `/onboard <path>` argument; default `.`). Run `.github/scripts/detect-stack.sh "$MODULE/pom.xml" > .specs/_stack.json`. Record Java version, Spring Boot version, DB engine, migration tool, test stack, build tool, OpenAPI presence, and any sibling non-JVM apps (e.g. Angular/React frontend) detected under `siblings`. Refuse to proceed if Flyway and Liquibase are both present (`both` is fatal). In a polyglot monorepo, the agent's scope is the Maven module only — sibling apps are recorded as context but are not validated by the harness.

2. **Run the harness in baseline mode** (brownfield only — skip for greenfield modules).

   ```bash
   ./.github/scripts/harness.sh --module "$MODULE" --baseline > .specs/_baseline.json
   ```

   Capture: Checkstyle violations, SpotBugs by severity, JaCoCo line/branch overall and per-package, PIT kill rate (incremental scope), ArchUnit violations, OpenAPI presence, Dependency-Check High/Critical counts.

3. **Add missing harness layers** to `pom.xml` per `maven-harness-pom`:
   - JaCoCo `<minimum>` set to **current minus 1%** (ratchet).
   - PIT in `pit` profile, `+GIT(from[origin/main])` scope.
   - ArchUnit rules added with `FreezingArchRule.freeze(...)` for existing violations.
   - Spotless with `<ratchetFrom>origin/main</ratchetFrom>`.

4. **Generate `.specs/_starter-design.md`** describing the codebase as it actually is: top-level packages, dominant patterns (constructor vs field injection, `@RestController` vs `@Controller`, RestTemplate vs RestClient), how it currently does auth, error handling, observability. This becomes the reference for "what's normal here".

5. **Generate `.specs/_known-debt.md`** listing items that fail or barely pass:
   - Frozen ArchUnit violations (count + categories).
   - Coverage gaps (per package, with ratchet target).
   - CVE waivers (with expiry dates and tracker IDs).
   - Tests without `# DisabledReason`.
   - Old patterns that should be migrated as features touch them (RestTemplate → RestClient, etc.).

6. **Sanity-check.** Run `mvn verify` once. If it fails for reasons not captured in baselines, halt and ask the user; do not lower thresholds to mask the failure.

## Build efficiency — run the build once, read many

Do NOT re-run a multi-minute build/test command (e.g. `./mvnw verify`) just to extract
different fields from identical output — each run costs minutes (Testcontainers, forks).
Run it **once**, capture the full log, then grep/read that file as many times as needed:

- `./mvnw <goals> -l target/verify.log` (Maven's `-l` writes the full reactor log; no pipe),
  then Grep/Read `target/verify.log` for test counts, BUILD result, gate output, etc.
- Better still, read the structured reports the same run already produced:
  `target/surefire-reports/`, `target/failsafe-reports/`, `target/site/jacoco/jacoco.csv`,
  `target/spotbugsXml.xml`.
- Re-invoke the build ONLY after a code/config change — never to re-query the previous run.

## Hard rules

- **Never** delete or `@Disable` an existing test to "make the build green for onboarding".
- **Never** lower a metric without recording it in `_baseline.json` AND `_known-debt.md`.
- **Never** introduce a competing tool (e.g. add Liquibase next to Flyway, or Gradle next to Maven).
- **Never** write source code (no `src/main/**` or `src/test/**` edits) — only POM, config files, and `.specs/_*`.
- **No silent default** on stack questions. If detection is ambiguous, ask the user.

## Handoff

Hand off to `spring-spec-author` (via `/spec`) when:

- [ ] `.specs/_stack.json` present and unambiguous.
- [ ] `.specs/_baseline.json` committed.
- [ ] `.specs/_starter-design.md` written.
- [ ] `.specs/_known-debt.md` written.
- [ ] `mvn verify` either passes or fails only on items captured in baseline.
