#!/usr/bin/env bash
# harness.sh
# The agent's self-validation harness. Runs the Maven build (format, compile,
# static analysis, architecture, unit, integration, coverage, security), the
# optional PIT mutation layer and the OpenAPI diff, then writes a JSON summary
# to target/harness-summary.json for spring-validator.
#
# Usage:
#   .github/scripts/harness.sh [--module <dir>]               # human summary
#   .github/scripts/harness.sh [--module <dir>] --report      # summary JSON on stdout
#   .github/scripts/harness.sh [--module <dir>] --baseline    # baseline JSON on stdout,
#                                                             # also written to .specs/_baseline.json
# In --report and --baseline modes all build output goes to stderr, so stdout
# can be redirected to a file.
#
# Exit:
#   0 = every gate passed or was skipped (always 0 in --baseline mode)
#   1 = at least one gate failed (including a failing `mvn verify`)
#   2 = usage error or missing prerequisite (jq, python3, mvn)
#
# Requires: bash 3.2+, git, jq, python3, mvn.

set -euo pipefail

# Resolve paths BEFORE any cd, so --module works regardless of invocation path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVOKE_DIR="$(pwd)"

if [ "${1:-}" = "--module" ]; then
  shift
  MODULE_DIR="${1:-}"
  shift || true
  [ -d "$MODULE_DIR" ] || { echo "harness: module dir not found: $MODULE_DIR" >&2; exit 2; }
  cd "$MODULE_DIR"
fi

MODE="${1:-run}"
case "$MODE" in
  run|--report|--baseline) ;;
  *) echo "harness: unknown option: $MODE (expected --report or --baseline)" >&2; exit 2 ;;
esac

for tool in jq python3 mvn; do
  command -v "$tool" >/dev/null 2>&1 || { echo "harness: '$tool' is required but not on PATH" >&2; exit 2; }
done

# fd 3 carries the result; in machine-readable modes everything else goes to stderr.
if [ "$MODE" = "run" ]; then
  exec 3>&1
else
  exec 3>&1 1>&2
fi

SUMMARY="target/harness-summary.json"
mkdir -p target
STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

section() { echo "=== $* ==="; }

STACK_JSON="$("$SCRIPT_DIR/detect-stack.sh" pom.xml 2>/dev/null || echo '{}')"

has_layer() {
  echo "$STACK_JSON" | jq -r ".harness_layers.$1 // false"
}

# Layers 1-9 run inside `mvn verify`. A failure must not abort the script:
# the summary is still written so the validator can explain what broke.
section "format + compile + static + arch + unit + it + coverage + security"
VERIFY_RC=0
mvn -B -ntp verify || VERIFY_RC=$?

PIT_RC=""
if [ "$(has_layer pit)" = "true" ]; then
  if [ "$VERIFY_RC" -eq 0 ]; then
    section "mutation (incremental)"
    PIT_RC=0
    mvn -B -ntp -Ppit org.pitest:pitest-maven:mutationCoverage || PIT_RC=$?
  else
    echo "Skipping mutation testing: mvn verify failed (rc=$VERIFY_RC)."
  fi
fi

if [ -f src/main/resources/openapi/openapi.yaml ]; then
  section "openapi contract diff"
  prev="$(git show "origin/main:./src/main/resources/openapi/openapi.yaml" 2>/dev/null || true)"
  if [ -n "$prev" ]; then
    printf '%s\n' "$prev" > target/openapi-base.yaml
    if command -v openapi-diff >/dev/null 2>&1; then
      openapi-diff target/openapi-base.yaml src/main/resources/openapi/openapi.yaml --json > target/openapi-diff.json || true
    else
      echo "WARN: openapi-diff CLI not installed; skipping (use the openapitools/openapi-diff docker image)" >&2
    fi
  fi
fi

