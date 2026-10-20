#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
python3 program.py
flags=()
build_dir=obj_dir
build_log=build.log
if [ "${1:-}" = --synthesis ]; then
    flags=(-DSYNTHESIS)
    build_dir=obj_dir_synthesis
    build_log=build-synthesis.log
elif [ $# -ne 0 ]; then
    exit 2
fi
verilator --binary --timing --assert -j 4 -Wno-fatal \
    "${flags[@]}" -Mdir "$build_dir" \
    --top-module test -I../../../hdl/cpu/nuv30 \
    ../../../hdl/cpu/nuv30/v30u_ss_pkg.sv \
    ../../../hdl/cpu/nuv30/v30u_ucrom.sv \
    ../../../hdl/cpu/nuv30/v30u_biu.sv \
    ../../../hdl/cpu/nuv30/v30u_eu.sv \
    ../../../hdl/cpu/nuv30/v30_core.sv \
    ../../../hdl/cpu/jtframe_v30.sv test.sv > "$build_log" 2>&1
status=0
for divider in 2 3 6; do
    for waits in 0 1 3; do
        if ! "./$build_dir/Vtest" "+divider=$divider" "+waits=$waits"; then
            status=1
        fi
    done
done
exit "$status"
