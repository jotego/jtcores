#!/bin/bash -e
# use lint-one.sh core -u JTFRAME_SKIP
# for cores in development phase

trap "clean_up; exit 1" INT KILL

main() {
    CORE=$1
    shift
    set_target
    read_core_macros

    if must_skip; then
        echo "Skipping $CORE"
        exit 0
    fi

    prepare_test_folder
    cd $TEST_FOLDER
    make_dummy_rom

    run_linter
    check_msg
    clean_up
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