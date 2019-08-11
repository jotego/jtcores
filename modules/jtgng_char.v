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

// Generic 2-bit per pixel no-scroll tile generator

`timescale 1ns/1ps

module jtgng_char #(parameter 
    ROM_AW   = 13, 
    PALW     = 4,
    HOFFSET  = 8'd0,
    // bit field information
    IDMSB1   = 7,   // MSB of tile ID is
    IDMSB0   = 6,   //   { dout_high[IDMSB1:IDMSB0], dout_low }
    VFLIP    = 5,
    HFLIP    = 4,
    VFLIP_EN = 1, // 1 for enable VFLIP bit
    HFLIP_EN = 1  // 1 for enable HFLIP bit
) (
    input            clk,
    input            pxl_cen  /* synthesis direct_enable = 1 */,
    input            cpu_cen,
    input   [10:0]   AB,
    input   [ 7:0]   V, // V128-V1
    input   [ 7:0]   H, // Hfix-H1
    input            flip,
    input   [ 7:0]   din,
    output  [ 7:0]   dout,
    // Bus arbitrion
    input            char_cs,
    input            wr_n,
    output           busy,
    // Pause screen
    input            pause,
    output  [ 9:0]   scan,
    input   [ 7:0]   msg_low,
    input   [ 7:0]   msg_high,
    // ROM
    output reg [ROM_AW-1:0] char_addr,
    input      [15:0]       rom_data,
    input                   rom_ok,
    output reg [PALW-1:0]   char_pal,
    output reg [     1:0]   char_col
);

wire [7:0] dout_low, dout_high;
wire [7:0] Hfix = H + HOFFSET; // Corrects pixel output offset

localparam DATAREAD = 3'd1;

jtgng_tilemap #(
    .DATAREAD( DATAREAD )
) u_tilemap(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .Asel       ( AB[10]    ),
    .AB         ( AB[9:0]   ),
    .V          ( V         ),
    .H          ( Hfix      ),
    .flip       ( flip      ),
    .din        ( din       ),
    .dout       ( dout      ),
    // Bus arbitrion
    .cs         ( char_cs   ),
    .wr_n       ( wr_n      ),
    .busy       ( busy      ),
    // Pause screen
    .pause      ( pause     ),
    .scan       ( scan      ),
    .msg_low    ( msg_low   ),
    .msg_high   ( msg_high  ),
    // Current tile
    .dout_low   ( dout_low  ),
    .dout_high  ( dout_high )
);

reg [7:0] addr_lsb;
reg char_hflip;
reg half_addr;

// Draw pixel on screen
reg [15:0] chd;
reg [PALW:0] char_attr0, char_attr1; // MSB is HFLIP
reg [PALW-1:0] char_attr2;

reg [15:0] good_data;

// avoid getting the data too early
always @(posedge clk) begin
    if( Hfix[2:0]>(DATAREAD+3'd1) && rom_ok ) good_data <= rom_data;
end

// avoid errors if *FLIP_EN is assigned 0 or 1 (i.e. 32'd0, 32'd1)
wire vflip_en = VFLIP_EN[0];
wire hflip_en = HFLIP_EN[0];

always @(posedge clk) if(pxl_cen) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( Hfix[2:0]==DATAREAD ) begin // read data from memory when the CPU is forbidden to write on it
        // Set input for ROM reading
        char_attr1 <= char_attr0;
        char_attr0 <= { dout_high[HFLIP], dout_high[PALW-1:0] };
        char_addr  <= { {dout_high[IDMSB1:IDMSB0], dout_low},
            {3{(dout_high[VFLIP]&vflip_en) ^ flip}}^V[2:0] };
    end
    // The two case-statements cannot be joined because of the default statement
    // which needs to apply in all cases except the two outlined before it.
    case( Hfix[2:0] )
        (DATAREAD+3'd1): begin
            chd <= !char_hflip ? {good_data[7:0],good_data[15:8]} : good_data;
            char_hflip <= (char_attr1[PALW] & hflip_en) ^ flip;
            char_attr2 <= char_attr1[PALW-1:0];
        end
        (DATAREAD+3'd5):
            chd[7:0] <= chd[15:8];
        default:
            begin
                if( char_hflip ) begin
                    chd[7:4] <= {1'b0, chd[7:5]};
                    chd[3:0] <= {1'b0, chd[3:1]};
                end
                else  begin
                    chd[7:4] <= {chd[6:4], 1'b0};
                    chd[3:0] <= {chd[2:0], 1'b0};
                end
            end
    endcase
    // 1-pixel delay in order to latch signals:
    char_col <= char_hflip ? { chd[0], chd[4] } : { chd[3], chd[7] };
    char_pal <= char_attr2;
end

endmodule // jtgng_char