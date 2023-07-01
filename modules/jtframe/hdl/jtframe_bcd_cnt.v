/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-12-2022 */

// BCD counter

module jtframe_bcd_cnt #(parameter DIGITS=4, WRAP=1 ) (
    input               rst,
    input               clk,
    input               clr,
    input               up,
    output reg [DIGITS*4-1:0] cnt
);

integer i;
genvar k;
reg [DIGITS-1:0] nines;

always @* begin
    for( i=0; i<DIGITS; i=i+1 )
        nines[i] = cnt[(i*4)+:4]==4'h9;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cnt[3:0] <= 0;
    end else begin
        if( clr ) begin
            cnt[3:0] <= 0;
        end else if( up && (WRAP==1 || ~&nines) ) begin
            cnt[3:0] <= cnt[3:0]==4'd9 ? 4'd0 : cnt[3:0] + 1'd1;
        end
    end
end

generate
    for( k=1; k<DIGITS; k=k+1 ) begin : upper_bcds
        always @(posedge clk, posedge rst) begin
            if( rst ) begin
                cnt[k*4+:4] <= 0;
            end else begin
                if( clr ) begin
                    cnt[k*4+:4] <= 0;
                end else if( up && (WRAP==1 || ~&nines) && &nines[0+:k] ) begin
                    cnt[k*4+:4] <= cnt[k*4+:4]==4'd9 ? 4'd0 : cnt[k*4+:4] + 1'd1;
                end
            end
        end
    end
endgenerate

endmodule