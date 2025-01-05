#!/bin/bash

if [ -z "$JTFRAME" ]; then
    cd /jtcores
    git config --global --add safe.directory /jtcores
    source setprj.sh
fi

WARNLIST=
ERRLIST=
FAIL=
LOGFOLDER=$JTROOT/log/linter/
cd $CORES
rm -rf $LOGFOLDER
mkdir -p $LOGFOLDER

for i in *; do
    if [ ! -d $i ]; then continue; fi
    LOG=$LOGFOLDER/lint-$i.log
    if ! $JTFRAME/bin/lint-one.sh $i > $LOG 2>&1; then
        echo "Errors on $i"
        if [ ! -z "$ERRLIST" ]; then ERRLIST="$ERRLIST "; fi
        ERRLIST="${ERRLIST}$i"
    fi
    if [ -e $LOG ]; then
        if grep %Warning- $LOG > /dev/null; then
            echo "Warnings for $i"
            if [ ! -z "$WARNLIST" ]; then WARNLIST="$WARNLIST "; fi
            WARNLIST="${WARNLIST}$i"
        fi
    fi
done

# print out all log files that have problems
if [[ ! -z "$WARNLIST" || ! -z "$ERRLIST" ]]; then
    for i in $WARNLIST $ERRLIST; do
        echo =========== $i ================
        cat $LOGFOLDER/lint-$i.log
    done
fi

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

if [ -z "$FAIL" ]; then
    echo "lint-all: PASS"
else
    echo "lint-all: FAIL"
    exit 1
fi

rm -f lint*.log