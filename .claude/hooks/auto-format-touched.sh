#!/usr/bin/env bash
# auto-format-touched.sh
# Claude PostToolUse Edit|Write hook.
# Runs Spotless against the touched file (if it's Java) so the harness format gate passes.
# Best effort — don't fail the agent's edit on a formatting error; surface it instead.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"
file_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
[ -z "$file_path" ] && exit 0

case "$file_path" in
  *.java) ;;
  *) exit 0 ;;
esac

# Only run if Maven and Spotless are configured.
if [ -f pom.xml ] && grep -q 'spotless-maven-plugin' pom.xml; then
  # Format-only on the single file. spotless:apply rewrites in place.
  mvn -q spotless:apply -DspotlessFiles="$file_path" >/dev/null 2>&1 || \
    echo "WARN: Spotless apply failed on $file_path (continuing)" >&2
fi

exit 0
