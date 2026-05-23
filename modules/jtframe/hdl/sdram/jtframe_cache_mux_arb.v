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
    Date: 23-5-2026 */

module jtframe_cache_mux_arb(
    input            rst,
    input            clk,

    input      [7:0] ext_req,
    input      [7:0] ext_rd,
    input      [7:0] ext_wr,
    input            ack,
    input            dst,
    input            dok,
    input            rdy,

    output reg       active,
    output reg [2:0] active_sel,
    output     [7:0] ext_ack,
    output     [7:0] ext_dst,
    output     [7:0] ext_dok,
    output     [7:0] ext_rdy,
    output           rd,
    output           wr
);

reg        next_valid;
reg [2:0]  next_sel;

assign ext_ack = {
    active && active_sel==3'd7 && ack,
    active && active_sel==3'd6 && ack,
    active && active_sel==3'd5 && ack,
    active && active_sel==3'd4 && ack,
    active && active_sel==3'd3 && ack,
    active && active_sel==3'd2 && ack,
    active && active_sel==3'd1 && ack,
    active && active_sel==3'd0 && ack
};

assign ext_dst = {
    active && active_sel==3'd7 && dst,
    active && active_sel==3'd6 && dst,
    active && active_sel==3'd5 && dst,
    active && active_sel==3'd4 && dst,
    active && active_sel==3'd3 && dst,
    active && active_sel==3'd2 && dst,
    active && active_sel==3'd1 && dst,
    active && active_sel==3'd0 && dst
};

assign ext_dok = {
    active && active_sel==3'd7 && dok,
    active && active_sel==3'd6 && dok,
    active && active_sel==3'd5 && dok,
    active && active_sel==3'd4 && dok,
    active && active_sel==3'd3 && dok,
    active && active_sel==3'd2 && dok,
    active && active_sel==3'd1 && dok,
    active && active_sel==3'd0 && dok
};

assign ext_rdy = {
    active && active_sel==3'd7 && rdy,
    active && active_sel==3'd6 && rdy,
    active && active_sel==3'd5 && rdy,
    active && active_sel==3'd4 && rdy,
    active && active_sel==3'd3 && rdy,
    active && active_sel==3'd2 && rdy,
    active && active_sel==3'd1 && rdy,
    active && active_sel==3'd0 && rdy
};

assign rd = active && (
    (active_sel == 3'd0 && ext_rd[0]) ||
    (active_sel == 3'd1 && ext_rd[1]) ||
    (active_sel == 3'd2 && ext_rd[2]) ||
    (active_sel == 3'd3 && ext_rd[3]) ||
    (active_sel == 3'd4 && ext_rd[4]) ||
    (active_sel == 3'd5 && ext_rd[5]) ||
    (active_sel == 3'd6 && ext_rd[6]) ||
    (active_sel == 3'd7 && ext_rd[7])
);

assign wr = active && (
    (active_sel == 3'd0 && ext_wr[0]) ||
    (active_sel == 3'd1 && ext_wr[1]) ||
    (active_sel == 3'd2 && ext_wr[2]) ||
    (active_sel == 3'd3 && ext_wr[3]) ||
    (active_sel == 3'd4 && ext_wr[4]) ||
    (active_sel == 3'd5 && ext_wr[5]) ||
    (active_sel == 3'd6 && ext_wr[6]) ||
    (active_sel == 3'd7 && ext_wr[7])
);

always @(*) begin
    next_valid = 1'b0;
    next_sel   = 3'd0;
    if( ext_req[0] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd0;
    end else if( ext_req[1] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd1;
    end else if( ext_req[2] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd2;
    end else if( ext_req[3] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd3;
    end else if( ext_req[4] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd4;
    end else if( ext_req[5] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd5;
    end else if( ext_req[6] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd6;
    end else if( ext_req[7] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd7;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        active     <= 1'b0;
        active_sel <= 3'd0;
    end else begin
        if( active ) begin
            if( rdy ) active <= 1'b0;
        end else if( next_valid ) begin
            active     <= 1'b1;
            active_sel <= next_sel;
        end
    end
end

endmodule
