#!/bin/bash

source $JTFRAME/bin/jtsim-funcs

main() {
    test_get_macro
    if [ "$FAIL" = 1 ]; then
        exit 1
    fi
}

fail() {
    local veredict="$1"
    shift
    local msg="$*"
    local test_name=${FUNCNAME[1]}
    printf "%-20s %6s %s\n" $test_name $veredict "$msg"
    if [ "$veredict" = "FAIL" ]; then
        FAIL=1
    fi
}

test_get_macro() {
    ALLMACROS="a,d=,b=3,MAXFRAME=23,c=4"

    if [ ! -z `get_macro` ]; then
        fail FAIL empty case. Got -`get_macro`-
    fi

    if [ ! -z `get_macro a` ]; then
        fail FAIL a. Got `get_macro a`
    fi

    if [ ! -z `get_macro d` ]; then
        fail FAIL d
    fi

    if [ "`get_macro b`" != 3 ]; then
        fail FAIL "b expected 3 got" `get_macro b`
    fi

    if [ "`get_macro MAXFRAME`" != 23 ]; then
        fail FAIL "MAXFRAME expected 23 got" `get_macro MAXFRAME`
    fi
}

main $*