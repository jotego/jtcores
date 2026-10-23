/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

`timescale 1ns/1ps
module test;
`ifdef TEST_PAL
pal_tb u_test();
`elsif TEST_PAL_PHASE
pal_phase_tb u_test();
`elsif TEST_WAIT
wait_tb u_test();
`elsif TEST_MR
mr_tb u_test();
`elsif TEST_BLANKING
blanking_tb u_test();
`elsif TEST_COLMIX
colmix_tb u_test();
`elsif TEST_DECODE
decode_tb u_test();
`elsif TEST_CAB
cab_tb u_test();
`elsif TEST_MAIN
main_tb u_test();
`elsif TEST_MCU
mcu_tb u_test();
`elsif TEST_NSC
nsc8105_tb u_test();
`elsif TEST_MCU_DECODE
m6802_decode_tb u_test();
`elsif TEST_MCU_COMPAT
m6802_compat_tb u_test();
`elsif TEST_AUDIO
audio_tb u_test();
`elsif TEST_AUDIO_MIX
audio_mix_tb u_test();
`elsif TEST_AUDIO_NOSOUND
audio_mix_tb u_test();
`elsif TEST_RESET
reset_tb u_test();
`elsif TEST_NVRAM_IO
nvram_io_tb u_test();
`elsif TEST_SCENE
scene_tb u_test();
`elsif TEST_HEADER
header_tb u_test();
`elsif TEST_FLIP
flip_tb u_test();
`elsif TEST_VIDEO
video_tb u_test();
`elsif TEST_SPRITES
video_tb #(
    .WITH_SPRITES ( 1 )
) u_test();
`elsif TEST_COMPARE_6802
m6802_compare_tb #(
    .NSC ( 0 )
) u_test();
`elsif TEST_COMPARE_NSC
m6802_compare_tb #(
    .NSC ( 1 )
) u_test();
`elsif TEST_MR_6802
mcu_mr_tb #(
    .NSC ( 0 )
) u_test();
`elsif TEST_MR_NSC
mcu_mr_tb #(
    .NSC ( 1 )
) u_test();
`elsif TEST_NVRAM_6802
nvram_tb #(
    .NSC ( 0 )
) u_test();
`elsif TEST_NVRAM_NSC
nvram_tb #(
    .NSC ( 1 )
) u_test();
`elsif TEST_BUS
m6802_bus_tb u_test();
`elsif TEST_MAIN_WAIT_0
main_wait_tb #(
    .MODE ( 0 )
) u_test();
`elsif TEST_MAIN_WAIT_1
main_wait_tb #(
    .MODE ( 1 )
) u_test();
`elsif TEST_MAIN_WAIT_2
main_wait_tb #(
    .MODE ( 2 )
) u_test();
`elsif TEST_MAIN_WAIT_3
main_wait_tb #(
    .MODE ( 3 )
) u_test();
`elsif TEST_BUS_0_0
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 0 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_1
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 1 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_2
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 2 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_3
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 3 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_4
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 4 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_5
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 5 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_6
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 6 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_0_7
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 7 ),
    .HOST_STALL ( 0 )
) u_test();
`elsif TEST_BUS_1_0
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 0 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_1
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 1 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_2
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 2 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_3
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 3 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_4
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 4 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_5
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 5 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_6
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 6 ),
    .HOST_STALL ( 1 )
) u_test();
`elsif TEST_BUS_1_7
m6802_bus_tb #(
    .WITH_MR    ( 1 ),
    .PHASE      ( 7 ),
    .HOST_STALL ( 1 )
) u_test();
`else
initial $fatal(1,"Select a Seicro test with --macros TEST_<name>");
`endif
endmodule
