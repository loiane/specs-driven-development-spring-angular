#!/usr/bin/env bash
# forbid-skip-flags.sh
# Claude PreToolUse Bash hook.
# Blocks any shell command that uses build-skipping or verification-bypass flags.

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "BLOCKED: jq is required by .claude/hooks (install jq). Refusing to fail open." >&2
  exit 2
}
cd "${CLAUDE_PROJECT_DIR:-.}"

input="$(cat)"
cmd="$(echo "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

# Pattern -> reason
declare -a patterns=(
  '-DskipTests'           'Refusing to run with -DskipTests; tests are mandatory.'
  '-DskipITs'             'Refusing to run with -DskipITs; integration tests are mandatory when present.'
  '-Dpit\.skip'           'Refusing to skip mutation testing.'
  '-Dcheckstyle\.skip'    'Refusing to skip Checkstyle.'
  '-Dspotbugs\.skip'      'Refusing to skip SpotBugs.'
  '-Dspotless\.check\.skip' 'Refusing to skip Spotless.'
  '-Djacoco\.skip'        'Refusing to skip JaCoCo.'
  '--no-verify'           'Refusing to bypass git/maven verification hooks.'
  '-Dmaven\.test\.skip'   'Refusing to skip the test phase entirely.'
  'maven\.test\.failure\.ignore=true' 'Refusing to ignore test failures.'
)

i=0
while [ $i -lt ${#patterns[@]} ]; do
  pat="${patterns[$i]}"
  reason="${patterns[$((i+1))]}"
  if echo "$cmd" | grep -Eq -- "$pat"; then
    echo "BLOCKED: $reason  (matched pattern: $pat)" >&2
    echo "Command: $cmd" >&2
    exit 2
  fi
  i=$((i+2))
done

# Also block destructive git ops without explicit user instruction.
if echo "$cmd" | grep -Eq '\bgit\s+(commit|push|reset\s+--hard|clean\s+-fd)'; then
  echo "BLOCKED: This toolkit never auto-commits, pushes, or destructively cleans. Ask the user to run this themselves." >&2
  exit 2
fi

exit 0
