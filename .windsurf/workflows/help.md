---
description: Run /help — see .windsurf/workflows/help.md for the authoritative spec.
---
# /help

**Phase:** meta — read-only
**Owning agent:** none

## Purpose

Print the command catalog and the recommended phase order. Optionally explain a single command in depth.

## Inputs

- Optional `<command-name>` (without the leading slash).

## Reads

- `.windsurf/commands/README.md`
- `.windsurf/workflows/<command-name>.md` if a name was supplied.

## Writes

Nothing.

## Process

- No argument → print the table from `.windsurf/commands/README.md` and the natural-language alias list.
- With argument → print the contents of the matching shared command file (Purpose, Inputs, Reads, Writes, Process, Refuse if, Done when).

## Refuse if

Never.

## Done when

Help text is rendered.
