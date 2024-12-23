#!/bin/bash

if [ -z "$JTFRAME" ]; then
    cd /jtcores
    git config --global --add safe.directory /jtcores
    source setprj.sh
fi

WARNLIST=
ERRLIST=
cd $CORES

for i in *; do
    LOG=lint-$i.log
    $JTFRAME/devops/lint-one.sh $i 2&> $LOG
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

echo
echo
echo "======================= REPORT ============================"
echo

if [ ! -z "WARNLIST" ]; then
    echo "Cores with linter warnings:"
    echo $WARNLIST
    echo
fi

if [ ! -z "ERRLIST" ]; then
    echo "Cores with linter errors:"
    echo $ERRLIST
    echo "lint-all: FAIL"
    exit 1
fi

echo "lint-all: PASS"