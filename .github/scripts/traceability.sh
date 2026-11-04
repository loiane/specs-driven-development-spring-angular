#!/usr/bin/env bash
# traceability.sh
# Builds the AC-NNN -> tests + code matrix for a feature and writes
# .specs/<feature>/07a-traceability.md.
#
# Usage: .github/scripts/traceability.sh <feature-id>
#
# AC lines are read from 01-spec.md. The canonical format (docs/spec-format.md) is
#   - AC-001: When <trigger>, the system shall <action>.
# Legacy forms `- **AC-001** — …` and `### AC-001: <title>` are also accepted.
# Tests are linked via @Tag("AC-NNN") or @DisplayName("AC-NNN: …").
#
# Exit: 0 = every AC has at least one test, 1 = at least one AC has no tests,
#       2 = bad input (missing spec, no ACs found).

set -euo pipefail

FEATURE="${1:-}"
if [ -z "$FEATURE" ]; then
  echo "Usage: $0 <feature-id>" >&2
  exit 2
fi

SPEC=""
for candidate in .specs/"$FEATURE"/01-*.md; do
  if [ -f "$candidate" ]; then SPEC="$candidate"; break; fi
done
if [ -z "$SPEC" ] || [ ! -f "$SPEC" ]; then
  echo "ERROR: spec not found at .specs/$FEATURE/01-*.md" >&2
  exit 2
fi

OUT=".specs/$FEATURE/07a-traceability.md"

# Emit "AC-NNN|title" for each AC, first occurrence only.
extract_acs() {
  sed -nE \
    -e 's/^###[[:space:]]+(AC-[0-9]+)[[:space:]]*(:|\.|—|–|-)?[[:space:]]*(.*)$/\1|\3/p' \
    -e 's/^[-*][[:space:]]+(\*\*)?(AC-[0-9]+)(\*\*)?[[:space:]]*(:|\.|—|–|-)?[[:space:]]*(.*)$/\2|\5/p' \
    "$SPEC" | awk -F'|' '!seen[$1]++'
}

acs="$(extract_acs)"
if [ -z "$acs" ]; then
  echo "ERROR: no AC-NNN entries found in $SPEC (expected lines like '- AC-001: When …, the system shall …')" >&2
  exit 2
fi

shorten() {
  local s="${1//|/\\|}"
  if [ "${#s}" -gt 80 ]; then
    s="${s:0:77}..."
  fi
  printf '%s' "$s"
}

missing=0
{
  echo "# Traceability: $FEATURE"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "| AC | Title | Tests | Production code |"
  echo "|----|-------|-------|-----------------|"
  while IFS='|' read -r ac title; do
    [ -n "$ac" ] || continue
    test_files="$(grep -RIlE --include='*.java' \
      "@(Tag\(\"$ac\"\)|DisplayName\(\"${ac}[:\" ])" src/test 2>/dev/null || true)"
    tests=""
    code=""
    if [ -n "$test_files" ]; then
      tests="$(echo "$test_files" \
        | sed -E 's|^src/test/java/||; s|\.java$||; s|/|.|g' | tr '\n' ',' | sed 's/,$//')"
      # Best-effort: production classes referenced by those tests' imports.
      code="$(echo "$test_files" | tr '\n' '\0' | xargs -0 grep -h -E '^import [a-z]' 2>/dev/null \
        | grep -v -E '^import (java\.|org\.junit|org\.springframework\.test|org\.testcontainers|static )' \
        | sed -E 's/^import (.+);$/\1/' | sort -u | tr '\n' ',' | sed 's/,$//' || true)"
    else
      missing=$((missing+1))
    fi
    echo "| $ac | $(shorten "${title:-(no title)}") | ${tests:-_(none)_} | ${code:-_(unknown)_} |"
  done <<< "$acs"
  echo
  echo "## Notes"
  echo
  echo "- An AC with no tests is a hard validation failure."
  echo "- Production code column is heuristic (test imports). Verify manually for accuracy."
} > "$OUT"

echo "Wrote $OUT"
if [ "$missing" -gt 0 ]; then
  echo "FAIL: $missing AC(s) have no linked tests (@Tag(\"AC-NNN\") or @DisplayName(\"AC-NNN: …\"))." >&2
  exit 1
fi
