#!/bin/bash

main() {
    set -eu
    source "$JTFRAME/bin/jtcore-funcs"
    test_dir=$(mktemp -d)
    trap 'rm -rf -- "$test_dir"' EXIT
    cd "$test_dir"
    TARGET=mister BUILD_MODE=auto corename=probe LOG="$test_dir/build.log" SIM=FALSE
    MODULES="$test_dir/modules" PRJPATH="$test_dir/core"
    mkdir -p "$MODULES" "$PRJPATH/cfg"
    echo 'set_clock_groups -asynchronous' > "$MODULES/test.sdc"
    MOCK_RAPID_STATUS=0 MOCK_COMPILE_STATUS=0
    generate_project
    printf 'set_global_assignment -name VERILOG_FILE first.v\nset_global_assignment -name VERILOG_FILE second.v\n' > files.qip
    echo 'keep_other_setting=on' > quartus.ini

    BUILDDIR=$test_dir CLEAN_BUILD=0 MACROS=
    cache_build_timestamp
    printf '12345\n' > .jtcore-timestamp
    MACROS=
    cache_build_timestamp
    [[ "$BUILD_TIMESTAMP" = 12345 && "$MACROS" = *JTFRAME_TIMESTAMP=12345* ]]
    MACROS='JTFRAME_TIMESTAMP=67890'
    cache_build_timestamp
    [[ "$MACROS" = JTFRAME_TIMESTAMP=67890 ]]
    CLEAN_BUILD=1 MACROS=
    cache_build_timestamp
    [[ "$BUILD_TIMESTAMP" != 12345 ]]
    echo 'PASS cached, explicit, and clean build timestamps'

    compile_quartus
    [[ "$(tail -n 1 calls)" = compile && -s .jtcore-complete ]]
    ! grep -q PARTITION_ probe.qsf
    grep -q keep_other_setting=on quartus.ini
    generate_project
    compile_quartus
    [[ "$(tail -n 1 calls)" = recompile ]]
    echo 'PASS initial full build and subsequent Rapid Recompile'

    tac files.qip > reordered.qip
    mv reordered.qip files.qip
    generate_project
    compile_quartus
    [[ "$(tail -n 1 calls)" = recompile ]]
    echo 'PASS regenerated file-list ordering does not invalidate reuse'

    echo 'set_false_path -from test_clock' >> "$MODULES/test.sdc"
    generate_project
    compile_quartus
    [[ "$(tail -n 1 calls)" = compile ]]
    echo 'PASS changed shared constraints invalidate Rapid Recompile'

    echo 'set_global_assignment -name SDC_FILE extra.sdc' > "$PRJPATH/cfg/extra.qip"
    generate_project
    compile_quartus
    [[ "$(tail -n 1 calls)" = compile ]]
    echo 'PASS included QIP configuration changes invalidate Rapid Recompile'

    generate_project
    echo 'set_global_assignment -name SEED 2' >> probe.qsf
    compile_quartus
    [[ "$(tail -n 1 calls)" = compile ]]
    echo 'PASS changed settings use full compilation'

    BUILD_MODE=incremental
    generate_project
    compile_quartus
    grep -q PARTITION_HIERARCHY probe.qsf
    grep -q fitter_rapid_recompile=off quartus.ini
    [[ "$(tail -n 1 calls)" = compile ]]
    echo 'PASS incremental flow retains partitions'

    BUILD_MODE=auto
    generate_project
    echo 'set_instance_assignment -name PARTITION_HIERARCHY child -to u_child -section_id child' >> probe.qsf
    compile_quartus
    [[ "$RAPID_RECOMPILE" = 0 ]]
    grep -q u_child probe.qsf
    echo 'PASS child partitions select incremental flow'

    generate_project
    compile_quartus
    generate_project
    MOCK_RAPID_STATUS=1
    compile_quartus
    [[ "$(tail -n 2 calls | tr '\n' ' ')" = 'recompile compile ' ]]
    [[ -s "$test_dir/build.rapid.log" && -s .jtcore-complete ]]
    echo 'PASS failed Rapid Recompile falls back to full compilation'

    generate_project
    MOCK_COMPILE_STATUS=1
    if compile_quartus; then
        echo 'FAIL unsuccessful compilation was accepted' >&2
        exit 1
    fi
    [[ ! -e .jtcore-complete ]]
    echo 'PASS failed compilation invalidates completion marker'

    MOCK_COMPILE_STATUS=0 MOCK_RAPID_STATUS=0
    generate_project
    compile_quartus
    generate_project
    MOCK_UNSUPPORTED=1 MOCK_RAPID_STATUS=1
    compile_quartus
    [[ -s .jtcore-no-rapid ]]
    generate_project
    compile_quartus
    [[ "$RAPID_RECOMPILE" = 0 && "$(tail -n 1 calls)" = compile ]]
    echo 'PASS unsupported Rapid Recompile is remembered'

    MOCK_VERSION=20.1.2
    generate_project
    compile_quartus
    [[ "$RAPID_RECOMPILE" = 1 && ! -e .jtcore-no-rapid ]]
    echo 'PASS compiler changes clear unsupported capability cache'

    TARGET=mist
    generate_project
    compile_quartus
    [[ "$RAPID_RECOMPILE" = 0 ]]
    grep -q PARTITION_HIERARCHY probe.qsf
    echo 'PASS MiST retains the ordinary incremental flow'

    parse_args --clean --incremental
    [[ "$CLEAN_BUILD" = 1 && "$BUILD_MODE" = incremental ]]
    parse_args --rapid
    [[ "$BUILD_MODE" = auto ]]
    echo 'PASS compilation mode options'

    rm files.qip
    if compile_quartus; then
        echo 'FAIL missing generated file list was accepted' >&2
        exit 1
    fi
    echo 'PASS missing generated file list is rejected'

    echo 'Info (332146): Worst-case setup slack is -0.462' > cached.sta.rpt
    echo 'Info (332146): Worst-case hold slack is 0.243' >> cached.sta.rpt
    [[ "$(worst_negative_sta_slack cached.sta.rpt)" = -0.462 ]]
    echo 'PASS cached timing reports retain negative slack'
}

generate_project() {
    cat > probe.qsf <<'EOF'
set_global_assignment -name FAMILY "Cyclone V"
set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top
EOF
}

quartus_sh() {
    if [[ "$1" = --version ]]; then
        echo "Quartus Prime Version ${MOCK_VERSION:-20.1.1}"
        return 0
    fi
    echo "$2" >> calls
    mkdir -p db incremental_db
    if [[ "$2" = recompile ]]; then
        if [[ "${MOCK_UNSUPPORTED:-0}" = 1 ]]; then
            echo 'Error (14711): Rapid Recompile is not supported in the Lite Edition.'
        else
            echo 'Quartus Prime Rapid Recompile was successful'
        fi
        return "$MOCK_RAPID_STATUS"
    fi
    echo 'Quartus Prime Full Compilation was successful'
    return "$MOCK_COMPILE_STATUS"
}

main "$@"
