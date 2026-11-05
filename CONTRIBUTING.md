# Contributing

Thanks for your interest in improving the spec-driven development toolkit.

## Ground rules

- This repo ships **methodology assets** (skills, prompts, templates, hooks, harness scripts) for three agent surfaces: Claude Code (`.claude/`), GitHub Copilot (`.github/`), and Windsurf (`.windsurf/`). It is not a runtime library.
- Behavioral changes must land in **all three** platform copies in the same PR. CI enforces parity (see `.github/workflows/toolkit-ci.yml` and `tools/check-parity.sh`).
- Methodology guardrails in [docs/methodology.md](docs/methodology.md) and [docs/harness-principles.md](docs/harness-principles.md) are the contract. Don't change them silently — open an issue first.

## Local prerequisites

- `bash` (3.2+), `git`, `jq`, `python3`
- `shellcheck` (`brew install shellcheck`)
- `markdownlint-cli2` (`npm i -g markdownlint-cli2`) and `lychee` (`brew install lychee`) — optional, CI runs them
- Java 25 + Maven 3.9+ only if you're touching the harness POM fragment or testing the harness end-to-end

## Repository layout

See [README.md](README.md#repository-layout). Briefly:

- `docs/` — methodology, harness principles, artifact contract, spec format, platform mapping.
- `.claude/`, `.github/`, `.windsurf/` — per-platform copies of the same skills, templates, checklists, and the Maven parent-pom fragment.
- `.github/scripts/` — `harness.sh`, `detect-stack.sh`, `check-new-code-coverage.sh`, `traceability.sh`. Used by all three platforms.
- `examples/` — worked examples (greenfield, brownfield).
- `tools/check-parity.sh` and `tests/run.sh` — toolkit maintenance (parity check, hook/script regression tests). Run by CI.

## Making changes

1. Open an issue describing the change, especially for new skills, new phases, or any change to a phase exit contract.
2. Create a branch.
3. Edit the asset in the platform you primarily use (e.g. `.claude/skills/<name>/SKILL.md`).
4. **Mirror the change** to the other two platforms. The CI parity check will fail otherwise.
5. Run locally before pushing:

   ```bash
   shellcheck -S style .github/scripts/*.sh .claude/hooks/*.sh tools/*.sh tests/*.sh
   tests/run.sh                 # hook and script regression tests
   tools/check-parity.sh        # tri-platform parity
   npx markdownlint-cli2        # config: .markdownlint-cli2.yaml
   lychee './**/*.md'           # config: lychee.toml
   ```

6. Update [CHANGELOG.md](CHANGELOG.md) under `## [Unreleased]`.
7. Open a PR. Fill out the template.

## Adding a new skill

A skill is a single `SKILL.md` (plus optional `references/`) with the structure used by the existing skills (see `.claude/skills/spring-boot-4-conventions/SKILL.md` as a reference).

1. Create the skill in all three platform dirs:
   - `.claude/skills/<name>/SKILL.md`
   - `.github/skills/<name>/SKILL.md`
   - `.windsurf/skills/<name>/SKILL.md`
2. Reference it from the agent(s) and command(s) that need it.
3. Add it to the skill index in the relevant agent files (`.claude/agents/`, `.github/agents/`, `.windsurf/workflows/`).

## Adding a new slash command

1. Create the command in all three platforms:
   - `.claude/commands/<name>.md`
   - `.github/prompts/<name>.prompt.md`
   - `.windsurf/workflows/<name>.md`
2. Update the command tables in [README.md](README.md) and [docs/platform-mapping.md](docs/platform-mapping.md).
3. Add a natural-language alias if appropriate (in [.github/instructions/always-on.instructions.md](.github/instructions/always-on.instructions.md) and the matching files for the other two platforms).

## Versioning

This project follows [Semantic Versioning](https://semver.org/) for the toolkit as a whole. See [CHANGELOG.md](CHANGELOG.md) for what counts as breaking.

- **MAJOR** — a phase exit contract changes, an artifact's required schema changes, or a hook's enforcement semantics change.
- **MINOR** — a new skill, a new command, a new optional template section.
- **PATCH** — typo fixes, doc clarifications, non-behavioral edits.

## Security

Please report security issues per [SECURITY.md](SECURITY.md), not through public issues.

## License

By contributing you agree your contributions are licensed under the MIT License (see [LICENSE](LICENSE)).
