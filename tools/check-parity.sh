#!/usr/bin/env bash
# check-parity.sh
# Verifies that the per-platform copies of shared assets stay in lockstep:
#   skills/, templates/, checklists/, maven/ under .claude, .github and .windsurf.
# Also checks that every agent, slash command and guardrail exists on each platform:
#   agents:     .claude/agents/X.md   .github/agents/X.agent.md            .windsurf/workflows/X.md
#   commands:   .claude/commands/X.md .github/prompts/X.prompt.md          .windsurf/workflows/X.md
#   guardrails: .github/instructions/X.instructions.md                    .windsurf/rules/X.md
#
# Legitimate per-platform differences are normalised before comparing:
#   - platform directory prefixes (.claude/ .github/ .windsurf/)
#   - slash-command file paths (commands/X.md, prompts/X.prompt.md, workflows/X.md)
#
# Usage: tools/check-parity.sh            # exit 0 = in sync, 1 = drift found
# Toolkit-maintenance script: not needed in consumer projects.

set -euo pipefail

cd "$(dirname "$0")/.."

PLATFORMS=(.claude .github .windsurf)
SHARED_DIRS=(skills templates checklists maven)
REFERENCE=.claude

normalise() {
  sed -E \
    -e 's#\.(claude|github|windsurf)/#<platform>/#g' \
    -e 's#<platform>/(commands|workflows)/([A-Za-z0-9-]+)\.md#<command:\2>#g' \
    -e 's#<platform>/prompts/([A-Za-z0-9-]+)\.prompt\.md#<command:\1>#g' \
    "$1"
}

list_files() {
  (cd "$1" && find . -type f ! -name '.DS_Store' | sort)
}

drift=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for dir in "${SHARED_DIRS[@]}"; do
  for platform in "${PLATFORMS[@]}"; do
    [ "$platform" = "$REFERENCE" ] && continue
    ref_root="$REFERENCE/$dir"
    other_root="$platform/$dir"

    if ! diff <(list_files "$ref_root") <(list_files "$other_root") > "$tmp/files.diff"; then
      echo "DRIFT: file set differs between $ref_root and $other_root"
      sed 's/^/    /' "$tmp/files.diff"
      drift=1
    fi

    while IFS= read -r rel; do
      [ -f "$other_root/$rel" ] || continue
      if ! diff -u --label "$ref_root/${rel#./}" --label "$other_root/${rel#./}" \
        <(normalise "$ref_root/$rel") <(normalise "$other_root/$rel") > "$tmp/content.diff"; then
        echo "DRIFT: $other_root/${rel#./} differs from $ref_root/${rel#./}"
        sed 's/^/    /' "$tmp/content.diff"
        drift=1
      fi
    done < <(list_files "$ref_root")
  done
done

# names <dir> <suffix> — basenames of <dir>/*<suffix> with the suffix stripped.
names() {
  local f
  for f in "$1"/*"$2"; do
    [ -e "$f" ] && basename "$f" "$2"
  done | sort
}

# same_names <label> <list-a-label> <list-a> <list-b-label> <list-b>
same_names() {
  if ! diff <(printf '%s\n' "$3") <(printf '%s\n' "$5") > "$tmp/names.diff"; then
    echo "DRIFT: $1 differ between $2 (<) and $4 (>)"
    sed 's/^/    /' "$tmp/names.diff"
    drift=1
  fi
}

agents="$(names .claude/agents .md)"
commands="$(names .claude/commands .md)"
same_names "agents" ".claude/agents" "$agents" ".github/agents" "$(names .github/agents .agent.md)"
same_names "commands" ".claude/commands" "$commands" ".github/prompts" "$(names .github/prompts .prompt.md)"
same_names "agents + commands" ".claude/{agents,commands}" "$(printf '%s\n%s\n' "$agents" "$commands" | sort)" \
  ".windsurf/workflows" "$(names .windsurf/workflows .md)"
same_names "guardrails" ".github/instructions" "$(names .github/instructions .instructions.md)" \
  ".windsurf/rules" "$(names .windsurf/rules .md)"

if [ "$drift" -ne 0 ]; then
  echo
  echo "Platform copies have drifted. Apply the change to all three of: ${PLATFORMS[*]}."
  exit 1
fi

echo "Parity OK: ${SHARED_DIRS[*]}, agents, commands and guardrails match across ${PLATFORMS[*]}."
