#!/bin/bash
# Make a release to JTBIN from GitHub builds

function on_error {
	if [ -d $DST ]; then
		echo "Deleting $DST"
		rm -rf $DST;
	fi
}

trap on_error ERR
set -e

function pocket_zip {
	cd $JTBIN/pocket/raw
	zip -r jotego.$1.zip $1.txt Assets/$1 Cores/jotego.$1 \
		Platforms/$1.json Platforms/_images/$1.bin Presets/jotego.$1
	mv jotego.$1.zip $JTBIN/pocket/zips
	cd -
}

HASH=
SKIPROM=--skipROM
VERBOSE=

while [ $# -gt 0 ]; do
	case "$1" in
		-l|--local)
			unset JTBIN;;
		--host)
			shift
			export MRHOST=$1;;
		-r|--rom)
			SKIPROM=;;
		-v|--verbose)
			VERBOSE=1;;
		-h|--help)
			cat<<EOF
jtrelease.sh <hash> [arguments]

Copies a build to the SD card,MiSTer and JTBIN $JTBIN
Either the full path to the file is provided, or just the
hash to it, and the file is looked upon in the \$JTBUILDS path $JTBUILDS

-h, --help		This help screen
-l, --local		Do not copy to JTBIN
--host			MiSTer host name
-r, --rom		Regenerate ROM files
-v, --verbose   Verbose
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

if [ ! -z "$JTBUILDS" ]; then
	if [ ! -d "$JTBUILDS" ]; then echo "$JTBUILDS is not a valid path"; exit 1; fi
	JTBUILDS=${JTBUILDS}/
fi

if [ -z "$HASH" ]; then
	echo "Use jtrelease.sh git-hash"
	exit 1
fi

REF=${JTBUILDS}${HASH:0:7}.zip
echo $REF
if [ ! -e $REF ]; then
	echo "path `pwd`/$REF failed"
	REF=${JTBUILDS}mister_${HASH:0:7}.zip;
fi

if [ ! -e $REF ]; then
	echo "No build ${HASH:0:7} available"
	echo "Tried path: `pwd`/$REF"
	exit 125
fi

DST=`mktemp -d /tmp/jt_XXXXXX`
git clone $JTROOT $DST
cd $DST
. setprj.sh
cd $DST
git checkout $HASH
HASHLONG=`git rev-parse HEAD`
git submodule init $JTFRAME/target/pocket
git submodule update $JTFRAME/target/pocket
cd $JTFRAME/src/jtframe
go mod tidy
jtframe > /dev/null
cd $JTFRAME/src/jtutil
go mod tidy
jtutil > /dev/null
cd $DST
echo "Unzipping $REF"
unzip -q $REF -d release
if [ -d release/release ]; then mv release/release/* release; rmdir release/release; fi

if [[ -n "$JTBIN" && -d "$JTBIN" && "$JTBIN" != "$DST/release" ]]; then
	echo "Copying to $JTBIN"
	cd $JTBIN
	if [ -d .git ]; then
		BRANCH=jtcores_$HASH
		git reset --hard
		git clean -fd .
		git checkout master
		git branch -D $BRANCH 2> /dev/null || true
		git checkout -b $BRANCH
		rm -rf mist sidi* pocket mister mra
	fi
	# refresh schematics
	echo "Refreshing schematics"
	jtframe sch --git &
	# Regenerate the MRA files to include md5 sums
	echo "MRA regeneration including md5 sums"
	cd $DST
	rm -rf release/mra
	find release/pocket -name "*rbf_r" | xargs -l -I% basename % .rbf_r | sort | uniq | sed s/^jt// > pocket.cores
	find release/{mister,sidi,sidi128,mist} -name "*rbf" | xargs -l -I% basename % .rbf | sort | uniq | sed s/^jt// | sort > mister.cores
	jtframe mra $SKIPROM --md5 --git `cat pocket.cores` --nodbg
	comm -3 pocket.cores mister.cores > other.cores
	if [ `wc -l other.cores|cut -f1 -d' '` -gt 0 ]; then
		# cat other.cores
		jtframe mra $SKIPROM --md5 --skipPocket --git `cat other.cores` --nodbg
	fi
	echo "Copy RBF files to $JTBIN"
	cd $JTBIN
	cp -r $DST/release/* .
	echo "Make Pocket zip files"
	mkdir -p $JTBIN/pocket/zips
	for core in `find pocket/raw -name "*.rbf_r"`; do
		core=`basename $core .rbf_r`
		pocket_zip $core
	done
	jtutil md5
	# note that the beta zip files are generated before the commit
	# in order to have the MiST and SiDi cores too
	echo "Create zip files for JTFriday"
	cpbeta.sh
	echo "Removing games in beta phase for SiDi and MiST"
	for t in mist sidi sidi128; do
		for i in $JTBIN/$t/*.rbf; do
			corename=`basename $i .rbf`
			if jtframe cfgstr ${corename#jt} -o bash -t mister | grep JTFRAME_UNLOCKKEY > /dev/null; then
				rm -v $i;
			fi
		done
	done
	echo "Delete non-arcade PCB schematics"
	wait
	rm -f $JTBIN/sch/{adapter,odyssey,rng}.pdf
	echo "Commit to git"
	mkdir -p pocket/raw/Assets/jtpatreon/common
	echo "beta.bin goes here" > pocket/raw/Assets/jtpatreon/common/README.txt
	rm -f version.log
	git add .
	git commit -m "release for https://github.com/jotego/jtcores/commit/$HASHLONG"
else
	echo "Skipping JTBIN as \$JTBIN is not defined"
	exit 0
fi
cpbeta.sh
rm -rf $DST
