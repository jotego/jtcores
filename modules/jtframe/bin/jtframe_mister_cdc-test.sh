#!/bin/bash
# Exercise the real CDC helper against an existing, capture-enabled fitted DB.
# Usage: jtframe_mister_cdc-test.sh <passing-build> <revision> [<duplicate-build>|- <revision>|- [<request-duplicate-build> <revision>]]
set -u

main() {
    if [[ $# != 2 && $# != 4 && $# != 6 ]]; then
        echo "Usage: $0 <passing build> <revision> [<duplicate build>|- <revision>|- [<request duplicate build> <revision>]]" >&2
        return 2
    fi
    local build_dir revision helper test_dir
    build_dir=$(realpath "$1") || return 2
    revision=$2
    helper="${JTFRAME:?source setprj.sh first}/bin/jtframe_mister_cdc.tcl"
    test_dir=$(mktemp -d) || return 1
    trap 'rm -r -- "$test_dir"' RETURN
    if [[ ! -f "$build_dir/$revision.qpf" ]]; then
        echo "Missing fitted project: $build_dir/$revision.qpf" >&2
        return 2
    fi
    sed 's/2\.0\*\$period(\$label)/0.0*$period($label)/' "$helper" > "$test_dir/zero-window.tcl"
    sed 's/\*cap_drain_req_sync1_avl\*/\*jtframe_missing_test_anchor\*/' "$helper" > "$test_dir/missing-anchor.tcl"
    if cmp -s "$helper" "$test_dir/zero-window.tcl" || cmp -s "$helper" "$test_dir/missing-anchor.tcl"; then
        echo "Could not construct negative fixtures" >&2
        return 1
    fi
    run_case "$build_dir" "$revision" "$helper" "$test_dir/pass.log" pass 'JTFRAME_CDC PASS' || return 1
    run_case "$build_dir" "$revision" "$test_dir/zero-window.tcl" "$test_dir/window.log" fail 'timing bound violated' || return 1
    run_case "$build_dir" "$revision" "$test_dir/missing-anchor.tcl" "$test_dir/anchor.log" fail 'missing CDC anchor' || return 1
    # Use a disposable DB copy: changing its QSF must never weaken the gate.
    cp -a --reflink=auto "$build_dir" "$test_dir/mode" || return 1
    printf '\nset_global_assignment -name VERILOG_MACRO "JTFRAME_INTERLACED=1"\n' >> "$test_dir/mode/$revision.qsf"
    run_case "$test_dir/mode" "$revision" "$helper" "$test_dir/mode.log" fail 'structures disagree' || return 1
    cp "$build_dir/$revision.qsf" "$test_dir/mode/$revision.qsf"
    sed -i 's/"JTFRAME_REGRESSION=1"/{JTFRAME_REGRESSION=1}/' "$test_dir/mode/$revision.qsf"
    if cmp -s "$build_dir/$revision.qsf" "$test_dir/mode/$revision.qsf"; then
        echo "Could not construct braced-macro fixture" >&2
        return 1
    fi
    printf '\n# set_global_assignment -name VERILOG_MACRO "MISTER_DEBUG_NOHDMI=1"\n' >> "$test_dir/mode/$revision.qsf"
    run_case "$test_dir/mode" "$revision" "$helper" "$test_dir/braced.log" pass 'JTFRAME_CDC PASS' || return 1
    if [[ $# -ge 4 && "$3" != - ]]; then
        test_duplicate_half "$3" "$4" "$helper" "$test_dir" || return 1
    fi
    if [[ $# == 6 ]]; then
        test_duplicate_request "$5" "$6" "$helper" "$test_dir" || return 1
    fi
    echo "CDC fitted-database tests passed"
}

# Optional fixture: a real fit with both source copies of half 1.  Its normal
# HPS timing violation must remain fatal after the duplicate is accepted.
test_duplicate_half() {
    local dir rev helper tmp variant
    dir=$(realpath "$1") || return 2
    rev=$2 helper=$3 tmp=$4
    if [[ ! -f "$dir/$rev.qpf" ]]; then
        echo "Missing duplicate fitted project: $dir/$rev.qpf" >&2
        return 2
    fi
    sed '/set bits(\$bit) 1/i\        if {$bit eq "1"} continue' "$helper" > "$tmp/missing-half.tcl"
    sed 's/~DUPLICATE/~NOT_A_DUPLICATE/g' "$helper" > "$tmp/unknown-suffix.tcl"
    sed 's/\$sb ne \$db/\$sb eq \$db/' "$helper" > "$tmp/cross-bit.tcl"
    for variant in missing-half unknown-suffix cross-bit; do
        if cmp -s "$helper" "$tmp/$variant.tcl"; then
            echo "Could not construct $variant fixture" >&2
            return 1
        fi
    done
    run_case "$dir" "$rev" "$helper" "$tmp/duplicate.log" fail 'CDC synchronous avl_ascal hold violation' || return 1
    run_case "$dir" "$rev" "$tmp/missing-half.tcl" "$tmp/half.log" fail 'missing half_source half bit' || return 1
    run_case "$dir" "$rev" "$tmp/unknown-suffix.tcl" "$tmp/suffix.log" fail 'invalid half control path' || return 1
    run_case "$dir" "$rev" "$tmp/cross-bit.tcl" "$tmp/cross.log" fail 'invalid half control path' || return 1
}

# Optional fixture: a real fit (e.g. arblst seed 0) where Quartus cloned the
# drain request toggle and the clone feeds only same-domain logic.  It must
# pass, and must fail if clones are counted as separate logical sources.
test_duplicate_request() {
    local dir rev helper tmp
    dir=$(realpath "$1") || return 2
    rev=$2 helper=$3 tmp=$4
    if [[ ! -f "$dir/$rev.qpf" ]]; then
        echo "Missing request duplicate fitted project: $dir/$rev.qpf" >&2
        return 2
    fi
    sed 's/regsub {~DUPLICATE\[0-9\]\*\$} \$name {} name/# no clone folding/' "$helper" > "$tmp/no-fold.tcl"
    if cmp -s "$helper" "$tmp/no-fold.tcl"; then
        echo "Could not construct no-fold fixture" >&2
        return 1
    fi
    run_case "$dir" "$rev" "$helper" "$tmp/request-dup.log" pass 'JTFRAME_CDC PASS' || return 1
    run_case "$dir" "$rev" "$tmp/no-fold.tcl" "$tmp/no-fold.log" fail 'uncovered request endpoints' || return 1
}

run_case() {
    local build_dir=$1 revision=$2 script=$3 log=$4 expected=$5 marker=$6 status
    (cd "$build_dir" && quartus_sta -t "$script" "$revision") >"$log" 2>&1
    status=$?
    if [[ "$expected" == pass ]]; then
        if [[ $status != 0 ]] || ! grep -Fxq "$marker" "$log"; then
            cat "$log" >&2
            return 1
        fi
    elif [[ $status == 0 ]] || ! grep -Fq "$marker" "$log" || grep -Eq '^JTFRAME_CDC (PASS|SKIP)$' "$log"; then
        cat "$log" >&2
        return 1
    fi
}

main "$@"
