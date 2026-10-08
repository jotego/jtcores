#!/bin/bash
# use lint-one.sh core -u JTFRAME_SKIP
# for cores in development phase

trap "clean_up; exit 1" INT KILL

main() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
        return 0
    fi
    if [[ -z "$1" ]]; then
        usage >&2
        return 1
    fi

    CORE=$1
    shift
    parse_args "$@"
    set_target

    if must_skip_without_macros; then
        echo "Skipping $CORE"
        exit 0
    fi

    read_core_macros "$FRAME_ARGS" || exit $?

    if must_skip_from_macros; then
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

usage() {
    cat <<'EOF'
Usage: lint-one.sh <core> [options]

Lint one JT core with Verilator.

Options:
  -d, --def <macro>       Define a Verilog macro
  -u, --undef <macro>     Undefine a core macro
      --nodbg             Disable debug features
  -t, --target <target>   Select the target (default: mister)
  -mist|-mister|-pocket|-sidi128
                          Select the target using shorthand
  -h, --help              Show this help and exit
EOF
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
    local core_macros
    core_macros=$(jtframe cfgstr $CORE --output bash --target $TARGET $*) || return $?
    eval "$core_macros"
}

must_skip_without_macros() {
    [[ ! -e $CORES/$CORE/cfg/macros.def || -e $CORES/$CORE/cfg/skip ]]
}

must_skip_from_macros() {
    [[ -v JTFRAME_SKIP ]]
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

main "$@"
