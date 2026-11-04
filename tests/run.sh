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
write_state green "AssertionFailedError"
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "allows in-scope src/main edit in green" 0 "$rc" "$out"
jq '.tasks["T-001"] |= del(.red_at)' "$PROJECT/.specs/f/.tdd-state.json" > "$WORK/state.json" \
  && mv "$WORK/state.json" "$PROJECT/.specs/f/.tdd-state.json"
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "blocks green phase without red_at" 2 "$rc" "$out"
write_state refactor ""
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "blocks refactor phase with empty excerpt" 2 "$rc" "$out"
write_state "done" "AssertionFailedError"
run_hook block-impl-without-failing-test.sh "$(edit_json "$main_file")"
expect_rc "blocks when task is done" 2 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$test_file")"
expect_rc "allows in-scope test edit" 0 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$PROJECT/src/test/java/com/x/OtherTest.java")"
expect_rc "blocks out-of-scope test edit" 2 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$PROJECT/.specs/f/04-tasks.md")"
expect_rc "allows .specs edits" 0 "$rc" "$out"

echo "TDD hooks on Angular files"
new_project ng
mkdir -p "$PROJECT/.specs/f"
ng_main="$PROJECT/frontend/src/app/cart/cart.component.ts"
run_hook block-impl-without-failing-test.sh "$(edit_json "$ng_main")"
expect_rc "blocks Angular component edit without .tdd-state.json" 2 "$rc" "$out"
jq -n '{active_task: "T-002", tasks: {"T-002": {phase: "red", red_at: "2026-01-01T00:00:00Z",
  red_failure_excerpt: "Expected 0 to be 1", files_in_scope: ["frontend/src/app/cart/cart.component.ts",
  "frontend/src/app/cart/cart.component.spec.ts"]}}}' > "$PROJECT/.specs/f/.tdd-state.json"
run_hook block-impl-without-failing-test.sh "$(edit_json "$ng_main")"
expect_rc "allows in-scope Angular component edit in red" 0 "$rc" "$out"
for f in frontend/src/app/cart/cart.component.html frontend/src/app/cart/cart.component.scss \
         frontend/src/main.ts frontend/src/styles.css; do
  run_hook block-impl-without-failing-test.sh "$(edit_json "$PROJECT/$f")"
  expect_rc "blocks out-of-scope $f" 2 "$rc" "$out"
done
run_hook block-impl-without-failing-test.sh "$(edit_json "$PROJECT/frontend/src/app/cart/cart.component.spec.ts")"
expect_rc "production hook ignores *.spec.ts" 0 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$PROJECT/frontend/src/app/cart/cart.component.spec.ts")"
expect_rc "allows in-scope *.spec.ts" 0 "$rc" "$out"
run_hook enforce-files-in-scope.sh "$(edit_json "$PROJECT/frontend/src/app/other/other.component.spec.ts")"
expect_rc "blocks out-of-scope *.spec.ts" 2 "$rc" "$out"
for f in frontend/node_modules/x/src/index.ts frontend/angular.json frontend/package.json; do
  run_hook block-impl-without-failing-test.sh "$(edit_json "$PROJECT/$f")"
  expect_rc "ignores $f" 0 "$rc" "$out"
done

echo "route-natural-language-aliases.sh"
new_project alias
expect_alias() {
  run_hook route-natural-language-aliases.sh "$(jq -cn --arg p "$1" '{prompt:$p}')"
  local got
  got="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$got" = "${2:+Natural-language alias detected: route to $2.}" ]; then
    pass "'$1' -> ${2:-no route}"
  else
    fail "'$1' -> ${2:-no route}" "rc=$rc out=$out"
  fi
}
expect_alias "Please review the spec" "/spec-review"
expect_alias "Can you simplify the code in FooService?" "/code-simplify"
expect_alias "plan this epic" "/epic-plan"
expect_alias "Let's plan this" "/plan"
expect_alias "validate" "/validate"
expect_alias "OK, run the harness" "/validate"
expect_alias "implement T-004" "/build T-004"
expect_alias "please build t-012 now" "/build T-012"
expect_alias "How do I validate the request body?" ""
expect_alias "Explain the code review rubric" ""
expect_alias "Why is it important to ship it fast?" ""
expect_alias "build the project" ""

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

