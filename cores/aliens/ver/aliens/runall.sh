#!/bin/bash

main() {
    parse_args $*
    simulate_all_scenes
    save_scenes_in_folder
    report_bad_scenes
}

parse_args() {
    BAD=
    VERBOSE=
    ARGS=()
    while [ $# -gt 0 ]; do
        case $1 in
            -v|--verbose)
                VERBOSE=1;;
            *) ARGS+=("$1");;
        esac
        shift
    done
}

simulate_scene() {
    if ! sim.sh -s $(basename $i) --batch "${ARGS[@]}"; then
        BAD="$(basename $i) $BAD"
    fi
}

simulate_all_scenes() {
    for i in scenes/*; do
        if [ "$VERBOSE" = 1 ]; then
            simulate_scene
        else
            simulate_scene > /dev/null 2>&1
        fi
    done
}

remove_old_folder() {
    if [ -d all ]; then
        rm -rf all.old
        mv all all.old
    fi
}

save_scenes_in_folder() {
    remove_old_folder
    mkdir all
    find scenes -name "*jpg" | xargs -I_ mv _ all
    (find scenes -name "*crc" | xargs cat)>all/crc
}

report_bad_scenes() {
    if [ ! -z "$BAD" ]; then
        echo "Bad scenes: $BAD"
    fi
}

main $*