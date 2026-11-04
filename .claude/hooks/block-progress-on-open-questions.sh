#!/usr/bin/env bash
# block-progress-on-open-questions.sh
# Claude PreToolUse Edit|Write hook.
# Refuses to create or edit a higher-numbered .specs artifact while a lower-numbered
# artifact has unresolved Q-NNN open questions.

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "BLOCKED: jq is required by .claude/hooks (install jq). Refusing to fail open." >&2
  exit 2
}
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -z "$file_path" ] && exit 0

# Only enforce on numbered .specs/<id>/NN-*.md artifacts.
case "$file_path" in
  *.specs/*/[0-9][0-9]*-*.md) ;;
  *) exit 0 ;;
esac

# Extract feature dir and target file's number prefix.
feature_dir="$(dirname "$file_path")"
target_basename="$(basename "$file_path")"
target_num="${target_basename%%-*}"  # "03"

# Find lower-numbered files in same feature dir.
shopt -s nullglob
for f in "$feature_dir"/[0-9][0-9]*-*.md; do
  base="$(basename "$f")"
  num="${base%%-*}"
  if [[ "$num" < "$target_num" ]]; then
    # Count unresolved Q-NNN entries under "## Open Questions" (until the next "## " header).
    # Canonical: "- Q-001: <question>"; legacy "- **Q-001** — …" and "### Q-001" also count.
    # An entry whose "Status:" sub-bullet says resolved/deferred does not block.
    open_count="$(awk '
      function flush() { if (in_q && !closed) count++; in_q=0; closed=0 }
      /^## Open Questions[[:space:]]*$/ { capture=1; next }
      /^## / { flush(); capture=0 }
      !capture { next }
      /^([-*][[:space:]]+(\*\*)?|###[[:space:]]+)Q-[0-9]+/ { flush(); in_q=1; next }
      in_q && tolower($0) ~ /status:[[:space:]]*(resolved|deferred)/ { closed=1 }
      END { flush(); print count+0 }
    ' "$f")"
    if [ "$open_count" -gt 0 ]; then
      echo "BLOCKED: $f has $open_count unresolved Q-NNN open question(s). Resolve them (move to ## Resolved Questions with 'Status: resolved YYYY-MM-DD — answer') or mark them 'Status: deferred — rationale' before editing $file_path." >&2
      exit 2
    fi
  fi
done

exit 0
