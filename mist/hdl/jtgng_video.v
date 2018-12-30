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
    Date: 30-12-2018 */

module jtgng_video(
    input               rst,    
    input               clk,
    input               cen6,
    input       [10:0]  cpu_AB,
    input       [ 7:0]  V,
    input       [ 7:0]  H,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,

    // CHAR
    input               char_cs,
    output      [ 7:0]  chram_dout,
    output              MRDY_b,
    output reg  [12:0]  char_addr,
    input       [15:0]  chrom_data,
    // SCROLL - ROM
    input               scr_cs,
    input               scrpos_cs,    
    output      [ 7:0]  scr_dout,    
    output reg  [14:0]  scr_addr,
    input       [23:0]  scrom_data,    
    // Color Mix
    input               LVBL,
    input               LHBL,       
    input               blue_cs,
    input               redgreen_cs,    
    input               enable_char,
    input               enable_obj,
    input               enable_scr,    
    output  reg [3:0]   red,
    output  reg [3:0]   green,
    output  reg [3:0]   blue    
);

wire [ 3:0] chr_pal;
wire [ 1:0] chr_col;

jtgng_char u_char (
    .clk        ( clk           ),
    .clk_en     ( cen6          ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H128       ( H[7:0]        ),
    .char_cs    ( char_cs       ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    .rd         ( RnW           ),
    .MRDY_b     ( char_mrdy     ),
    .char_addr  ( char_addr     ),
    .chrom_data ( chrom_data    ),
    .char_col   ( chr_col       ),
    .char_pal   ( chr_pal       )
);

wire scr_mrdy, scrwin;
wire [ 2:0] scr_col;
wire [ 2:0] scr_pal;
wire [ 2:0] HS;

jtgng_scroll u_scroll (
    .clk        ( clk           ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H          ( H             ),
    .HSlow      ( HS            ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( scram_dout    ),
    .rd         ( RnW           ),
    .MRDY_b     ( scr_mrdy      ),
    .scr_addr   ( scr_addr      ),
    .scr_col    ( scr_col       ),
    .scr_pal    ( scr_pal       ),
    .scrom_data ( scr_dout      ),
    .scrwin     ( scrwin        )
);

wire [3:0] cc;
wire blue_cs;
wire redgreen_cs;
wire [ 5:0] obj_pxl;

jtgng_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    // .H           ( H[2:0]        ),
    // characters
    .chr_col    ( chr_col       ),
    .chr_pal    ( chr_pal       ),
    // scroll
    .scr_col    ( scr_col       ),
    .scr_pal    ( scr_pal       ),
    .scrwin     ( scrwin        ),
    // objects
    .obj_pxl    ( obj_pxl       ),
    // DEBUG
    .enable_char( enable_char   ),
    .enable_obj ( enable_obj    ),
    .enable_scr ( enable_scr    ),
    // CPU interface
    .AB         ( cpu_AB[7:0]   ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .DB         ( cpu_dout      ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

wire [14:0] obj_addr;
wire [31:0] obj_dout;

jtgng_obj u_obj (
    .clk     (clk     ),
    .rst     (rst     ),
    .AB      (obj_AB  ),
    .DB      (main_ram),
    .OKOUT   (OKOUT   ),
    .bus_req (bus_req ),
    .bus_ack (bus_ack ),
    .blen    (blcnten ),
    .LVBL    ( LVBL   ),
    .LHBL    ( LHBL   ),
    .HINIT   ( Hinit  ),
    .flip    ( flip   ),
    .V       ( V[7:0] ),
    .H       ( H      ),
    // SDRAM interface
    .obj_addr( obj_addr ),
    .objrom_data( obj_dout ),
    // pixel data
    .obj_pxl ( obj_pxl )
);

endmodule // jtgng_video