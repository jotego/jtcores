#!/bin/bash
# Make a release to JTBIN from GitHub builds

set -e

HASH=
SKIPROM=
VERBOSE=
BUILDS=/nobackup/core-builds

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

	Copies a build from $BUILDS to the SD card,
	MiSTer and JTBIN ($JTBIN)

	-l, --local		Do not copy to JTBIN

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

REF=$BUILDS/${HASH:0:7}.zip
echo $REF
if [ ! -e $REF ]; then REF=$BUILDS/mister_${HASH:0:7}.zip; fi

if [ ! -e $REF ]; then
	echo "No build ${HASH:0:7} available"
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
if [ -d release/release ]; then mv release/release/* release; rmdir release/release; fi
jtframe mra `find release/{mister,sidi} -name "*rbf*" | xargs -l -I_ basename _ .rbf | sort | uniq | sed s/^jt//` $SKIPROM

if [ -z "$SKIPROM" ]; then
	jtbin2sd &
fi

if [[ -n "$JTBIN" && -d "$JTBIN" && "$JTBIN" != "$DST/release" ]]; then
	echo "Copying to $JTBIN"
	cd $JTBIN
	if [ -d .git ]; then git checkout -b $(date +"%Y%m%d"); fi
	cp -r $DST/release/* .
	# remove games in beta phase for SiDi and MiST
	for t in mist sidi; do
		for i in $JTBIN/$t/*.rbf; do
			corename=`basename $i .rbf`
			if grep "${corename#jt}.*mister" $JTROOT/beta.yaml > /dev/null; then rm -v $i; fi
		done
	done
else
	echo "Skipping JTBIN as \$JTBIN is not defined"
	exit 0
fi

wait
rm -rf $DST
