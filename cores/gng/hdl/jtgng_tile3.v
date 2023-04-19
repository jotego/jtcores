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
    Date: 19-2-2019 */

// 

module jtgng_tile3 #( parameter
    DATAREAD = 1,
    ROM_AW   = 15,
    PALW     = 4,
    // bit field information
    IDMSB1   = 7,   // MSB of tile ID is
    IDMSB0   = 6,   //   { attr[IDMSB1:IDMSB0], id }
    VFLIP    = 5,
    HFLIP    = 4
) (
    input                   clk,
    input                   pxl_cen,
    input       [8:0]       HS,
    input       [8:0]       VS,
    input       [7:0]       attr,
    input       [7:0]       id,
    input                   flip,
    // Gfx ROM
    output reg [ROM_AW-1:0] scr_addr,
    input            [23:0] rom_data,
    input                   rom_ok,
    output reg [PALW-1:0]   scr_pal,
    output reg     [ 2:0]   scr_col
);

reg scr_hflip;
reg [7:0] addr_lsb;

reg [PALW:0] scr_attr0, scr_attr1; // MSB is tile H flip

// Set input for ROM reading
always @(posedge clk) if(pxl_cen) begin
    if( HS[2:0]==DATAREAD ) begin // attr/low data corresponds to this tile
            // from HS[2:0] = 1,2,3...0. because RAM output is latched
        scr_attr1 <= scr_attr0;
        scr_attr0 <= { attr[HFLIP], attr[PALW-1:0] };
        scr_addr  <= {   attr[IDMSB1:IDMSB0], id, // AS
                        HS[3]^attr[HFLIP] /*scr_hflip*/,
                        {4{attr[VFLIP] /*vflip*/}}^VS[3:0] /*vert_addr*/ };
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
    if( HS[2:0]==(DATAREAD+3'd1) ) begin
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

endmodule