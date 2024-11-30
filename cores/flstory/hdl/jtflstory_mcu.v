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
    Date: 20-11-2024 */

module jtflstory_mcu(
    input             rst,
    input             clk,
    input             cen,

    // bus status
    output reg        obf,
    output reg        ibf,
    output            busrq_n,
    input             busak_n,
    // as bus master
    output reg [15:0] bm_addr,
    output     [ 7:0] bm_dout,
    input      [ 7:0] bm_din,
    output            bm_we,    // active high
    output            bm_rd,
    // as bus slave
    input             bs_wr,    // write to the comm latch
    input             bs_rd,    // read from the comm latch
    input      [ 7:0] bs_dout,
    output     [ 7:0] bs_din,
    // ROM
    output     [10:0] rom_addr,
    input      [ 7:0] rom_data
);
`ifndef NOMAIN
localparam  COMM_RD = 1,
            COMM_WR = 2,
            BUSRQ_N = 3,
            BUSM_WE = 4,
            BUSM_RD = 5,
            ADLO_LE = 6,
            ADHI_LE = 7;

reg  [7:0] bus2mcu, mcu2bus, pbl;
wire [7:0] pa_in, pa_out, pb_out;
wire [3:0] pc_in;

assign pc_in   = {2'b11,~obf,ibf};
assign busrq_n =  pb_out[BUSRQ_N];
assign bm_we   = ~pb_out[BUSM_WE];
assign bm_rd   = ~pb_out[BUSM_RD];
assign pa_in   = busak_n ? bus2mcu : bm_din;
assign bs_din  = mcu2bus;
assign bm_dout = pa_out;

always @(posedge clk) begin
    pbl <= pb_out;
    if(bm_we) begin
        bus2mcu <= bm_dout;
        ibf     <= 1;
    end
    if(rst | bm_rd) obf <= 0;
    if( ~pbl[COMM_WR] & pb_out[COMM_WR] ) begin
        mcu2bus <= pa_out;
        obf <= 1;
    end
    if( ~pbl[COMM_RD] & pb_out[COMM_RD] ) ibf <= 0;
    if( ~pbl[ADHI_LE] & pb_out[ADHI_LE] ) bm_addr[15:8] <= pa_out;
    if( ~pbl[ADLO_LE] & pb_out[ADLO_LE] ) bm_addr[ 7:0] <= pa_out;
end

jtframe_6805mcu  u_mcu (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .wr         (               ),
    .addr       (               ),
    .dout       (               ),
    .irq        ( ibf           ),
    .timer      ( 1'b0          ),
    // Ports
    .pa_in      ( pa_in         ),
    .pa_out     ( pa_out        ),
    .pb_in      ( 8'hff         ), // pull up
    .pb_out     ( pb_out        ),
    .pc_in      ( pc_in         ),
    .pc_out     (               ),
    // ROM interface
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     (               )
);
`else
assign  rom_addr = 0;
`endif
endmodule