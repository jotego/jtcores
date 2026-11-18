/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-11-2026 */

// MiSTer UIO parser and stable request/result mailboxes for exact capture.
// HPS words are sampled only on io_strobe while io_enable is asserted.
module jtframe_mister_capture_io(
    input              clk_rom,
    input              rst,
    input              io_strobe,
    input              io_enable,
    input       [15:0] host_word,
    input              uio_start,
    input              uio_finish,
    input              uio_active,
    input       [15:0] uio_command,
    input       [ 6:0] uio_words,
    input       [95:0] uio_payload,
    input              uio_bad_word,
    input       [ 6:0] uio_bad_index,
    output     [127:0] uio_caps,
    output             uio_result_valid,
    input       [ 7:0] cap_state_in,
    input       [ 7:0] cap_fault_in,
    output reg         cap_req_toggle,
    output reg [ 31:0] cap_req,
    input              cap_req_ack_toggle,
    output reg         cap_release_toggle,
    output reg  [15:0] cap_release,
    input              cap_release_ack_toggle,
    output reg         cap_abort_toggle,
    output reg  [15:0] cap_abort,
    input              cap_abort_ack_toggle,
    input              cap_result_toggle,
    input       [511:0] cap_result,
    output reg         cap_result_ack_toggle
);

localparam [15:0] CAP_CAPS=16'h0090, CAP_ARM=16'h0091,
                  CAP_RESULT_READ=16'h0092, CAP_RELEASE=16'h0093,
                  CAP_ABORT=16'h0094;
localparam [1:0] RD_NONE=0, RD_CAPS=1, RD_RESULT=2;
localparam [1:0] ACT_NONE=0, ACT_ARM=1, ACT_RELEASE=2, ACT_ABORT=3;
localparam [7:0] F_BAD_LENGTH=1, F_BAD_WORD=2, F_BAD_STATE=3,
                 F_BAD_RELEASE=12;

wire txn_active, txn_owned;
wire [1:0] read_mode;
wire [15:0] tx_command;
wire [6:0] txn_words, expected_words, received_bytes;
wire [63:0] tx_payload;
wire [7:0] tx_error;
reg result_valid;
reg [15:0] command_freshness, submitted_freshness, result_freshness;
reg [7:0] first_fault;
reg last_release_complete, owner_valid;
reg [14:0] owner_checkpoint, last_release_checkpoint;

reg [1:0] req_ack_sync, release_ack_sync, abort_ack_sync, result_toggle_sync;
reg req_ack_seen, release_ack_seen, abort_ack_seen, result_toggle_seen;
reg [1:0] action_kind;
reg action_busy, action_internal;
reg [14:0] active_checkpoint;
reg overrun_abort_pending;
reg [14:0] overrun_abort_checkpoint;
reg [15:0] caps_flags;
reg action_ack;
assign txn_active = uio_active;
assign tx_command = uio_command;
assign txn_words = uio_words;
assign received_bytes = uio_words-1'b1;
assign tx_payload = uio_payload[63:0];
assign txn_owned = tx_command>=CAP_CAPS && tx_command<=CAP_ABORT;
assign read_mode = !txn_active ? RD_NONE : tx_command==CAP_CAPS ? RD_CAPS :
                   tx_command==CAP_RESULT_READ ? RD_RESULT : RD_NONE;
assign expected_words = tx_command==CAP_CAPS || tx_command==CAP_ARM ? 8 :
                        tx_command==CAP_RESULT_READ ? 64 : 4;
assign tx_error = uio_bad_word && uio_bad_index<=expected_words ? F_BAD_WORD :
                  received_bytes>expected_words ? F_BAD_LENGTH : 0;
assign uio_caps = {16'd0,result_freshness,16'd0,command_freshness,
                   caps_flags,16'd64,16'd2,16'hCA50};
assign uio_result_valid = result_valid;
wire txn_write = txn_active && txn_owned && read_mode==RD_NONE;
wire transport_busy = action_busy || overrun_abort_pending || txn_write;
wire has_fault = first_fault != 0 || cap_fault_in != 0;

always @* begin
    caps_flags = 16'd0;
    caps_flags[0] = transport_busy;
    caps_flags[1] = owner_valid;
    caps_flags[2] = cap_state_in == 8'd3 && result_valid && !has_fault;
    caps_flags[3] = has_fault;
    caps_flags[4] = last_release_complete;
    caps_flags[5] = cap_state_in == 8'd5;
    // Native capture v3: descriptor contains a write-side pixel checksum.
    caps_flags[6] = 1'b1;
    caps_flags[15:8] = first_fault != 0 ? first_fault : cap_fault_in;
    action_ack = action_kind == ACT_ARM ? req_ack_sync[1] == cap_req_toggle :
                 action_kind == ACT_RELEASE ? release_ack_sync[1] == cap_release_toggle :
                 action_kind == ACT_ABORT ? abort_ack_sync[1] == cap_abort_toggle : 1'b0;
end

always @(posedge clk_rom) begin
    if(rst) begin
        result_valid            <= 1'b0;
        command_freshness      <= 16'd0;
        submitted_freshness      <= 16'd0;
        result_freshness    <= 16'd0;
        first_fault             <= 8'd0;
        last_release_complete   <= 1'b0;
        owner_valid             <= 1'b0;
        owner_checkpoint        <= 15'd0;
        last_release_checkpoint <= 15'd0;
        req_ack_sync            <= 2'b00;
        release_ack_sync        <= 2'b00;
        abort_ack_sync          <= 2'b00;
        result_toggle_sync      <= 2'b00;
        req_ack_seen            <= 1'b0;
        release_ack_seen        <= 1'b0;
        abort_ack_seen          <= 1'b0;
        result_toggle_seen      <= 1'b0;
        cap_req_toggle          <= 1'b0;
        cap_req                 <= 32'd0;
        cap_release_toggle      <= 1'b0;
        cap_release             <= 16'd0;
        cap_abort_toggle        <= 1'b0;
        cap_abort               <= 16'd0;
        cap_result_ack_toggle   <= 1'b0;
        action_kind             <= ACT_NONE;
        action_busy             <= 1'b0;
        action_internal         <= 1'b0;
        active_checkpoint       <= 15'd0;
        overrun_abort_pending   <= 1'b0;
        overrun_abort_checkpoint<= 15'd0;
    end else begin
        req_ack_sync       <= {req_ack_sync[0], cap_req_ack_toggle};
        release_ack_sync   <= {release_ack_sync[0], cap_release_ack_toggle};
        abort_ack_sync     <= {abort_ack_sync[0], cap_abort_ack_toggle};
        result_toggle_sync <= {result_toggle_sync[0], cap_result_toggle};

        // Capture and transport faults share the CAPS first-fault field. The
        // coherent ascal fault is sampled into the same sticky latch; ignore
        // the pre-ARM fault while a fresh idle ARM is awaiting its decision.
        if(first_fault==0 && cap_fault_in!=0 &&
           !(action_busy && action_kind==ACT_ARM))
            first_fault <= cap_fault_in;

        if(result_toggle_sync[1] != result_toggle_seen) begin
            result_toggle_seen <= result_toggle_sync[1];
            if(owner_valid && cap_result[8*8 +: 15] == owner_checkpoint) begin
                result_valid <= 1'b1;
                result_freshness <= result_freshness + 1'b1;
            end else if(first_fault==0 && cap_fault_in==0) begin
                // ACK the stale mailbox so it cannot block future results,
                // but never advertise it as this request's cached result.
                first_fault <= F_BAD_STATE;
            end
            cap_result_ack_toggle <= result_toggle_sync[1];
        end

        if(action_busy && action_ack) begin
            action_busy <= 1'b0;
            action_kind <= ACT_NONE;
            if(!action_internal) command_freshness <= submitted_freshness;
            if(action_kind == ACT_ARM) begin
                if(cap_state_in != 0 && cap_state_in != 4 && cap_fault_in == 0) begin
                    owner_checkpoint <= cap_req[14:0];
                    owner_valid <= 1'b1;
                end else begin
                    if(first_fault==0) first_fault <= cap_fault_in!=0 ? cap_fault_in : F_BAD_STATE;
                    owner_valid <= 1'b0;
                end
            end else if(action_kind == ACT_RELEASE) begin
                if(cap_state_in == 0 && cap_fault_in == 0) begin
                    owner_valid <= 1'b0;
                    result_valid <= 1'b0;
                    last_release_complete <= 1'b1;
                    last_release_checkpoint <= active_checkpoint;
                end else begin
                    // An ACK toggle alone cannot certify a clean release.
                    // Keep the tuple owned so the caller can abort safely.
                    if(first_fault==0 && cap_fault_in==0) first_fault <= F_BAD_STATE;
                    last_release_complete <= 1'b0;
                end
            end else if(action_kind == ACT_ABORT) begin
                if(cap_state_in == 0) begin
                    owner_valid <= 1'b0;
                    result_valid <= 1'b0;
                    last_release_complete <= 1'b0;
                end else if(first_fault==0 && cap_fault_in==0) begin
                    // A rejected abort is acknowledged to retire its toggle,
                    // but ownership remains live until cleanup reaches IDLE.
                    first_fault <= F_BAD_STATE;
                end
            end
            action_internal <= 1'b0;
        end

        if(!action_busy && overrun_abort_pending) begin
            cap_abort <= {1'b0,overrun_abort_checkpoint};
            cap_abort_toggle <= ~cap_abort_toggle;
            active_checkpoint <= overrun_abort_checkpoint;
            action_kind <= ACT_ABORT;
            action_busy <= 1'b1;
            action_internal <= 1'b1;
            overrun_abort_pending <= 1'b0;
        end

        if(uio_finish) begin
            if(txn_active && txn_owned) begin
                if(read_mode != RD_NONE) begin
                    if(txn_words != expected_words + 1'd1 && first_fault==0 && cap_fault_in==0)
                        first_fault <= F_BAD_LENGTH;
                    if(read_mode==RD_RESULT && !result_valid && first_fault==0 && cap_fault_in==0)
                        first_fault <= F_BAD_STATE;
                end else if(tx_error != 0 || received_bytes != expected_words) begin
                    if(first_fault==0 && cap_fault_in==0)
                        first_fault <= tx_error!=0 ? tx_error : F_BAD_LENGTH;
                end else if(action_busy || overrun_abort_pending) begin
                    if(first_fault==0 && cap_fault_in==0) first_fault <= F_BAD_STATE;
                    overrun_abort_pending <= 1'b1;
                    overrun_abort_checkpoint <= owner_valid ? owner_checkpoint : active_checkpoint;
                end else if(tx_command == CAP_ARM) begin
                    // Reject bits that cannot be represented by the bundled
                    // request. Ascal validates the checkpoint and hold range.
                    if(cap_state_in != 0 || owner_valid || tx_payload[15] ||
                       tx_payload[31:16] != 0 || |tx_payload[63:43]) begin
                        if(first_fault==0 && cap_fault_in==0) first_fault <= F_BAD_STATE;
                        command_freshness <= command_freshness + 1'b1;
                    end else begin
                        cap_req <= {5'd0,tx_payload[42:32],1'b0,tx_payload[14:0]};
                        cap_req_toggle <= ~cap_req_toggle;
                        submitted_freshness <= command_freshness + 1'b1;
                        action_kind <= ACT_ARM;
                        action_busy <= 1'b1;
                        action_internal <= 1'b0;
                        owner_checkpoint <= tx_payload[14:0];
                        active_checkpoint <= tx_payload[14:0];
                        last_release_complete <= 1'b0;
                        result_valid <= 1'b0;
                        first_fault <= 8'd0;
                    end
                end else if(tx_command == CAP_RELEASE) begin
                    if(tx_payload[14:0] == last_release_checkpoint &&
                       tx_payload[31:15] == 0 &&
                       last_release_complete) begin
                        command_freshness <= command_freshness + 1'b1;
                    end else if(!owner_valid || tx_payload[14:0] != owner_checkpoint ||
                                tx_payload[31:15] != 0 || tx_payload[14:0] == 0) begin
                        if(first_fault==0 && cap_fault_in==0) first_fault <= F_BAD_RELEASE;
                        command_freshness <= command_freshness + 1'b1;
                    end else begin
                        cap_release <= {1'b0,tx_payload[14:0]};
                        cap_release_toggle <= ~cap_release_toggle;
                        active_checkpoint <= tx_payload[14:0];
                        submitted_freshness <= command_freshness + 1'b1;
                        action_kind <= ACT_RELEASE;
                        action_busy <= 1'b1;
                        action_internal <= 1'b0;
                        last_release_complete <= 1'b0;
                    end
                end else if(tx_command == CAP_ABORT) begin
                    if(!owner_valid || tx_payload[14:0] != owner_checkpoint ||
                       tx_payload[31:15] != 0 || tx_payload[14:0] == 0) begin
                        if(first_fault==0 && cap_fault_in==0) first_fault <= F_BAD_STATE;
                        command_freshness <= command_freshness + 1'b1;
                    end else begin
                        cap_abort <= {1'b0,tx_payload[14:0]};
                        cap_abort_toggle <= ~cap_abort_toggle;
                        active_checkpoint <= tx_payload[14:0];
                        submitted_freshness <= command_freshness + 1'b1;
                        action_kind <= ACT_ABORT;
                        action_busy <= 1'b1;
                        action_internal <= 1'b0;
                    end
                end
            end
        end
        if(uio_start) begin
            if(host_word==CAP_RESULT_READ && !result_valid && first_fault==0 && cap_fault_in==0)
                first_fault <= F_BAD_STATE;
        end
    end
end

endmodule
