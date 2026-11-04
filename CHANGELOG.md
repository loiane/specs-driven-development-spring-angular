# Changelog

All notable changes to this toolkit are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

What counts as a breaking change for this toolkit is defined in [CONTRIBUTING.md](CONTRIBUTING.md#versioning).

## [Unreleased]

### Added
- `LICENSE` (MIT) at repo root.
- `.gitignore` covering macOS, IDE, Java/Maven, Node/Angular, and harness artifacts.
- `.editorconfig` for consistent line endings and indentation.
- `CONTRIBUTING.md` with parity rules and per-platform change checklist.
- `SECURITY.md` with disclosure process and consumer hardening guidance.
- `CHANGELOG.md` (this file).

### Removed
- Committed `.DS_Store` files.

### Changed
- Canonical spec line format documented in `docs/spec-format.md`: `- AC-NNN: <EARS sentence>` and `- Q-NNN: <question>` with a `Status:` sub-bullet. The `ears-spec-authoring` and `issue-tracker-ingestion` skills and the greenfield example now use it.
- `traceability.sh` exits `1` when any AC has no linked test and `2` when no ACs are found (previously always `0`).
- Open questions marked `Status: deferred` or `Status: resolved` no longer block later phases.

### Fixed
- README and `docs/platform-mapping.md` references to paths and commands that did not exist on disk.
- `forbid-skip-flags.sh` never blocked anything: patterns such as `-DskipTests` were parsed by `grep` as options.
- `.claude/settings.json` hooks used an invalid schema and were never registered. They now use the nested `hooks: [{type, command}]` form, `$CLAUDE_PROJECT_DIR` paths, and also match `MultiEdit`.
- Blocking hooks now fail closed (exit 2) when `jq` is missing instead of silently allowing the action.
- `traceability.sh` only recognised `### AC-NNN` headings, ignored `@DisplayName("AC-NNN: …")`, and required bash 4 (`mapfile`).
- `block-progress-on-open-questions.sh` only recognised `- **Q-NNN**`, so questions written from the spec template never blocked.

## [0.1.0] — Initial public toolkit

- Seven-phase spec-driven workflow (specify → review → plan → build → test → validate → review).
- Optional Phase 8 (ship) with `09-ship-plan.md`.
- Tri-platform wiring: Claude Code (`.claude/`), GitHub Copilot (`.github/`), Windsurf (`.windsurf/`).
- 22 skills covering Spring Boot 4 / Spring Framework 7 conventions, Angular, security baseline, OpenAPI contract-first, Testcontainers patterns, JaCoCo + PIT policy, ArchUnit rules, ADR authoring, brownfield onboarding, performance optimization, traceability, and more.
- 10-layer Maven harness fragment (Spotless, Checkstyle, SpotBugs/Error Prone, ArchUnit, Surefire/Failsafe, JaCoCo, PIT, OpenAPI diff, OWASP dependency check).
- TDD enforcement via `.tdd-state.json` and `block-impl-without-failing-test` hook (Claude); equivalent guardrails for Copilot and Windsurf.
- Worked greenfield example under `examples/greenfield/`.
- Brownfield onboarding example under `examples/brownfield/`.
