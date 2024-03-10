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
    Date: 26-3-2022 */

module jtpinpon_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM offsets
localparam [21:0] SCR_START   =  `SCR_START,
                  OBJ_START   =  `OBJ_START;

localparam [24:0] PROM_START  =  `JTFRAME_PROM_START;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 2:0] dipsw_c; // The bit 3 is not connected on the board
wire        V16;

wire        cpu_cen;
wire        cpu_rnw, cpu_irqn, cpu_nmin;
wire        vram_cs, oram_cs, flip;
wire [ 7:0] vram_dout, obj_dout, cpu_dout;
wire        vsync60;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[18:0];
assign dip_flip = flip;
assign debug_view= 0;

wire        is_char = ioctl_addr[21:0] >= SCR_START && ioctl_addr[21:0]<OBJ_START;
wire        is_obj  = ioctl_addr[21:0] >= OBJ_START && ioctl_addr[21:0]<PROM_START[21:0];

always @(*) begin
    pre_addr = ioctl_addr;
    if( is_char ) begin
        pre_addr[0]   =  ioctl_addr[3];
        pre_addr[3:1] =  ioctl_addr[2:0]^3'd1;
    end
    if( is_obj ) begin
        pre_addr[0]   = ~ioctl_addr[3];
        pre_addr[1]   = ~ioctl_addr[4];
        pre_addr[5:2] =  { ioctl_addr[5], ioctl_addr[2:0] }; // making [5] explicit for now
    end
end

`ifndef NOMAIN
jtpinpon_main u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cpu_cen        ( cpu_cen       ),
    .ti1_cen        ( ti1_cen       ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),

    .oram_cs        ( oram_cs       ),
    .obj_dout       ( obj_dout      ),
    // GFX configuration
    .flip           ( flip          ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    .V16            ( V16           ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       ),
    .dip_test       ( dip_test      ),
    // Sound
    .snd            ( ti1           )
);
`else
    assign cpu_rnw   = 1;
    assign cpu_dout  = 0;
    assign vram_cs   = 0;
    assign oram_cs   = 0;
    assign snd       = 0;
    assign sample    = 0;
    assign flip      = 0;
`endif

jtpinpon_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .flip       ( flip      ),

    // CPU interface
    .cpu_addr   ( main_addr[10:0]  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vram_dout  ( vram_dout ),
    // Objects
    .oram_cs    ( oram_cs   ),
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
    .obj_addr   ( objrom_addr),
    .obj_data   ( objrom_data),
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
    .gfx_en     ( gfx_en    )
);

endmodule
