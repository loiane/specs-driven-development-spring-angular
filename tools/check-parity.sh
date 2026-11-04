#!/usr/bin/env bash
# check-parity.sh
# Verifies that the per-platform copies of shared assets stay in lockstep:
#   skills/, templates/, checklists/, maven/ under .claude, .github and .windsurf.
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

if [ "$drift" -ne 0 ]; then
  echo
  echo "Platform copies have drifted. Apply the change to all three of: ${PLATFORMS[*]}."
  exit 1
fi

echo "Parity OK: ${SHARED_DIRS[*]} match across ${PLATFORMS[*]}."
