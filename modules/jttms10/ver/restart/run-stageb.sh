#!/usr/bin/env bash
set -euo pipefail

main() {
    local sim_dir module_dir repo_dir source_root out_dir generated_dir obj_dir
    local source_rev baseline_rev arg
    sim_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    module_dir=$(cd -- "$sim_dir/../.." && pwd)
    repo_dir=$(cd -- "$module_dir/../.." && pwd)
    baseline_rev=4b0ae60113440b9011ed74216fab54cd46270955
    source_rev=$baseline_rev
    out_dir=${TMPDIR:-/tmp}/jttms10-stageb-baseline
    while (($#)); do
        arg=$1
        case "$arg" in
            --source-rev)
                (($# >= 2)) || { echo "--source-rev requires a commit" >&2; return 2; }
                source_rev=$2; shift 2 ;;
            --out)
                (($# >= 2)) || { echo "--out requires a directory" >&2; return 2; }
                out_dir=$2; shift 2 ;;
            --help)
                echo "usage: $0 [--source-rev COMMIT] [--out DIRECTORY]"
                return 0 ;;
            *)
                echo "unknown argument: $arg" >&2; return 2 ;;
        esac
    done
    if [[ -e "$out_dir" ]]; then
        if [[ ! -d "$out_dir" || -n "$(find "$out_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
            echo "refusing non-empty or non-directory output path: $out_dir" >&2
            return 2
        fi
    fi
    source_rev=$(git -C "$repo_dir" rev-parse --verify "$source_rev^{commit}")
    mkdir -p "$out_dir"
    out_dir=$(cd -- "$out_dir" && pwd)
    generated_dir="$out_dir/generated"
    obj_dir="$out_dir/obj_dir"
    source_root="$out_dir/source-snapshot"

    set --
    source "$repo_dir/setprj.sh"
    printf '%s\n' "$source_rev" > "$out_dir/source-revision.txt"
    mkdir -p "$source_root"
    git -C "$repo_dir" archive "$source_rev" modules/jttms10 | tar -x -C "$source_root"
    ln -s "$repo_dir/modules/jtframe" "$source_root/modules/jtframe"
    module_dir="$source_root/modules/jttms10"
    printf '%s\n' "$module_dir/hdl" > "$out_dir/rtl-source-dir.txt"
    printf 'git archive %s modules/jttms10\n' "$source_rev" > "$out_dir/source-selection.txt"
    git -C "$repo_dir" status --short -- modules/jttms10/hdl modules/jttms10/ucode \
        > "$out_dir/live-cpu-yaml-status.txt"
    relevant_sources "$module_dir" "$sim_dir" > "$out_dir/input-before.sha256"

    local build_cmd vector_cmd
    build_cmd="bash $module_dir/ver/build.sh $generated_dir"
    vector_cmd="STAGEB_OUT=$generated_dir python3 $sim_dir/stageb_vectors.py"
    printf '%s\n' "$build_cmd" > "$out_dir/module-build-command.txt"
    printf '%s\n' "$vector_cmd" > "$out_dir/vector-command.txt"
    bash "$module_dir/ver/build.sh" "$generated_dir"
    STAGEB_OUT="$generated_dir" python3 "$sim_dir/stageb_vectors.py"
    generated_sources "$generated_dir" > "$out_dir/generated-before.sha256"

    local verilator_args=(--quiet --binary --timing --top-module test -Wno-fatal
        -I"$generated_dir" -I"$module_dir/hdl" --Mdir "$obj_dir")
    verilator "${verilator_args[@]}" "$sim_dir/test-stageb.sv" "$module_dir/hdl"/*.v
    {
        printf '%q ' verilator "${verilator_args[@]}" "$sim_dir/test-stageb.sv" "$module_dir/hdl"/*.v
        printf '\nVerilator version: '
        verilator --version
    } > "$out_dir/verilator-build-command.txt"
    printf 'cd %q && %q\n' "$generated_dir" "$obj_dir/Vtest" > "$out_dir/simulation-command.txt"

    set +e
    (cd "$generated_dir" && "$obj_dir/Vtest") 2>&1 | tee "$out_dir/run.log"
    local sim_status=${PIPESTATUS[0]}
    set -e
    printf 'Verilator test CLI exit status: %d\n' "$sim_status" | tee -a "$out_dir/run.log"
    relevant_sources "$module_dir" "$sim_dir" > "$out_dir/input-after.sha256"
    generated_sources "$generated_dir" > "$out_dir/generated-after.sha256"
    local stable=pass
    if ! cmp -s "$out_dir/input-before.sha256" "$out_dir/input-after.sha256" ||
       ! cmp -s "$out_dir/generated-before.sha256" "$out_dir/generated-after.sha256"; then
        stable=fail
        printf 'SOURCE_STABILITY_FAIL\n' | tee -a "$out_dir/run.log"
    else
        printf 'SOURCE_STABILITY_PASS\n' | tee -a "$out_dir/run.log"
    fi
    STAGEB_OUT="$generated_dir" STAGEB_RESULT_DIR="$out_dir" \
        STAGEB_STATUS="$sim_status" STAGEB_STABLE="$stable" python3 - <<'PY'
import json
import os
from pathlib import Path

out = Path(os.environ["STAGEB_RESULT_DIR"])
generated = Path(os.environ["STAGEB_OUT"])
result = {
    "source_revision": (out / "source-revision.txt").read_text().strip(),
    "source_selection": (out / "source-selection.txt").read_text().strip(),
    "input_manifest_sha256": __import__("hashlib").sha256((out / "input-before.sha256").read_bytes()).hexdigest(),
    "generated_manifest_sha256": __import__("hashlib").sha256((out / "generated-before.sha256").read_bytes()).hexdigest(),
    "frozen_case_manifest": json.loads((generated / "stageb-cases.json").read_text()),
    "commands": {
        "module_build": (out / "module-build-command.txt").read_text().strip(),
        "vector_generation": (out / "vector-command.txt").read_text().strip(),
        "verilator_build": (out / "verilator-build-command.txt").read_text().strip(),
        "simulation": (out / "simulation-command.txt").read_text().strip(),
    },
    "verilator_cli_exit_status": int(os.environ["STAGEB_STATUS"]),
    "source_stability": os.environ["STAGEB_STABLE"],
}
(out / "result.json").write_text(json.dumps(result, indent=2) + "\n")
PY
    [[ $stable == pass ]] || return 125
    return "$sim_status"
}

relevant_sources() {
    local module_dir=$1 sim_dir=$2
    {
        find "$module_dir/hdl" "$module_dir/ucode" -type f -print
    printf '%s\n' "$module_dir/ver/build.sh" \
            "$module_dir/ver/decoder/generate.py" "$module_dir/ver/decoder/dump.sv" \
            "$sim_dir/test-stageb.sv" "$sim_dir/stageb_vectors.py" "$sim_dir/run-stageb.sh"
    } | sort -u | while IFS= read -r file; do sha256sum "$file"; done
}

generated_sources() {
    find "$1" -type f -print | sort | while IFS= read -r file; do sha256sum "$file"; done
}

main "$@"
