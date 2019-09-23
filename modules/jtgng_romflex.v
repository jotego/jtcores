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
    Date: 4-9-2019 */

`timescale 1ns/1ps

module jtgng_romflex #(parameter AW=18, DW=8, INVERT_A0=0, USE_BRAM=0 )(
    input               rst,
    input               clk,
    input               cen,
    input [AW-1:0]      addr,
    input               addr_ok,    // signals that value in addr is valid
    input [31:0]        din,
    input               din_ok,
    input               we,
    input               prog_we,
    input      [AW-1:0] prog_addr,
    input      [DW-1:0] prog_data,
    output              req,
    output              data_ok,    // strobe that signals that data is ready
    output     [AW-1:0] addr_req,
    output     [DW-1:0] dout
);

generate
    
if( USE_BRAM==0 ) begin
    jtgng_romrq #(.AW(AW), .DW(DW), .INVERT_A0(INVERT_A0)) 
    u_req(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cen        ( cen       ),
        .addr       ( addr      ),
        .addr_ok    ( addr_ok   ),    // signals that value in addr is valid
        .din        ( din       ),
        .din_ok     ( din_ok    ),
        .we         ( we        ),
        .req        ( req       ),
        .data_ok    ( data_ok   ),    // strobe that signals that data is ready
        .addr_req   ( addr_req  ),
        .dout       ( dout      )
    );
end
else begin
    reg [AW-1:0] a;
    always @(*) begin
        a = prog_we ? prog_addr : { addr[AW-1:1], (INVERT_A0&&DW==8) ? ~addr[0]:addr[0]};
    end

    jtgng_multiram #(.AW(AW), .DW(DW), .UNITW(12))
    u_multi(
        .clk    (  clk        ),
        .addr   (  a          ),
        .din    (  prog_data  ),
        .we     (  prog_we    ), // do not use the we input here!
        .dout   (  dout       )
    );
    assign req = 1'b0;
    assign data_ok = 1'b1; // it is really not ok for 3 clock cycles, but that's quick
        // enough so we can ignore it
    assign addr_req = {AW{1'b0}};
end

endgenerate
endmodule