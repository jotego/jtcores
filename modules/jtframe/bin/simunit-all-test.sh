#!/usr/bin/env bash
# Tests simunit-all.sh sharding, test order, times file and PASS/FAIL report
# with a stub simunit.sh in a temporary tree. No simulation runs.
set -euo pipefail

main() {
    setup
    test_shards_partition_list
    test_shard_validation
    test_balanced_shards
    test_report
    test_save_times
    test_times_format
    test_log_without_newline
    echo PASS
}

setup() {
    script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    work=$(mktemp -d)
    trap 'rm -rf -- "$work"' EXIT
    root=$work/root
    # created out of order: the shards must not depend on find's order
    local test
    for test in m07 a03 z01 a10 b02 c05 m04 a01 q09 b11; do
        mkdir -p "$root/ver/$test"
        touch "$root/ver/$test/.simunit"
    done
    mkdir -p "$work/jtframe/bin"
    cp "$script_dir/simunit-all.sh" "$work/jtframe/bin/"
    make_stub
    # the stub JTFRAME has no times file, so by default all tests weigh the same
    printf 'ver/m07 500\nver/a03 400\nver/z01 300\n# comment\nver/gone 900\n' > "$work/times"
}

# fails the tests whose folder holds a file called fail and logs the start order
make_stub() {
    local stub="$work/jtframe/bin/simunit.sh"
    {
        echo '#!/usr/bin/env bash'
        echo 'dir="$2"'
        echo 'echo "${dir##*/}" >> "$START_LOG"'
        echo 'echo "log of $dir"'
        echo '[ ! -e "$dir/nonl" ] || printf "no newline"'
        echo '[ ! -e "$dir/fail" ]'
    } > "$stub"
    chmod +x "$stub"
}

run_all() {
    JTROOT=$root JTFRAME=$work/jtframe START_LOG=$work/started \
        "$work/jtframe/bin/simunit-all.sh" "$@"
}

test_shards_partition_list() {
    run_all --list > "$work/all"
    test "$(wc -l < "$work/all")" -eq 10 || fail "expected 10 tests in --list"
    LC_ALL=C sort -c "$work/all" || fail "--list is not sorted"
    local count k
    for count in 1 3 4 10 12; do
        : > "$work/joined"
        for (( k = 1; k <= count; k++ )); do
            run_all --list --shard "$k/$count" > "$work/shard" 2> /dev/null
            check_shard_size "$count" "$(wc -l < "$work/shard")"
            cat "$work/shard" >> "$work/joined"
        done
        LC_ALL=C sort "$work/joined" | cmp -s - "$work/all" ||
            fail "shards of $count do not partition the list"
    done
}

# with equal weights, shards differ in size by one test at most
check_shard_size() {
    local count="$1" size="$2"
    local low=$(( 10 / count ))
    [ "$size" -eq "$low" ] || [ "$size" -eq $(( low + 1 )) ] ||
        fail "unbalanced shard of $size tests for $count shards"
}

test_shard_validation() {
    local bad
    for bad in 0/3 4/3 3 a/b 1/0 -1/2; do
        if run_all --list --shard "$bad" > /dev/null 2>&1; then
            fail "--shard $bad was accepted"
        fi
    done
    if run_all --list --times "$work/missing" > /dev/null 2>&1; then
        fail "a missing --times file was accepted"
    fi
}

