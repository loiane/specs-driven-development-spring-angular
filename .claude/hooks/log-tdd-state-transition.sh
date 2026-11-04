#!/usr/bin/env bash
# log-tdd-state-transition.sh
# Claude PostToolUse Edit|Write hook.
# When .tdd-state.json is touched OR an implementation log block is appended,
# write a one-line audit entry to .specs/<feature>/.tdd-audit.log so transitions
# are reviewable later.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -z "$file_path" ] && exit 0

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

case "$file_path" in
  *.specs/*/.tdd-state.json)
    feature_dir="$(dirname "$file_path")"
    audit="$feature_dir/.tdd-audit.log"
    active="$(jq -r '.active_task // "?"' "$file_path" 2>/dev/null || echo '?')"
    phase="$(jq -r --arg t "$active" '.tasks[$t].phase // "?"' "$file_path" 2>/dev/null || echo '?')"
    echo "$ts task=$active phase=$phase" >> "$audit"
    ;;
  *.specs/*/05-implementation-log.md)
    feature_dir="$(dirname "$file_path")"
    audit="$feature_dir/.tdd-audit.log"
    last_block="$(grep -E '^### T-' "$file_path" | tail -n 1 || true)"
    echo "$ts log_block=$last_block" >> "$audit"
    ;;
esac

exit 0
