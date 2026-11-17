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
    output reg         response_enable,
    output reg  [15:0] response_word,
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

reg txn_active, txn_owned;
reg [1:0] read_mode;
reg [15:0] tx_command;
reg [6:0] txn_words, read_index;
reg [6:0] expected_words;
reg [4:0] received_bytes;
reg [63:0] tx_payload;
reg [7:0] tx_error;
reg [127:0] caps_latch;
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
reg [7:0] caps_fault_code;
reg [15:0] transaction_expected;
reg transaction_known, transaction_read;
reg action_ack;
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
    caps_flags[15:8] = first_fault != 0 ? first_fault : cap_fault_in;
    caps_fault_code = first_fault != 0 ? first_fault : cap_fault_in;
    transaction_expected = 0;
    transaction_known = 1'b1;
    transaction_read = 1'b0;
    case(host_word)
        CAP_CAPS: begin transaction_expected=8; transaction_read=1; end
        CAP_ARM: begin transaction_expected=8; end
        CAP_RESULT_READ: begin transaction_expected=64; transaction_read=1; end
        CAP_RELEASE, CAP_ABORT: begin transaction_expected=4; end
        default: transaction_known=1'b0;
    endcase
    action_ack = action_kind == ACT_ARM ? req_ack_sync[1] == cap_req_toggle :
                 action_kind == ACT_RELEASE ? release_ack_sync[1] == cap_release_toggle :
                 action_kind == ACT_ABORT ? abort_ack_sync[1] == cap_abort_toggle : 1'b0;
end

always @(posedge clk_rom) begin
    if(rst) begin
        txn_active              <= 1'b0;
        txn_owned               <= 1'b0;
        read_mode               <= RD_NONE;
        tx_command              <= 16'd0;
        txn_words               <= 7'd0;
        read_index              <= 7'd0;
        expected_words          <= 7'd0;
        received_bytes          <= 5'd0;
        tx_payload              <= 64'd0;
        tx_error                <= 8'd0;
        caps_latch              <= 128'd0;
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
        response_enable         <= 1'b0;
        response_word           <= 16'd0;
    end else begin
        req_ack_sync       <= {req_ack_sync[0], cap_req_ack_toggle};
        release_ack_sync   <= {release_ack_sync[0], cap_release_ack_toggle};
        abort_ack_sync     <= {abort_ack_sync[0], cap_abort_ack_toggle};
        result_toggle_sync <= {result_toggle_sync[0], cap_result_toggle};
        response_enable    <= io_enable && read_mode!=RD_NONE;

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

        if(!io_enable) begin
            if(txn_active && txn_owned) begin
                if(read_mode != RD_NONE) begin
                    if(txn_words != expected_words + 1'd1 && first_fault==0 && cap_fault_in==0)
                        first_fault <= F_BAD_LENGTH;
                    if(read_mode==RD_RESULT && !result_valid && first_fault==0 && cap_fault_in==0)
                        first_fault <= F_BAD_STATE;
                end else if(tx_error != 0 || {2'b0,received_bytes} != expected_words) begin
                    if(first_fault==0 && cap_fault_in==0)
                        first_fault <= tx_error!=0 ? tx_error : F_BAD_LENGTH;
                end else if(action_busy || overrun_abort_pending) begin
                    if(first_fault==0 && cap_fault_in==0) first_fault <= F_BAD_STATE;
                    overrun_abort_pending <= 1'b1;
                    overrun_abort_checkpoint <= owner_valid ? owner_checkpoint : active_checkpoint;
                end else if(tx_command == CAP_ARM) begin
                    if(cap_state_in != 0 || owner_valid || tx_payload[15] ||
                       tx_payload[31:16] != 0 || tx_payload[63:32] < 100 ||
                       tx_payload[63:32] > 2000 || tx_payload[14:0] == 0) begin
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
            txn_active <= 1'b0;
            txn_owned <= 1'b0;
            read_mode <= RD_NONE;
            txn_words <= 7'd0;
            read_index <= 7'd0;
            received_bytes <= 5'd0;
            tx_error <= 8'd0;
            expected_words <= 7'd0;
        end else if(io_strobe) begin
            if(!txn_active) begin
                txn_active <= 1'b1;
                txn_words <= 7'd1;
                tx_command <= host_word;
                tx_payload <= 64'd0;
                received_bytes <= 5'd0;
                tx_error <= 8'd0;
                read_index <= 7'd0;
                expected_words <= transaction_expected[6:0];
                txn_owned <= transaction_known;
                read_mode <= RD_NONE;
                if(transaction_known && transaction_read) begin
                    if(host_word == CAP_CAPS) begin
                        caps_latch <= {16'd0,result_freshness,16'd0,
                            command_freshness,caps_flags,16'd64,16'd2,16'hCA50};
                        read_mode <= RD_CAPS;
                    end else begin
                        if(!result_valid && first_fault==0 && cap_fault_in==0)
                            first_fault <= F_BAD_STATE;
                        read_mode <= RD_RESULT;
                    end
                end
            end else begin
                if(txn_words != 7'h7f) txn_words <= txn_words + 1'b1;
                if(read_mode==RD_CAPS) begin
                    response_word <= caps_latch[{read_index[2:0],4'b0000} +: 16];
                    read_index <= read_index + 1'b1;
                end else if(read_mode==RD_RESULT) begin
                    response_word <= {8'd0,(result_valid ? cap_result[{read_index[5:0],3'b000} +: 8] : 8'd0)};
                    read_index <= read_index + 1'b1;
                end else if(txn_owned) begin
                    if(received_bytes < 8) begin
                        tx_payload[{received_bytes[2:0],3'b000} +: 8] <= host_word[7:0];
                        received_bytes <= received_bytes + 1'b1;
                        if(host_word[15:8] != 0 && tx_error==0) tx_error <= F_BAD_WORD;
                        if({2'b0,received_bytes} >= expected_words && tx_error==0) tx_error <= F_BAD_LENGTH;
                    end else if(tx_error==0) tx_error <= F_BAD_LENGTH;
                end
            end
        end
    end
end

endmodule
