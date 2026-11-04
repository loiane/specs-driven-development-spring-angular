---
name: brownfield-onboarding
description: Onboard an existing Spring codebase into the spec-driven workflow without blocking day one. Establish a `_baseline.json`, ratchet rules, and produce a starter design doc that reflects what the code actually looks like.
when_to_use:
  - User runs `/onboard` or asks "add this workflow to my existing project".
  - First feature on a repo that has no `.specs/` folder.
authoritative_references:
  - docs/methodology.md
  - .claude/skills/maven-harness-pom/SKILL.md
  - .github/scripts/detect-stack.sh
---

# Brownfield onboarding

## Goal

Reach a state where `/spec` works on the next feature, the harness runs green (or with documented baseline drift), and the team is not blocked by years of accumulated lint/coverage debt.

## Steps

1. **Detect the stack.** Run `.github/scripts/detect-stack.sh > .specs/_stack.json`. Record:
   - Java version, Spring Boot version
   - DB engine (Postgres/MySQL/H2/…)
   - Migration tool (Flyway/Liquibase/none/both)
   - Test stack (JUnit 4 vs 5, Testcontainers presence)
   - Build tool (Maven only for now)
   - OpenAPI spec presence

2. **Run the harness once, capture baselines.**

   ```bash
   .github/scripts/harness.sh --baseline > .specs/_baseline.json
   ```

   Result is committed:

   ```json
   {
     "captured_at": "2026-04-18T10:00:00Z",
     "git_sha": "abc1234",
     "checkstyle": { "violations": 412 },
     "spotbugs": { "high": 3, "medium": 27, "low": 88 },
     "jacoco": { "overall_line": 0.71, "overall_branch": 0.58 },
     "pit": { "kill_rate": 0.46, "scope": "incremental" },
     "archunit": { "violations": 18 },
     "openapi": { "present": false },
     "dependency_check": { "high": 1, "critical": 0 }
   }
   ```

3. **Add missing harness layers to the POM.** Use `maven-harness-pom` skill. Pin to current values, not the targets:

   - JaCoCo `<minimum>` set to current minus 1% (ratchet).
   - PIT enabled in a profile (`-Ppit`), incremental scope only.
   - ArchUnit rules added with `FreezingArchRule.freeze(...)`.
   - Spotless added in `check` mode for new code only initially (use `<ratchetFrom>origin/main</ratchetFrom>`).

4. **Generate a starter design.** `spring-architect` reads the codebase and writes `.specs/_starter-design.md` describing modules-as-they-are, the dominant patterns, and notable deviations. This is the reference for future feature designs ("we already do X, so a new feature should follow X unless an ADR says otherwise").

5. **Document the gaps.** Write `.specs/_known-debt.md` listing the things that fail or barely pass:

   ```markdown
   - 18 ArchUnit violations frozen.
   - Coverage at 71% (target 90%); ratchet by +1% per feature.
   - 1 High-severity CVE waived: CVE-2024-XXXX in com.example:legacy-lib until upgrade ticket SHOP-123.
   - Field injection in 47 places; freeze ArchUnit rule, fix incrementally.
   ```

6. **First feature.** Run `/spec` against a small ticket. The agent reads `.specs/_baseline.json` and `.specs/_starter-design.md` and never proposes work that breaks them silently.

## Ratchet policy

- Coverage: per-package thresholds raised by 1% per merged PR that touches the package.
- ArchUnit: frozen violations decrease only; never add a new violation.
- Mutation: incremental scope from day one; full-scope nightly run is informational.
- CVE waivers: every waiver has an expiry date and a tracker ticket.

## Anti-patterns

- "We'll fix coverage later" without setting a ratchet number.
- Disabling a harness layer because it's noisy → lower the threshold instead, log the debt.
- Editing baselines downward without an ADR.
- Committing `_baseline.json` changes that lower a metric without explanation.
