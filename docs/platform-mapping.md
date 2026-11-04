# Platform Mapping

How the platform-neutral core in `shared/` is wired into Claude Code, GitHub Copilot, and Windsurf.

## Single source of truth (planned)

Skills, templates, checklists, and prompt fragments are intended to live under a top-level `shared/` directory, with each platform-specific directory (`.claude/`, `.github/`, `.windsurf/`) reduced to a thin wrapper.

**Current reality:** each platform directory carries its own copy. The CI workflow `.github/workflows/toolkit-ci.yml` enforces parity via `tools/check-parity.sh`, which ignores legitimate per-platform path differences (`.claude/` vs `.github/` vs `.windsurf/`, and command file locations). Promoting `shared/` to a real source of truth is tracked in [CHANGELOG.md](../CHANGELOG.md) under `## [Unreleased]`.

## Mapping table

| Concept | Shared core | Claude Code | GitHub Copilot | Windsurf |
| --- | --- | --- | --- | --- |
| Skill | `skills/<name>/SKILL.md` | `.claude/skills/<name>/SKILL.md` (symlink/copy) | `.github/instructions/skill-<name>.instructions.md` (path-scoped) | `.windsurf/rules/skills/<name>.md` (model-decision activation) |
| Agent | (concept) | `.claude/agents/<name>.md` (subagent) | `.github/chatmodes/<name>.chatmode.md` | `.windsurf/rules/agents/<name>.md` + invocation in workflow |
| Slash command | (concept) | `.claude/commands/<name>.md` | `.github/prompts/<name>.prompt.md` | `.windsurf/workflows/<name>.md` |
| Hook / guardrail | (concept) | `.claude/hooks/<name>.sh` + `.claude/settings.json` | `.github/instructions/guard-<name>.instructions.md` | `.windsurf/rules/guard-<name>.md` (always-on) |
| Template | `templates/<name>.template.md` | (read directly) | (read directly) | (read directly) |
| Checklist | `checklists/<name>.md` | (read directly) | (read directly) | (read directly) |

## Tool/permission model

Each agent has a strict permission boundary. The mechanism differs per platform:

| Boundary | Claude Code | Copilot | Windsurf |
| --- | --- | --- | --- |
| Allowed file globs | `allowed-tools` + hook diff-check | `tools` frontmatter + path-scoped instructions | rule frontmatter `globs:` + workflow scope |
| Forbidden actions | PreToolUse hook | instruction file + `tools` allowlist | always-on rule + workflow validation step |
| Required artifact present | PreToolUse hook | instruction (model-enforced) + workflow check | rule check at workflow entry |
| Output-only file | hook on `Write` tool | instruction + chatmode `tools` excludes `editFiles` for prod paths | rule + workflow output validation |

Where Windsurf has no native pre-tool hook, the equivalent guarantee is encoded as:

1. an **always-on rule** that the model is instructed to obey, and
2. a **workflow validation step** that re-runs the harness and fails if the rule was violated, surfacing the violation for the user.

## Example: the `block-impl-without-failing-test` invariant

- **Claude Code:** `.claude/hooks/block-impl-without-failing-test.sh` is a PreToolUse hook on `Edit`/`Write` that reads `.specs/<feature-id>/.tdd-state.json`; refuses the call if no failing test was recorded for the active task.
- **Copilot:** `.github/instructions/guard-tdd.instructions.md` (applied to `src/main/**`) plus the `spring-implementer` chatmode whose `tools:` excludes `editFiles` until a `red` log entry exists. The `/build` prompt orchestrates phases sequentially.
- **Windsurf:** `.windsurf/rules/guard-tdd.md` (always-on, scoped to `src/main/**`) + the `/build` workflow which records and verifies `.tdd-state.json` between steps.

## Slash command equivalence

| Workflow | Claude Code | Copilot | Windsurf |
| --- | --- | --- | --- |
| `/spec` | `.claude/commands/spec.md` | `.github/prompts/spec.prompt.md` | `.windsurf/workflows/spec.md` |
| `/spec-review` | … `spec-review.md` | … `spec-review.prompt.md` | … `spec-review.md` |
| `/epic-plan` | … `epic-plan.md` | … `epic-plan.prompt.md` | … `epic-plan.md` |
| `/plan` | … `plan.md` | … `plan.prompt.md` | … `plan.md` |
| `/build <task-id>` | … `build.md` | … `build.prompt.md` | … `build.md` |
| `/code-simplify` (alias: "simplify the code") | … `code-simplify.md` | … `code-simplify.prompt.md` | … `code-simplify.md` |
| `/test` | … `test.md` | … `test.prompt.md` | … `test.md` |
| `/validate` | … `validate.md` | … `validate.prompt.md` | … `validate.md` |
| `/review` | … `review.md` | … `review.prompt.md` | … `review.md` |
| `/ship` | … `ship.md` | … `ship.prompt.md` | … `ship.md` |
| `/onboard` | … `onboard.md` | … `onboard.prompt.md` | … `onboard.md` |
| `/wire-harness` | … `wire-harness.md` | … `wire-harness.prompt.md` | … `wire-harness.md` |
| `/status` | … `status.md` | … `status.prompt.md` | … `status.md` |
| `/help` | … `help.md` | … `help.prompt.md` | … `help.md` |

> **Note:** `git commit` is run by the human, not the agent. There is no
> `/commit` slash command. Likewise the brownfield baseline is captured by
> `/onboard` (which calls `./.github/scripts/harness.sh --baseline`); there
> is no separate `/baseline` command.

## MCP servers

Issue-tracker integration uses MCP. The core `issue-tracker-ingestion` skill is platform-neutral; each platform wires in MCP servers per its convention:

- **Claude Code:** `.mcp.json` at the workspace root or `~/.claude/mcp.json` (user scope).
- **Copilot:** MCP servers configured via VS Code settings; the chatmode lists allowed `mcp_*` tools.
- **Windsurf:** `.windsurf/mcp/` configuration files; the workflow whitelists relevant MCP servers.

The agent runs `.github/scripts/detect-stack.sh --mcp` at the start of `/spec` to enumerate available servers and pick one that matches the user's tracker.

## Drift control

A `.github/scripts/sync-platforms.sh` (planned) will regenerate the per-platform copies from `shared/` once that directory exists. Until then, any change to a skill, template, or checklist must be propagated manually to all three platform directories. CI (`.github/workflows/toolkit-ci.yml`) runs `tools/check-parity.sh` and fails on any divergence.
