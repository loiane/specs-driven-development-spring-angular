#!/usr/bin/env bash
# enforce-files-in-scope.sh
# Claude PreToolUse Edit|Write hook.
# Blocks edits outside the active task's files_in_scope, EXCEPT:
#   - .specs/** is always allowed (artifacts).
#   - src/test/** is allowed for spring-test-engineer (red step).
#
# This is a defense-in-depth alongside block-impl-without-failing-test.sh which
# already covers src/main/**. This script extends the same check to test files.

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "BLOCKED: jq is required by .claude/hooks (install jq). Refusing to fail open." >&2
  exit 2
}
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -z "$file_path" ] && exit 0

# Always allow artifact edits.
case "$file_path" in
  *.specs/*) exit 0 ;;
  */pom.xml|*/checkstyle.xml|*/dependency-check-suppressions.xml) exit 0 ;;
esac

# Only check src/test/** here (src/main/** handled by sibling hook).
case "$file_path" in
  */src/test/*) ;;
  *) exit 0 ;;
esac

# shellcheck disable=SC2012 # ls -t is needed to pick the most recently modified state file
state_file="$(ls -t .specs/*/.tdd-state.json 2>/dev/null | head -n 1 || true)"
[ -z "$state_file" ] && exit 0  # no active feature; let it through (e.g. test-plan author)

active_task="$(jq -r '.active_task // empty' "$state_file")"
[ -z "$active_task" ] && exit 0

in_scope="$(jq -r --arg t "$active_task" --arg f "$file_path" '
  .tasks[$t].files_in_scope // []
  | map(select(. as $s | $s != "" and ($f == $s or ($f | endswith("/" + $s)))))
  | length
' "$state_file")"

if [ "$in_scope" = "0" ]; then
  echo "BLOCKED: $file_path is not in task $active_task files_in_scope. Edit only the declared test paths, or update 04-tasks.md and re-plan." >&2
  exit 2
fi

exit 0
