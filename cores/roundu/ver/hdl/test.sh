#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
for unit in decode video bg mix; do
    if [ "$unit" = decode ]; then
        roundu_sources=(decode_tb.v ../../hdl/jtroundu_decode.v)
    elif [ "$unit" = mix ]; then
        roundu_sources=(mix_tb.v ../../hdl/jtroundu_mix.v)
    else
        roundu_sources=("${unit}_tb.v" ../../hdl/jtroundu_video.v ../../hdl/jtroundu_text.v
            ../../hdl/jtroundu_road.v ../../hdl/jtroundu_bg.v ../../../../modules/jtframe/hdl/video/tilemap/*.v)
    fi
    iverilog -g2012 -s "${unit}_tb" -o "$unit.vvp" "${roundu_sources[@]}"
    if [ "$unit" = bg ]; then
        vvp bg.vvp +SCROLL=355
        vvp bg.vvp +SCROLL=450
    else
        vvp "$unit.vvp"
    fi
done
python3 ../game/obj_oracle.py
iverilog -g2012 -DSIMULATION -s obj_tb -o ../roundup5/obj-unit/obj.vvp \
    obj_tb.v ../../hdl/jtroundu_obj.v \
    ../../../../modules/jtframe/hdl/ram/jtframe_obj_buffer.v \
    ../../../../modules/jtframe/hdl/ram/jtframe_dual_ram.v
(
    cd ../roundup5/obj-unit
    vvp obj.vvp +BANK=0 +WAIT=0 | tee bank0-wait0.log
    vvp obj.vvp +BANK=0 +WAIT=5 | tee bank0-wait5.log
    vvp obj.vvp +BANK=1 +WAIT=5 | tee bank1-wait5.log
)
python3 ../game/road_oracle.py
iverilog -g2012 -s road_tb -o ../roundup5/road-unit/road.vvp road_tb.v ../../hdl/jtroundu_road.v
(
    cd ../roundup5/road-unit
    vvp road.vvp +BANK=0 +ENABLE=1 | tee bank0.log
    vvp road.vvp +BANK=1 +ENABLE=1 | tee bank1.log
    vvp road.vvp +BANK=1 +ENABLE=0 | tee disabled.log
)
