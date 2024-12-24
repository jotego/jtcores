#!/bin/bash
# Clean all target build folders in $CORES and the log

if [[ -z "$JTFRAME" || -z "$JTROOT" || -z "$CORES" ]]; then exit 1; fi

TARGETS=`find $JTFRAME/target -maxdepth 1 -type d | tail -n +2 | xargs -l basename`

for i in $TARGETS; do
	find $CORES -maxdepth 2 -type d -name $i | xargs rm -rf
	rm -rf $JTROOT/log
done
