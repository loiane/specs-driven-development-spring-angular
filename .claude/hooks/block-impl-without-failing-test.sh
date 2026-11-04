#!/usr/bin/env bash
# block-impl-without-failing-test.sh
# Claude Code PreToolUse hook for Edit|Write.
# Refuses to edit production code -- Java under src/main/** and Angular sources
# (*.ts, *.html, *.scss, *.css under src/, except *.spec.ts) -- unless the active
# task in .specs/<active>/.tdd-state.json
# has a recorded failing test (red_at set, red_failure_excerpt non-empty), is in
# phase red|green|refactor|simplify, and lists the file in files_in_scope.
#
# Input: JSON on stdin (Claude Code hook protocol). We read tool_input.file_path.
# Output: exit 0 to allow, exit 2 + stderr message to block.

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "BLOCKED: jq is required by .claude/hooks (install jq). Refusing to fail open." >&2
  exit 2
}
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"

file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -z "$file_path" ] && exit 0

# Only enforce on production code. Test files are handled by enforce-files-in-scope.sh.
case "$file_path" in
  */node_modules/*|*/src/test/*|*.spec.ts|*.test.ts) exit 0 ;;
  src/main/*|*/src/main/*) ;;
  src/*.ts|*/src/*.ts|src/*.html|*/src/*.html|src/*.scss|*/src/*.scss|src/*.css|*/src/*.css) ;;
  *) exit 0 ;;
esac

# Find the active feature: the most recent .specs/<id>/.tdd-state.json by mtime.
# shellcheck disable=SC2012 # ls -t is needed to pick the most recently modified state file
state_file="$(ls -t .specs/*/.tdd-state.json 2>/dev/null | head -n 1 || true)"
if [ -z "$state_file" ] || [ ! -f "$state_file" ]; then
  echo "BLOCKED: no .specs/<feature>/.tdd-state.json found. Run /build <task-id> so the test-engineer writes the failing test first." >&2
  exit 2
fi

active_task="$(jq -r '.active_task // empty' "$state_file")"
if [ -z "$active_task" ]; then
  echo "BLOCKED: no active_task in $state_file. Run /build <task-id>." >&2
  exit 2
fi

phase="$(jq -r --arg t "$active_task" '.tasks[$t].phase // empty' "$state_file")"
red_excerpt="$(jq -r --arg t "$active_task" '.tasks[$t].red_failure_excerpt // empty' "$state_file")"
red_at="$(jq -r --arg t "$active_task" '.tasks[$t].red_at // empty' "$state_file")"

if [ "$phase" != "red" ] && [ "$phase" != "green" ] && [ "$phase" != "refactor" ] && [ "$phase" != "simplify" ]; then
  echo "BLOCKED: task $active_task phase is '$phase'. Cannot edit production code without a failing test (phase=red)." >&2
  exit 2
fi

if [ -z "$red_at" ] || [ -z "$red_excerpt" ]; then
  echo "BLOCKED: task $active_task has no recorded failing test (red_at and red_failure_excerpt must both be set). Run the failing test first and record it in .tdd-state.json." >&2
  exit 2
fi

# Files in scope check
in_scope="$(jq -r --arg t "$active_task" --arg f "$file_path" '
  .tasks[$t].files_in_scope // []
  | map(select(. as $s | $s != "" and ($f == $s or ($f | endswith("/" + $s)))))
  | length
' "$state_file")"

if [ "$in_scope" = "0" ]; then
  echo "BLOCKED: $file_path is not in task $active_task files_in_scope. Edit only the declared paths, or update the task entry first (and re-run /plan)." >&2
  exit 2
fi

exit 0
