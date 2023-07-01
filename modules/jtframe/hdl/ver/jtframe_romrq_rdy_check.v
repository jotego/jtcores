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
    Date: 3-5-2021 */

// Verifies that the SDRAM is driven correctly

module jtframe_romrq_rdy_check(
    input       rst,
    input       clk,
    input [3:0] ba_rd,
    input [3:0] ba_wr,
    input [3:0] ba_ack,
    input [3:0] ba_rdy
);

reg  [3:0] busy, ackd, last_rq;
wire [3:0] rq = ba_rd | ba_wr;
wire [3:0] rq_edge = rq & ~last_rq;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy <= 0;
        ackd <= 0;
        last_rq <= 0;
    end else begin
        last_rq <= rq;
        busy <= (busy | rq_edge) & ~ba_ack;
        if( ba_ack & ~busy ) begin
            $display("Warning: ACK from SDRAM but there was no active request (busy=%4b, ack=%4b)", busy, ba_ack );
        end
        ackd <= (ackd & ~rq_edge & ~ba_rdy ) | ba_ack;
        if( ba_rdy & ~ackd ) begin
            $display("\nError: RDY from SDRAM but there was no acknowledgement (rdy=%4b, ackd=%4b)\n", ba_rdy, ackd );
            $finish;
        end
    end
end

endmodule