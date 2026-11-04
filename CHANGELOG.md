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
- Toolkit CI restored as `.github/workflows/toolkit-ci.yml`: shellcheck, hook/script tests, markdown lint, link check, tri-platform parity, repo hygiene.
- `tools/check-parity.sh` — parity check that normalises legitimate per-platform path differences (the old raw `diff -rq` could never pass).
- `tests/run.sh` — plain-bash regression tests for the Claude hooks, `traceability.sh`, `detect-stack.sh` and `settings.json` wiring.
- `.markdownlint-cli2.yaml` and `lychee.toml` so local runs and CI use the same configuration.
- `harness.sh` and `check-new-code-coverage.sh` tests in `tests/run.sh` (fake `mvn` on `PATH`, single-line JaCoCo report).

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
- `harness.sh` always exited 0, even when coverage or mutation gates failed; it now exits 1 on any failed gate (2 on missing prerequisites) and adds `build`, `finished_at` and `overall` to the summary. `--baseline` still exits 0.
- `harness.sh` aborted before writing the summary when `mvn verify` failed, so the validator had nothing to read. The build result is now a gate and the summary is always written; PIT is skipped after a failed build.
- `harness.sh --report > file` and `--baseline > .specs/_baseline.json` (as documented in the commands and agents) captured Maven's log instead of JSON. Build output now goes to stderr in those modes, and `--baseline` writes to the repo root's `.specs/` even with `--module`.
- `harness.sh` coverage summary now reads JaCoCo's report-level totals instead of the last counter in the file, and a project with no branches no longer fails the branch threshold.
- `check-new-code-coverage.sh` failed on macOS (`mapfile`, gawk-only `match()`), could not parse single-line JaCoCo reports, counted comments and blank lines as uncovered, ignored untracked files, and diffed against the tip of `origin/main` instead of the merge base. Rewritten for bash 3.2 + BSD awk with `python3` for the XML.
- Docs pointed at files and features that don't exist: `shared/skills/...` in the Copilot instructions, `guard-tdd` guardrails, `.windsurf/rules/{skills,agents}/`, `.windsurf/mcp/`, `sync-platforms.sh`, `detect-stack.sh --mcp` and `docs/known-debt.md`. `docs/platform-mapping.md` now describes the actual layout.
- The natural-language alias hook routed any prompt containing words like "validate" or "code review" (e.g. "how do I validate input?"). Aliases now only fire when the prompt starts with the phrase, and "implement T-NNN" / "build T-NNN" now route to `/build T-NNN` as documented.
- `block-impl-without-failing-test.sh` did not check `red_at`, and only checked `red_failure_excerpt` in the `red` phase. Every editable phase now requires both, and the guardrail docs on all three platforms describe the same rule (edits are also allowed in `green`, `refactor`, and `simplify`).
- `.gitignore` ignored `.specs/<feature>/.tdd-audit.log` through `*.log`; the audit trail is now committed with the other artifacts.
- `files_in_scope` was never enforced by `block-impl-without-failing-test.sh` / `enforce-files-in-scope.sh`: the jq filter compared each path with itself. Entries now match exactly or as a `/`-anchored path suffix.
- Platform drift: `.github/` and `.windsurf/` were missing the "Domain Entities and Relationships" sections in the spec/design templates and review checklists; ADR template placeholder styles differed; broken `./.githu.github/scripts/harness.sh` path in the Claude brownfield skill.
- `detect-stack.sh` emitted `"db_engines": [""]` (and an unbound-variable error on bash 3.2) when no DB driver was found.
- Dead links to the EARS and Flyway references; markdown lint findings across docs, skills, agents and templates.
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
