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

# Lowercase for matching.
lc="$(echo "$prompt" | tr '[:upper:]' '[:lower:]')"

emit() {
  cat <<EOF
{"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "Natural-language alias detected: route to $1."}}
EOF
}

case "$lc" in
  *"simplify the code"*|*"make this clearer"*|*"make this readable"*|*"remove the cleverness"*)
    emit "/code-simplify" ;;
  *"spec this"*|*"turn this ticket into requirements"*|*"write a spec"*)
    emit "/spec" ;;
  *"review the spec"*)
    emit "/spec-review" ;;
  *"plan this epic"*|*"design this epic"*|*"slice this epic"*)
    emit "/epic-plan" ;;
  *"plan this"*|*"design this"*|*"break into tasks"*|*"break this into tasks"*)
    emit "/plan" ;;
  *"validate"*|*"run the harness"*)
    emit "/validate" ;;
  *"review the code"*|*"pre-commit review"*|*"code review"*)
    emit "/review" ;;
  *"ship it"*|*"release this"*|*"prepare release"*)
    emit "/ship" ;;
  *"onboard this repo"*|*"onboard this project"*)
    emit "/onboard" ;;
  *)
    exit 0 ;;
esac
