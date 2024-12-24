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
    Date: 6-8-2021 */

module jtexed_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 0;
assign dwnld_busy = ioctl_rom;
assign debug_view = 0;

wire [8:0] V;
wire [8:0] H;

wire [12:0] cpu_AB;
wire [ 7:0] cpu_dout, char_dout;
wire [15:0] scr2_hpos;
wire [10:0] scr1_hpos, scr1_vpos;
wire        snd_cs, map1_cs, map2_cs;
wire        char_cs, blue_cs, redgreen_cs;
wire        flip;
wire        rd, cpu_cen;
wire        char_busy;
wire        scr1_ok, scr2_ok, map1_ok, map2_ok, char_ok;
wire [ 2:0] scr1_pal, scr2_pal;

localparam OBJW=14;  // 32 kB

// ROM data
wire [15:0] char_data, map2_data;
wire [ 7:0] map1_data;
wire [31:0] scr1_data, scr2_data;
wire [15:0] obj_data;
wire [ 7:0] main_data;
wire [ 7:0] snd_data;

// ROM address
wire [16:0] main_addr;
wire [14:0] snd_addr;

wire [13:0] map1_addr;
wire [11:0] map2_addr;

wire [12:0] char_addr;
wire [13:0] scr1_addr;
wire [12:0] scr2_addr;
wire [OBJW-1:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;

wire main_ok, snd_ok, obj_ok, obj_ok0;
wire cen12, cen8, cen6, cen3, cen1p5;

wire char_on, scr1_on, scr2_on, obj_on;

// PROMs
localparam PROM_IRQ = 8;
reg  [11:0] prom_we;
wire        promsel_we;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign sample=1'b1;

assign {dipsw_b, dipsw_a} = dipsw[15:0];

always @(*) begin
    prom_we = 0;
    if( promsel_we ) prom_we[ prog_addr[11:8] ] = 1;
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    // unused:
    .cen16  (           ),
    .cen8   ( cen8      ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen16b (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

wire RnW;
// sound
wire sres_b, snd_int;
wire [7:0] snd_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [ 7:0] main_ram;

localparam        CPU_OFFSET  = 0,
                  SND_OFFSET  = `SND_START  >> 1,
                  MAP1_OFFSET = `MAP_START  >> 1,
                  MAP2_OFFSET =  (`MAP_START+25'h4000)>>1,
                  CHAR_OFFSET = `CHAR_START >> 1,
                  SCR1_OFFSET = `SCR1_START >> 1,
                  SCR2_OFFSET = `SCR2_START >> 1,
                  OBJ_OFFSET  = `OBJ_START  >> 1,
                  PROM_OFFSET = `PROM_START;

// Address transformations for optimum SDRAM download
wire [21:0] pre_prog;
reg  [21:0] prog_reg;
reg  [25:0] pre_io;

assign prog_addr = prog_reg;

always @(*) begin
    // IOCTL
    pre_io = ioctl_addr;
    if( ioctl_addr>=(MAP2_OFFSET<<1) && ioctl_addr<(CHAR_OFFSET<<1) ) // Map 2
        pre_io = { ioctl_addr[25:7], ioctl_addr[5:0], ioctl_addr[6] };

//    if ( ioctl_addr>=(SCR1_OFFSET<<1) && ioctl_addr<(SCR2_OFFSET<<1) )  // Scroll 1
//        pre_io = { ioctl_addr[24:7], ioctl_addr[5:2], ioctl_addr[6], ioctl_addr[1:0] };

    if( ioctl_addr>=(SCR2_OFFSET<<1) && ioctl_addr<(OBJ_OFFSET<<1) )  // Scroll 2
        pre_io = { ioctl_addr[25:8], ioctl_addr[5:1], ioctl_addr[7:6], ioctl_addr[0] };

    // Programming address
    prog_reg = pre_prog;
    if( pre_prog>=OBJ_OFFSET && pre_prog<PROM_OFFSET ) // OBJ
        prog_reg = { pre_prog[21:6], pre_prog[4:1], pre_prog[5], pre_prog[0] };

    if( pre_prog>=SCR1_OFFSET && pre_prog<SCR2_OFFSET ) // SCR1
        prog_reg = { pre_prog[21:6], pre_prog[4:1], pre_prog[5], pre_prog[0] };

end

wire [7:0] nc;

jtframe_dwnld #(
    .PROM_START(PROM_OFFSET),
    .SWAB      (          1)  // regular byte order
) u_dwnld(
    .clk          ( clk          ),
    .ioctl_rom    ( ioctl_rom    ),
    .ioctl_addr   ( pre_io       ),
    .ioctl_dout   ( ioctl_dout   ),
    .ioctl_wr     ( ioctl_wr     ),
    .prog_addr    ( pre_prog     ),
    .prog_data    ({nc,prog_data}),
    .prog_mask    ( prog_mask    ), // active low
    .prog_we      ( prog_we      ),
    .prom_we      ( promsel_we   ),
    .header       (              ),
    .sdram_ack    ( sdram_ack    ),
    .gfx8_en      ( 1'b0         ),
    .gfx16_en     ( 1'b0         )
);

`ifndef NOMAIN

jtcommnd_main #(.GAME(3)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cen_sel    ( 1'b0          ), // 3MHz CPU
    // Timing
    .flip       (               ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd2_latch (               ),
    .snd_int    ( snd_int       ),
    // Palette - unused
    .redgreen_cs(               ),
    .blue_cs    (               ),
    // Layer enable bits
    .char_on    ( char_on       ),
    .scr1_on    ( scr1_on       ),
    .scr2_on    ( scr2_on       ),
    .obj_on     ( obj_on        ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( 8'd0          ),
    .scr_cs     (               ),
    .scr_busy   ( 1'b0          ),
    .scr_hpos   ( scr1_hpos     ),
    .scr_vpos   ( scr1_vpos     ),
    .scr1_pal   ( scr1_pal      ),
    .scr2_pal   ( scr2_pal      ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // PROM 6L (interrupts)
    .prog_addr  ( prog_addr[7:0]),
    .prom_6l_we ( prom_we[PROM_IRQ]),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr1_hpos   = 0;
assign scr1_vpos   = 0;
assign cpu_cen     = cen3;
`endif

jt1942_sound #(.EXEDEXES(1)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .sres_b         ( 1'b1           ),
    .game_id        ( 2'd0           ),
    .main_dout      ( cpu_dout       ),
    .main_latch0_cs ( 1'b0           ),
    .main_latch1_cs ( 1'b0           ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( snd_int        ),
    .rom_cs         ( snd_cs         ),
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_ok         ( snd_ok         ),
    .snd            ( snd            ),
    .sample         (                ),
    .peak           ( game_led       ),
    // pins used for Higemaru but unused here
    .main_a0        ( 1'b0           ),
    .main_ay0_cs    ( 1'b0           ),
    .main_ay1_cs    ( 1'b0           ),
    .main_wr_n      ( 1'b1           )
);

jtexed_video #(
    .OBJW   ( OBJW      )
)
u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( dip_flip      ),
    .cpu_dout   ( cpu_dout      ),
    // Layer enable
    .char_on    ( char_on       ),
    .scr1_on    ( scr1_on       ),
    .scr2_on    ( scr2_on       ),
    .obj_on     ( obj_on        ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL 1 - ROM
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1_ok    ( scr1_ok       ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr1_pal   ( scr1_pal      ),
    .map1_addr  ( map1_addr     ), // 16kB in 8 bits or 8kW in 16 bits
    .map1_data  ( map1_data     ),
    .map1_cs    ( map1_cs       ),
    .map1_ok    ( map1_ok       ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_pal   ( scr2_pal      ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2_ok    ( scr2_ok       ),
    .map2_addr  ( map2_addr     ), // 8kB in 8 bits or 4kW in 16 bits
    .map2_data  ( map2_data     ),
    .map2_cs    ( map2_cs       ),
    .map2_ok    ( map2_ok       ),
    // OBJ
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // PROMs
    .prog_addr  ( prog_addr[7:0]),
    .prom_we    ( prom_we       ),
    .prom_din   ( prog_data     ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // Debug
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( 13              ), // Char
    .SLOT1_AW    ( 14              ), // Scroll 1
    .SLOT2_AW    ( 12              ), // Scroll 2 Map
    .SLOT3_AW    ( 13              ), // Scroll 2
    .SLOT4_AW    ( 14              ), // Scroll 1 Map
    .SLOT6_AW    ( 15              ), // Sound
    .SLOT7_AW    ( 17              ), // Main
    .SLOT8_AW    ( OBJW            ), // OBJ

    .SLOT0_DW    ( 16              ), // Char
    .SLOT1_DW    ( 32              ), // Scroll 1
    .SLOT2_DW    ( 16              ), // Scroll 2 Map
    .SLOT3_DW    ( 32              ), // Scroll 2
    .SLOT4_DW    (  8              ), // Scroll 1 Map
    .SLOT6_DW    (  8              ), // Sound
    .SLOT7_DW    (  8              ), // Main
    .SLOT8_DW    ( 16              ), // OBJ

    .SLOT0_OFFSET( CHAR_OFFSET[21:0] ),
    .SLOT1_OFFSET( SCR1_OFFSET[21:0] ),
    .SLOT2_OFFSET( MAP2_OFFSET[21:0] ),
    .SLOT3_OFFSET( SCR2_OFFSET[21:0] ),
    .SLOT4_OFFSET( MAP1_OFFSET[21:0] ),
    .SLOT6_OFFSET( SND_OFFSET[21:0]  ),
    .SLOT7_OFFSET( CPU_OFFSET[21:0]  ),
    .SLOT8_OFFSET( OBJ_OFFSET[21:0]  )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ), // Char
    .slot1_cs    ( LVBL          ), // Scroll 1
    .slot2_cs    ( map2_cs       ), // Map 2
    .slot3_cs    ( LVBL          ), // Scroll 2
    .slot4_cs    ( map1_cs       ), // Map 1
    .slot5_cs    ( 1'b0          ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ), // OBJ

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr1_ok       ),
    .slot2_ok    ( map2_ok       ),
    .slot3_ok    ( scr2_ok       ),
    .slot4_ok    ( map1_ok       ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr1_addr     ),
    .slot2_addr  ( map2_addr     ),
    .slot3_addr  ( scr2_addr     ),
    .slot4_addr  ( map1_addr     ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr1_data     ),
    .slot2_dout  ( map2_data     ),
    .slot3_dout  ( scr2_data     ),
    .slot4_dout  ( map1_data     ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_rd    ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule
