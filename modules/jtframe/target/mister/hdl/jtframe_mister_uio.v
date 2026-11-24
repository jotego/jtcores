/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-11-2026 */

// Shared transaction tracker for the CAB and capture UIO command ranges.
// All data are held until the transaction ends; command backends own the
// command-specific length, state, and ownership checks.
module jtframe_mister_uio #(
    parameter CAPTURE_SUPPORT=1
)(
    input              rst, clk,
    input              io_enable, io_strobe,
    input       [15:0] host_word,
    input      [127:0] cab_caps, cap_caps, cap_result,
    input      [255:0] cab_snapshot,
    input              cab_snapshot_valid,
    output             response_enable,
    output reg  [15:0] response_word,
    output             start,
    output             finish,
    output reg         active,
    output reg  [15:0] command,
    output reg  [ 6:0] words,
    output reg  [95:0] payload,
    output reg         bad_word,
    output reg  [ 6:0] bad_index
);

reg [127:0] caps_latch;
reg cab_read_valid;
reg wait_idle;
wire is_cab_caps, is_cap_caps, is_cab_read, is_cap_read;
wire [4:0] read_index;

assign start  = !rst && !wait_idle && io_enable && io_strobe && !active;
assign finish = !rst && !wait_idle && !io_enable && active;
assign is_cab_caps = command==16'h0080;
assign is_cap_caps = CAPTURE_SUPPORT && command==16'h0090;
assign is_cab_read = command==16'h0087;
assign is_cap_read = CAPTURE_SUPPORT && command==16'h0092;
assign read_index = words[4:0]-1'b1;
assign response_enable = !rst && !wait_idle && io_enable && active &&
                         (is_cab_caps || is_cap_caps || is_cab_read || is_cap_read);

always @(posedge clk) begin
    if(rst) begin
        active <= 0;
        command <= 0;
        words <= 0;
        payload <= 0;
        bad_word <= 0;
        bad_index <= 0;
        caps_latch <= 0;
        response_word <= 0;
        cab_read_valid <= 0;
        // A reset in the middle of a packet must discard its whole tail.
        // If the bus is idle at reset, the first subsequent packet is valid.
        wait_idle <= io_enable;
    end else if(wait_idle) begin
        if(!io_enable) wait_idle <= 0;
    end else if(!io_enable) begin
        active <= 0;
    end else if(io_strobe) begin
        if(!active) begin
            active <= 1;
            command <= host_word;
            words <= 1;
            payload <= 0;
            bad_word <= 0;
            bad_index <= 0;
            if(host_word==16'h0080) caps_latch <= cab_caps;
            if(host_word==16'h0090) caps_latch <= cap_caps;
            if(host_word==16'h0092) caps_latch <= cap_result;
            if(host_word==16'h0087) cab_read_valid <= cab_snapshot_valid;
        end else begin
            if(words!=7'h7f) words <= words+1'd1;
            if(words<=12) payload[{(words[3:0]-1'b1),3'b000} +: 8] <= host_word[7:0];
            if(host_word[15:8]!=0 && !bad_word) begin
                bad_word <= 1;
                bad_index <= words;
            end
            if(is_cab_caps || is_cap_caps || is_cap_read)
                response_word <= caps_latch[{read_index[2:0],4'b0000} +: 16];
            else if(is_cab_read)
                response_word <= cab_read_valid ?
                    {8'd0,cab_snapshot[{read_index[4:0],3'b000} +: 8]} : 16'd0;
        end
    end
end

endmodule
