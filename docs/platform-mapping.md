# Platform Mapping

How the same workflow is wired into Claude Code, GitHub Copilot, and Windsurf.

## One copy per platform, kept in lockstep

Each platform directory (`.claude/`, `.github/`, `.windsurf/`) carries its own copy of the skills, templates, checklists, and Maven fragments, so consumers can delete the directories for agents they don't use. The scripts in `.github/scripts/` are the one exception: all three platforms call them.

The CI workflow `.github/workflows/toolkit-ci.yml` enforces parity via `tools/check-parity.sh`, which ignores legitimate per-platform path differences (`.claude/` vs `.github/` vs `.windsurf/`, and command file locations). It also checks that every agent, slash command, and guardrail in the tables below exists on each platform. Any change to a skill, template, or checklist must be made in all three directories.

## Mapping table

| Concept | Claude Code | GitHub Copilot | Windsurf |
| --- | --- | --- | --- |
| Skill | `.claude/skills/<name>/SKILL.md` | `.github/skills/<name>/SKILL.md` (referenced from instructions, prompts, and chatmodes) | `.windsurf/skills/<name>/SKILL.md` (referenced from rules and workflows) |
| Agent | `.claude/agents/<name>.md` (subagent) | `.github/chatmodes/<name>.chatmode.md` | `.windsurf/workflows/<name>.md` |
| Slash command | `.claude/commands/<name>.md` | `.github/prompts/<name>.prompt.md` | `.windsurf/workflows/<name>.md` |
| Hook / guardrail | `.claude/hooks/<name>.sh` + `.claude/settings.json` (enforced) | `.github/instructions/<scope>.instructions.md` (`applyTo:` globs; model-enforced) | `.windsurf/rules/<scope>.md` (`trigger:` always-on or glob; model-enforced) |
| Template | `.claude/templates/` | `.github/templates/` | `.windsurf/templates/` |
| Checklist | `.claude/checklists/` | `.github/checklists/` | `.windsurf/checklists/` |
| Maven fragment | `.claude/maven/` | `.github/maven/` | `.windsurf/maven/` |
| Harness scripts | `.github/scripts/` | `.github/scripts/` | `.github/scripts/` |

The guardrail files by scope:

| Scope | Copilot | Windsurf |
| --- | --- | --- |
| Always on | `always-on.instructions.md` | `always-on.md` |
| `**/src/main/**/*.java` | `production-code.instructions.md` | `production-code.md` |
| `**/src/test/**/*.java` | `test-code.instructions.md` | `test-code.md` |
| `.specs/**/*.md` | `specs-artifacts.instructions.md` | `specs-artifacts.md` |
| `**/src/**/*.{ts,html,scss,css}` (Angular) | `frontend-code.instructions.md` | `frontend-code.md` |

The `**/` prefix makes the guardrails apply in multi-module repos and when the Angular app lives in a subdirectory such as `frontend/`.

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

- **Claude Code:** `.claude/hooks/block-impl-without-failing-test.sh` is a PreToolUse hook on `Edit`/`Write` that reads `.specs/<feature-id>/.tdd-state.json`; refuses the call if no failing test was recorded for the active task. It covers Java under `src/main/**` and Angular production files (`*.ts`, `*.html`, `*.scss`, `*.css` under `src/`, except `*.spec.ts`); `enforce-files-in-scope.sh` covers `src/test/**` and `*.spec.ts`.
- **Copilot:** `.github/instructions/production-code.instructions.md` and `frontend-code.instructions.md` tells the model to check `.tdd-state.json` before editing. Copilot has no pre-tool hook, so this is model-enforced; the `/build` prompt orchestrates phases sequentially and `/validate` catches violations afterwards.
- **Windsurf:** `.windsurf/rules/production-code.md` and `frontend-code.md` (`trigger: glob`) carry the same check, and the `/build` workflow records and verifies `.tdd-state.json` between steps.

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
- **Copilot:** `.vscode/mcp.json` in the workspace or VS Code user settings.
- **Windsurf:** `~/.codeium/windsurf/mcp_config.json`.

At the start of `/spec`, the agent asks which tracker the work comes from and uses whichever matching MCP tools it has been given (see the `issue-tracker-ingestion` skill). If none is configured, it asks the user to paste the ticket.

## Drift control

There is no generator: a change to a skill, template, or checklist is made by hand in all three platform directories. CI (`.github/workflows/toolkit-ci.yml`) runs `tools/check-parity.sh` and fails on any divergence; run it locally before pushing.
