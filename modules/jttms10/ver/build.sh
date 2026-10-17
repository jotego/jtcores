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
"$JTFRAME/bin/jtframe" ucode --list --output tms10 jttms10 tms10
python3 "$module_dir/ver/decoder/generate.py" "$module_dir/hdl/jttms10_ctrl.v" "$out_dir" \
    --check "$module_dir/hdl/tms10_dispatch.hex"
