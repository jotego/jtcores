/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-5-2026 */

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
reg [7:0]  active_onehot;

// One-hot distribution of ack/dst/dok/rdy to the selected port — 1 LUT level
assign ext_ack = {8{ack}} & active_onehot;
assign ext_dst = {8{dst}} & active_onehot;
assign ext_dok = {8{dok}} & active_onehot;
assign ext_rdy = {8{rdy}} & active_onehot;

// One-hot mux for rd/wr from the selected port — 2 LUT levels (AND+reduction)
assign rd = |(active_onehot & ext_rd);
assign wr = |(active_onehot & ext_wr);

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
        active        <= 1'b0;
        active_sel    <= 3'd0;
        active_onehot <= 8'd0;
    end else begin
        if( active ) begin
            if( rdy ) begin
                active        <= 1'b0;
                active_onehot <= 8'd0;
            end
        end else if( next_valid ) begin
            active        <= 1'b1;
            active_sel    <= next_sel;
            active_onehot <= 8'd1 << next_sel;
        end
    end
end

endmodule