# m07=500, a03=400, z01=300 and seven tests of 30 s: shard 1 gets m07 and the
# seven short tests (710 s), shard 2 gets a03 and z01 (700 s)
test_balanced_shards() {
    run_all --list --times "$work/times" --shard 1/2 > "$work/shard1"
    run_all --list --times "$work/times" --shard 2/2 > "$work/shard2"
    grep -qx ver/m07 "$work/shard1" || fail "m07 must be in shard 1"
    grep -qx ver/a03 "$work/shard2" || fail "a03 must be in shard 2"
    grep -qx ver/z01 "$work/shard2" || fail "z01 must be in shard 2"
    test "$(wc -l < "$work/shard1")" -eq 8 || fail "shard 1/2 must have 8 tests"
    test "$(wc -l < "$work/shard2")" -eq 2 || fail "shard 2/2 must have 2 tests"
    # with one job the start order is the run order: longest first, then by name
    : > "$work/started"
    run_all --jobs 1 --times "$work/times" > /dev/null
    test "$(head -n 4 "$work/started" | tr '\n' ' ')" = "m07 a03 z01 a01 " ||
        fail "tests did not start longest first: $(tr '\n' ' ' < "$work/started")"
}

test_report() {
    touch "$root/ver/b02/fail"
    if run_all --jobs 2 > "$work/report" 2>&1; then
        fail "a failing test returned success"
    fi
    grep -qE '^ver/b02 FAIL \([0-9]+ s\)$' "$work/report" || fail "missing FAIL line"
    grep -qE "^    log of $root/ver/b02$" "$work/report" || fail "missing log of failed test"
    grep -qE '^ver/a01 PASS \([0-9]+ s\)$' "$work/report" || fail "missing PASS line"
    if grep -q "log of $root/ver/a01" "$work/report"; then
        fail "log of a passing test was printed"
    fi
    test "$(tail -n 1 "$work/report")" = FAIL || fail "missing final FAIL"
    rm "$root/ver/b02/fail"
    run_all --jobs 2 --shard 2/3 > "$work/report" || fail "passing shard returned failure"
    test "$(grep -c ' PASS (' "$work/report")" -eq 3 || fail "shard 2/3 must run 3 tests"
    test "$(tail -n 1 "$work/report")" = PASS || fail "missing final PASS"
}

test_save_times() {
    touch "$root/ver/c05/fail"
    if run_all --jobs 2 --save-times "$work/saved" > /dev/null; then
        fail "a failing test returned success with --save-times"
    fi
    rm "$root/ver/c05/fail"
    test "$(grep -vc '^#' "$work/saved")" -eq 10 || fail "--save-times must list 10 tests"
    grep -qE '^ver/c05 [0-9]+$' "$work/saved" || fail "--save-times misses the failed test"
    grep -v '^#' "$work/saved" | cut -d' ' -f1 | cmp -s - "$work/all" ||
        fail "--save-times is not sorted by test name"
    run_all --list --times "$work/saved" > /dev/null || fail "saved times cannot be read back"
}

# leading zeros, CRLF line ends and bad values must not drop tests
test_times_format() {
    printf 'ver/z01 09\nver/a03 08\r\nver/b02 010\nver/c05 1x\nver/m04 1234567890\n' > "$work/odd"
    run_all --jobs 2 --times "$work/odd" > "$work/report" || fail "odd times file broke the run"
    test "$(grep -c ' PASS (' "$work/report")" -eq 10 || fail "odd times file dropped tests"
    run_all --list --times "$work/odd" --shard 1/2 > "$work/shard1"
    run_all --list --times "$work/odd" --shard 2/2 > "$work/shard2"
    LC_ALL=C sort "$work/shard1" "$work/shard2" | cmp -s - "$work/all" ||
        fail "odd times file breaks the shards"
}

test_log_without_newline() {
    touch "$root/ver/a01/fail" "$root/ver/a01/nonl"
    run_all --jobs 1 --save-times "$work/saved" > "$work/report" || true
    rm "$root/ver/a01/fail" "$root/ver/a01/nonl"
    grep -qx '    no newline' "$work/report" || fail "log without newline not printed alone"
    test "$(tail -n 1 "$work/report")" = FAIL || fail "final FAIL glued to a log line"
    test "$(grep -vc '^#' "$work/saved")" -eq 10 || fail "--save-times lost a test"
}

fail() {
    echo "simunit-all-test.sh: $*" >&2
    exit 1
}

main "$@"
