../../hdl/jtrumble_colmix.v
../../hdl/jtrumble_game.v
../../hdl/jtrumble_main.v
../../hdl/jtrumble_sdram.v
../../hdl/jtrumble_video.v
../../hdl/jtrumble_banks.v
-F $MODULES/jtgng_obj.f
-F $MODULES/jtgng_sound.f
$MODULES/jtgng_char.v
$MODULES/jtgng_scroll.v
$MODULES/jtgng_tile4.v
$MODULES/jtgng_tilemap.v

$MODULES/jt12/hdl/jt12_rst.v
-F $MODULES/jt12/hdl/jt03.f

$JTFRAME/hdl/cpu/mc6809i.v
$JTFRAME/hdl/cpu/jtframe_sys6809.v
$JTFRAME/hdl/video/jtframe_vtimer.v
$JTFRAME/hdl/video/jtframe_blank.v

-F $JTFRAME/hdl/sdram/jtframe_sdram_bank.f
$JTFRAME/hdl/sdram/jtframe_dwnld.v

$JTFRAME/hdl/clocking/jtframe_cen48.v
$JTFRAME/hdl/clocking/jtframe_cen24.v
# $JTFRAME/hdl/jtframe_sh.v
