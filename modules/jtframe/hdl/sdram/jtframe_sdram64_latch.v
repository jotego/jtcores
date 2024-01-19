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
    Date: 29-4-2021 */

module jtframe_sdram64_latch #(parameter LATCH=0, AW=22)(
    input               rst,
    input               clk,
    input      [AW-1:0] ba0_addr,
    input      [AW-1:0] ba1_addr,
    input      [AW-1:0] ba2_addr,
    input      [AW-1:0] ba3_addr,
    output reg [AW-1:0] ba0_addr_l,
    output reg [AW-1:0] ba1_addr_l,
    output reg [AW-1:0] ba2_addr_l,
    output reg [AW-1:0] ba3_addr_l,
    input      [  12:0] ba0_row,
    input      [  12:0] ba1_row,
    input      [  12:0] ba2_row,
    input      [  12:0] ba3_row,
    input         [3:0] rd,
    input         [3:0] wr,
    input         [3:0] rdy,
    input               prog_en,
    input               prog_rd,
    input               prog_wr,
    output reg    [3:0] rd_l,
    output reg    [3:0] wr_l,
    output reg    [3:0] match,
    output reg          noreq
);

localparam RMSB = AW==22 ? AW-1 : AW-2,
           RLSB = RMSB-12;

wire prog_rq = prog_en &(prog_wr | prog_rd);

generate
    if( LATCH==1 ) begin
        always @(posedge clk, posedge rst) begin
            if( rst ) begin
                ba0_addr_l <= 0;
                ba1_addr_l <= 0;
                ba2_addr_l <= 0;
                ba3_addr_l <= 0;
                wr_l       <= 0;
                rd_l       <= 0;
                noreq      <= 1;
            end else begin
                ba0_addr_l <= ba0_addr;
                ba1_addr_l <= ba1_addr;
                ba2_addr_l <= ba2_addr;
                ba3_addr_l <= ba3_addr;
                match[0]   <= ba0_addr[RMSB:RLSB]===ba0_row;
                match[1]   <= ba1_addr[RMSB:RLSB]===ba1_row;
                match[2]   <= ba2_addr[RMSB:RLSB]===ba2_row;
                match[3]   <= ba3_addr[RMSB:RLSB]===ba3_row;
                wr_l       <= wr & ~rdy;
                rd_l       <= rd;
                noreq      <= ~|{wr,rd,prog_rq};
            end
        end
    end else begin
        always @(*) begin
                ba0_addr_l = ba0_addr;
                ba1_addr_l = ba1_addr;
                ba2_addr_l = ba2_addr;
                ba3_addr_l = ba3_addr;
                match[0]   = ba0_addr[RMSB:RLSB]===ba0_row;
                match[1]   = ba1_addr[RMSB:RLSB]===ba1_row;
                match[2]   = ba2_addr[RMSB:RLSB]===ba2_row;
                match[3]   = ba3_addr[RMSB:RLSB]===ba3_row;
                wr_l       = wr;
                rd_l       = rd;
                noreq      = ~|{wr,rd,prog_rq};
        end
    end
endgenerate

endmodule
