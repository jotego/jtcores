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

    test_mister_cdc_hook

    local jtcore_path=$JTFRAME/bin/jtcore
    local entry_root=$test_dir/nocopy-entry
    mkdir -p "$entry_root/modules" "$entry_root/stub-bin" "$entry_root/cores/probe/cfg" "$entry_root/cores/probe/mister/output_files"
    ln -s "$JTFRAME" "$entry_root/modules/jtframe"
    printf 'CORENAME=JTPROBE\n' > "$entry_root/cores/probe/cfg/macros.def"
    cat > "$entry_root/stub-bin/jtframe" <<'EOF'
#!/bin/bash
[[ "$1" = cfgstr ]] || exit 91
printf 'CORENAME=JTPROBE\n'
EOF
    chmod +x "$entry_root/stub-bin/jtframe"
    printf 'fixture-rbf\n' > "$entry_root/cores/probe/mister/output_files/jtprobe.rbf"
    local output
    output=$( (
        cd "$entry_root/cores/probe"
        JTROOT=$entry_root JTFRAME=$entry_root/modules/jtframe CORES=$entry_root/cores \
            JTBIN=$entry_root/release JTCORE_DEFAULT= OUTPUT_FOLDER= PATH=$entry_root/stub-bin:$PATH \
            "$jtcore_path" --skip --nocopy --target mister probe
    ) 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    [[ "$output" != *'publish_mister_build_evidence: command not found'* ]]
    [[ -s "$entry_root/cores/probe/mister/output_files/jtprobe.rbf" && ! -e "$entry_root/release/mister/jtprobe.rbf" ]]
    echo 'PASS actual jtcore --skip --nocopy completion does not require build-evidence helper or copy the RBF'

    output=$( (
        cd "$entry_root/cores/probe"
        JTROOT=$entry_root JTFRAME=$entry_root/modules/jtframe CORES=$entry_root/cores \
            JTBIN=$entry_root/release JTCORE_DEFAULT= OUTPUT_FOLDER= PATH=$entry_root/stub-bin:$PATH \
            "$jtcore_path" --skip --target mister probe
    ) 2>&1) || { printf '%s\n' "$output" >&2; exit 1; }
    [[ "$output" != *'publish_mister_build_evidence: command not found'* ]]
    cmp -s "$entry_root/cores/probe/mister/output_files/jtprobe.rbf" "$entry_root/release/mister/jtprobe.rbf"
    echo 'PASS actual jtcore copy path preserves RBF bytes without build-evidence helper'
}

test_mister_cdc_hook() {
    local saved_frame=$JTFRAME saved_path=$PATH
    local bin="$test_dir/cdc-quartus/bin" wrong="$test_dir/cdc-other" frame="$test_dir/cdc-frame" helper_dir="$test_dir/cdc-frame/target/mister/syn"
    mkdir -p "$bin" "$wrong" "$frame/bin" "$helper_dir"
    : > "$helper_dir/jtframe_mister_cdc.tcl"
    cat > "$bin/quartus_sh" <<'EOF'
#!/bin/bash
exit 0
EOF
    cat > "$bin/quartus_sta" <<'EOF'
#!/bin/bash
printf '%s\n' "$PWD|$*" >> "$MOCK_CDC_CALLS"
case "$MOCK_CDC_MODE" in
  pass) echo 'JTFRAME_CDC PASS' ;;
  skip) echo 'JTFRAME_CDC SKIP' ;;
  duplicate) printf '%s\n' 'JTFRAME_CDC PASS' 'JTFRAME_CDC SKIP' ;;
  unknown) echo 'JTFRAME_CDC MAYBE' ;;
  error) echo 'JTFRAME_CDC PASS'; exit 1 ;;
  missing) echo 'unexpected timing output' ;;
esac
EOF
    cat > "$wrong/quartus_sta" <<'EOF'
#!/bin/bash
echo 'wrong Quartus version selected' >&2
exit 1
EOF
    chmod +x "$bin/quartus_sh" "$bin/quartus_sta" "$wrong/quartus_sta"
    export MOCK_CDC_CALLS="$test_dir/cdc-calls" MOCK_CDC_MODE=pass
    JTFRAME=$frame PATH="$wrong:$bin:$saved_path" TARGET=mister corename=probe LOG="$test_dir/cdc-build.log"
    NODBG=--nodbg SKIPTIMING=1 JTFRAME_NOSTA=1 FAIL=1
    run_mister_cdc_audit
    [[ "$FAIL" = 1 ]]
    grep -Fq "$test_dir|-t $helper_dir/jtframe_mister_cdc.tcl probe" "$MOCK_CDC_CALLS"
    [[ -s "$test_dir/cdc-build.cdc.rpt" ]]
    MOCK_CDC_MODE=skip run_mister_cdc_audit
    for MOCK_CDC_MODE in duplicate unknown error missing; do
        if run_mister_cdc_audit; then echo "FAIL CDC audit accepted $MOCK_CDC_MODE" >&2; exit 1; fi
    done
    MOCK_CDC_MODE=pass
    mv "$bin/quartus_sta" "$bin/quartus_sta.saved"
    if run_mister_cdc_audit; then echo 'FAIL missing matching quartus_sta accepted' >&2; exit 1; fi
    mv "$bin/quartus_sta.saved" "$bin/quartus_sta"
    rm "$helper_dir/jtframe_mister_cdc.tcl"
    if run_mister_cdc_audit; then echo 'FAIL missing CDC helper accepted' >&2; exit 1; fi
    TARGET=sidi128 run_mister_cdc_audit
    JTFRAME=$saved_frame PATH=$saved_path TARGET=mist
    unset JTFRAME_NOSTA SKIPTIMING NODBG MOCK_CDC_CALLS MOCK_CDC_MODE
    echo 'PASS MiSTer CDC hook selects matching Quartus, preserves STA failure and fails closed'
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
    if [[ "$1" = -t ]]; then
        echo "project-open-close" >> calls
        sed -i 's/17.0.2 Standard Edition/20.1.1 Lite Edition/' "$BUILDDIR/$corename.qsf"
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
