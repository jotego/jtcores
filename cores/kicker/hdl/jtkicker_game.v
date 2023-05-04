/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 11-11-2021 */

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
wire [ 7:0] vscr_dout, vram_dout, obj_dout, cpu_dout;
wire        vsync60;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];
assign dip_flip = ~dipsw_c[0];
assign debug_view = {4'hf, dipsw_c};
assign scr_cs = LVBL;
assign pcm_cs = 1;

always @(*) begin
    post_addr = prog_addr;
    if( ioctl_addr[21:0] >= SCR_START && ioctl_addr[21:0]<OBJ_START ) begin
        post_addr[0]   = ~prog_addr[3];
        post_addr[3:1] =  prog_addr[2:0];
    end
    if( ioctl_addr[21:0] >= OBJ_START && ioctl_addr[21:0]<PCM_START ) begin
        post_addr[0]   = ~prog_addr[3];
        post_addr[1]   = ~prog_addr[4];
        post_addr[5:2] =  { prog_addr[5], prog_addr[2:0] }; // making [5] explicit for now
    end
end

`ifndef NOMAIN
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
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vscr_cs        ( vscr_cs       ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),
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
`endif
    .snd            ( snd           ),
    .sample         ( sample        ),
    .peak           ( game_led      )
);
`else
    assign main_cs = 0;
    assign obj1_cs = 0;
    assign obj2_cs = 0;
    assign vram_cs = 0;
    assign flip    = 0;
    assign cpu_rnw = 1;
    assign cpu_addr = 0;
    assign cpu_dout = 0;
`endif

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
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( vscr_cs   ),
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