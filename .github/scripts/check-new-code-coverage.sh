#!/usr/bin/env bash
# check-new-code-coverage.sh
# Computes line coverage on the Java lines added or changed since the merge base
# with BASE_REF (default origin/main), including uncommitted and untracked files,
# and fails if the ratio is below NEW_CODE_THRESHOLD (default 0.95).
# Only executable lines (lines JaCoCo reports on) count; comments, blank lines
# and imports are ignored.
#
# Run from the Maven module directory (the one containing target/).
# Inputs:
#   target/site/jacoco/jacoco.xml
#   git diff against $(git merge-base "${BASE_REF:-origin/main}" HEAD)
# Output:
#   target/new-code-coverage.json (also printed to stdout)
# Exit:
#   0 = pass, 1 = below threshold, 2 = missing inputs or prerequisites
#
# Requires: bash 3.2+, git, python3.

set -euo pipefail

THRESHOLD="${NEW_CODE_THRESHOLD:-0.95}"
BASE_REF="${BASE_REF:-origin/main}"
JACOCO_XML="target/site/jacoco/jacoco.xml"
OUT="target/new-code-coverage.json"

command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required but not on PATH." >&2; exit 2; }

if [ ! -f "$JACOCO_XML" ]; then
  echo "ERROR: $JACOCO_XML not found. Run mvn verify first." >&2
  exit 2
fi

if ! BASE="$(git merge-base "$BASE_REF" HEAD 2>/dev/null)"; then
  echo "ERROR: cannot find a merge base with '$BASE_REF'. Fetch it or set BASE_REF." >&2
  exit 2
fi

# One "<path relative to cwd>:<line>" per added or changed line.
changed_lines() {
  local f
  git diff --relative --name-only --diff-filter=AMR "$BASE" -- 'src/main/java/*.java' |
    while IFS= read -r f; do
      git diff --relative -U0 "$BASE" -- "$f" | awk -v file="$f" '
        /^@@/ {
          split($3, rhs, ",")          # $3 is "+start[,count]"
          start = substr(rhs[1], 2) + 0
          count = (rhs[2] == "" ? 1 : rhs[2] + 0)
          for (i = 0; i < count; i++) print file ":" (start + i)
        }'
    done
  # Untracked files are entirely new code.
  git ls-files --others --exclude-standard -- 'src/main/java/*.java' |
    while IFS= read -r f; do
      awk -v file="$f" '{ print file ":" NR }' "$f"
    done
}

mkdir -p target
changed_lines | python3 -c '
import json, sys, xml.etree.ElementTree as ET

jacoco, threshold, base_ref, out = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4]

# (package/path/File.java) -> {line number: covered?} for executable lines only.
lines = {}
for pkg in ET.parse(jacoco).getroot().iter("package"):
    for src in pkg.findall("sourcefile"):
        key = pkg.get("name") + "/" + src.get("name")
        lines[key] = {int(l.get("nr")): int(l.get("ci", "0")) > 0 for l in src.findall("line")}

total = covered = 0
for entry in sys.stdin:
    path, _, nr = entry.strip().rpartition(":")
    rel = path.split("src/main/java/", 1)[-1]
    hit = lines.get(rel, {}).get(int(nr))
    if hit is None:
        continue  # not an executable line
    total += 1
    covered += hit

ratio = covered / total if total else 1.0
result = {
    "status": "pass" if ratio >= threshold else "fail",
    "ratio": round(ratio, 4),
    "covered_new_lines": covered,
    "total_new_lines": total,
    "threshold": threshold,
    "base_ref": base_ref,
}
if total == 0:
    result["reason"] = "no new executable lines in src/main/java"
with open(out, "w") as f:
    json.dump(result, f, indent=2)
    f.write("\n")
print(json.dumps(result, indent=2))
sys.exit(0 if result["status"] == "pass" else 1)
' "$JACOCO_XML" "$THRESHOLD" "$BASE_REF" "$OUT"
