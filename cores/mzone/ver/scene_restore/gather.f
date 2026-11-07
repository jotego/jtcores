jtmzone_game_sdram.vh
+incdir+.
+incdir+$JTFRAME/hdl/inc
+define+SIMULATION
+define+NOSOUND
+define+JTFRAME_MEMGEN
+define+JTFRAME_PXLCLK
+define+JTFRAME_IOCTL_RD=7172
+define+JTFRAME_COLORW=4
+define+JTFRAME_BUTTONS=2
+define+OBJ_START=77824
+define+SCR_START=110592
+define+SND_START=65536
+define+MCU_ROM_START=73728
+define+JTFRAME_PROM_START=126976
$JTROOT/cores/mzone/hdl/jtmzone_game.v
$JTROOT/cores/mzone/hdl/jtmzone_main.v
jtmzone_video_mmr.vh
$JTROOT/cores/mzone/hdl/jtmzone_snd.v
$JTROOT/cores/mzone/hdl/jtmzone_snd_dev.v
$JTROOT/cores/mzone/hdl/jtmzone_video.v
$JTROOT/cores/mzone/hdl/jtmzone_scroll.v
$JTROOT/cores/mzone/hdl/jtmzone_fix.v
$JTROOT/cores/mzone/hdl/jtmzone_obj.v
$JTROOT/cores/mzone/hdl/jtmzone_objdraw.v
$JTROOT/cores/mzone/hdl/jtmzone_colmix.v
$JTFRAME/hdl/clocking/jtframe_cen48.v
$JTFRAME/hdl/cpu/jtframe_z80.v
$JTFRAME/hdl/cpu/t80/T80s.v
$JTFRAME/hdl/sdram/jtframe_romrq_bcache.v
$JTFRAME/hdl/cpu/jtframe_sys6809.v
-y $JTFRAME/hdl
-y $JTFRAME/hdl/video
-y $JTFRAME/hdl/video/tilemap
-y $JTFRAME/hdl/ram
-y $JTFRAME/hdl/sdram
-y $JTFRAME/hdl/sound
-y $JTFRAME/hdl/clocking
-y $JTFRAME/hdl/cpu
$JTFRAME/hdl/ram/jtframe_dual_ram32.v
