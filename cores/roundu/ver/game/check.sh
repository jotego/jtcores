#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 18-10-2026

set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
export JTROOT="$(cd ../../../.. && pwd -P)"
export JTFRAME="$JTROOT/modules/jtframe"
export CORES="$JTROOT/cores"
export JTBIN="$JTROOT/release"
export MODULES="$JTROOT/modules"

"$JTFRAME/bin/jtframemac" mem roundu --target mister --local --inc > mem-generation.log 2>&1
"$JTFRAME/bin/jtframemac" cfgstr roundu --target mister --output iverilog > defines.f

iverilog -g2012 -s download_tb -c defines.f -I . -I "$JTFRAME/hdl/inc" \
    -o download.vvp download_tb.v ../../hdl/jtroundu_download.v \
    "$JTFRAME/hdl/sdram/jtframe_dwnld.v" > download-build.log 2>&1
vvp download.vvp | tee download.log
../hdl/test.sh
./sim.sh -lint > lint.log 2>&1
