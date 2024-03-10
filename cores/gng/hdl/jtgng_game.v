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
    Date: 27-10-2017 */


module jtgng_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] sdram_din;
wire [12:0] wr_row, cpu_AB;
wire [ 8:0] V, H, wr_col;
wire [ 7:0] cpu_dout, char_dout, scr_dout, st_snd;
wire        char_cs, flip, HINIT;
wire        char_busy, scr_busy, block_flash, preLHBL, preLVBL;
wire        cen6, cen3, cen1p5, cen1p5b,
            LHBL_obj, LVBL_obj,
            RnW, blue_cs, redgreen_cs, bus_ack, bus_req;
// OBJ
wire [ 8:0] obj_AB;
wire        OKOUT, blcnten;
wire [ 7:0] main_ram;
// sound
wire        sres_b;
wire [ 7:0] snd_latch;

wire        scr_cs;
wire [ 8:0] scr_hpos, scr_vpos;

assign block_flash = status[13];
assign dip_flip    = flip;
assign debug_view  = debug_bus[7] ? st_snd :
            { 3'd0, ~sres_b, 2'd0, blcnten, OKOUT };

localparam [25:0]   OBJ_START  = `JTFRAME_BA3_START;

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr >= OBJ_START ) begin
        post_addr[5:1] = {prog_addr[4:1],prog_addr[5]};
    end
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    .cen1p5b( cen1p5b   ),
    // unused
    .cen8   (           ),
    .cen4   (           ),
    .cen12b (           ),
    .cen16  (           ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen4_12(           ),
    .cen16b (           )
);

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( pxl_cen  ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

`ifndef NOMAIN
jtgng_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_dma    ( clk           ),
    .cen6       ( cen6          ),
    // Timing
    .flip       ( flip          ),
    .LVBL       ( LVBL          ),
    .block_flash( block_flash   ),

    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    //.scr_holdn  ( gfx_en[2]     ), // hold scroll latches
    .scr_holdn  ( 1'b1          ), // hold scroll latches
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .dma_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign blue_cs     = 1'b0;
assign redgreen_cs = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 9'd0;
assign scr_vpos    = 9'd0;
`endif

`ifndef NOSOUND
jtgng_sound u_sound (
    .rst            ( rst        ),
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    // Interface with main CPU
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .snd_int        ( V[5]       ),
    // ROM
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .rom_cs         ( snd_cs     ),
    .rom_ok         ( snd_ok     ),
    // sound output
    .fm0            ( fm0        ),
    .fm1            ( fm1        ),
    .psg0           ( psg0       ),
    .psg1           ( psg1       ),
    // debug
    .debug_bus      ( debug_bus  ),
    .debug_view     ( st_snd     ),
    // unused
    .snd2_latch     (            )
);
`else
    assign snd_addr = 0;
    assign snd_cs   = 0;
    assign fm0      = 0;
    assign fm1      = 0;
    assign psg0     = 0;
    assign psg1     = 0;
    assign st_snd   = 0;
`endif

/* verilator tracing_off */
jtgng_video #(.GNGPAL(1)) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( pxl2_cen      ),
    .cen6       ( pxl_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data[23:0]),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // Color Mix
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .gfx_en     ( gfx_en        ),
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // PROM ports used to assign a non-zero starting value to the palette RAM
    .prog_addr  ( prog_addr[7:0]),
    .prom_red_we( prog_we       ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // Unused
    .prom_green_we( 1'd0 ),
    .prom_blue_we ( 1'd0 ),
    .prom_din     ( 4'd0 )
);

endmodule
