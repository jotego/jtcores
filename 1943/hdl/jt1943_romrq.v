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
    Date: 28-2-2019 */

module jt1943_romrq #(parameter AW=18, DW=8, INVERT_A0=0 )(
    input               rst,
    input               clk, 
    input               cen,
    input [AW-1:0]      addr,
    input [31:0]        din,
    input               we,
    output reg          req,
    output reg [AW-1:0] addr_req,
    output reg [DW-1:0] dout
);

reg [AW-1:0] cached_addr;
reg [1:0]    subaddr;
reg [31:0]   cached_data;
reg init;

always @(*) begin
    case(DW)
        8:  addr_req = {addr[AW-1:2],2'b0};
        16: addr_req = {addr[AW-1:1],1'b0};
        32: addr_req = addr;
    endcase 
    req = init || (addr_req !== cached_addr );
end

always @(posedge clk) 
    if( rst ) begin
        init <= 1'b1;
    end else if(cen) begin
        if( we ) begin
            cached_data <= din;
            cached_addr <= addr_req;
            init        <= 1'b0;
        end
    end
always @(*) begin
    subaddr[1] <= addr[1];
    if( INVERT_A0 )
        subaddr[0] <= ~addr[0];
    else
        subaddr[0] <=  addr[0]; 
end

generate
    if(DW==8) begin
        always @(posedge clk)
        if(!req) case( subaddr )
            2'd0: dout <= cached_data[ 7: 0];
            2'd1: dout <= cached_data[15: 8];
            2'd2: dout <= cached_data[23:16];
            2'd3: dout <= cached_data[31:24];
        endcase
    end else if(DW==16) begin
        always @(posedge clk)
        if(!req) case( subaddr[0] )
                1'd0: dout = cached_data[15:0];
                1'd1: dout = cached_data[31:16];
        endcase
    end else always @(*) dout = cached_data;
endgenerate


endmodule // jt1943_romrq