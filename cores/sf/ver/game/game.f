../../hdl/jtsf_game.v
../../hdl/jtsf_video.v
../../hdl/jtsf_colmix.v
../../hdl/jtsf_main.v
../../hdl/jtsf_sound.v
../../hdl/jtsf_adpcm.v
../../hdl/jtsf_scroll.v
../../../biocom/hdl/jtbiocom_sound.v
../../../modules/jtgng_timer.v
../../../modules/jtgng_tile4.v
$JTFRAME/hdl/sdram/jtframe_dwnld.v
$JTFRAME/hdl/video/jtframe_vtimer.v
$JTFRAME/hdl/video/jtframe_tilebuf.v
$JTFRAME/hdl/cpu/jtframe_68kdma.v
$JTFRAME/hdl/jtframe_z80wait.v
$JTFRAME/hdl/jtframe_ff.v
$JTFRAME/hdl/cpu/jtframe_z80.v

# SDRAM
-F $JTFRAME/hdl/sdram/jtframe_sdram64.f

$JTFRAME/hdl/ram/jtframe_dual_ram.v
$JTFRAME/hdl/ram/jtframe_ram.v
$JTFRAME/hdl/sound/jtframe_mixer.v
-F ../../../modules/jtgng_video.f
# -F ../../../modules/jtgng_sound.f
$JTFRAME/hdl/clocking/jtframe_cen96.v
$JTFRAME/hdl/clocking/jtframe_cen48.v
$JTFRAME/hdl/clocking/jtframe_cen24.v
$JTFRAME/hdl/video/jtframe_blank.v
# 68000
$JTFRAME/hdl/cpu/jtframe_68kdma.v
$JTFRAME/hdl/cpu/jtframe_68kdtack.v

# FIR
-F $JTFRAME/hdl/sound/jtframe_uprate2_fir.f