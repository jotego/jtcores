#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 07-11-2026
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
build_dir="$repo_root/cores/geebee/ver/geebee/build"
mkdir -p "$build_dir"

docker run --rm --pull=never --entrypoint /bin/bash \
    -v "$repo_root:/src:ro" -v "$build_dir:/out" \
    jotego/simulator:arm64 -lc '
set -euo pipefail
apt-get update -qq
apt-get install -y -qq --no-install-recommends ghdl >/tmp/ghdl-install.log
cd /tmp
for file in T80_ALU.vhd T80_Reg.vhd T80_MCode.vhd T80.vhd T80s.vhd; do
    ghdl -a -fsynopsys -fexplicit "/src/modules/jtframe/hdl/cpu/t80/$file"
done
ghdl --synth --out=verilog -fsynopsys -fexplicit -gMode=2 T80s > /out/T80s.v
'
