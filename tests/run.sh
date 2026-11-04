#!/usr/bin/env bash
# run.sh — regression tests for the toolkit's hooks and scripts.
# Plain bash (3.2+) with jq; no test framework required.
#
# Usage: tests/run.sh
# Toolkit-maintenance script: not needed in consumer projects.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/.claude/hooks"
SCRIPTS="$ROOT/.github/scripts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

passed=0
detail=""
failed=0

pass() { passed=$((passed+1)); echo "  ok   $1"; }
fail() {
  failed=$((failed+1))
  echo "  FAIL $1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | sed 's/^/         /'; fi
}

# check <name> <command...> — passes when the command succeeds.
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name" "${detail:-}"; fi
}

# expect_rc <name> <expected-rc> <actual-rc> [output]
expect_rc() {
  if [ "$3" -eq "$2" ]; then pass "$1"; else fail "$1 (expected rc=$2, got rc=$3)" "${4:-}"; fi
}

# run_hook <hook> <json> — runs a hook from inside $PROJECT; sets $rc and $out.
run_hook() {
  out="$(cd "$PROJECT" && echo "$2" | CLAUDE_PROJECT_DIR="$PROJECT" "$BASH" "$HOOKS/$1" 2>&1)"
  rc=$?
}

new_project() {
  PROJECT="$WORK/$1"
  mkdir -p "$PROJECT"
}

edit_json() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }
bash_json() { jq -cn --arg c "$1" '{tool_input:{command:$c}}'; }

echo "forbid-skip-flags.sh"
new_project skip
for cmd in "mvn verify -DskipTests" "mvn verify -DskipITs" "mvn -Dmaven.test.skip=true package" \
           "mvn verify -Dpit.skip" "mvn verify -Dcheckstyle.skip" "mvn verify -Djacoco.skip" \
           "git commit --no-verify -m x" "git commit -m x" "git push origin main"; do
  run_hook forbid-skip-flags.sh "$(bash_json "$cmd")"
  expect_rc "blocks: $cmd" 2 "$rc" "$out"
done
for cmd in "mvn verify" "mvn -q test -Dtest=FooTest" "git status"; do
  run_hook forbid-skip-flags.sh "$(bash_json "$cmd")"
  expect_rc "allows: $cmd" 0 "$rc" "$out"
done

echo "missing jq fails closed"
nojq="$WORK/nojq-bin"
mkdir -p "$nojq"
ln -s "$(command -v cat)" "$nojq/cat"
for hook in forbid-skip-flags.sh block-impl-without-failing-test.sh enforce-files-in-scope.sh block-progress-on-open-questions.sh; do
  out="$(echo '{}' | PATH="$nojq" "$BASH" "$HOOKS/$hook" 2>&1)"; rc=$?
  expect_rc "$hook blocks without jq" 2 "$rc" "$out"
done
for hook in auto-format-touched.sh log-tdd-state-transition.sh route-natural-language-aliases.sh; do
  out="$(echo '{}' | PATH="$nojq" "$BASH" "$HOOKS/$hook" 2>&1)"; rc=$?
  expect_rc "$hook skips without jq" 0 "$rc" "$out"
done

echo "block-progress-on-open-questions.sh"
new_project questions
mkdir -p "$PROJECT/.specs/f"
target="$PROJECT/.specs/f/02-spec-review.md"
check_questions() {
  printf '%b' "$2" > "$PROJECT/.specs/f/01-spec.md"
  run_hook block-progress-on-open-questions.sh "$(edit_json "$target")"
  expect_rc "$1" "$3" "$rc" "$out"
}
check_questions "blocks on open '- Q-001:'" '## Open Questions\n\n- Q-001: x?\n  - Status: open\n' 2
check_questions "blocks on legacy '- **Q-001** —'" '## Open Questions\n\n- **Q-001** — x?\n' 2
check_questions "blocks on '### Q-001'" '## Open Questions\n\n### Q-001: x?\n' 2
check_questions "allows deferred question" '## Open Questions\n\n- Q-001: x?\n  - Status: deferred — later\n' 0
check_questions "allows resolved questions section" '## Open Questions\n\n*(none)*\n\n## Resolved Questions\n\n- Q-001: x?\n  - Status: resolved 2026-01-01 — y\n' 0
run_hook block-progress-on-open-questions.sh "$(edit_json "$PROJECT/src/main/java/A.java")"
expect_rc "ignores non-spec files" 0 "$rc" "$out"

