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

module jtgng_scroll #(parameter 
    ROM_AW   = 15,
    PALW     = 4,
    HOFFSET  = 9'd5,
    // bit field information
    IDMSB1   = 7,   // MSB of tile ID is
    IDMSB0   = 6,   //   { dout_high[IDMSB1:IDMSB0], dout_low }
    VFLIP    = 5,
    HFLIP    = 4
) (
    input              clk,     // 24 MHz
    input              pxl_cen  /* synthesis direct_enable = 1 */,    //  6 MHz
    input              cpu_cen,
    input              Asel,
    input        [9:0] AB,
    input        [7:0] V, // V128-V1
    input        [8:0] H, // H256-H1
    input        [8:0] hpos,
    input        [8:0] vpos,
    input              scr_cs,
    input              flip,
    input        [7:0] din,
    output       [7:0] dout,
    input              wr_n,
    output             MRDY_b,
    output             busy,

    // ROM
    output reg  [ROM_AW-1:0] scr_addr,
    input       [23:0]       rom_data,
    input                    rom_ok,
    output reg [PALW-1:0]    scr_pal,
    output reg     [ 2:0]    scr_col
);

wire [8:0] Hfix = H + HOFFSET; // Corrects pixel output offset
reg  [ 8:0] HS, VS;
wire [ 7:0] VF = {8{flip}}^V;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0];

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(*) begin
    VS = vpos + {1'b0, VF};
    { HS[8:3], HSaux } = hpos + { ~Hfix[8], H7, HF[6:0]};
    HS[2:0] = HSaux ^ {3{flip}};
end

wire [7:0] dout_low, dout_high;

localparam DATAREAD = 3'd1;

jtgng_tilemap #(
    .HOFFSET    ( HOFFSET ),
    .SELBIT     ( 1       ),
    .INVERT_SCAN( 1       ),
    .DATAREAD   ( DATAREAD)
) u_tilemap(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .Asel       ( Asel      ),
    .AB         ( AB        ),
    .V          ( VS[8:1]   ),
    .H          ( HS[8:1]   ),
    .flip       ( 1'b0      ),  // Flip is already done on HS and VS
    .din        ( din       ),
    .dout       ( dout      ),
    // Bus arbitrion
    .cs         ( scr_cs    ),
    .wr_n       ( wr_n      ),
    .MRDY_b     ( MRDY_b    ),
    .busy       ( busy      ),
    // Pause screen -unused for scroll-
    .pause      ( 1'b0      ),
    .scan       (           ),
    .msg_low    ( 8'd0      ),
    .msg_high   ( 8'd0      ),
    // Current tile
    .dout_low   ( dout_low  ),
    .dout_high  ( dout_high )
);

reg scr_hflip;
reg [7:0] addr_lsb;

reg [PALW:0] scr_attr0, scr_attr1; // MSB is tile H flip

// Set input for ROM reading
always @(posedge clk) if(pxl_cen) begin
    if( HS[2:0]==DATAREAD ) begin // dout_high/low data corresponds to this tile
            // from HS[2:0] = 1,2,3...0. because RAM output is latched
        scr_attr1 <= scr_attr0;
        scr_attr0 <= { dout_high[HFLIP], dout_high[PALW-1:0] };
        scr_addr  <= {   dout_high[IDMSB1:IDMSB0], dout_low, // AS
                        HS[3]^dout_high[HFLIP] /*scr_hflip*/,
                        {4{dout_high[VFLIP] /*vflip*/}}^VS[3:0] /*vert_addr*/ };
    end
end

// Draw pixel on screen
reg [7:0] x,y,z;
reg [PALW-1:0] scr_attr2;

reg [23:0] good_data;
always @(posedge clk) begin
    if( HS[2:0] > (DATAREAD+3'd1) && rom_ok )
        good_data <= rom_data;
end

always @(posedge clk) if(pxl_cen) begin
    // new tile starts 8+5=13 pixels off
    // 8 pixels from delay in ROM reading
    // 4 pixels from processing the x,y,z and attr info.
    if( HS[2:0]==DATAREAD ) begin
            { z,y,x } <= good_data;
            scr_hflip <= scr_attr1[PALW] ^ flip; // must be ready when z,y,x are.
            scr_attr2 <= scr_attr1[PALW-1:0];
        end
    else
        begin
            if( scr_hflip ) begin
                x <= {1'b0, x[7:1]};
                y <= {1'b0, y[7:1]};
                z <= {1'b0, z[7:1]};
            end
            else  begin
                x <= {x[6:0], 1'b0};
                y <= {y[6:0], 1'b0};
                z <= {z[6:0], 1'b0};
            end
        end
    scr_col <= scr_hflip ? { x[0], y[0], z[0] } : { x[7], y[7], z[7] };
    scr_pal <= scr_attr2[PALW-1:0]; // MSB in G&G is "scrwin" = scroll wins over sprite
end

endmodule // jtgng_scroll