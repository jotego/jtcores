#!/bin/bash -e
# Make a release to JTBIN from GitHub builds

source jtrelease-funcs

trap clean_up ERR

parse_args $*
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
