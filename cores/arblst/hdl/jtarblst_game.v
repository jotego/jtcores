/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi <andreabogazzi79@gmail.com>
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 17-06-2026 */

module jtarblst_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [13:1] cpu_addr;
wire [ 1:0] cpu_dsn;
wire [ 8:0] hdump;
wire [ 7:0] st_main, st_sub, st_video, slatch0, slatch1;
wire [15:0] vram_dout;
wire        flip, cpu_rnw, sub_rst,
            vram_cs, vctrl_cs, vflag_cs, tctrl_cs,
            shram_cs;

reg game_id = 1'b0;
reg [15:0] thoffs;

always @(posedge clk) if( prog_we && header ) case( prog_addr[3:0] )
    4'd0: game_id <= prog_data[0];
    default:;
endcase

assign debug_view = st_video;
assign dip_flip   = ~flip;
assign mute       = 0;

always @(posedge clk) begin
    thoffs <= game_id ? 16'h1f : 16'h0d;
end

/* verilator tracing_on */
jtarblst_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen8       ( cen8          ),
    .lvbl       ( LVBL          ),

    .rom_addr   ( main_addr     ),
    .ram_addr   ( ram_addr      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dsn    ( cpu_dsn       ),
    .ram_we     ( ram_we        ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),

    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    .ram_dout   ( ram_dout      ),

    // X1-010 sound (main bus)
    .cen_pcm    ( cen_pcm       ),
    .pcm_addr   ( pcm_addr      ),
    .pcm_data   ( pcm_data      ),
    .pcm_cs     ( pcm_cs        ),
    .snd_left   ( pcm_8k        ),
    .snd_right  ( pcm_4k        ),

    // I/O sub-CPU (sub_ctrl_w decoded in main)
    .slatch0    ( slatch0       ),
    .slatch1    ( slatch1       ),
    .sub_rst    ( sub_rst       ),
    .shram_cs   ( shram_cs      ),
    .shram_we   ( shram_we      ),
    .shram_dout ( shram_dout    ),

    // video
    .pal_we     ( pal_we        ),
    .pal_dout   ( pal_dout      ),
    .tctrl_cs   ( tctrl_cs      ),
    .tlv_we     ( tlv_we        ),
    .tlv_dout   ( tlv_dout      ),
    .vram_cs    ( vram_cs       ),
    .vflag_cs   ( vflag_cs      ),
    .vctrl_cs   ( vctrl_cs      ),
    .vram_dout  ( vram_dout     ),

    // cabinet
    .game_id    ( game_id       ),
    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     ),
    .st_dout    ( st_main       ),
    .debug_bus  ( debug_bus     )
);

/* verilator tracing_on */
jtarblst_sub u_sub(
    .rst        ( sub_rst       ),
    .clk        ( clk           ),
    .cen        ( cen8          ),   // 8 MHz crystal cen -> ~2 MHz E (jt65c02 /4)
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .slatch0    ( slatch0       ),
    .slatch1    ( slatch1       ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .subsh_addr ( subsh_addr    ),
    .subsh_din  ( subsh_din     ),
    .subsh_dout ( subsh_dout    ),
    .subsh_we   ( subsh_we      ),

    .hs         ( HS            ),
    .lvbl       ( LVBL          ),
    .st_dout    ( st_sub        )
);

/* verilator tracing_on */
jtcal50_video #(
    .OBJAW ( 13     ), // 16kB sprite RAM + setac bank
    .SCR_EN( 1      ), // X1-001 background layer (draw_background) draws the attract scenery
    .OBJ_LIMIT( 9'h1ff ),
    // MAME visarea rows 16..239 (224 lines) -> vdump 8..231, VS stays centred
    .VB_END  ( 9'd8    ),
    .VB_START( 9'd232  ),
    // set_fg_xoffsets noflip: calibr50 -1, metafox/arbalest 0 -> one count right
    .OBJ_XOFF( 9'h1ff  )
) u_video(
    .rst        ( rst           ),
    // MAME x1_012 set_xoffsets noflip: metafox 16 -> 0x00, arbalest -2 -> 0x12
    .thoffs     ( thoffs        ),
    .clk        ( clk           ),
    .clk_cpu    ( clk           ),
    .cen244     (               ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .hdump      ( hdump         ),
    .flip       ( flip          ),

    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .vram_cs    ( vram_cs       ),
    .vctrl_cs   ( vctrl_cs      ),
    .vflag_cs   ( vflag_cs      ),
    .vram_dout  ( vram_dout     ),

    .col_addr   ( col_addr      ),
    .col_data   ( col_data      ),
    .yram_dout  ( yram_dout     ),
    .yram_we    ( yram_we       ),

    .dma_addr   ( dma_addr      ),
    .dma_din    ( dma_din       ),
    .dma_we     ( dma_we        ),
    .dma_dout   ( dma_dout      ),
    .code_dout  ( code_dout     ),
    .code_addr  ( code_addr     ),

    .tctrl_cs   ( tctrl_cs      ),
    .tvram_addr ( tlrd_addr     ),
    .tvram_dout ( tlrd_data     ),
    .tile_addr  ( tile_addr     ),
    .tile_data  ( tile_data     ),
    .tile_cs    ( tile_cs       ),
    .tile_ok    ( tile_ok       ),

    .pal_addr   ( palrd_addr    ),
    .pal_data   ( pal_data      ),

    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_ok     ( scr_ok        ),
    .scr_cs     ( scr_cs        ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .obj_cs     ( obj_cs        ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .ioctl_addr (ioctl_addr[3:0]),
    .ioctl_din  ( ioctl_din     ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_video      )
);

endmodule
