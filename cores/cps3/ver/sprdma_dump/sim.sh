#!/bin/bash
set -e

main() {
    check_env
    parse_args "$@"
    build_sim
    run_dumps
}

check_env() {
    if test -z "$JTROOT" || test -z "$JTFRAME"; then
        echo "ERROR: JTROOT and JTFRAME must be set (source setprj.sh first)."
        exit 1
    fi
}

parse_args() {
    if test -z "$1"; then
        echo "Usage: sim.sh <setname> [dump] [-s dump1,dump2] [-a]"
        exit 1
    fi

    SETNAME="$1"
    shift

    DUMP_LIST=""
    RUN_ALL=0

    if test "$#" -gt 0 && test "${1#-}" = "$1"; then
        DUMP_LIST="$1"
        shift
    fi

    while test "$#" -gt 0; do
        case "$1" in
            -s)
                if test -z "$2"; then
                    echo "ERROR: -s requires a comma-separated dump list"
                    exit 1
                fi
                DUMP_LIST="$2"
                shift 2
                ;;
            -a)
                RUN_ALL=1
                shift
                ;;
            *)
                echo "ERROR: unknown option $1"
                exit 1
                ;;
        esac
    done

    BASE_DIR="$JTROOT/cores/cps3/ver/$SETNAME/dumps"

    if test ! -d "$BASE_DIR"; then
        echo "ERROR: dumps folder not found: $BASE_DIR"
        exit 1
    fi

    if test -z "$DUMP_LIST" && test "$RUN_ALL" -eq 0; then
        echo "No dump folder specified for given setname $SETNAME. All dumps will be tested."
        RUN_ALL=1
    fi

    if test "$RUN_ALL" -eq 1; then
        DUMP_DIRS=$(ls -1 "$BASE_DIR")
    else
        DUMP_DIRS=$(printf '%s' "$DUMP_LIST" | tr ',' ' ')
    fi
}

build_sim() {
    IVERILOG=${IVERILOG:-iverilog}
    VVP=${VVP:-vvp}

    BUILD_DIR=$(mktemp -d)
    GATHER_EXPANDED=$(mktemp)
    trap 'rm -rf "$BUILD_DIR" "$GATHER_EXPANDED"' EXIT

    envsubst < "$JTROOT/cores/cps3/ver/sprdma_dump/gather.f" > "$GATHER_EXPANDED"

    $IVERILOG -g2012 -s test -o "$BUILD_DIR/simv" -f "$GATHER_EXPANDED"
}

run_dumps() {
    for DUMP in $DUMP_DIRS; do
        run_dump "$DUMP"
    done
}

run_dump() {
    local dump_name="$1"
    local dump_path="$BASE_DIR/$dump_name"
    local wave_name

    if test ! -d "$dump_path"; then
        echo "ERROR: dump folder not found: $dump_path"
        exit 1
    fi

    SPRITERAM="$dump_path/spriteram.bin"
    SCENE="$dump_path/scene.bin"
    DMAST="$dump_path/dmast.bin"
    GSCROLL="$dump_path/gscroll.bin"

    if test ! -f "$SPRITERAM" || test ! -f "$SCENE" || test ! -f "$DMAST" || test ! -f "$GSCROLL"; then
        echo "ERROR: missing required dump files in $dump_path"
        exit 1
    fi

    echo "Running dump test: $SETNAME/$dump_name"
    $VVP -lxt "$BUILD_DIR/simv" \
        +SPRITERAM="$SPRITERAM" \
        +SCENE="$SCENE" \
        +DMAST="$DMAST" \
        +GSCROLL="$GSCROLL"

    wave_name="sprdma_${SETNAME}_${dump_name}.vcd"
    if test -f test.lxt; then
        mv test.lxt "$wave_name"
        echo "Waveform: $wave_name"
    fi
}

main "$@"
