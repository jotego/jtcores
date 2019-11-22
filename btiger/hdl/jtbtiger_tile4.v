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
    Date: 20-11-2019 */

module jtbtiger_tile4 (
    input              clk,
    input              cen6,
    input       [4:0]  HS,
    input       [4:0]  SV,
    input       [7:0]  attr,
    input       [7:0]  id,
    input              SCxON,
    input              flip,
    input              layout,
    // Gfx ROM
    output reg  [16:0] scr_addr,
    input       [15:0] rom_data,
    output      [ 7:0] scr_pxl
);

localparam ROM_AW = 17;
localparam ATTW   = 4;
localparam PXLW   = 8;

reg  [7:0]      addr_lsb;
reg  [ATTW-1:0] scr_attr0;
reg             scr_hflip0, scr_hflip1;

reg scr_hflip, aux;

always @(*) begin
    scr_hflip = attr[7]; // ^flip ?
end

// Set input for ROM reading
always @(posedge clk) if(cen6) begin
    if( HS[2:0]==3'd1 ) begin
        scr_attr0      <= attr[6:3];
        scr_addr[16:1] <= { attr[2:0], id, // AS
                        SV[2:0]^{3{flip}}};
        scr_hflip0 <= scr_hflip;
    end
    scr_addr[0] <= HS[2]^scr_hflip0; // 8x4
end

// Draw pixel on screen
reg [     3:0] w,x,y,z;
reg [     3:0] scr_col0;
reg [ATTW-1:0] scr_attr1, scr_pal0;

// Character data delay
// clock count      stage
// -1               Assign map address
// 1                read map data
// 5                read tile rom data
// 6                assign to scr_col
// 7                read from PROM
// Total delay = 1 (+8) pixels

always @(posedge clk) if(cen6) begin
    if( HS[1:0]==2'd1 ) begin
            { z,y,x,w } <= rom_data;
            scr_hflip1  <= scr_hflip0; // must be ready when z,y,x are.
            scr_attr1   <= scr_attr0;
        end
    else
        begin
            if( scr_hflip1 ) begin
                w <= {1'b0, w[3:1]};
                x <= {1'b0, x[3:1]};
                y <= {1'b0, y[3:1]};
                z <= {1'b0, z[3:1]};
            end
            else  begin
                w <= {w[2:0], 1'b0};
                x <= {x[2:0], 1'b0};
                y <= {y[2:0], 1'b0};
                z <= {z[2:0], 1'b0};
            end
        end
    scr_col0  <= scr_hflip1 ? { w[0], x[0], y[0], z[0] } : { w[3], x[3], y[3], z[3] };
    scr_pal0  <= scr_attr1;
end

reg [PXLW-1:0] pxl_dly; // to have the same delay as the palette case
always @(posedge clk)
    pxl_dly <= { scr_pal0, scr_col0 };
assign scr_pxl = pxl_dly;

endmodule