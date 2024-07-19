#!/bin/bash

if [ -z "$JTFRAME" ]; then
    cd /jtcores
    git config --global --add safe.directory /jtcores
    source setprj.sh
fi

WARNLIST=
ERRLIST=
FAIL=
cd $CORES

for i in *; do
    if [ ! -d $i ]; then continue; fi
    LOG=lint-$i.log
    $JTFRAME/bin/lint-one.sh $i > $LOG 2>&1
    if [ -e $LOG ]; then
        if grep %Warning- $LOG > /dev/null; then
            echo "Warnings for $i"
            if [ ! -z "$WARNLIST" ]; then WARNLIST="$WARNLIST "; fi
            WARNLIST="${WARNLIST}$i"
        fi

        if grep -i error $LOG > /dev/null; then
            echo "Errors on $i"
            if [ ! -z "$ERRLIST" ]; then ERRLIST="$ERRLIST "; fi
            ERRLIST="${ERRLIST}$i"
        fi
    fi
done

if [ ! -z "$WARNLIST" ]; then
    echo "Cores with linter warnings:"
    echo $WARNLIST
    echo
    FAIL=1
fi

if [ ! -z "$ERRLIST" ]; then
    echo "Cores with linter errors:"
    echo $ERRLIST
    FAIL=1
fi

# print out all log files that have problems
if [[ ! -z "$WARNLIST" || ! -z "$ERRLIST" ]]; then
    for i in $WARNLIST $ERRLIST; do
        echo =========== $i ================
        cat lint-$i.log
    done
fi

if [ -z "$FAIL" ]; then
    echo "lint-all: PASS"
else
    echo "lint-all: FAIL"
    exit 1
fi

rm -f lint*.log