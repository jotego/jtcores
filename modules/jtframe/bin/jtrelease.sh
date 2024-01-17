#!/bin/bash
# Make a release to JTBIN from GitHub builds

set -e

HASH="$1"
shift

if [ -z "$HASH" ]; then
	echo "Use jtrelease.sh git-hash"
	exit 1
fi

REF=/nobackup/core-builds/mister_${HASH:0:7}.zip

if [ ! -e $REF ]; then
	echo "No build $REF available"
	exit 125
fi

DST=`mktemp -d`
git clone $JTROOT $DST
cd $DST
. setprj.sh
cd $DST
git checkout $HASH
git submodule init $JTFRAME/target/pocket
git submodule update $JTFRAME/target/pocket
jtframe
unzip $REF
jtframe mra `find release/{mister,sidi} -name "*rbf*" | xargs -l -I_ basename _ .rbf | sort | uniq | sed s/^jt//`

if [ -d /media/$USER/POCKET ]; then
	jtbin2sd &
fi

if ping -c 1 -q $MRHOST > /dev/null; then
	jtbin2mr
fi

if [[ -n "$JTBIN" && -d "$JTBIN" ]]; then
	cd $JTBIN
	cp -r $DST/release/* .
else
	echo "Skipping JTBIN as \$JTBIN is not defined"
	exit 0
fi


wait
rm -rf $DST
