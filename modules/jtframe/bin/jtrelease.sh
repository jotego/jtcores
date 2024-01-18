#!/bin/bash
# Make a release to JTBIN from GitHub builds

set -e

HASH=
SKIPROM=
VERBOSE=

while [ $# -gt 0 ]; do
	case "$1" in
		-l|--local)
			unset JTBIN;;
		--host)
			shift
			export MRHOST=$1;;
		-s|--skipROM)
			SKIPROM=--skipROM;;
		-v|--verbose)
			VERBOSE=1;;
		-h|--help)
			cat<<EOF

	jtrelease.sh <hash> [arguments]

	Copies a build from /nobackup/core-builds to the SD card,
	MiSTer and JTBIN ($JTBIN)

EOF
			exit 0;;
		*) if [[ -z "$HASH" && ${1:0:1} != - ]]; then
			HASH=$1
		else
			echo "Do not know what to do with arguments $HASH and $1"
			exit 1
		fi
	esac
	shift
done

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
jtframe > /dev/null
unzip $REF -d release
jtframe mra `find release/{mister,sidi} -name "*rbf*" | xargs -l -I_ basename _ .rbf | sort | uniq | sed s/^jt//` $SKIPROM

if [ -z "$SKIPROM" ]; then
	jtbin2sd &
fi

jtbin2mr

if [[ -n "$JTBIN" && -d "$JTBIN" && "$JTBIN" != "$DST/release" ]]; then
	echo "Copying to $JTBIN"
	cd $JTBIN
	cp -r $DST/release/* .
else
	echo "Skipping JTBIN as \$JTBIN is not defined"
	exit 0
fi

wait
rm -rf $DST
