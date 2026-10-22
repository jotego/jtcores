#!/bin/bash
set -euo pipefail
module_dir=$(cd -- "$(dirname -- "$0")/.." && pwd)
repo_dir=$(cd -- "$module_dir/../.." && pwd)
export JTFRAME="$repo_dir/modules/jtframe"
export MODULES="$repo_dir/modules"
out_dir=${1:-"$module_dir/ver/build"}
mkdir -p "$out_dir"
out_dir=$(cd -- "$out_dir" && pwd)
cd "$out_dir"
python3 "$module_dir/ver/ucode/check_cpu_flow.py" "$module_dir/ucode/tms10.yaml"
"$JTFRAME/bin/jtframe" ucode --list --output tms10 jttms10 tms10
"$JTFRAME/bin/jtframe" ucode --list --output tms10_bus_phase jttms10 bus_phase
if [ -f "$module_dir/ucode/gfx.yaml" ]; then
    "$JTFRAME/bin/jtframe" ucode --list --output tms10_gfx jttms10 gfx
    python3 "$module_dir/ver/gfx/check_targets.py" \
        "$module_dir/ucode/gfx.yaml" "$out_dir/tms10_gfx_param.vh" \
        "$out_dir/tms10_gfx.uc"
    python3 "$module_dir/ver/gfx/check_flow.py" "$module_dir/ucode/gfx.yaml"
fi
python3 "$module_dir/ver/decoder/generate.py" "$module_dir/hdl/jttms10_ctrl.v" "$out_dir" \
    --check "$module_dir/hdl/tms10_dispatch.hex"
