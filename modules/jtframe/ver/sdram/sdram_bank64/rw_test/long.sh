#!/bin/bash

CMD="parallel --halt now,fail=1 "
PERIODS="10 16.67"
TIME=100

while [ $# -gt 0 ]; do
    case $1 in
        -h|-help)
            echo "Usage: long.sh [-dry-run]"
            exit 0;;
        -dry-run|-dry)
            CMD="$CMD --dry-run";;
        -time)
            shift
            TIME=$1;;
        *)
            echo "Unsupported argument: $1"
            exit 1;;
    esac
    shift
done

# Special cases
#$CMD sim.sh -nodump -time 25 -period  ::: $PERIODS ::: -norefresh -perf || exit $?

#different bank lengths
$CMD sim.sh -nodump -period {1} -time $TIME -idle {2} \
-len 0 {3} -len 1 {4} -len 2 {5} -len 3 {5} -prech 0  \
::: $PERIODS ::: 90 99 ::: 16 32 64 ::: 16 32 64 ::: 16 32 64 || exit $?
