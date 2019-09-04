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

// This module breaks up a RAM into smaller units
// and then multiplexes all the outputs in two steps
// It takes three clock cycles to get a valid output
// This eases the design implementation in terms of
// placing and timing. 

module jtgng_multiram #(parameter AW=18, UNITW=13, DW=8)(
    input               clk,
    input   [AW-1:0]    addr,
    input   [DW-1:0]    din,
    input               we,
    output  [DW-1:0]    dout
);

localparam MAXA  = 2^AW-1;
localparam UNITS = (2^AW)>>UNITW;

`ifdef SIMULATION
initial begin
    if( AW-2 < UNITW ) begin
        $display("ERROR: UNITW is too large. %m ");
        $finish;
    end
end
`endif

wire [AW-UNITW-1:0] bank = addr[AW-1:UNITW];
wire [UNITW-1:0]    lowa = addr[UNITW-1:0];

reg [(DW*UNITS)-1:0] bank_dout;
generate
    genvar k;
    for( k=0; k<UNITS; k=k+1 ) begin : u
        reg [DW-1:0] ram[2^UNIT];
        always @(posedge clk) begin
            bank_dout[ (DW*(k+1))-1:DW*k ] <= ram[lowa];
            if( we && bank==k ) ram[lowa] <= din;
        end
    end

    reg [DW-1:0] even, odd;
    always @(posedge clk) begin
        for( k=0; k<UNITS; k=k+2 ) begin
            if( bank==k ) even <= bank_dout[ (DW*(k+1))-1:DW*k ];
        end
    end

    always @(posedge clk) begin
        for( k=1; k<UNITS; k=k+2 ) begin
            if( bank==k ) odd <= bank_dout[ (DW*(k+1))-1:DW*k ];
        end
    end

    always @(posedge clk) begin
        dout <= bank[0] ? odd : even;
    end

endgenerate

endmodule