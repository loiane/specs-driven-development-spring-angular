---
description: Run /help — see .claude/commands/help.md for the authoritative spec.
argument-hint: see .claude/commands/help.md

---
# /help

**Phase:** meta — read-only
**Owning agent:** none

## Purpose

Print the command catalog and the recommended phase order. Optionally explain a single command in depth.

## Inputs

- Optional `<command-name>` (without the leading slash).

## Reads

- `.claude/commands/`
- `.claude/commands/<command-name>.md` if a name was supplied.

## Writes

Nothing.

## Process

- No argument → print the table from `.claude/commands/` and the natural-language alias list.
- With argument → print the contents of the matching shared command file (Purpose, Inputs, Reads, Writes, Process, Refuse if, Done when).

## Refuse if

Never.

## Done when

Help text is rendered.
