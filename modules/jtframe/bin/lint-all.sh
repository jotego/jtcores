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

for core in *; do
    if [ ! -d $core ]; then continue; fi
    LOG=$LOGFOLDER/lint-$core.log
    if ! $JTFRAME/bin/lint-one.sh $core > $LOG 2>&1; then
        if [ ! -z "$ERRLIST" ]; then ERRLIST="$ERRLIST "; fi
        ERRLIST="${ERRLIST}$core"
    fi
    if [ -e $LOG ]; then
        if grep %Warning- $LOG > /dev/null; then
            if [ ! -z "$WARNLIST" ]; then WARNLIST="$WARNLIST "; fi
            WARNLIST="${WARNLIST}$core"
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

function make_table {
    echo $* | tr ' ' '\n' | column
}

function count_cores {
    echo $* | wc -w
}

if [ ! -z "$WARNLIST" ]; then
    echo "Cores with linter warnings:"
    make_table $WARNLIST
    echo `count_cores $WARNLIST` warnings
    FAIL=1
fi

if [ ! -z "$ERRLIST" ]; then
    echo "Cores with linter errors:"
    make_table $ERRLIST
    echo `count_cores $ERRLIST` errors
    FAIL=1
fi

if [ -z "$FAIL" ]; then
    echo "lint-all: PASS"
else
    echo "lint-all: FAIL"
    exit 1
fi

rm -f lint*.log