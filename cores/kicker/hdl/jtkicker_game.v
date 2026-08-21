/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 11-11-2021 */

module jtkicker_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM offsets
localparam [21:0] SCR_START = `SCR_START,
                  OBJ_START = `OBJ_START,
                  PCM_START = `PCM_START;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
wire        V16;

wire [ 2:0] pal_sel;
wire        cpu_cen;
wire        cpu_rnw, cpu_irqn, cpu_nmin;
wire        vscr_cs, vram_cs, obj1_cs, obj2_cs, flip;
wire [ 7:0] vscr_dout, vcpu_din, obj_dout, cpu_dout;
wire        vsync60;
wire        is_scr, is_obj;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];
assign dip_flip = ~dipsw_c[0];
assign debug_view = {4'hf, dipsw_c};
assign scr_cs = LVBL;
assign pcm_cs = 1;
assign is_scr = ioctl_addr[21:0] >= SCR_START && ioctl_addr[21:0]<OBJ_START;
assign is_obj = ioctl_addr[21:0] >= OBJ_START && ioctl_addr[21:0]<PCM_START;
assign vramrw_din = {2{cpu_dout}};
assign ioctl_din  = 0;

always @(*) begin
    post_addr = prog_addr;
    if( is_scr ) begin
        post_addr[0]   = ~prog_addr[3];
        post_addr[3:1] =  prog_addr[2:0];
    end
    if( is_obj ) begin
        post_addr[0]   = ~prog_addr[3];
        post_addr[1]   = ~prog_addr[4];
        post_addr[5:2] =  { prog_addr[5], prog_addr[2:0] }; // making [5] explicit for now
    end
end

`MAIN_MODULE u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cpu4_cen       ( cpu4_cen      ),
    .cpu_cen        ( cpu_cen       ),
    .ti1_cen        ( ti1_cen       ),
    .ti2_cen        ( ti2_cen       ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .cab_1p         ( cab_1p[1:0]   ),
    .coin           ( coin[1:0]     ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vscr_cs        ( vscr_cs       ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vcpu_din      ),
    .vscr_dout      ( vscr_dout     ),

    .obj1_cs        ( obj1_cs       ),
    .obj2_cs        ( obj2_cs       ),
    .obj_dout       ( obj_dout      ),
    // GFX configuration
    .pal_sel        ( pal_sel       ),
    .flip           ( flip          ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    .V16            ( V16           ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       ),
    // Sound
`ifdef PCM
    .pcm_addr       ( pcm_addr      ),
    .pcm_data       ( pcm_data      ),
    .pcm_ok         ( pcm_ok        ),
    .vlm            ( vlm           ),
    .ti1            ( ti1           )
`else
    .ti1            ( ti1           ),
    .ti2            ( ti2           )
`endif
);

`ifndef PCM
    assign pcm_addr = 0;
`endif

`VIDEO_MODULE u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .pal_sel    ( pal_sel   ),
    .flip       ( flip      ),

    // CPU interface
    .cpu_addr   ( main_addr[10:0]  ),
    .cpu_dout   ( cpu_dout   ),
    .cpu_rnw    ( cpu_rnw    ),
    .vcpu_din   ( vcpu_din   ),
    .vramrw_we  ( vramrw_we  ),
    .vramrw_dout( vramrw_dout),
    .vramrw_addr( vramrw_addr),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( vscr_cs   ),
    .vram_addr  ( vram_addr ),
    .vram_dout  ( vram_dout ),
    .vscr_dout  ( vscr_dout ),
    // Objects
    .obj1_cs    ( obj1_cs   ),
    .obj2_cs    ( obj2_cs   ),
    .obj_dout   ( obj_dout  ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr[10:0] ),
    .prom_en    ( prom_we   ),

    // Scroll
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_ok     ( scr_ok    ),
    // Objects
    .obj_addr   (objrom_addr),
    .obj_data   (objrom_data),
    .obj_cs     ( objrom_cs ),
    .obj_ok     ( objrom_ok ),

    .V16        ( V16       ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

endmodule
