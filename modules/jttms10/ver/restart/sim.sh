#!/usr/bin/env bash
set -euo pipefail

main() {
    local repo_dir module_dir source_module source_repo sim_dir out_dir generated_dir obj_dir rtl_dir bench
    sim_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
    module_dir=$(cd -- "$sim_dir/../.." && pwd)
    repo_dir=$(cd -- "$module_dir/../.." && pwd)
    out_dir=${1:-${TMPDIR:-/tmp}/jttms10-restart-tests}
    mkdir -p "$out_dir"
    out_dir=$(cd -- "$out_dir" && pwd)
    generated_dir="$out_dir/generated"
    obj_dir="$out_dir/obj_dir"
    source_module=${JTTMS10_RESTART_MODULE_DIR:-$module_dir}
    source_repo=$(cd -- "$source_module/../.." && pwd)
    rtl_dir=${JTTMS10_RESTART_RTL_DIR:-$source_module/hdl}
    bench=${JTTMS10_RESTART_BENCH:-$sim_dir/test.sv}

    # Use the same project environment as a normal module build, while keeping
    # every generated file outside the shared ver/build directory.
    set --
    source "$repo_dir/setprj.sh"
    if [[ -n ${JTTMS10_RESTART_SOURCE_REV:-} ]]; then
        printf '%s\n' "$JTTMS10_RESTART_SOURCE_REV" > "$out_dir/source-revision.txt"
    else
        git -C "$repo_dir" rev-parse HEAD > "$out_dir/source-revision.txt"
    fi
    printf '%s\n' "$rtl_dir" > "$out_dir/rtl-source-dir.txt"
    printf 'bash %q %q\n' "$source_module/ver/build.sh" "$generated_dir" \
        > "$out_dir/module-build-command.txt"
    printf '%s\n' "$repo_dir" > "$out_dir/setprj-root.txt"
    make_input_manifest "$source_module" "$sim_dir" "$bench" > "$out_dir/input-before.sha256"
    git -C "$repo_dir" status --short -- modules/jttms10/ucode \
        > "$out_dir/ucode-working-tree.txt"
    local verilator_args=(--quiet --binary --timing --top-module test
        -Wno-fatal -I"$generated_dir" -I"$rtl_dir" --Mdir "$obj_dir")
    if [[ -z ${JTTMS10_RESTART_RTL_DIR:-} && -z ${JTTMS10_RESTART_MODULE_DIR:-} ]]; then
        verilator_args+=(-DRESTART_HAS_PEEK)
        git -C "$repo_dir" status --short -- modules/jttms10/hdl \
            > "$out_dir/rtl-working-tree.txt"
    else
        printf 'external RTL snapshot; exact source revision recorded above\n' \
            > "$out_dir/rtl-working-tree.txt"
    fi
    if [[ -n ${JTTMS10_RESTART_DEFINE:-} ]]; then
        verilator_args+=("-D${JTTMS10_RESTART_DEFINE}")
    fi
    if [[ -n ${JTTMS10_RESTART_MODULE_DIR:-} ]]; then
        export JTROOT="$source_repo" MODULES="$source_repo/modules"
    fi
    bash "$source_module/ver/build.sh" "$generated_dir"
    make_generated_manifest "$generated_dir" > "$out_dir/generated-before.sha256"

    verilator "${verilator_args[@]}" "$bench" "$rtl_dir"/*.v
    {
        printf '%q ' verilator "${verilator_args[@]}" "$bench" "$rtl_dir"/*.v
        printf '\n'
        printf 'Verilator version: '
        verilator --version
    } > "$out_dir/build-command.txt"
    printf 'cd %q && %q\n' "$generated_dir" "$obj_dir/Vtest" > "$out_dir/run-command.txt"
    set +e
    (cd "$generated_dir" && "$obj_dir/Vtest") 2>&1 | tee "$out_dir/run.log"
    local sim_status=${PIPESTATUS[0]}
    set -e
    printf 'Verilator test CLI exit status: %d\n' "$sim_status" | tee -a "$out_dir/run.log"
    make_input_manifest "$source_module" "$sim_dir" "$bench" > "$out_dir/input-after.sha256"
    make_generated_manifest "$generated_dir" > "$out_dir/generated-after.sha256"
    if ! cmp -s "$out_dir/input-before.sha256" "$out_dir/input-after.sha256" ||
       ! cmp -s "$out_dir/generated-before.sha256" "$out_dir/generated-after.sha256"; then
        printf 'SOURCE_STABILITY_FAIL: an input or generated ROM changed during the run\n' \
            | tee -a "$out_dir/run.log"
        return 125
    fi
    printf 'SOURCE_STABILITY_PASS: input and generated ROM hashes unchanged\n' \
        | tee -a "$out_dir/run.log"
    RESTART_RESULT_DIR="$out_dir" RESTART_SIM_STATUS="$sim_status" \
        RESTART_SOURCE_REV="$(cat "$out_dir/source-revision.txt")" \
        python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path

out = Path(os.environ["RESTART_RESULT_DIR"])
def read(name):
    return (out / name).read_text().strip()
def sha256(name):
    return hashlib.sha256((out / name).read_bytes()).hexdigest()

result = {
    "source_revision": os.environ["RESTART_SOURCE_REV"],
    "source_module": read("rtl-source-dir.txt").removesuffix("/hdl"),
    "rtl_directory": read("rtl-source-dir.txt"),
    "input_manifest_sha256": sha256("input-before.sha256"),
    "generated_rom_manifest_sha256": sha256("generated-before.sha256"),
    "module_build_command": read("module-build-command.txt"),
    "verilator_build_command": read("build-command.txt"),
    "simulation_command": read("run-command.txt"),
    "cli_exit_status": int(os.environ["RESTART_SIM_STATUS"]),
    "source_stability": "pass",
}
(out / "result.json").write_text(json.dumps(result, indent=2) + "\n")
PY
    return "$sim_status"
}

make_input_manifest() {
    local source_module=$1 sim_dir=$2 bench=$3
    {
        find "$source_module/hdl" "$source_module/ucode" "$source_module/ver" \
            -type f ! -path '*/build/*' -print
        printf '%s\n' "$bench" "$sim_dir/sim.sh"
    } | sort -u | while IFS= read -r path; do sha256sum "$path"; done
}

make_generated_manifest() {
    local generated_dir=$1
    find "$generated_dir" -type f -print | sort | while IFS= read -r path; do
        sha256sum "$path"
    done
}

main "$@"
