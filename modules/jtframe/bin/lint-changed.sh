#!/bin/bash

cd $JTROOT
CHECK=`git status --short | grep "M cores" | cut -d/ -f 2 | sort | uniq`
if [ -z "$CHECK" ]; then exit 0; fi

TMP=`mktemp`
echo $CHECK | xargs $JTFRAME/bin/lint-one.sh > $TMP 2>&1

BAD=0
if grep %Warning $TMP; then BAD=1; fi
if grep -i error $TMP; then BAD=1; fi
if [ $BAD = 1 ]; then
	cat $TMP
	rm -f $TMP
	exit 1
fi
rm -f $TMP
exit 0