echo "block-impl-without-failing-test.sh / enforce-files-in-scope.sh"
new_project tdd
mkdir -p "$PROJECT/.specs/f"
main_file="$PROJECT/src/main/java/com/x/Foo.java"
test_file="$PROJECT/src/test/java/com/x/FooTest.java"
write_state() {
  jq -n --arg phase "$1" --arg excerpt "$2" '{
    feature_id: "f", active_task: "T-001",
    tasks: { "T-001": { phase: $phase, red_at: "2026-01-01T00:00:00Z", red_failure_excerpt: $excerpt,
      files_in_scope: ["src/main/java/com/x/Foo.java", "src/test/java/com/x/FooTest.java"] } } }' \
    > "$PROJECT/.specs/f/.tdd-state.json"
}
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "blocks src/main edit without .tdd-state.json" 2 "$rc" "$out"
write_state red "AssertionFailedError"
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "allows in-scope src/main edit in red with excerpt" 0 "$rc" "$out"
run_hook block-impl-without-failing-test.sh "$(edit_json "$PROJECT/src/main/java/com/x/Bar.java")"
expect_rc "blocks out-of-scope src/main edit" 2 "$rc" "$out"
run_hook block-impl-without-failing-test.sh "$(edit_json "$PROJECT/src/main/java/com/y/Foo.java")"
expect_rc "blocks same file name in a different package" 2 "$rc" "$out"
write_state red ""
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "blocks red phase with empty excerpt" 2 "$rc" "$out"
write_state "done" "AssertionFailedError"
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "blocks when task is done" 2 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$test_file")"
expect_rc "allows in-scope test edit" 0 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$PROJECT/src/test/java/com/x/OtherTest.java")"
expect_rc "blocks out-of-scope test edit" 2 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$PROJECT/.specs/f/04-tasks.md")"
expect_rc "allows .specs edits" 0 "$rc" "$out"

echo "route-natural-language-aliases.sh"
new_project alias
run_hook route-natural-language-aliases.sh '{"prompt":"Please review the spec"}'
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("/spec-review")' >/dev/null; then
  pass "routes 'review the spec' to /spec-review"
else
  fail "routes 'review the spec' to /spec-review" "$out"
fi

echo "traceability.sh"
new_project trace
mkdir -p "$PROJECT/.specs/f" "$PROJECT/src/test/java/a"
cat > "$PROJECT/.specs/f/01-spec.md" <<'SPEC'
## Acceptance Criteria

- AC-001: When x, the system shall y | z.
- **AC-002** — While s, the system shall t.
### AC-003: Heading form
SPEC
cat > "$PROJECT/src/test/java/a/FooTest.java" <<'JAVA'
package a;
import com.x.Foo;
class FooTest {
  @Tag("AC-001") void t() {}
  @DisplayName("AC-003: heading form") void u() {}
}
JAVA
out="$(cd "$PROJECT" && "$BASH" "$SCRIPTS/traceability.sh" f 2>&1)"; rc=$?
expect_rc "fails when an AC has no tests" 1 "$rc" "$out"
matrix="$PROJECT/.specs/f/07a-traceability.md"
detail="$(cat "$matrix")"
check "links @Tag and escapes '|' in titles" \
  grep -q '^| AC-001 | When x, the system shall y \\| z. | a.FooTest | com.x.Foo |$' "$matrix"
check "parses legacy bold bullet" grep -q '^| AC-002 | While s, the system shall t. | _(none)_ |' "$matrix"
check "parses heading form and links @DisplayName" grep -q '^| AC-003 | Heading form | a.FooTest |' "$matrix"
detail=""
sed -i.bak '/AC-002/d' "$PROJECT/.specs/f/01-spec.md"
out="$(cd "$PROJECT" && "$BASH" "$SCRIPTS/traceability.sh" f 2>&1)"; rc=$?
expect_rc "passes when every AC has a test" 0 "$rc" "$out"
printf '## Acceptance Criteria\n\nnone yet\n' > "$PROJECT/.specs/f/01-spec.md"
out="$(cd "$PROJECT" && "$BASH" "$SCRIPTS/traceability.sh" f 2>&1)"; rc=$?
expect_rc "errors when no ACs are found" 2 "$rc" "$out"

echo "detect-stack.sh"
new_project stack
printf '<project><artifactId>x</artifactId></project>' > "$PROJECT/pom.xml"
out="$(cd "$PROJECT" && "$BASH" "$SCRIPTS/detect-stack.sh" pom.xml 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | jq -e '.db_engines == []' >/dev/null 2>&1; then
  pass "emits valid JSON with empty db_engines"
else
  fail "emits valid JSON with empty db_engines" "$out"
fi
printf '<project><artifactId>postgresql</artifactId><artifactId>flyway-core</artifactId></project>' > "$PROJECT/pom.xml"
out="$(cd "$PROJECT" && "$BASH" "$SCRIPTS/detect-stack.sh" pom.xml 2>&1)"
if echo "$out" | jq -e '.db_engines == ["postgresql"] and .migration == "flyway"' >/dev/null 2>&1; then
  pass "detects postgresql + flyway"
else
  fail "detects postgresql + flyway" "$out"
fi

echo ".claude/settings.json"
# shellcheck disable=SC2016 # literal $CLAUDE_PROJECT_DIR prefix in settings.json
missing_hooks="$(jq -r '.hooks[][].hooks[].command' "$ROOT/.claude/settings.json" \
  | sed -E 's#^"\$CLAUDE_PROJECT_DIR"/##' \
  | while read -r hook; do [ -x "$ROOT/$hook" ] || echo "$hook"; done)"
detail="$missing_hooks"
check "every registered hook exists and is executable" test -z "$missing_hooks"

echo
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
