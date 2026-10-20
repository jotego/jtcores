#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 19-10-2026

set -euo pipefail
roundu_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
roundu_image=${JTFRAME_SIM_IMAGE:-jotego/simulator:arm64}
docker image inspect "$roundu_image" >/dev/null
docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$roundu_repo:/jtcores" -w /jtcores/cores/roundu/ver/roundup5 \
    "$roundu_image" -lc '
        set -euo pipefail
        cpu=/jtcores/modules/jtframe/hdl/cpu
        ln -sf "$cpu/nuv30/ucrom.hex" ucrom.hex
        ln -sf "$cpu/nuv30/ucdecode.hex" ucdecode.hex
        verilator --binary --timing --assert -j 4 -Wno-fatal -Mdir obj_main \
            --top-module main_tb -I"$cpu/nuv30" \
            "$cpu/nuv30/v30u_ss_pkg.sv" "$cpu/nuv30/v30u_ucrom.sv" \
            "$cpu/nuv30/v30u_biu.sv" "$cpu/nuv30/v30u_eu.sv" \
            "$cpu/nuv30/v30_core.sv" "$cpu/jtframe_v30.sv" \
            ../../hdl/jtroundu_main.v ../../hdl/jtroundu_v30bus.v \
            ../../hdl/jtroundu_decode.v ../hdl/main_tb.sv > main-build.log 2>&1
        if [ "$#" -ne 0 ]; then
            ./obj_main/Vmain_tb "$@"
        else
            for latency in 0 1 3 7 9 10 12 15 16 20 40; do
                ./obj_main/Vmain_tb "+latency=$latency" > "main-latency-$latency.log"
                tail -5 "main-latency-$latency.log" | head -1
            done
        fi
    ' main-test "$@"
