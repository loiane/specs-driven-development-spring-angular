---
mode: agent
description: Run /wire-harness — see .github/prompts/wire-harness.prompt.md for the authoritative spec.
tools: ['codebase', 'editFiles', 'search', 'runCommands', 'runTests']
model: GPT-5
---
# /wire-harness

**Phase:** 0 (meta) — onboarding extension
**Owning agent:** `.github/chatmodes/spring-onboarding.chatmode.md`
**Skills used:** `maven-harness-pom`, `jacoco-coverage-policy`, `pit-mutation-tuning`, `flyway-or-liquibase-detection`, `harness-report-parsing`

## Purpose

Wire the Maven harness layers (Spotless, Checkstyle, SpotBugs, Surefire/Failsafe split, JaCoCo, PIT, OWASP Dependency-Check) plus the chosen migration tool dependency into a Maven module's `pom.xml`. Runs against a module that has already been classified by `/onboard` so that subsequent `/spec` → `/plan` → `/build` cycles execute against fully gated quality bars from day one.

This command exists because `/onboard` Process step 4 says "add missing harness layers" but only on the POM-and-config surface, while `/build` is strictly TDD and refuses to edit the POM without a `<task-id>` in flight. `/wire-harness` fills that gap.

## Inputs

None required. Optional argument: a path to a Maven module (default `.`). For polyglot monorepos pass the module directory (e.g. `shoply-api`).

## Reads

- The target module's `pom.xml`.
- `.specs/_stack.json` (must exist — produced by `/onboard`).
- `.specs/_onboarding.md` and `.specs/_known-debt.md` (to know what's already accepted as deferred).
- `.specs/adr/` (must already contain the migration-tool decision if the module uses a database).
- `.github/maven/parent-pom-fragment.xml` and `.github/skills/maven-harness-pom/SKILL.md` (authoritative reference).
- `.github/skills/jacoco-coverage-policy/SKILL.md`, `.github/skills/pit-mutation-tuning/SKILL.md`, `.github/skills/flyway-or-liquibase-detection/SKILL.md`.

## Writes

- `<module>/pom.xml` (plugin and dependency wiring; properties block; profile blocks).
- `<module>/checkstyle.xml` (starter Google-style config if missing).
- `<module>/dependency-check-suppressions.xml` (empty suppression file if missing).
- `.specs/_baseline.json` (refreshed via `.github/scripts/harness.sh --baseline` after the wiring run).
- `.specs/_stack.json` (refreshed via `.github/scripts/detect-stack.sh`).
- `.specs/_known-debt.md` (close the harness debt entry; add new entries for any layer **deferred** during this pass with rationale and trigger).
- `.specs/_starter-design.md` (record chosen profiles, code style, naming conventions for unit/IT tests).
- `.specs/adr/ADR-NNN-*.md` (one ADR per deferred layer that overrides a default in `maven-harness-pom`).

## Process

1. **Pre-flight.** Refuse if `.specs/_stack.json` is missing (run `/onboard` first). Refuse if `migration == "both"`. If `migration == "none"` and the module has any DB engine, refuse and instruct the user to author the migration-tool ADR first (`/spec` → ADR via `/plan`, or a direct ADR under `spring-architect`).
2. **Compatibility check.** For each layer, verify the pinned plugin version in `.github/skills/maven-harness-pom/SKILL.md` is compatible with the detected `java_version` and `spring_boot_version`. If a layer is incompatible (e.g. Error Prone on a too-new JDK), **defer it** — do not invent a workaround. Each deferral becomes an ADR in step 6.
3. **Wire layers.** Edit `<module>/pom.xml` per `.github/skills/maven-harness-pom/SKILL.md`:
   - Properties block with pinned versions.
   - Spotless (Google Java Format), Checkstyle, SpotBugs (+ FindSecBugs).
   - Surefire (excludes `**/*IT.java`) + Failsafe (`**/*IT.java`, group `integration`).
   - JaCoCo with the thresholds from `jacoco-coverage-policy` (full thresholds for greenfield; ratchet for brownfield using `_baseline.json`). Exclude the Spring Boot `@SpringBootApplication` class from coverage rules.
   - PIT inside a `pit` profile (off the default `mvn verify` path).
   - OWASP Dependency-Check inside a `security` profile (off the default `mvn verify` path so the NVD download doesn't gate every local build).
   - Migration tool runtime dependency (e.g. `flyway-core` + `flyway-mysql`) per `flyway-or-liquibase-detection`.
4. **Config files.**
   - Create `<module>/checkstyle.xml` (Google-style starter) if absent.
   - Create `<module>/dependency-check-suppressions.xml` (empty `<suppressions>`) if absent.
   - Fix obvious POM hygiene that Spotless/Checkstyle will flag (e.g. populate or remove empty Initializr-generated `<name/>`, `<description/>`, `<url/>`, `<scm/>` elements).
5. **Apply formatting.** Run `mvn -pl <module> spotless:apply` once to bring existing source files (Initializr scaffolding) into compliance. This is the **only** edit to `src/**` allowed in this command, and it is mechanical.
6. **Document deferrals.** For each layer deferred in step 2, write `.specs/adr/ADR-NNN-<slug>.md` per `.github/skills/adr-authoring/SKILL.md` (Context, Decision drivers, Considered options, Decision outcome with rationale, Consequences, Trigger to revisit). Add a corresponding `DEBT-NNN` entry to `.specs/_known-debt.md`.
7. **Verify.** Run `mvn -pl <module> -am verify`. The build must be **green**. Then run `.github/scripts/harness.sh --module <module> --baseline` and capture the result into `.specs/_baseline.json`.
8. **Refresh artifacts.** Re-run `.github/scripts/detect-stack.sh <module>/pom.xml > .specs/_stack.json`. Update `.specs/_known-debt.md` to mark the harness-layers debt resolved (preserve the entry, prepend the resolution note). Update `.specs/_starter-design.md` with the chosen profiles, code style, and test-naming conventions.

## Refuse if

- `.specs/_stack.json` does not exist (precondition: run `/onboard` first).
- `migration == "both"` in the stack JSON (fatal; same rule as `/onboard`).
- `migration == "none"` and the module has a DB engine and no ADR has decided the migration tool.
- The agent would need to edit any file under `<module>/src/main/**` or `<module>/src/test/**` other than via `mvn spotless:apply` (test code and architecture-rule code belong to a future `/build` task).
- Any harness layer's compatibility cannot be established and the user has not chosen between deferring it or pinning an explicit override version.
- A coverage or mutation threshold would need to be lowered without a `_baseline.json` baseline + an ADR justifying the ratchet.

## Done when

- `mvn -pl <module> -am verify` is green from a clean checkout (after the one-shot `spotless:apply`).
- `.github/scripts/harness.sh --module <module> --report` shows every wired layer as `pass` (or `skipped` if it lives in an opt-in profile).
- `.specs/_baseline.json` exists and reflects the post-wiring run.
- `.specs/_known-debt.md` no longer lists the harness-layers debt as open; any deferred layer has its own `DEBT-NNN` + ADR.
- The user has been told the next recommended command is `/spec` (greenfield) or `/build <task-id>` (if a task is already pending).
