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
    Date: 9-10-2025 */

module jtriders_tmnt2_zoom(
    input        clk,

    input        xylock,
    input signed[15:0] offset,
    input       [15:0] zoom,

    // LUTs
    output reg [ 9:0] mant, log,
    input      [ 8:0] frac,
    input      [14:0] lin,

    output reg [15:0] adj,
    output reg [ 1:0] ztype
);

wire [15:0] lin_signed;
reg signed [15:0] i, imul;
reg  [15:0] abs;
reg  [ 9:0] exp;
reg  signed [31:0] xmul32;
reg  signed [63:0] xmul64;

wire signed [63:0] three=64'd3;

assign lin_signed = offset[15] ? -{1'b0,lin} : {1'b0,lin};


always @(*) begin    
    abs   = offset[15] ? -offset : offset;
    if(abs[15]) abs=16'h7fff;
    mant = abs[14] ? abs[14-:10]:
           abs[13] ? abs[13-:10]:
           abs[12] ? abs[12-:10]:
           abs[11] ? abs[11-:10]:
           abs[10] ? abs[10-:10]:
                    abs[ 9-:10];
    exp  = abs[14] ? 10'd256 :
           abs[13] ? 10'd204 :
           abs[12] ? 10'd153 :
           abs[11] ? 10'd102 :
           abs[10] ? 10'd051 : 10'd0;
    i    = zoom - 16'h4f00;
    imul = zoom + ((i*16'd15) >> 6);
end

always @(posedge clk) begin
    log    <= {1'b0,frac} + exp + {1'b0,i[15:8]};
    xmul32 <= offset * imul;
    xmul64 <= xmul32 * three;
end

always @* begin
    ztype = 0;
    adj   = offset;
    if(!xylock) begin
        if(zoom > 16'h4f00) begin
            adj   = lin_signed + offset;
            ztype = 1;
        end else if(i[15]) begin
            if(imul[15]) begin
                adj   = 0;
                ztype = 2;
            end else begin
                adj   = xmul64[16+:16];
                ztype = 3;
            end
        end
    end
end                    

endmodule