echo "check-new-code-coverage.sh"
new_project newcov
git_q() { git -C "$PROJECT" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
git_q init -q -b main
mkdir -p "$PROJECT/src/main/java/com/x" "$PROJECT/target/site/jacoco"
printf 'package com.x;\nclass Foo {\n  int a() { return 1; }\n}\n' > "$PROJECT/src/main/java/com/x/Foo.java"
echo target/ > "$PROJECT/.gitignore"
git_q add -A && git_q commit -q -m base
git_q checkout -q -b feature
# Line 3 changed and line 4 added (executable); line 5 is a comment (not in JaCoCo).
printf 'package com.x;\nclass Foo {\n  int a() { return 2; }\n  int b() { return 3; }\n  // note\n}\n' > "$PROJECT/src/main/java/com/x/Foo.java"
printf 'package com.x;\nclass Bar {\n  int c() { return 4; }\n}\n' > "$PROJECT/src/main/java/com/x/Bar.java"
# Single-line report, as JaCoCo 0.8.x may write it.
jacoco_report() {
  printf '<?xml version="1.0"?><report name="x"><package name="com/x"><sourcefile name="Foo.java"><line nr="2" mi="0" ci="3"/><line nr="3" mi="0" ci="2"/><line nr="4" mi="%s" ci="%s"/></sourcefile><sourcefile name="Bar.java"><line nr="3" mi="0" ci="2"/></sourcefile></package></report>' "$1" "$2" \
    > "$PROJECT/target/site/jacoco/jacoco.xml"
}
run_newcov() { out="$(cd "$PROJECT" && BASE_REF=main "$BASH" "$SCRIPTS/check-new-code-coverage.sh" 2>&1)"; rc=$?; }
jacoco_report 0 2
run_newcov
expect_rc "passes when every new executable line is covered" 0 "$rc" "$out"
detail="$out"
check "counts changed, added and untracked lines but not comments" \
  jq -e '.total_new_lines == 3 and .covered_new_lines == 3' "$PROJECT/target/new-code-coverage.json"
jacoco_report 2 0
run_newcov
expect_rc "fails below the threshold" 1 "$rc" "$out"
check "reports 2 of 3 lines covered" jq -e '.covered_new_lines == 2 and .ratio == 0.6667' "$PROJECT/target/new-code-coverage.json"
out="$(cd "$PROJECT" && NEW_CODE_THRESHOLD=0.5 BASE_REF=main "$BASH" "$SCRIPTS/check-new-code-coverage.sh" 2>&1)"; rc=$?
expect_rc "honours NEW_CODE_THRESHOLD" 0 "$rc" "$out"
detail=""
git_q stash -u
run_newcov
expect_rc "passes with no new code" 0 "$rc" "$out"
out="$(cd "$PROJECT" && BASE_REF=no-such-ref "$BASH" "$SCRIPTS/check-new-code-coverage.sh" 2>&1)"; rc=$?
expect_rc "errors on an unknown BASE_REF" 2 "$rc" "$out"
rm "$PROJECT/target/site/jacoco/jacoco.xml"
run_newcov
expect_rc "errors without jacoco.xml" 2 "$rc" "$out"

echo "harness.sh"
new_project harness
fakebin="$WORK/fake-mvn-bin"
mkdir -p "$fakebin" "$PROJECT/svc"
# Fake mvn: writes a surefire report and exits with $FAKE_MVN_RC; logs each call.
cat > "$fakebin/mvn" <<'MVN'
#!/usr/bin/env bash
echo "mvn $*" >> "${FAKE_MVN_LOG:?}"
echo "[INFO] fake maven output"
mkdir -p target/surefire-reports
printf '<testsuite tests="3" failures="%s" errors="0" skipped="0"/>' "${FAKE_TEST_FAILURES:-0}" \
  > target/surefire-reports/TEST-a.xml
case "$*" in *mutationCoverage*)
  if [ -n "${FAKE_PIT_REPORT:-}" ]; then
    mkdir -p target/pit-reports
    echo '<mutations><mutation status="KILLED"/><mutation status="KILLED"/><mutation status="TIMED_OUT"/><mutation status="SURVIVED"/></mutations>' \
      > target/pit-reports/mutations.xml
  fi ;;
esac
exit "${FAKE_MVN_RC:-0}"
MVN
chmod +x "$fakebin/mvn"
printf '<project><artifactId>pitest-maven</artifactId></project>' > "$PROJECT/svc/pom.xml"
git_q init -q
export FAKE_MVN_LOG="$WORK/mvn.log"
run_harness() {
  : > "$FAKE_MVN_LOG"
  out="$(cd "$PROJECT" && PATH="$fakebin:$PATH" "$BASH" "$SCRIPTS/harness.sh" --module svc "$@" 2>"$WORK/harness.err")"
  rc=$?
}
summary="$PROJECT/svc/target/harness-summary.json"
FAKE_MVN_RC=1 FAKE_TEST_FAILURES=1 run_harness --report
expect_rc "exits 1 when mvn verify fails" 1 "$rc" "$(cat "$WORK/harness.err")"
detail="$out"
check "--report prints only JSON on stdout" jq -e '.overall == "fail"' <<< "$out"
check "writes the summary even when the build fails" \
  jq -e '.gates.build == {"status":"fail","exit_code":1} and .gates.unit.status == "fail"' "$summary"
detail="$(cat "$FAKE_MVN_LOG")"
check "skips mutation testing after a failed build" test "$(grep -c pitest "$FAKE_MVN_LOG")" -eq 0
FAKE_PIT_REPORT=1 run_harness --report
expect_rc "exits 0 when every gate passes" 0 "$rc" "$(cat "$WORK/harness.err")"
check "runs mutation testing after a green build" grep -q pitest "$FAKE_MVN_LOG"
detail="$out"
check "reports the mutation kill rate" jq -e '.gates.mutation.status == "pass" and .gates.mutation.kill_rate == 0.75' <<< "$out"
rm -rf "$PROJECT/svc/target/pit-reports"
run_harness
expect_rc "exits 1 when PIT leaves no report" 1 "$rc" "$(cat "$WORK/harness.err")"
check "fails the mutation gate when PIT leaves no report" \
  jq -e '.gates.mutation.status == "fail" and .overall == "fail"' "$summary"
detail=""
FAKE_MVN_RC=1 run_harness --baseline
expect_rc "--baseline exits 0 even when gates fail" 0 "$rc" "$(cat "$WORK/harness.err")"
detail="$out"
check "--baseline writes .specs/_baseline.json at the repo root" \
  jq -e '.overall == "fail" and .gates.build.status == "fail"' "$PROJECT/.specs/_baseline.json"
check "--baseline prints the same JSON on stdout" jq -e '.captured_at' <<< "$out"
detail=""
run_harness --bogus
expect_rc "rejects unknown options" 2 "$rc" "$(cat "$WORK/harness.err")"

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
