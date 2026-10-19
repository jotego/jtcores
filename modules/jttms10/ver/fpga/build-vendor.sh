#!/bin/bash
# Preserve this build directory between runs to retain generated IP and databases.
set -euo pipefail

main() {
    if [[ $# != 3 ]]; then
        echo "Usage: $0 VENDOR.zip BUILD_DIR prepare|generate|compile|rapid" >&2
        exit 2
    fi
    local archive build_dir action=$3 source_dir stamp
    archive=$(realpath -e -- "$1")
    mkdir -p -- "$2"
    build_dir=$(cd -- "$2" && pwd)
    source_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    stamp=$build_dir/.jtcores-tei0022-vendor
    check_inputs "$archive" "$action"
    if [[ ! -f "$stamp" ]]; then
        [[ -z $(ls -A -- "$build_dir") ]] || {
            echo "Refusing to initialize a nonempty, unmarked build directory" >&2
            exit 1
        }
        unzip -q "$archive" 'test_board/source_files/quartus/*' -d "$build_dir/vendor"
        cp -a -- "$build_dir/vendor/test_board/source_files/quartus/." "$build_dir/"
        cp -- "$source_dir/create-vendor.tcl" "$build_dir/"
        sha256sum -- "$archive" > "$stamp"
    fi
    [[ $(cut -d ' ' -f 1 "$stamp") == "$vendor_sha" ]] || {
        echo "Build directory belongs to a different vendor source" >&2
        exit 1
    }
    cd -- "$build_dir"
    mkdir -p logs
    /opt/quartus_free/quartus_sh --version > logs/quartus-version.txt
    if [[ ! -f test_board.qpf ]]; then
        timed project /opt/quartus_free/quartus_sh -t create-vendor.tcl
    fi
    case "$action" in
        prepare) ;;
        generate) generate ;;
        compile) generate; timed compile /opt/quartus_free/quartus_sh --flow compile test_board ;;
        rapid)
            [[ -s output_files/test_board.sof && -d db ]] || {
                echo "Rapid Recompile requires a completed compilation in this directory" >&2
                exit 1
            }
            timed rapid /opt/quartus_free/quartus_sh --flow recompile test_board
            ;;
    esac
}

check_inputs() {
    vendor_sha=182d6f3017186ddc3e486abf047ca66276462fac67b788367b0c7288838c5d90
    [[ $(sha256sum -- "$1" | cut -d ' ' -f 1) == "$vendor_sha" ]] || {
        echo "Vendor ZIP SHA-256 mismatch" >&2
        exit 1
    }
    case "$2" in prepare|generate|compile|rapid) ;; *) echo "Unknown action: $2" >&2; exit 2 ;; esac
    [[ -x /opt/quartus_free/quartus_sh && -x /usr/bin/time ]] || {
        echo "Need /opt/quartus_free/quartus_sh and /usr/bin/time" >&2
        exit 1
    }
}

generate() {
    local qsys=/opt/intelFPGA_lite/20.1/quartus/sopc_builder/bin
    if [[ ! -f QSYS_test_board.qsys ]]; then
        timed qsys-create "$qsys/qsys-script" \
            '--cmd=set ::args {5CSEMA5F31C8|Cyclone V|TEI0022_dual_IS43TR16256BL-125KBLI|no_project}' \
            "--script=$PWD/QSYS_test_board.tcl" "--search-path=$PWD/ip/**/*,\$"
    fi
    if [[ ! -f .qsys-generated ]]; then
        timed qsys-generate "$qsys/qsys-generate" "$PWD/QSYS_test_board.qsys" \
            --synthesis=VHDL -bsf "--search-path=$PWD/**/*,\$"
        [[ -s QSYS_test_board/synthesis/QSYS_test_board.qip ]]
        touch .qsys-generated
    fi
}

timed() {
    local stage=$1 log status=0
    shift
    log="logs/$(date -u +%Y%m%dT%H%M%S)-$stage"
    printf '%q ' "$@" > "$log.command"
    printf '\n' >> "$log.command"
    /usr/bin/time -f 'seconds=%e\nexit_code=%x' -o "$log.time" \
        "$@" > "$log.log" 2>&1 || status=$?
    cat "$log.time"
    if (( status )); then
        tail -n 30 "$log.log" >&2
        return "$status"
    fi
}

main "$@"
