/*  This file is part of JTEEPROM.
    JTEEPROM program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTEEPROM program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTEEPROM.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-6-2022 */

// Wrapper to provide an 8-bit dump interface

module jt9346_16b8b #(
    parameter
    AW=6,   // Memory address bits
    CW=AW,  // bits between the 2-bit op command and the data
    DW=8
) (
    input           rst,        // system reset
    input           clk,        // system clock
    // chip interface
    input           sclk,       // serial clock
    input           sdi,         // serial data in
    output          sdo,         // serial data out and ready/not busy signal
    input           scs,         // chip select, active high. Goes low in between instructions
    // Dump access
    input           dump_clk,
    input  [(DW==16?AW+1:AW):0] dump_addr,
    input           dump_we,
    input     [7:0] dump_din,
    output    [7:0] dump_dout,
    // NVRAM contents changed
    input           dump_clr,   // Clear the flag
    output          dump_flag   // There was a write
);

    wire [AW-1:0] dx_addr;
    wire          dx_we;
    wire [DW-1:0] dx_din, dx_dout;

    generate
        if( DW==8 ) begin
            assign dx_addr   = dump_addr[AW-1:0];
            assign dx_we     = dump_we;
            assign dx_din    = dump_din;
            assign dump_dout = dx_dout;
        end else begin
            reg  [15:0] xx_din=0;
            reg         xx_we=0;

            assign dx_we     = xx_we;
            assign dx_addr   = dump_addr[AW:1];
            assign dump_dout = dump_addr[0] ? dx_dout[15:8] : dx_dout[7:0];
            assign dx_din    = xx_din[DW-1:0];

            always @(posedge clk) begin
                xx_we <= 0;
                if (dump_we) begin
                    if(dump_addr[0]) begin
                        xx_we <= 1;
                        xx_din[15:8] <= dump_din;
                    end else begin
                        xx_din[7:0] <= dump_din;
                    end
                end
            end
        end
    endgenerate

    jt9346 #(.AW(AW),.DW(DW),.CW(CW)) u_jt9346 (
        .rst        ( rst       ),        // system reset
        .clk        ( clk       ),        // system clock
        // chip interface
        .sclk       ( sclk      ),       // serial clock
        .sdi        ( sdi       ),         // serial data in
        .sdo        ( sdo       ),         // serial data out and ready/not busy signal
        .scs        ( scs       ),         // chip select, active high. Goes low in between instructions
        // Dump access
        .dump_clk   ( dump_clk  ),
        .dump_addr  ( dx_addr   ),
        .dump_we    ( dx_we     ),
        .dump_din   ( dx_din    ),
        .dump_dout  ( dx_dout   ),
        // NVRAM contents changed
        .dump_clr   ( dump_clr  ),   // Clear the flag
        .dump_flag  ( dump_flag )   // There was a write
    );

endmodule