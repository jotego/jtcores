#!/bin/bash -e
# This file is part of JTFRAME.
# JTFRAME program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# JTFRAME program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

# Author: Jose Tejada Gomez. Twitter: @topapate
# Version: 1.0
# Date: 12-1-2023

# Creates the beta zip files from the contents of $JTROOT/release
# Places a copy of the files in $JTROOT and another one, for
# archiving purposes in $JTFRIDAY


main() {
    parse_args $*
    check_jtfriday_defined

    make_temp_folder
    copy_all_targets

    make_zip_files
    archive_zip_files
    clean_up
}

parse_args() {
    FRIDAY="friday"
    while [ $# -gt 0 ]; do
        case "$1" in
            --last)
                FRIDAY="last friday";;
            -h|--help)
                show_help
                exit 0;;
            *)
                echo "Unknown argument $1"
                exit 1;;
        esac
        shift
    done
    SHORTSTAMP=$(date --date="$FRIDAY" +"%y%m%d")
}

show_help() {
    cat<<EOF
cpbeta.sh <hash> [arguments]

Creates zip files for distribution on JTFRIDAY.

-h, --help      This help screen
-l, --last      Use last friday's date, instead of next's
                or latest published date, if it is more recent
                than last friday's
EOF
}

check_jtfriday_defined() {
    if [ ! -d "$JTFRIDAY" ]; then
        cat <<EOF
Missing JTFRIDAY variable pointing to the destination folder
Define it if you want to archive a copy of the zip files there
EOF
        exit 1
    fi
}

make_temp_folder() {
    DEST=`mktemp --directory`
}

copy_all_targets() {
    copy_mister_files
    copy_mist_sidi_files
    copy_pocket_files
}

copy_mister_files() {
    mkdir -p "$DEST"/_Arcade/cores "$DEST/mra"
    mkdir -p $DEST/games/mame
    cp $JTUTIL/jtbeta.zip $DEST/games/mame
    cp $JTBIN/mister/*rbf "$DEST"/_Arcade/cores
}

copy_mist_sidi_files() {
    cp -r $JTBIN/mra/* "$DEST"/_Arcade
    cp -r $JTBIN/{mist,sidi,sidi128,mra} "$DEST"
}

copy_pocket_files() {
    mkdir -p $DEST/pocket/Assets/jtpatreon/common
    cp -r $JTBIN/pocket/raw/* $DEST/pocket
    unzip -q $JTUTIL/jtbeta.zip -d $DEST/pocket/Assets/jtpatreon/common
    mkdir $DEST/pocket/readme
    mv $DEST/pocket/*.txt $DEST/pocket/readme
}

make_zip_files() {
    cd $DEST
    cat >zip_comment <<EOF
      -- JOTEGO --

Beta files for Patreon supporters.
  https://www.patreon.com/jotego

EOF
    betazip jtfriday_${SHORTSTAMP}_mister.zip _Arcade games &
    betazip jtfriday_${SHORTSTAMP}_pocket.zip mra pocket &
    betazip jtfriday_${SHORTSTAMP}_other.zip  mra mist sidi* &
    wait
    cp *.zip $JTROOT
}

betazip() {
    cat $DEST/zip_comment | zip -qr --test --archive-comment -9 $*
}


archive_zip_files() {
    ZIPDEST="$JTFRIDAY"/$SHORTSTAMP
    mkdir -p "$ZIPDEST"
    cp *.zip "$ZIPDEST"
    cp $JTUTIL/jtbeta.zip "$ZIPDEST"
}

clean_up() {
    cd $JTROOT
    rm -rf $DEST
}

main $*