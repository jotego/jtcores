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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 24-01-2025 */

module jtframe_serializer#(parameter DW=8, PAR=1)( // Set PAR==0 for even parity
    input            rst,
    input            clk,
    input            cen,
    input   [DW-1:0] din,
    input            load,
    output           done,
    output           sdout,
    output reg       sclk
);

localparam CK=$clog2(DW+2);
reg  [DW+1:0] pre_data;
reg  [CK-1:0] cnt;
wire          par;

assign done  = cnt==0;
assign sdout = pre_data[0];
assign par   = ^din ^(PAR==1);

always @(posedge clk) begin 
    if(rst) begin
        sclk     <= 0;
        pre_data <= {DW+2{1'b1}};
        cnt      <= 0;
    end else if(cen) begin
        sclk     <= ~sclk;
        if(!sclk) begin
            if(!done) begin
                pre_data <= {1'b1,pre_data[DW+1:1]};
                cnt      <= cnt-1'b1;
            end
            if(load) begin
                pre_data <= {par,din, 1'b0};
                cnt      <= DW[0+:CK] + 'd2;
            end
        end
    end
end

endmodule