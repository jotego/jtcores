#!/bin/bash
# use lint-one.sh core -u JTFRAME_SKIP
# for cores in development phase

trap "clean_up; exit 1" INT KILL

main() {
    CORE=$1
    shift
    parse_args $*
    set_target
    read_core_macros "$FRAME_ARGS"

    if must_skip; then
        echo "Skipping $CORE"
        exit 0
    fi

    prepare_test_folder
    cd $TEST_FOLDER
    make_dummy_rom

    run_linter "$SIM_ARGS"
    check_msg
    clean_up
}

parse_args() {
    FRAME_ARGS=
    SIM_ARGS=
    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--def) shift
                add_to_both -d $1;;
            -u|--undef) shift
                add_to_both --undef $1;;
            --nodbg)
                add_to_jtframe $1
                add_to_jtsim -d JTFRAME_RELEASE;;
            -o|--output) shift;;
            --tpl) shift
                add_to_jtframe --tpl $1;;
            -t|--target) shift
                TARGET=$1;;
            -mist|-mister|-pocket|-sidi128)
                TARGET=${1#-};;
            *)
                add_to_jtsim $*;;
        esac
        shift
    done
}

add_to_jtframe() {
    FRAME_ARGS+=" $*"
}

add_to_jtsim() {
    SIM_ARGS+=" $*"
}

add_to_both() {
    add_to_jtframe $*
    add_to_jtsim $*
}

set_target() {
    if [ -z "$TARGET" ]; then
        TARGET=mister
    fi
}

read_core_macros() {
    eval `jtframe cfgstr $CORE --output bash --target $TARGET $*`
}

must_skip() {
    [[ ! -e $CORES/$CORE/cfg/macros.def || -e $CORES/$CORE/cfg/skip || -v JTFRAME_SKIP ]]
}

prepare_test_folder() {
    cd $CORES/$CORE
    TEST_FOLDER=ver/lint
    rm -rf $TEST_FOLDER
    mkdir -p $TEST_FOLDER
}

make_dummy_rom() {
    if [ ! -e rom.bin ]; then
        # dummy ROM
        dd if=/dev/zero of=rom.bin count=1 2> /dev/null
        DELROM=
    fi
}

run_linter() {
    jtsim -lint -$TARGET $*
}

check_msg() {
    jtframe msg $CORE
}

clean_up() {
    rm -rf $TEST_FOLDER
}

main $*