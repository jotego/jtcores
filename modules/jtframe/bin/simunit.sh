#!/bin/bash -e
# use to simulate unit tests
# create a file called gather.f with the names of the files to include in the sim
# not local to the simulation folder

RUNFOLDER="$1"
if [ -z "$RUNFOLDER" ]; then
	RUNFOLDER=`pwd`
fi

cd $RUNFOLDER
echo "Running from `pwd`"

GATHER=`mktemp`
envsubst < gather.f > $GATHER

iverilog `find -name "*.v"` `find -name "*.sv"` $JTFRAME/hdl/{video/jtframe_vtimer.v,ver/jtframe_test_clocks.v} -f$GATHER -s test -o sim -D SIMULATION && sim -lxt > sim.log
rm -f sim $GATHER
if grep PASS sim.log > /dev/null; then
	echo PASS
else
	cat sim.log
	echo FAIL
	exit 1
fi
