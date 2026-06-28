# Changelog

All notable changes to this toolkit are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

What counts as a breaking change for this toolkit is defined in [CONTRIBUTING.md](CONTRIBUTING.md#versioning).

## [Unreleased]

### Added
- **Loop engineering** — the `loop-engineering` skill (the six-part loop pattern,
  four loop shapes, and the issue-to-merged pipeline) plus four concrete loop
  skills: `spec-sharpen-loop`, `sdd-build-loop`, `pr-quality-gate`, and
  `pr-review-response`. Mirrored across `.claude/`, `.github/`, and `.windsurf/`.
- `docs/loop-engineering.md` documenting the loop pattern, shapes, composition,
  and guardrails, linked from the README.
- `LICENSE` (MIT) at repo root.
- `.gitignore` covering macOS, IDE, Java/Maven, Node/Angular, and harness artifacts.
- `.editorconfig` for consistent line endings and indentation.
- `CONTRIBUTING.md` with parity rules and per-platform change checklist.
- `SECURITY.md` with disclosure process and consumer hardening guidance.
- `CHANGELOG.md` (this file).

### Removed
- Committed `.DS_Store` files.

### Fixed
- README and `docs/platform-mapping.md` references to paths and commands that did not exist on disk.

## [0.1.0] — Initial public toolkit

- Seven-phase spec-driven workflow (specify → review → plan → build → test → validate → review).
- Optional Phase 8 (ship) with `09-ship-plan.md`.
- Tri-platform wiring: Claude Code (`.claude/`), GitHub Copilot (`.github/`), Windsurf (`.windsurf/`).
- 22 skills covering Spring Boot 4 / Spring Framework 7 conventions, Angular, security baseline, OpenAPI contract-first, Testcontainers patterns, JaCoCo + PIT policy, ArchUnit rules, ADR authoring, brownfield onboarding, performance optimization, traceability, and more.
- 10-layer Maven harness fragment (Spotless, Checkstyle, SpotBugs/Error Prone, ArchUnit, Surefire/Failsafe, JaCoCo, PIT, OpenAPI diff, OWASP dependency check).
- TDD enforcement via `.tdd-state.json` and `block-impl-without-failing-test` hook (Claude); equivalent guardrails for Copilot and Windsurf.
- Worked greenfield example under `examples/greenfield/`.
- Brownfield onboarding example under `examples/brownfield/`.
