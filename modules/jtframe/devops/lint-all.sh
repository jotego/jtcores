#!/bin/bash

if [[ ! -v JTFRAME && -e setprj.sh ]]; then
    source setprj.sh
fi

WARNLIST=
ERRLIST=
cd $CORES

for i in *; do
    LOG=lint-$i.log
    $JTFRAME/devops/lint-one.sh $i 2> $LOG
    if [ -e $LOG ]; then
        if grep %Warning- $LOG > /dev/null; then
            if [ ! -z "$WARNLIST" ]; then WARNLIST="$WARNLIST "; fi
            WARNLIST="${WARNLIST}$i"
        fi

        if grep -i error $LOG > /dev/null; then
            if [ ! -z "$ERRLIST" ]; then ERRLIST="$ERRLIST "; fi
            ERRLIST="${ERRLIST}$i"
        fi
        echo $i
        cat $LOG
        rm -f $LOG
    fi
done

echo
echo
echo "==========================================================="
echo

if [ ! -z "WARNLIST" ]; then
    echo "Cores with linter warnings:"
    echo $WARNLIST
    echo
fi

if [ ! -z "ERRLIST" ]; then
    echo "Cores with linter errors:"
    echo $ERRLIST
    # exit 1
fi