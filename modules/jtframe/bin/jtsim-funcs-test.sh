#!/bin/bash

source $JTFRAME/bin/jtsim-funcs

main() {
    test_get_macro
    test_has_macro
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

main $*