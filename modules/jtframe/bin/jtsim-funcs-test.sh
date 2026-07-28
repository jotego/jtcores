#!/bin/bash

source $JTFRAME/bin/jtsim-funcs

main() {
    test_get_macro
    test_has_macro
    test_verilator_optimization_default
    test_verilator_optimization_long
    test_verilator_optimization_fast
    test_verilator_optimization_override
    test_compare_scene_snapshot_match
    test_compare_scene_snapshot_mismatch
    test_compare_scene_snapshot_size_mismatch
    if [ "$FAIL" = 1 ]; then
        exit 1
    fi
}

fail() {
    local msg="$*"
    local test_name=${FUNCNAME[1]}
    printf "%-20s FAIL %s\n" $test_name "$msg"
    FAIL=1
}

pass() {
    local bad="$1"
    if [ ! -z "$bad" ]; then
        return
    fi
    local test_name=${FUNCNAME[1]}
    printf "%-20s PASS\n" $test_name
}

test_has_macro() {
    local bad
    ALLMACROS="a,d=,b=3,MAXFRAME=23,c=4"
    if has_macro not_there; then
        fail "found non existing macro"
        bad=1
    fi
    if ! has_macro MAXFRAME; then
        fail "coult not find MAXFRAME"
        bad=1
    fi
    pass $bad
}


test_get_macro() {
    ALLMACROS="a,d=,b=3,MAXFRAME=23,c=4"
    local bad

    if [ ! -z `get_macro` ]; then
        fail empty case. Got -`get_macro`-
        bad=1
    fi

    if [ ! -z `get_macro a` ]; then
        fail a. Got `get_macro a`
        bad=1
    fi

    if [ ! -z `get_macro d` ]; then
        fail d
        bad=1
    fi

    if [ "`get_macro b`" != 3 ]; then
        fail "b expected 3 got" `get_macro b`
        bad=1
    fi

    if [ "`get_macro MAXFRAME`" != 23 ]; then
        fail "MAXFRAME expected 23 got" `get_macro MAXFRAME`
        bad=1
    fi

    ALLMACROS="JTFRAME_SIM_DIPS=0xf0"
    if [ -z "`get_macro JTFRAME_SIM_DIPS`" ]; then
        fail "Cannot find JTFRAME_SIM_DIPS"
        bad=1
    fi
    pass $bad
}

clear_verilator_optimization() {
    unset ALLMACROS FAST MAXFRAME OPT_FAST OPT_SLOW OPT_GLOBAL
}

check_verilator_opts() {
    local expected_fast="$1"
    local expected_slow="$2"
    local expected_global="$3"
    local bad
    if [ "$OPT_FAST" != "$expected_fast" ]; then
        fail "OPT_FAST expected '$expected_fast' got '$OPT_FAST'"
        bad=1
    fi
    if [ "$OPT_SLOW" != "$expected_slow" ]; then
        fail "OPT_SLOW expected '$expected_slow' got '$OPT_SLOW'"
        bad=1
    fi
    if [ "$OPT_GLOBAL" != "$expected_global" ]; then
        fail "OPT_GLOBAL expected '$expected_global' got '$OPT_GLOBAL'"
        bad=1
    fi
    [ -z "$bad" ]
}

test_verilator_optimization_default() {
    local bad
    clear_verilator_optimization
    set_verilator_optimization
    check_verilator_opts "-O1 -march=native" "-O1 -march=native" \
        "-O1 -march=native" || bad=1
    pass $bad
}

test_verilator_optimization_long() {
    local bad
    clear_verilator_optimization
    ALLMACROS="MAXFRAME=601"
    set_verilator_optimization
    check_verilator_opts "-O2 -march=native" "-O2 -march=native" \
        "-O2 -march=native" || bad=1
    pass $bad
}

test_verilator_optimization_fast() {
    local bad
    clear_verilator_optimization
    ALLMACROS="MAXFRAME=601"
    FAST=1
    set_verilator_optimization
    check_verilator_opts "-O3 -march=native" "-O3 -march=native" \
        "-O3 -march=native" || bad=1
    pass $bad
}

test_verilator_optimization_override() {
    local bad
    clear_verilator_optimization
    OPT_FAST="-Og"
    set_verilator_optimization
    check_verilator_opts "-Og" "-O1 -march=native" "-O1 -march=native" || bad=1
    pass $bad
}

prepare_scene_compare_test() {
    SCENE_TEST_TMP=$(mktemp -d)
    mkdir -p "$SCENE_TEST_TMP/scene"
    SCENE="$SCENE_TEST_TMP/scene/dump.bin"
    touch "$SCENE"
    convert -size 2x2 xc:black "$SCENE_TEST_TMP/scene/snapshot.png"
}

scene_compare_tools_available() {
    command -v identify >/dev/null && command -v convert >/dev/null && command -v compare >/dev/null
}

test_compare_scene_snapshot_match() {
    local bad tmp
    if ! scene_compare_tools_available; then
        pass
        return
    fi
    prepare_scene_compare_test
    tmp="$SCENE_TEST_TMP"
    cp "$tmp/scene/snapshot.png" "$tmp/scene/candidate.png"
    compare_scene_snapshot "$tmp/scene/candidate.png" >/dev/null || {
        fail "matching snapshot returned failure"
        bad=1
    }
    rm -rf "$tmp"
    pass $bad
}

test_compare_scene_snapshot_mismatch() {
    local bad tmp
    if ! scene_compare_tools_available; then
        pass
        return
    fi
    prepare_scene_compare_test
    tmp="$SCENE_TEST_TMP"
    convert -size 2x2 xc:white "$tmp/scene/candidate.png"
    if compare_scene_snapshot "$tmp/scene/candidate.png" >/dev/null; then
        fail "mismatching snapshot returned success"
        bad=1
    fi
    rm -rf "$tmp"
    pass $bad
}

test_compare_scene_snapshot_size_mismatch() {
    local bad tmp
    if ! scene_compare_tools_available; then
        pass
        return
    fi
    prepare_scene_compare_test
    tmp="$SCENE_TEST_TMP"
    convert -size 3x2 xc:black "$tmp/scene/candidate.png"
    if compare_scene_snapshot "$tmp/scene/candidate.png" >/dev/null; then
        fail "size mismatch returned success"
        bad=1
    fi
    rm -rf "$tmp"
    pass $bad
}

main $*
