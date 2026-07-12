#!/usr/bin/env bash
#
# mayhem/build.sh — build the fuzzgoat libFuzzer harness (+ standalone reproducer) and the
# functional test oracle.
#
# fuzzgoat is a single-file JSON parser (based on udp/json-parser) that has been DELIBERATELY
# backdoored with several memory-corruption bugs in json_value_free() (see fuzzgoat.c). Upstream
# ships NO test suite. It DOES ship a corrected reference implementation, fuzzgoatNoVulns.c, which
# is the same parser with the bugs removed. We use that reference (plus the upstream main.c driver)
# to build a behavioral known-answer oracle for test.sh.
set -euo pipefail

# clang rejects an empty SOURCE_DATE_EPOCH — unset rather than pass "".
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build contract from the base image (override-able). SANITIZER_FLAGS uses `=` so an explicit empty
# value (the sanitizer off-switch) is honored; DEBUG_FLAGS carries DWARF<4 independently.
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
# SanitizerCoverage for the fuzzed CODE so libFuzzer is coverage-guided on the parser itself
# (ASan/UBSan add NO coverage). -fsanitize=fuzzer-no-link instruments without pulling in the
# libFuzzer main, so the same object links into BOTH the fuzzer and the standalone reproducer.
: "${FUZZ_COV:=-fsanitize=fuzzer-no-link}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE STANDALONE_FUZZ_MAIN FUZZ_COV MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# ---------------------------------------------------------------------------
# 1) Fuzz target. Compile the buggy parser (fuzzgoat.c) INSTRUMENTED (ASan+UBSan + fuzzer coverage +
#    DWARF<4) so the FUZZED CODE is sanitized and coverage-guided — not just the harness. $DEBUG_FLAGS
#    comes AFTER $SANITIZER_FLAGS so its -gdwarf-3 wins over the base's plain -g (DWARF-5).
#    -lm: the parser uses pow()/floor() and must link cleanly even with an empty SANITIZER_FLAGS.
# ---------------------------------------------------------------------------
echo "[build] fuzz_fuzzgoat (libFuzzer harness over json_parse + json_value_free)"
$CC $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS $LIB_FUZZING_ENGINE -I"$SRC" \
    "$SRC/mayhem/fuzz_fuzzgoat.c" "$SRC/fuzzgoat.c" -lm \
    -o /mayhem/fuzz_fuzzgoat

# ---------------------------------------------------------------------------
# 2) Standalone (non-fuzzer) reproducer: same harness + code, linked against the run-once driver
#    instead of the libFuzzer engine. Takes one input file, runs LLVMFuzzerTestOneInput once, crashes
#    naturally. Repro artifact, not a Mayhem target.
# ---------------------------------------------------------------------------
echo "[build] fuzz_fuzzgoat-standalone (run-once reproducer)"
$CC $SANITIZER_FLAGS $FUZZ_COV $DEBUG_FLAGS -I"$SRC" \
    "$STANDALONE_FUZZ_MAIN" "$SRC/mayhem/fuzz_fuzzgoat.c" "$SRC/fuzzgoat.c" -lm \
    -o /mayhem/fuzz_fuzzgoat-standalone

# ---------------------------------------------------------------------------
# 3) Functional oracle. Build the CORRECTED reference (main.c + fuzzgoatNoVulns.c) with the project's
#    NORMAL flags — a clean, independent, un-sanitized build that test.sh only RUNS. This is a real
#    JSON parser, so test.sh can feed it known JSON and assert the printed structure (a no-op / exit(0)
#    PATCH emits no output and fails the oracle). $COVERAGE_FLAGS (empty by default) lets a coverage
#    build instrument the oracle; no effect otherwise.
# ---------------------------------------------------------------------------
echo "[build] fuzzgoat_ref (functional oracle: main.c + fuzzgoatNoVulns.c)"
mkdir -p "$SRC/build-tests"
$CC -O2 $COVERAGE_FLAGS -I"$SRC" \
    "$SRC/main.c" "$SRC/fuzzgoatNoVulns.c" -lm \
    -o "$SRC/build-tests/fuzzgoat_ref"

echo "[build] done:"
ls -l /mayhem/fuzz_fuzzgoat /mayhem/fuzz_fuzzgoat-standalone "$SRC/build-tests/fuzzgoat_ref"
