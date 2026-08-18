/* This file is part of JT12.

 
    JT12 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT12 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT12.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-12-2018
    
*/

module jt12_comb #(parameter 
    w=16,   // bit width
    m=1     // depth of comb filter
)(
    input               rst,
    input               clk,
(* direct_enable *)    input cen,
    input  signed [w-1:0] snd_in,
    output reg signed [w-1:0] snd_out
);

wire signed [w-1:0] prev;

// m-delay stage
generate
    genvar k;
    reg signed [w-1:0] mem[0:m-1];
    assign prev=mem[m-1];
    for(k=0;k<m;k=k+1) begin : mem_gen
        always @(posedge clk)
            if(rst) begin
                mem[k] <= {w{1'b0}};
            end else if(cen) begin
                mem[k] <= k==0 ? snd_in : mem[k-1];
            end
    end
endgenerate

// Comb filter at synthesizer sampling rate
always @(posedge clk)
    if(rst) begin
        snd_out <= {w{1'b0}};
    end else if(cen) begin
        snd_out <= snd_in - prev;
    end

endmodule // jt12_comb