# Layers without reports are reported as "skipped".
parse_surefire() {
  local dir="$1"
  [ -d "$dir" ] || { echo '{"status":"skipped"}'; return; }
  local total=0 fail=0 err=0 skip=0 t fa er sk f
  while IFS= read -r f; do
    t=$(grep -oE 'tests="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    fa=$(grep -oE 'failures="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    er=$(grep -oE 'errors="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    sk=$(grep -oE 'skipped="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    total=$((total+t)); fail=$((fail+fa)); err=$((err+er)); skip=$((skip+sk))
  done < <(find "$dir" -name 'TEST-*.xml')
  local status="pass"
  if [ "$fail" -gt 0 ] || [ "$err" -gt 0 ]; then status="fail"; fi
  printf '{"status":"%s","tests":%d,"failures":%d,"errors":%d,"skipped":%d}' "$status" "$total" "$fail" "$err" "$skip"
}

# python3 parses the XML because JaCoCo can write the whole report on one line.
parse_jacoco() {
  local f="target/site/jacoco/jacoco.xml"
  [ -f "$f" ] || { echo '{"status":"skipped"}'; return; }
  python3 - "$f" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
# Report totals are the <counter> elements directly under <report>.
totals = {c.get('type'): (int(c.get('missed', '0')), int(c.get('covered', '0')))
          for c in root.findall('counter')}
lm, lc = totals.get('LINE', (0, 0))
bm, bc = totals.get('BRANCH', (0, 0))
lr = lc / (lm + lc) if lm + lc > 0 else 0.0
br = bc / (bm + bc) if bm + bc > 0 else 1.0  # no branches means nothing to miss
status = "fail" if lr < 0.90 or br < 0.90 else "pass"
print('{"status":"%s","line":%.4f,"branch":%.4f}' % (status, lr, br))
PYEOF
}

parse_pit() {
  local f="target/pit-reports/mutations.xml"
  if [ -z "$PIT_RC" ]; then echo '{"status":"skipped"}'; return; fi
  if [ ! -f "$f" ]; then
    printf '{"status":"fail","exit_code":%d,"reason":"no mutations.xml"}' "$PIT_RC"
    return
  fi
  python3 - "$f" "$PIT_RC" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
statuses = [m.get('status', '') for m in root.iter('mutation')]
total = len(statuses)
detected = statuses.count('KILLED') + statuses.count('TIMED_OUT')
kr = detected / total if total > 0 else 0.0
status = "pass" if kr >= 0.75 and sys.argv[2] == "0" else "fail"
print('{"status":"%s","exit_code":%s,"kill_rate":%.4f,"killed":%d,"survived":%d,"no_coverage":%d,"total":%d}'
      % (status, sys.argv[2], kr, detected, statuses.count('SURVIVED'), statuses.count('NO_COVERAGE'), total))
PYEOF
}

build_status="pass"
[ "$VERIFY_RC" -eq 0 ] || build_status="fail"
build=$(printf '{"status":"%s","exit_code":%d}' "$build_status" "$VERIFY_RC")
unit=$(parse_surefire target/surefire-reports)
it=$(parse_surefire target/failsafe-reports)
cov=$(parse_jacoco)
pit=$(parse_pit)

summary_json="$(jq -n \
  --arg started "$STARTED_AT" \
  --arg finished "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg sha "$(git rev-parse --short HEAD 2>/dev/null || echo unknown)" \
  --argjson stack "$STACK_JSON" \
  --argjson build "$build" --argjson unit "$unit" --argjson it "$it" \
  --argjson coverage "$cov" --argjson mutation "$pit" '
  {started_at: $started, finished_at: $finished, git_sha: $sha, stack: $stack,
   gates: {build: $build, unit: $unit, it: $it, coverage: $coverage, mutation: $mutation}}
  | .overall = (if any(.gates[]; .status == "fail") then "fail" else "pass" end)')"
printf '%s\n' "$summary_json" > "$SUMMARY"

overall="$(printf '%s' "$summary_json" | jq -r '.overall')"

case "$MODE" in
  --report)
    printf '%s\n' "$summary_json" >&3
    ;;
  --baseline)
    # Baselines live at the repo root even when --module was used.
    baseline_dir="$(cd "$INVOKE_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "$INVOKE_DIR")/.specs"
    mkdir -p "$baseline_dir"
    baseline_json="$(printf '%s' "$summary_json" | jq '{captured_at: .started_at, git_sha, stack, gates, overall}')"
    printf '%s\n' "$baseline_json" > "$baseline_dir/_baseline.json"
    printf '%s\n' "$baseline_json" >&3
    echo "Wrote $baseline_dir/_baseline.json"
    exit 0
    ;;
  *)
    echo
    printf '%s' "$summary_json" | jq '{overall, gates}'
    ;;
esac

[ "$overall" = "pass" ] || exit 1
