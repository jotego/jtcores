#!/bin/bash -e
# Make a release to JTBIN from GitHub builds

source jtrelease-funcs

trap clean_up ERR

HASH=
LAST=
SKIPROM=--skipROM
VERBOSE=

while [ $# -gt 0 ]; do
	case "$1" in
		-l|--local)
			unset JTBIN;;
		--last)
			LAST="--last";;
		--host)
			shift
			export MRHOST=$1;;
		-r|--rom)
			SKIPROM=;;
		-v|--verbose)
			VERBOSE=1;;
		-h|--help)
			show_help
			exit 0;;
		*) if [[ -z "$HASH" && ${1:0:1} != - ]]; then
			HASH=`git rev-parse --short $1`
			HASH=${HASH:0:7}
		else
			echo "Do not know what to do with arguments $HASH and $1"
			exit 1
		fi
	esac
	shift
done

check_jtbin

REF=`get_valid_zip $HASH`
DST=`mktemp -d /tmp/jt_XXXXXX`

clone_repo $HASH $DST
HASHLONG=`get_full_hash`

recompile_tool jtframe
recompile_tool jtutil
unzip_release $REF $DST

echo "Copying to $JTBIN"
cd $JTBIN
clean_jtbin
refresh_schematics

cd $DST
regenerate_mra
cd $JTBIN
copy_rbf $DST
make_all_pocket_zips
make_md5_reference_file
# note that the beta zip files are generated before deleting
# the mist and sidi beta files from JTBIN
cpbeta.sh $LAST
remove_mist_betas
make_game_list
make_sound_balance_audit
make_pocket_beta_helper
commit_release
tag_release_in_jtcores
clean_up
