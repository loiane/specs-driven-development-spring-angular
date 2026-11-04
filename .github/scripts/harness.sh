#!/usr/bin/env bash
# harness.sh
# The agent's self-validation harness. Runs the 10 layers and emits a single
# JSON summary consumed by spring-validator.
#
# Usage:
#   ./scripts/harness.sh                  # run; print human summary; exit non-zero on failure
#   ./scripts/harness.sh --report         # run; emit harness-summary.json to stdout
#   ./scripts/harness.sh --baseline       # run in capture mode for brownfield onboarding

set -euo pipefail

# Resolve the script's own directory BEFORE any cd, so --module works regardless
# of relative invocation path.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional first arg: --module <path> to cd into a Maven module (multi-project repos).
if [ "${1:-}" = "--module" ]; then
  shift
  MODULE_DIR="${1:-}"
  shift || true
  [ -d "$MODULE_DIR" ] || { echo "harness: module dir not found: $MODULE_DIR" >&2; exit 2; }
  cd "$MODULE_DIR"
fi

MODE="${1:-run}"
SUMMARY="target/harness-summary.json"
mkdir -p target

# Helper: timestamped section
section() { echo "=== $* ==="; }

# Detect stack so we know which layers to enforce.
STACK_JSON="$("$SCRIPT_DIR/detect-stack.sh" pom.xml 2>/dev/null || echo '{}')"

has_layer() {
  echo "$STACK_JSON" | jq -r ".harness_layers.$1 // false"
}

# 1-9 sequential layers via Maven verify; PIT separately under -Ppit.
section "format + compile + static + arch + unit + it + coverage + security"
mvn -B -ntp verify

if [ "$(has_layer pit)" = "true" ]; then
  section "mutation (incremental)"
  PIT_RC=0
  mvn -B -ntp -Ppit org.pitest:pitest-maven:mutationCoverage || PIT_RC=$?
  [ "$PIT_RC" -eq 0 ] || echo "WARN: PIT exited with code $PIT_RC; see the mutation gate in the summary." >&2
fi

# Contract diff if openapi spec is present.
if [ -f src/main/resources/openapi/openapi.yaml ]; then
  section "openapi contract diff"
  prev="$(git show "origin/main:src/main/resources/openapi/openapi.yaml" 2>/dev/null || true)"
  if [ -n "$prev" ]; then
    echo "$prev" > target/openapi-base.yaml
    if command -v openapi-diff >/dev/null 2>&1; then
      openapi-diff target/openapi-base.yaml src/main/resources/openapi/openapi.yaml --json > target/openapi-diff.json || true
    else
      echo "WARN: openapi-diff CLI not installed; skipping (run: npm i -g @apidevtools/swagger-cli or use openapitools/openapi-diff docker image)" >&2
    fi
  fi
fi

# Build the summary JSON. Best-effort parse — layers without reports just emit "skipped".
parse_surefire() {
  local dir="$1"
  [ -d "$dir" ] || { echo '{"status":"skipped"}'; return; }
  local total=0 fail=0 err=0 skip=0
  while IFS= read -r f; do
    t=$(grep -oE 'tests="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    fa=$(grep -oE 'failures="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    er=$(grep -oE 'errors="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    sk=$(grep -oE 'skipped="[0-9]+"' "$f" | head -n1 | grep -oE '[0-9]+' || echo 0)
    total=$((total+t)); fail=$((fail+fa)); err=$((err+er)); skip=$((skip+sk))
  done < <(find "$dir" -name 'TEST-*.xml')
  local status="pass"
  [ "$fail" -gt 0 ] || [ "$err" -gt 0 ] && status="fail"
  printf '{"status":"%s","tests":%d,"failures":%d,"errors":%d,"skipped":%d}' "$status" "$total" "$fail" "$err" "$skip"
}

parse_jacoco() {
  local f="target/site/jacoco/jacoco.xml"
  [ -f "$f" ] || { echo '{"status":"skipped"}'; return; }
  # Use python3 to parse XML properly — JaCoCo 0.8.x can write the entire
  # report on a single line, which breaks chained grep pipelines.
  local result
  result=$(python3 - "$f" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
root = tree.getroot()
# The last <counter type="LINE|BRANCH"> in document order is the report total.
line_c = [(int(c.get('missed','0')), int(c.get('covered','0')))
          for c in root.iter('counter') if c.get('type')=='LINE']
branch_c = [(int(c.get('missed','0')), int(c.get('covered','0')))
            for c in root.iter('counter') if c.get('type')=='BRANCH']
lm, lc = line_c[-1] if line_c else (0, 0)
bm, bc = branch_c[-1] if branch_c else (0, 0)
lt = lm + lc; bt = bm + bc
lr = lc / lt if lt > 0 else 0.0
br = bc / bt if bt > 0 else 0.0
status = "fail" if lr < 0.90 or br < 0.90 else "pass"
print('{"status":"' + status + '","line":' + f'{lr:.4f}' + ',"branch":' + f'{br:.4f}' + '}')
PYEOF
  )
  echo "$result"
}

parse_pit() {
  local f="target/pit-reports/mutations.xml"
  [ -f "$f" ] || { echo '{"status":"skipped"}'; return; }
  local result
  result=$(python3 - "$f" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
root = tree.getroot()
total = 0; killed = 0; survived = 0; no_cov = 0; timed_out = 0
for m in root.iter('mutation'):
    total += 1
    s = m.get('status', '')
    if s == 'KILLED':   killed += 1
    elif s == 'SURVIVED': survived += 1
    elif s == 'NO_COVERAGE': no_cov += 1
    elif s == 'TIMED_OUT': timed_out += 1
detected = killed + timed_out
kr = detected / total if total > 0 else 0.0
threshold = 0.75
status = "pass" if kr >= threshold else "fail"
print('{"status":"' + status + '","kill_rate":' + f'{kr:.4f}' + ',"killed":' + str(detected) + ',"survived":' + str(survived) + ',"no_coverage":' + str(no_cov) + ',"total":' + str(total) + '}')
PYEOF
  )
  echo "$result"
}

unit=$(parse_surefire target/surefire-reports)
it=$(parse_surefire target/failsafe-reports)
cov=$(parse_jacoco)
pit=$(parse_pit)

cat > "$SUMMARY" <<EOF
{
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "git_sha": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')",
  "stack": $STACK_JSON,
  "gates": {
    "unit":     $unit,
    "it":       $it,
    "coverage": $cov,
    "mutation": $pit
  }
}
EOF

if [ "$MODE" = "--report" ]; then
  cat "$SUMMARY"
elif [ "$MODE" = "--baseline" ]; then
  jq '{captured_at: .started_at, git_sha, stack, gates}' "$SUMMARY" > .specs/_baseline.json
  echo "Wrote .specs/_baseline.json"
else
  echo
  jq '.gates' "$SUMMARY"
fi
