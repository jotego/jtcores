#!/bin/bash
set -euo pipefail
seicro_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd -P)
seicro_test_dir="$seicro_repo/cores/seicro/ver/hdl/build"
mkdir -p "$seicro_test_dir"
export JTROOT="$seicro_repo"
export JTFRAME="$JTROOT/modules/jtframe"
export CORES="$JTROOT/cores"
export MODULES="$JTROOT/modules"
export JTBIN="$JTROOT/release"
seicro_native=${JTFRAME_NATIVE:-$CORES/seicro/ver/game/jtframemac}
if [ ! -x "$seicro_native" ]; then seicro_native=$JTFRAME/bin/jtframemac; fi
cd -- "$seicro_test_dir"
"$seicro_native" mem seicro -t mister --local --inc
"$seicro_native" files plain seicro -t mister -m IVERILOG,SIMULATION --local > generation.log
"$seicro_native" cfgstr seicro -t mister -o iverilog > definitions.txt
python3 - <<'PY'
from pathlib import Path
import os
files = []
for line in Path('files').read_text().splitlines():
    file = Path(line.strip())
    if not file.is_absolute():
        file = Path(os.environ['JTROOT']) / file
    if file.suffix.lower() in ['.v', '.sv'] and file.resolve() not in files:
        files.append(file.resolve())
Path('rtl.f').write_text('\n'.join(map(str, files))+'\n')
PY
for top in jtseicro_game jtseicro_game_sdram; do
    iverilog -g2012 -DSIMULATION -DIVERILOG -s "$top" -I. -I"$JTFRAME/hdl/inc" \
        -f definitions.txt -c rtl.f -o elaboration
    printf 'PASS elaboration: %s\n' "$top"
done
for top in decode_tb cab_tb main_tb mcu_tb nsc8105_tb nvram_tb nvram_io_tb; do
    iverilog -g2012 -DSIMULATION -DIVERILOG -s "$top" -I. -I"$JTFRAME/hdl/inc" \
        -o test -f definitions.txt -c rtl.f "$CORES/seicro/ver/hdl/$top.v"
    vvp test
done
iverilog -g2012 -DSIMULATION -DIVERILOG -s nvram_tb -Pnvram_tb.NSC=1 \
    -I. -I"$JTFRAME/hdl/inc" -o nvram_nsc_test -f definitions.txt -c rtl.f \
    "$CORES/seicro/ver/hdl/nvram_tb.v"
vvp nvram_nsc_test
iverilog -g2012 -DSIMULATION -DIVERILOG -s video_tb -Pvideo_tb.WITH_SPRITES=1 \
    -I. -I"$JTFRAME/hdl/inc" -o test -f definitions.txt -c rtl.f \
    "$CORES/seicro/ver/hdl/video_tb.v"
vvp test
printf 'a7\n' > seicro_portb.hex
iverilog -g2012 -DSIMULATION -DIVERILOG -DNOMAIN -DNOSOUND -s scene_tb \
    -I. -I"$JTFRAME/hdl/inc" -o scene_test -f definitions.txt -c rtl.f \
    "$CORES/seicro/ver/hdl/scene_tb.v"
vvp scene_test
iverilog -g2012 -DSIMULATION -DIVERILOG -DNOMAIN -DNOSOUND -s header_tb \
    -I. -I"$JTFRAME/hdl/inc" -o header_test -f definitions.txt -c rtl.f \
    "$CORES/seicro/ver/hdl/header_tb.v"
vvp header_test
iverilog -g2012 -DSIMULATION -DIVERILOG -DNOMAIN -s flip_tb \
    -I. -I"$JTFRAME/hdl/inc" -o flip_test -f definitions.txt -c rtl.f \
    "$CORES/seicro/ver/hdl/flip_tb.v"
vvp flip_test
