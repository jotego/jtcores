/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_game(
    `include "jtframe_game_ports.inc"
);
wire [8:0] hdump, scrx;
wire [7:0] scry, pal_addr, mmr_din, st_main;
wire       flip, sound_en, sha_cs, sha_ok, a76, tigerh;

assign dip_flip   = flip;
assign debug_view = 0;
assign palr_addr  = pal_addr;
assign palg_addr  = pal_addr;
assign palb_addr  = pal_addr;

`ifdef JTFRAME_IOCTL_RD
assign ioctl_din = ioctl_addr[13:0]>=14'd10240 ? mmr_din : 8'd0;
`endif

jtslap_header u_header(
    .clk      ( clk            ),
    .header   ( header         ),
    .prog_we  ( prog_we        ),
    .prog_addr( ioctl_addr[3:0]),
    .prog_data( prog_data      ),
    .a76      ( a76            ),
    .tigerh   ( tigerh         )
);

jtslap_main u_main(
    .rst        ( rst             ),
    .clk        ( clk             ),
    .pxl_cen    ( pxl_cen         ),
    .cpu_cen    ( cpu_cen         ),
    .mcu_cen    ( mcu_cen         ),
    .LVBL       ( LVBL            ),
    .hdump      ( hdump           ),
    .dip_pause  ( dip_pause       ),
    .a76        ( a76             ),
    .tigerh     ( tigerh          ),
    .cpu_addr   ( cpu_addr        ),
    .cpu_dout   ( cpu_dout        ),
    .ram_we     ( ram_we          ),
    .sha_we     ( sha_we          ),
    .objram_we  ( objram_we       ),
    .scrram_we  ( scrram_we       ),
    .fixram_we  ( fixram_we       ),
    .ram_dout   ( ram_dout        ),
    .sha_dout   ( sha_dout        ),
    .objram_dout( objram_dout     ),
    .scrram_dout( scrram_dout     ),
    .fixram_dout( fixram_dout     ),
    .sound_en   ( sound_en        ),
    .sha_cs     ( sha_cs          ),
    .sha_ok     ( sha_ok          ),
    .scrx       ( scrx            ),
    .scry       ( scry            ),
    .flip       ( flip            ),
    .mcu_addr   ( mcu_addr        ),
    .mcu_data   ( mcu_data        ),
    .main_addr  ( main_addr       ),
    .main_cs    ( main_cs         ),
    .main_data  ( main_data       ),
    .main_ok    ( main_ok         ),
    .ioctl_addr ( ioctl_addr[1:0] ),
    .ioctl_din  ( mmr_din         ),
    .debug_bus  ( debug_bus       ),
    .st_dout    ( st_main         )
);

jtslap_sound u_sound(
    .rst       ( rst              ),
    .clk       ( clk              ),
    .snd_cen   ( snd_cen          ),
    .free_cen  ( mcu_cen          ),
    .psg_cen   ( psg_cen          ),
    .sound_en  ( sound_en         ),
    .tigerh    ( tigerh           ),
    .sha_cs    ( sha_cs           ),
    .sha_ok    ( sha_ok           ),
    .ram_addr  ( sndram_addr      ),
    .ram_dout  ( sndram_dout      ),
    .ram_data  ( sha2sndram_data  ),
    .ram_we    ( sndram_we        ),
    .snd_addr  ( snd_addr         ),
    .snd_cs    ( snd_cs           ),
    .snd_data  ( snd_data         ),
    .snd_ok    ( snd_ok           ),
    .dipsw     ( dipsw[15:0]      ),
    .joystick1 ( joystick1[5:0]   ),
    .joystick2 ( joystick2[5:0]   ),
    .cab_1p    ( cab_1p[1:0]      ),
    .coin      ( coin[1:0]        ),
    .psg1      ( psg1             ),
    .psg2      ( psg2             )
);
`ifdef SIMSCENE
/* verilator tracing_on */
`endif

jtslap_video u_video(
    .rst      ( rst               ),
    .clk      ( clk               ),
    .pxl_cen  ( pxl_cen           ),
    .HS       ( HS                ),
    .VS       ( VS                ),
    .LHBL     ( LHBL              ),
    .LVBL     ( LVBL              ),
    .hdump    ( hdump             ),
    .scrx     ( scrx              ),
    .scry     ( scry              ),
    .flip     ( flip              ),
    .fixv_addr( fixv_addr         ),
    .scrv_addr( scrv_addr         ),
    .fixv_data( fixram2fixv_data   ),
    .scrv_data( scrram2scrv_data   ),
    .objv_addr( objv_addr         ),
    .objv_data( objram2objv_data   ),
    .fix_addr ( fix_addr          ),
    .fix_cs   ( fix_cs            ),
    .fix_data ( fix_data          ),
    .fix_ok   ( fix_ok            ),
    .scr_addr ( scr_addr          ),
    .scr_cs   ( scr_cs            ),
    .scr_data ( scr_data          ),
    .scr_ok   ( scr_ok            ),
    .obj_addr ( obj_addr          ),
    .obj_cs   ( obj_cs            ),
    .obj_data ( obj_data          ),
    .obj_ok   ( obj_ok            ),
    .pal_addr ( pal_addr          ),
    .palr_data( palr_data         ),
    .palg_data( palg_data         ),
    .palb_data( palb_data         ),
    .red      ( red               ),
    .green    ( green             ),
    .blue     ( blue              ),
    .gfx_en   ( gfx_en            )
);
endmodule
