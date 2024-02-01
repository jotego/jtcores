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
    Date: 1-12-2020 */

// SDRAM access multiplexer, 2 -> 1

module jtframe_ram1_1slot #(parameter
    SDRAMW   = 22,
    SLOT0_DW = 16,
    SLOT0_AW =  8,
/* verilator lint_off WIDTH */
    parameter [SDRAMW-1:0] SLOT1_OFFSET = 0,
/* verilator lint_on WIDTH */
    parameter REF_FILE="sdram_bank3.hex"
)(
    input               rst,
    input               clk,

    input  [SLOT0_AW-1:0] slot0_addr,
    output [SLOT0_DW-1:0] slot0_dout,
    input  [SLOT0_DW-1:0] slot0_din,

    input    [SDRAMW-1:0] slot0_offset,

    input                 slot0_cs,
    output                slot0_ok,
    input                 slot0_wen,
    input       [1:0]     slot0_wrmask,
    output              hold_rst,     // signals a busy state so the game is kept in reset

    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg         sdram_wr,
    output      [SDRAMW-1:0] sdram_addr,
    input               data_rdy,
    input               data_dst,
    input       [15:0]  data_read,
    output reg  [15:0]  data_write,  // only 16-bit writes
    output reg  [ 1:0]  sdram_wrmask // each bit is active low
);

wire req, req_rnw;
reg  we;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        we           <= 0;
        sdram_rd     <= 0;
        sdram_wr     <= 0;
        sdram_wrmask <= 0;
    end else begin
        if( sdram_ack ) begin
            sdram_rd <= 0;
            sdram_wr <= 0;
        end
        if( !we || data_rdy ) begin
            we <= 0;
            // accept a new request
            if( req ) begin
                we          <= 1;
                data_write  <= hold_rst ? 16'd0 : {(SLOT0_DW==8?2:1){slot0_din}};
                sdram_wrmask<= slot0_wrmask;
                sdram_rd    <= req_rnw;
                sdram_wr    <= ~req_rnw;
            end
        end
    end
end

jtframe_ram_rq #(.SDRAMW(SDRAMW),.AW(SLOT0_AW),.DW(SLOT0_DW)) u_slot0(
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .addr      ( slot0_addr             ),
    .addr_ok   ( slot0_cs               ),
    .offset    ( slot0_offset           ),
    .wrdata    ( slot0_din              ),
    .wrin      ( slot0_wen              ),
    .req_rnw   ( req_rnw                ),
    .sdram_addr( sdram_addr             ),
    .din       ( data_read              ),
    .din_ok    ( data_rdy               ),
    .dst       ( data_dst               ),
    .dout      ( slot0_dout             ),
    .req       ( req                    ),
    .data_ok   ( slot0_ok               ),
    .we        ( we                     ),
    .erase_bsy ( hold_rst               )
);

endmodule
