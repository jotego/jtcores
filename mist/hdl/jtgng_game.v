/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */
    
module jtgng_game(
    input           rst,
    input           soft_rst,
    input           clk,        // 24   MHz
    input           cen6,       //  6   MHz
    input           cen3,       //  3   MHz
    input           cen1p5,     //  1.5 MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    // cabinet I/O
    input   [7:0]   joystick1,
    input   [7:0]   joystick2,  
    // SDRAM interface
    input           SDRAM_CLK,      // SDRAM Clock 81 MHz
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CKE,      // SDRAM Clock Enable
    // ROM load
    input           downloading,
    input   [24:0]  romload_addr,
    input   [15:0]  romload_data,
    // DEBUG
    input           enable_char,
    input           enable_obj,
    input           enable_scr,
    // DIP switches
    input           dip_game_mode,
    input           dip_attract_snd,
    input           dip_upright,
    // Sound output
    output  signed [15:0] ym_snd,
    output          sample
);

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout;
wire rd;
wire char_mrdy, scr_mrdy;
wire [12:0] char_addr;
wire [ 7:0] chram_dout,scram_dout;
wire [15:0] chrom_data;
wire rom_ready;

reg rst_game=1'b1;
reg rst_aux;

always @(posedge clk)
    if( rst || !rom_ready ) begin
        {rst_game,rst_aux} <= 2'b11;
    end
    else begin
        {rst_game,rst_aux} <= {rst_aux, downloading };
    end

jtgng_timer u_timer(
    .clk       ( clk      ),
    .clk_en    ( cen6     ),
    .rst       ( rst      ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LVBL      ( LVBL     ),
    .Vinit     (          )
);

wire RnW;
wire [3:0] char_pal;

wire [14:0] scr_addr;
wire [23:0] scr_dout;

wire [3:0] cc;
wire blue_cs;
wire redgreen_cs;
wire [ 5:0] obj_pxl;

wire bus_ack, bus_req;
wire [16:0] main_addr;
wire [ 7:0] main_dout;
wire [15:0] sdram_din;
wire [12:0] wr_row;
wire [ 8:0] wr_col; 
wire        main_cs;
// OBJ  
wire [ 8:0] obj_AB;
wire OKOUT;
wire [7:0] main_ram;
wire blcnten;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire scr_cs, scrpos_cs;

jtgng_main u_main(
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .rst        ( rst_game      ),
    .soft_rst   ( soft_rst      ),
    .ch_mrdy    ( char_mrdy     ),
    .scr_mrdy   ( scr_mrdy      ),
    .char_dout  ( chram_dout    ),
    .scr_dout   ( scram_dout    ),
    // bus sharing
    .ram_dout   ( main_ram      ),
    .obj_AB     ( obj_AB        ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    
    .LVBL       ( LVBL          ),
    .main_cs    ( main_cs       ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .flip       ( flip          ),
    .bus_ack    ( bus_ack       ),
    .cpu_AB     ( cpu_AB        ),
    .RnW        ( RnW           ),
    .rom_addr   ( main_addr     ),
    .rom_dout   ( main_dout     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),   
    // DIP switches
    .dip_flip       ( 1'b0      ),
    .dip_game_mode  ( dip_game_mode     ),
    .dip_attract_snd( dip_attract_snd   ),
    .dip_upright    ( dip_upright       )
);

wire [15:0] obj_addr;
wire [15:0] obj_dout;

wire [14:0] snd_addr;
wire [ 7:0] snd_dout;
`ifndef NOSOUND
jtgng_sound u_sound (
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    .rst            ( rst_game   ),
    .soft_rst       ( soft_rst   ),
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .V32            ( V[5]       ),
    .rom_addr       ( snd_addr   ),
    .rom_dout       ( snd_dout   ),
    .rom_cs         (            ),
    .ym_snd         ( ym_snd     ),
    .sample         ( sample     ) 
);
`else 
assign snd_addr = 15'd0;
`endif

jtgng_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_mrdy  ( char_mrdy     ),
    .char_addr  ( char_addr     ),
    .chrom_data ( chrom_data    ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),    
    .scram_dout ( scram_dout    ),    
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_dout      ),   
    .scr_mrdy   ( scr_mrdy      ), 
    // OBJ
    .HINIT      ( HINIT         ),    
    .obj_AB     ( obj_AB        ),    
    .main_ram   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .obj_addr   ( obj_addr      ),
    .objrom_data( obj_dout      ),    
    // Color Mix
    .LHBL       ( LHBL          ),       
    .LVBL       ( LVBL          ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),    
    .enable_char( enable_char   ),
    .enable_obj ( enable_obj    ),
    .enable_scr ( enable_scr    ),    
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )    
);

jtgng_rom u_rom (
    .clk        ( SDRAM_CLK     ), // 96MHz = 32 * 6 MHz -> CL=2
    .clk24      ( clk           ),
    .cen6       ( cen6          ),
    .H          ( H[2:0]        ),
    .rst        ( rst           ),
    .char_addr  ( char_addr     ),
    .main_addr  ( main_addr     ),
    .snd_addr   ( snd_addr      ),
    .obj_addr   ( obj_addr      ),
    .scr_addr   ( scr_addr      ),

    .char_dout  ( chrom_data    ),
    .main_dout  ( main_dout     ),
    .snd_dout   ( snd_dout      ),
    .obj_dout   ( obj_dout      ),
    .scr_dout   ( scr_dout      ),
    .ready      ( rom_ready     ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_DQML ( SDRAM_DQML    ),
    .SDRAM_DQMH ( SDRAM_DQMH    ),
    .SDRAM_nWE  ( SDRAM_nWE     ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_BA   ( SDRAM_BA      ),
    .SDRAM_CKE  ( SDRAM_CKE     ),
    // ROM load
    .downloading ( downloading  ),
    .romload_addr( romload_addr ),
    .romload_data( romload_data )
);

endmodule // jtgng