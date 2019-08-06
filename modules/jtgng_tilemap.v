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
    Date: 27-10-2017 */

// 2-word tile memory

`timescale 1ns/1ps

module jtgng_tilemap #(parameter 
    HOFFSET  = 8'd4,
    SELBIT   = 2,
    INVERT_SCAN = 0
) (
    input            clk,
    input            cpu_cen /* synthesis direct_enable = 1 */,
    input            Asel,  // This is the address bit that selects
                            // between the low and high tile map
    input      [9:0] AB,
    input      [7:0] V,
    input      [7:0] H,
    input            flip,
    input      [7:0] din,
    output reg [7:0] dout,
    // Bus arbitrion
    input            cs,
    input            wr_n,
    output reg       MRDY_b,
    output reg       busy,
    // Pause screen
    input            pause,
    output     [9:0] scan,
    input      [7:0] msg_low,
    input      [7:0] msg_high,
    // Current tile
    output reg [7:0] dout_low,
    output reg [7:0] dout_high
);

wire sel_scan = ~H[SELBIT];

assign scan = INVERT_SCAN ? { {10{flip}}^{H[7:3],V[7:3]}} 
        : { {10{flip}}^{V[7:3],H[7:3]}};
reg [9:0] addr;
reg we_low, we_high;
wire [7:0] mem_low, mem_high;

always @(posedge clk) begin : mem_mux
    reg last_Asel, last_scan;

    if( sel_scan ) begin
        addr    <= scan;
        we_low  <= 1'b0;
        we_high <= 1'b0;
    end else begin
        addr    <= AB;
        we_low  <= cs && !wr_n && !Asel;
        we_high <= cs && !wr_n &&  Asel;
    end

    // Output latch
    last_scan <= sel_scan;
    last_Asel <= Asel;
    if( !last_scan && !sel_scan )
        dout <= last_Asel ? dout_high : dout_low;

    // Bus arbitrion
    MRDY_b <= !( cs && sel_scan ); // halt CPU
    busy   <= sel_scan;
end


jtgng_ram #(.aw(10)) u_ram_low(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( mem_low  )
);

jtgng_ram #(.aw(10)) u_ram_high(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( din      ),
    .addr   ( addr     ),
    .we     ( we_high  ),
    .q      ( mem_high )
);

always @(*) begin
    dout_low  = pause ? msg_low  : mem_low;
    dout_high = pause ? msg_high : mem_high;
end


endmodule
