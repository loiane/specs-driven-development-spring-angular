# Claude Code — self-contained workspace

This folder contains all Claude Code configuration. It is fully self-contained — no external `shared/` folder is needed.

## Structure

```text
.claude/
├── README.md
├── settings.json              # global Claude Code settings (permissions, hooks)
├── agents/                    # one .md per agent — frontmatter + full agent definition
├── skills/                    # one folder per skill — full SKILL.md
├── commands/                  # slash commands — full command definitions
├── hooks/                     # pre/post tool-use hook scripts
├── templates/                 # document templates
├── checklists/                # review checklists
└── maven/                     # Maven POM fragments
```

Each agent, skill, and command file contains the complete definition (not a thin pointer).
Cross-IDE parity is maintained: the same prompt across Claude Code, Copilot, and Windsurf
produces the same artifacts. Corresponding files:

- `.claude/agents/NAME.md` ↔ `.github/agents/NAME.agent.md` ↔ `.windsurf/workflows/NAME.md`
- `.claude/skills/NAME/SKILL.md` ↔ `.github/skills/NAME/SKILL.md` ↔ `.windsurf/skills/NAME/SKILL.md`
- `.claude/commands/NAME.md` ↔ `.github/prompts/NAME.prompt.md` ↔ `.windsurf/workflows/NAME.md`

Scripts used by agents live in `.github/scripts/`.
