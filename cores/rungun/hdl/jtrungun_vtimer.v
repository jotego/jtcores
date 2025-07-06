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
    Date: 5-7-2025 */

module jtrungun_vtimer(
    input            rst, clk, pxl_cen, vs, hs, 
                     hflip, vflip,
    output     [8:0] hdump, hdumpf,
    output     [7:0] vdump, vdumpf
);

wire [8:0] hinit;
wire [7:0] vinit;

reg  [8:0] hcnt;
reg  [7:0] vcnt;
reg        hs_l, vs_l;

assign hinit = { {3{hflip}}, 1'b0, hflip, 4'd0 };
assign vinit = { {4{vflip}}, 4'd0 };

assign hdump  = hcnt,
       hdumpf = {9{hflip}}^hdump,
       vdump  = vcnt,
       vdumpf = {8{vflip}}^vdump;

// external counters
always @(posedge clk) if(pxl_cen) begin
    hs_l <= hs;
    vs_l <= vs;
end

always @(posedge clk) begin
    if(rst) begin
        hcnt <= 0;
        vcnt <= 0;
    end else begin        
        hcnt <= hcnt+9'd1;
        if( hs & ~hs_l ) begin
            hcnt <= hinit;
            vcnt <= vcnt+8'd1;
            if( vs & &vs_l ) vcnt <= vinit;
        end
    end
end

endmodule