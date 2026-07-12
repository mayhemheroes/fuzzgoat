#!/usr/bin/env bash
#
# mayhem/test.sh — RUN fuzzgoat's functional oracle (built by mayhem/build.sh) and emit CTRF.
#
# fuzzgoat ships NO upstream test suite: it is a deliberately-backdoored JSON parser plus a corrected
# reference implementation (fuzzgoatNoVulns.c). build.sh compiles the corrected reference with the
# upstream main.c driver into build-tests/fuzzgoat_ref — a genuine JSON parser+printer. This oracle
# feeds it known JSON documents and asserts the printed parse tree (known-answer tests on real
# program OUTPUT). A PATCH that neuters the program to _exit(0) (functional collapse, or the gate's
# sabotage check) produces NO output and every assertion fails — so the oracle is not reward-hackable.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

REF="$SRC/build-tests/fuzzgoat_ref"
if [ ! -x "$REF" ]; then
  echo "oracle binary not found at $REF — mayhem/build.sh did not build it" >&2
  emit_ctrf "fuzzgoat-oracle" 0 1
  exit 1
fi

# Known-answer inputs (valid JSON the corrected parser must parse and print).
T="$(mktemp -d)"
printf '{"greeting":"hello","count":42,"flag":true}' > "$T/obj.json"
printf '[10,20,30]'                                  > "$T/arr.json"
printf '{"outer":{"inner":"deep"}}'                  > "$T/nested.json"

passed=0; failed=0

# check <name> <input-file> <extended-regex>
check() {
  local name="$1" file="$2" pat="$3" out
  out="$("$REF" "$file" 2>/dev/null)"
  if printf '%s\n' "$out" | grep -qE "$pat"; then
    passed=$((passed+1)); echo "PASS $name"
  else
    failed=$((failed+1)); echo "FAIL $name (pattern: $pat)"
  fi
}

# --- object with string / int / bool members ---
check "obj.key.greeting" "$T/obj.json" 'name = greeting'
check "obj.val.hello"    "$T/obj.json" 'string: hello'
check "obj.key.count"    "$T/obj.json" 'name = count'
check "obj.val.42"       "$T/obj.json" 'int:[[:space:]]+42'
check "obj.key.flag"     "$T/obj.json" 'name = flag'
check "obj.val.true"     "$T/obj.json" 'bool: 1'

# --- array of integers ---
check "arr.header"       "$T/arr.json" '^array'
check "arr.val.10"       "$T/arr.json" 'int:[[:space:]]+10'
check "arr.val.20"       "$T/arr.json" 'int:[[:space:]]+20'
check "arr.val.30"       "$T/arr.json" 'int:[[:space:]]+30'

# --- nested object ---
check "nested.key.outer" "$T/nested.json" 'name = outer'
check "nested.key.inner" "$T/nested.json" 'name = inner'
check "nested.val.deep"  "$T/nested.json" 'string: deep'

rm -rf "$T"

emit_ctrf "fuzzgoat-oracle" "$passed" "$failed"
