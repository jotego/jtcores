#!/usr/bin/env bash
# Tests reg-cabs.sh on a fake repository
set -euo pipefail

main() {
    setup
    test_copy
    test_core_list
    test_reused_folder
    test_stale_cab
    test_duplicate
    test_empty
    echo PASS
}

setup() {
    script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    work=$(mktemp -d)
    trap 'rm -rf -- "$work"' EXIT
    mkdir -p "$work/modules/jtframe/devops"
    cp "$script_dir/reg-cabs.sh" "$work/modules/jtframe/devops/"
    regcabs=$work/modules/jtframe/devops/reg-cabs.sh
    add_cab aaa set1
    add_cab aaa set2
    add_cab bbb set3
    mkdir -p "$work/cores/bbb/ver/game" "$work/cores/ccc/ver/game"
    echo 1 > "$work/cores/bbb/ver/game/other.cab"
}

add_cab() {
    mkdir -p "$work/cores/$1/ver/$2"
    echo "capture 100 # $1/$2" > "$work/cores/$1/ver/$2/reg.cab"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

listing() {
    local files=("$1"/*)
    echo "${files[@]##*/}"
}

test_copy() {
    (cd / && "$regcabs") > /dev/null
    [ "$(listing "$work/release/cab")" = "set1.cab set2.cab set3.cab" ] || fail "default output"
    grep -q 'bbb/set3' "$work/release/cab/set3.cab" || fail "wrong content"
}

test_core_list() {
    "$regcabs" -o "$work/list" bbb > /dev/null
    [ "$(listing "$work/list")" = set3.cab ] || fail "core list"
    if "$regcabs" -o "$work/x" nosuchcore 2> /dev/null; then fail "accepted an unknown core"; fi
}

# A rerun into the same folder overwrites its own files
test_reused_folder() {
    add_cab aaa set1
    "$regcabs" > /dev/null || fail "rerun into the same folder"
}

test_stale_cab() {
    local out=$work/stale msg
    mkdir -p "$out"
    echo "hand written" > "$out/mine.cab"
    if msg=$("$regcabs" -o "$out" 2>&1); then fail "accepted a folder with a stale .cab"; fi
    [[ "$msg" == *"mine.cab"* ]] || fail "stale file not named: $msg"
    [ "$(listing "$out")" = mine.cab ] || fail "stale check wrote or deleted files"
    rm "$work/cores/aaa/ver/set2/reg.cab"
    if "$regcabs" > /dev/null 2>&1; then fail "kept set2.cab after its reg.cab was removed"; fi
    add_cab aaa set2
}

test_duplicate() {
    add_cab ccc set1
    if "$regcabs" -o "$work/dup" 2> /dev/null; then fail "accepted a duplicated setname"; fi
    [ ! -e "$work/dup" ] || fail "duplicated setname wrote files"
    rm -r "$work/cores/ccc/ver/set1"
}

test_empty() {
    "$regcabs" -o "$work/empty" ccc > /dev/null || fail "core without reg.cab"
    [ -d "$work/empty" ] || fail "no output folder"
    [ -z "$(ls -A "$work/empty")" ] || fail "expected an empty folder"
}

main "$@"
