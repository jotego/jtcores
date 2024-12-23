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
    Date: 28-2-2021 */

module jtframe_mr_ddrmux(
    input          rst,
    input          clk,
    input          ioctl_rom,
    // Fast DDR load
    input   [ 7:0] ddrld_burstcnt,
    input   [28:0] ddrld_addr,
    input          ddrld_rd,
    output         ddrld_busy,
    // Rotation signals
    input          rot_clk,
    input   [ 7:0] rot_burstcnt,
    input   [28:0] rot_addr,
    input          rot_rd,
    input          rot_we,
    input   [ 7:0] rot_be,
    output         rot_busy,
    // DDR Signals
    output         ddr_clk,
    input          ddr_busy,
    output  [ 7:0] ddr_burstcnt,
    output  [28:0] ddr_addr,
    output         ddr_rd,
    output  [ 7:0] ddr_be,
    output         ddr_we
);

`ifdef JTFRAME_MR_DDRLOAD
    localparam DDRLOAD=1;
`else
    localparam DDRLOAD=0;
`endif

`ifdef JTFRAME_VERTICAL
    localparam VERTICAL=1;
`else
    localparam VERTICAL=0;
`endif

localparam DDREN = DDRLOAD[0] || VERTICAL[0];

reg ddrld_en;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ddrld_en <= 0;
    end else if(!ddr_busy) begin
        case( {DDRLOAD[0], VERTICAL[0]} )
            2'b00: ddrld_en <= 0; // don't care
            2'b10: ddrld_en <= 1;
            2'b01: ddrld_en <= 0;
            2'b11: ddrld_en <= ioctl_rom;
        endcase
    end
end

assign ddr_clk = ddrld_en ? clk : rot_clk;

// This simple mux allows for bad data transfers when switching from ROM download
// to the frame buffer, but it shouldn't be a problem

assign ddr_burstcnt = ddrld_en ? ddrld_burstcnt : rot_burstcnt;
assign ddr_addr     = ddrld_en ? ddrld_addr     : rot_addr;
assign ddr_rd       = ddrld_en ? ddrld_rd       : rot_rd;
assign ddr_be       = ddrld_en ? 8'hff          : rot_be;
assign ddr_we       = ddrld_en ? 1'b0           : rot_we;

assign ddrld_busy   = ~ddrld_en | ddr_busy;
assign rot_busy     =  ddrld_en | ddr_busy;

endmodule