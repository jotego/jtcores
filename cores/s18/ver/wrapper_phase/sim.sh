#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source modules/jtframe/bin/setprj.sh >/dev/null
root=$(pwd)
out=${WRAPPER_PHASE_OUT:-/nobackup/tasks/jtcores-180/wrapper-phase}
mkdir -p "$out/src" "$out/obj_dir"
cp cores/s18/ver/wrapper_phase/test.v "$out/src/"
cp cores/s18/ver/wrapper_phase/test.cpp "$out/src/"
cp cores/s18/hdl/jts18_vdp.v cores/s18/hdl/ym7101.v cores/s18/hdl/ym7101_raster.v cores/s18/hdl/ym_lib.v cores/s18/hdl/vram.sv "$out/src/"
go run cores/s18/ver/wrapper_phase/init.go
for f in baseline_jts18_vdp.v baseline_ym7101.v baseline_ym_lib.v baseline_vram.sv; do mv "$f" "$out/src/$f"; done
cp cores/s18/hdl/jts18_vdp_pri_gate.sv cores/s18/hdl/jts18_vdp_pri.sv "$out/src/"
cp cores/s18/hdl/jts18_colmix.v "$out/src/"
cp cores/s16/hdl/jts16_prio.v cores/shanon/hdl/jtshanon_coldac.v "$out/src/"
cp modules/jtframe/hdl/clocking/jtframe_frac_cen.v modules/jtframe/hdl/clocking/jtframe_gated_cen.v \
  modules/jtframe/hdl/clocking/jtframe_freqinfo.v modules/jtframe/hdl/clocking/jtframe_pxlcen.v \
  modules/jtframe/hdl/jtframe_bcd_cnt.v "$out/src/"
cp modules/jtframe/hdl/video/jtframe_vtimer.v "$out/src/"
cp modules/jtframe/hdl/video/jtframe_blank.v "$out/src/"
cp modules/jtframe/hdl/jtframe_sh.v "$out/src/"
cp modules/jtframe/hdl/video/jtframe_short_blank.v modules/jtframe/hdl/video/crosshair/jtframe_crosshair.v \
  modules/jtframe/hdl/video/crosshair/jtframe_crosshair_color.v modules/jtframe/hdl/video/crosshair/jtframe_crosshair_draw.sv \
  modules/jtframe/hdl/video/jtframe_video_counter.v "$out/src/"
verilator --quiet --cc --exe --build --build-jobs "${WRAPPER_PHASE_JOBS:-2}" --timing \
  --top-module test --Mdir "$out/obj_dir" -Wno-fatal -Wno-TIMESCALEMOD \
  -DJTFRAME_PXLCLK=6 -DJTFRAME_SIM96 -DJTFRAME_LIGHTGUN -DSIMULATION -DJTFRAME_MCLK=48000000 \
  -I"$JTFRAME/ver/inc" "$out/src/test.v" "$out/src/test.cpp" "$out/src/jts18_vdp.v" "$out/src/ym7101.v" \
  "$out/src/ym7101_raster.v" "$out/src/ym_lib.v" "$out/src/vram.sv" \
  "$out/src/baseline_jts18_vdp.v" "$out/src/baseline_ym7101.v" "$out/src/baseline_ym_lib.v" "$out/src/baseline_vram.sv" \
  "$out/src/jts18_vdp_pri_gate.sv" "$out/src/jts18_vdp_pri.sv" \
  "$out/src/jts16_prio.v" "$out/src/jtshanon_coldac.v" \
  "$out/src/jts18_colmix.v" \
  "$out/src/jtframe_frac_cen.v" "$out/src/jtframe_gated_cen.v" "$out/src/jtframe_freqinfo.v" \
  "$out/src/jtframe_pxlcen.v" "$out/src/jtframe_bcd_cnt.v" "$out/src/jtframe_vtimer.v" "$out/src/jtframe_blank.v" "$out/src/jtframe_sh.v" \
  "$out/src/jtframe_short_blank.v" "$out/src/jtframe_crosshair.v" "$out/src/jtframe_crosshair_color.v" \
  "$out/src/jtframe_crosshair_draw.sv" "$out/src/jtframe_video_counter.v"
cd "$out"
sha256sum src/* > source-hashes.sha256
{
  echo "baseline_sha=3dc6b88e0204fd3abbb462b34f428757f8596e94"
  echo "candidate_git_head=$(git -C "$root" rev-parse HEAD)"
  echo "simulation_args=$*"
  echo "runner_sha256=$(sha256sum "$root/cores/s18/ver/wrapper_phase/sim.sh" | awk '{print $1}')"
  echo "test_sha256=$(sha256sum src/test.v | awk '{print $1}')"
  echo "verilator=$(verilator --version)"
  echo "build_jobs=${WRAPPER_PHASE_JOBS:-2}"
  echo "clock_setup=JTFRAME MultiClock96 half-period sequence; clk48 is main clock (JTFRAME_SDRAM96/CLK48 absent), old YM internal clock is clk96; framework mixer/tail pxl_cen/pxl2_cen use jtframe_pxlcen frac 1/4 on clk48; current VDP, timer and S16 fixture use generated jtframe_gated_cen W2 NUM1 DEN4 MFREQ48000 with rst/busy=0 on clk48; production S18 tuple adapter uses pxl_48cen (two 25-bit registers, one gated-event latency); paired frac1/4 phase reference is emitted; no synchronizers"
  echo "sample_path=actual jts16_prio + synchronous palette + jtshanon_coldac S16 diagnostic -> production colmix -> no-crop short_blank -> JTFRAME_LIGHTGUN crosshair (all on clk48, drawing disabled)"
  cat source-hashes.sha256
} > manifest.txt
obj_dir/Vtest "$@" | tee run.log
