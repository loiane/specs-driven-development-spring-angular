#!/usr/bin/env bash
# route-natural-language-aliases.sh
# Claude UserPromptSubmit hook.
# Translates the configured natural-language aliases into explicit slash commands
# by emitting an additional context line. This does not rewrite the user's prompt;
# it adds a hint so the agent picks the right command.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"
prompt="$(echo "$input" | jq -r '.prompt // empty')"
[ -z "$prompt" ] && exit 0

# Aliases only fire when the prompt starts with the phrase (after an optional
# polite lead-in), so questions like "how do I validate input?" are not routed.
lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/^[[:space:]]+//; s/^(please|ok|okay|now|so|great|thanks)[,.!]?[[:space:]]+//; s/^(can|could|would) you[[:space:]]+//; s/^(let'"'"'s|lets)[[:space:]]+//; s/^please[[:space:]]+//')"

emit() {
  jq -cn --arg cmd "$1" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: ("Natural-language alias detected: route to " + $cmd + ".")}}'
}

# "implement T-001" / "build T-001" -> /build T-001
task_id="$(printf '%s' "$lc" | sed -nE 's/^(implement|build)[[:space:]]+(t-[0-9]{3,})([^0-9].*)?$/\2/p' | tr '[:lower:]' '[:upper:]')"
if [ -n "$task_id" ]; then
  emit "/build $task_id"
  exit 0
fi

case "$lc" in
  "simplify the code"*|"make this clearer"*|"make this readable"*|"remove the cleverness"*)
    emit "/code-simplify" ;;
  "spec this"*|"turn this ticket into requirements"*|"write a spec"*)
    emit "/spec" ;;
  "review the spec"*)
    emit "/spec-review" ;;
  "plan this epic"*|"design this epic"*|"slice this epic"*)
    emit "/epic-plan" ;;
  "plan this"*|"design this"*|"break into tasks"*|"break this into tasks"*)
    emit "/plan" ;;
  "validate"|"validate."|"validate!"|"validate it"*|"validate this"*|"run the harness"*)
    emit "/validate" ;;
  "review the code"*|"pre-commit review"*|"do a code review"*)
    emit "/review" ;;
  "ship it"*|"release this"*|"prepare release"*|"prepare the release"*)
    emit "/ship" ;;
  "onboard this repo"*|"onboard this project"*)
    emit "/onboard" ;;
  *)
    exit 0 ;;
esac
