/* SPDX-License-Identifier: GPL-3.0-or-later */

// Shares the K056832 tile-ROM slot between the visible line fetcher and the
// CPU's 0x1b0000 readback window.  The CPU request wins only after a full
// low-CS break, so an edge-triggered JTFRAME cache cannot reuse a tile reply.
module jtmoomsa_k056832_romrd(
    input             rst,
    input             clk,
    input             rd_cs,
    input      [12:1] rd_addr,
    input      [15:0] rd_bank,
    output            rd_ok,
    output     [15:0] rd_data,
    input      [18:0] tile_addr,
    input             tile_cs,
    output            tile_ok,
    output     [20:2] scr_addr,
    output            scr_cs,
    input      [31:0] scr_data,
    input             scr_ok
);

localparam S_IDLE = 3'd0, S_BREAK = 3'd1, S_REQ = 3'd2,
           S_WAIT = 3'd3, S_DONE = 3'd4;

reg [2:0] state;
reg [12:1] rd_addr_l;
reg [15:0] rd_bank_l;
reg [15:0] rd_data_l;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= S_IDLE;
        rd_addr_l <= 0;
        rd_bank_l <= 0;
        rd_data_l <= 0;
    end else begin
        case (state)
            S_IDLE: if (rd_cs) begin
                rd_addr_l <= rd_addr;
                rd_bank_l <= rd_bank;
                state <= S_BREAK;
            end
            S_BREAK: state <= rd_cs ? S_REQ : S_IDLE;
            S_REQ:   state <= rd_cs ? S_WAIT : S_IDLE;
            S_WAIT: begin
                if (!rd_cs)
                    state <= S_IDLE;
                else if (scr_ok) begin
                    rd_data_l <= rd_addr_l[1] ? scr_data[31:16] : scr_data[15:0];
                    state <= S_DONE;
                end
            end
            S_DONE: if (!rd_cs) state <= S_IDLE;
            default: state <= S_IDLE;
        endcase
    end
end

assign scr_cs = rd_cs ? ((state == S_REQ) || (state == S_WAIT)) :
                ((state == S_IDLE) ? tile_cs : 1'b0);
assign scr_addr = (rd_cs && ((state == S_REQ) || (state == S_WAIT))) ?
                  {rd_bank_l[7:0],rd_addr_l[12:2]} : tile_addr;
assign rd_ok = rd_cs && (state == S_DONE);
assign rd_data = rd_data_l;
assign tile_ok = !rd_cs && (state == S_IDLE) && scr_ok;

endmodule
