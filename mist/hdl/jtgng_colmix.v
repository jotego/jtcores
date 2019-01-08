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
    
// This module introduces 1-pixel delay
// clock operates at 4*cen6 because colour data requires
// two memory reads per pixel
// It could be done at 2*cen6, but this solutions is neat
// and 24MHz is not a tough requirement for modern FPGAs

module jtgng_colmix(
    input           rst,
    input           clk,    // 24 MHz
    input           cen6 /* synthesis direct_enable = 1 */,
    // Synchronization
    //input [2:0]       H,
    // characters
    input [1:0]     chr_col,
    input [3:0]     chr_pal,        // character color code
    // scroll
    input [2:0]     scr_col,
    input [2:0]     scr_pal,
    input           scrwin,
    // objects
    input [5:0]     obj_pxl,
    // Debug
    input           enable_char,
    input           enable_obj,
    input           enable_scr,
    // CPU inteface
    input [7:0]     AB,
    input           blue_cs,
    input           redgreen_cs,
    input [7:0]     DB,
    input           LVBL,
    input           LHBL,   

    output  reg [3:0]   red,
    output  reg [3:0]   green,
    output  reg [3:0]   blue
);

reg rdtop=1'b0;
reg we;
wire [7:0] dout;

`ifndef OBJTEST
reg [7:0] pixel_mux;
always @(*) begin   
    if( chr_col==2'b11 || !enable_char ) begin
        // Object or scroll
        if( enable_scr && &obj_pxl[3:0] || !enable_obj || (scrwin&&scr_col!=3'd0) ) 
            pixel_mux = {2'b00, scr_pal, scr_col }; // scroll wins
        else
            pixel_mux = {2'b01, obj_pxl }; // object wins
    end
    else begin // characters
        pixel_mux = { 2'b11, chr_pal, chr_col };
    end
end
`else
    wire [7:0] pixel_mux = {2'b01,obj_pxl};
`endif

reg [3:0] rbuf,gbuf,bbuf;


always @(*) 
    we = !LVBL && ( redgreen_cs || blue_cs );

always @(posedge clk) begin
    rdtop <= ~rdtop;
    // assign current pixel colour
    if ( rdtop ) // if rdtop is high, dout corresponds to low data
        { rbuf, gbuf } <= dout;
    else
        bbuf <= dout[7:4]; // blue is on top half of memory
end

always @(posedge clk) if (cen6)
    {red, green, blue } <= (LVBL&&LHBL)? {rbuf,gbuf,bbuf} : 12'd0; 

wire [8:0] rdaddress = {   rdtop, pixel_mux };
wire [8:0] wraddress = { blue_cs, AB        };

// RAM
jtgng_dual_ram #(.aw(9)) RAM(
    .clk        ( clk       ),
    .clk_en     ( cen6      ), // clock enable only applies to write operation
    .data       ( DB        ),
    .rd_addr    ( rdaddress ),
    .wr_addr    ( wraddress ),
    .we         ( we        ),
    .q          ( dout      )
);

endmodule // jtgng_colmix