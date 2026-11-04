## Summary

<!-- What does this PR change and why? Link any related issues. -->

## Type of change

- [ ] Docs / typo / non-behavioral
- [ ] New skill / template / command
- [ ] Change to an existing skill / template / command
- [ ] Hook or harness script change
- [ ] Maven parent-pom fragment change
- [ ] Methodology change (phases, exit contracts, artifacts)
- [ ] CI / repo hygiene

## Tri-platform parity

If this change touches a skill, template, checklist, command, or the Maven
fragment, it MUST land in all three platform directories in this same PR.

- [ ] `.claude/` updated
- [ ] `.github/` updated
- [ ] `.windsurf/` updated
- [ ] N/A (docs/CI/example only)

## Checks

- [ ] `shellcheck` clean (`shellcheck -S style .github/scripts/*.sh .claude/hooks/*.sh`)
- [ ] Markdown lints (`npx markdownlint-cli2 "**/*.md"`)
- [ ] Platform parity (`tools/check-parity.sh` — see CONTRIBUTING.md)
- [ ] [CHANGELOG.md](../CHANGELOG.md) updated under `## [Unreleased]`
- [ ] If methodology changed: [docs/methodology.md](../docs/methodology.md) updated
- [ ] If artifact contract changed: [docs/artifact-contract.md](../docs/artifact-contract.md) updated

## Breaking change?

<!-- A change is breaking if it modifies a phase exit contract, an artifact's required schema, or hook enforcement semantics. See CONTRIBUTING.md#versioning. -->

- [ ] Yes — describe migration:
- [ ] No
