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
../../../modules/jtframe/hdl/sdram/jtframe_dwnld.v
../../../modules/jtframe/hdl/video/jtframe_vtimer.v
../../../modules/jtframe/hdl/video/jtframe_tilebuf.v
../../../modules/jtframe/hdl/cpu/jtframe_68kdma.v
../../../modules/jtframe/hdl/jtframe_z80wait.v
../../../modules/jtframe/hdl/jtframe_ff.v
../../../modules/jtframe/hdl/cpu/jtframe_z80.v

# SDRAM
-F ../../../modules/jtframe/hdl/sdram/jtframe_sdram_bank.f

../../../modules/jtframe/hdl/ram/jtframe_dual_ram.v
../../../modules/jtframe/hdl/ram/jtframe_ram.v
../../../modules/jtframe/hdl/sound/jtframe_mixer.v
-F ../../../modules/jtgng_video.f
# -F ../../../modules/jtgng_sound.f
../../../modules/jtframe/hdl/clocking/jtframe_cen96.v
../../../modules/jtframe/hdl/clocking/jtframe_cen48.v
../../../modules/jtframe/hdl/clocking/jtframe_cen24.v
../../../modules/jtframe/hdl/video/jtframe_blank.v
# 68000
../../../modules/jtframe/hdl/cpu/jtframe_68kdma.v
../../../modules/fx68k/fx68kAlu.sv
../../../modules/fx68k/fx68k.sv
../../../modules/fx68k/uaddrPla.sv
# FIR
-F ../../../modules/jtframe/hdl/sound/jtframe_uprate2_fir.f