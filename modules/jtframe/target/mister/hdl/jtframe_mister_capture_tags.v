/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

// MiSTer regression capture tags.  The only tag identity is the native
// checkpoint; checkpoint N identifies interval N-1.  Lifecycle traffic uses
// a stable toggle mailbox, whose handshake (not a run epoch) separates runs.
module jtframe_mister_capture_tags(
    input              clk_sys,
    input              rst,
    input              lvbl,
    input              cab_frame_start,
    input       [14:0] cab_frame_index,
    input       [14:0] cab_completed,
    input       [ 2:0] cab_state,
    input       [ 7:0] cab_error,
    output reg         cap_tag_valid,
    output reg  [14:0] cap_tag,
    input              cap_tag_ready,
    output reg         cap_tag_overflow,
    output reg         cap_tag_sequence_error,
    output            cap_tag_error,
    output reg         cap_life_toggle,
    output reg  [31:0] cap_life,
    input              cap_life_ack_toggle
);

localparam [2:0] CAB_IDLE=3'd0, CAB_ARMED=3'd1, CAB_RUNNING=3'd2,
                 CAB_DONE=3'd3, CAB_ERROR=3'd4;

reg lvbl_l;
reg interval_active;
reg [14:0] interval_index, last_tag_checkpoint;
reg tag_seen;
reg [1:0] life_ack_sync;
reg life_ack_seen;
reg [14:0] observed_count;
reg [2:0] observed_state;
reg [7:0] observed_error;
reg life_latest_valid, life_abort_pending;
reg tag_error_clear_pending;
reg [31:0] life_latest, life_abort;
reg observed_active, life_initialized;
reg [31:0] life_next;
reg life_event, life_abort_event;
reg end_token;
reg [14:0] end_checkpoint;
wire life_busy = cap_life_toggle != life_ack_sync[1];
wire life_ack_event = life_ack_sync[1] != life_ack_seen;

assign cap_tag_error = cap_tag_overflow || cap_tag_sequence_error;

always @* begin
    life_event = !life_initialized || cab_state != observed_state ||
                 cab_error != observed_error;
    life_abort_event = cab_error != 0 || cab_state == CAB_ERROR ||
                       (observed_active && cab_state == CAB_IDLE) ||
                       (cab_state == CAB_ARMED && observed_state != CAB_IDLE &&
                        observed_state != CAB_ARMED);
    life_next = 32'd0;
    life_next[14:0] = cab_completed;
    life_next[17:15] = cab_state;
    life_next[25:18] = cab_error;
    end_token = lvbl_l && !lvbl && interval_active && cab_error == 0 &&
                (cab_state == CAB_RUNNING ||
                 (cab_state == CAB_DONE && interval_index < cab_completed));
    end_checkpoint = interval_index + 15'd1;
end

always @(posedge clk_sys) begin
    if (rst) begin
        lvbl_l <= 1'b0;
        life_ack_sync <= 2'b00;
        interval_active <= 1'b0;
        interval_index <= 15'd0;
        last_tag_checkpoint <= 15'd0;
        tag_seen <= 1'b0;
        cap_tag_valid <= 1'b0;
        cap_tag <= 15'd0;
        cap_tag_overflow <= 1'b0;
        cap_tag_sequence_error <= 1'b0;
        cap_life_toggle <= 1'b0;
        cap_life <= 32'd0;
        life_ack_seen <= 1'b0;
        observed_count <= 15'd0;
        observed_state <= CAB_IDLE;
        observed_error <= 8'd0;
        life_latest <= 32'd0;
        life_abort <= 32'd0;
        life_latest_valid <= 1'b0;
        life_abort_pending <= 1'b0;
        tag_error_clear_pending <= 1'b0;
        observed_active <= 1'b0;
        life_initialized <= 1'b0;
    end else begin
        lvbl_l <= lvbl;
        life_ack_sync <= {life_ack_sync[0], cap_life_ack_toggle};
        if (cap_tag_valid && cap_tag_ready) cap_tag_valid <= 1'b0;

        if (cab_frame_start) begin
            if (cab_state == CAB_RUNNING && cab_error == 0 && lvbl) begin
                interval_index <= cab_frame_index;
                interval_active <= 1'b1;
            end else begin
                interval_active <= 1'b0;
            end
        end
        if (lvbl_l && !lvbl) interval_active <= 1'b0;

        if (end_token) begin
            if (tag_seen && end_checkpoint != last_tag_checkpoint + 15'd1)
                cap_tag_sequence_error <= 1'b1;
            if (!cap_tag_valid || cap_tag_ready) begin
                cap_tag_valid <= 1'b1;
                cap_tag <= end_checkpoint;
                last_tag_checkpoint <= end_checkpoint;
                tag_seen <= 1'b1;
            end else begin
                // Never stall native video. A dropped token permanently faults
                // the session rather than allowing a later identity to alias.
                cap_tag_overflow <= 1'b1;
            end
        end

        if (life_ack_event) begin
            life_ack_seen <= life_ack_sync[1];
            if (tag_error_clear_pending && cap_life[17:15]==CAB_ARMED &&
                cap_life[25:18]==0) begin
                cap_tag_overflow <= 1'b0;
                cap_tag_sequence_error <= 1'b0;
                tag_error_clear_pending <= 1'b0;
            end
        end

        // A coalesced latest state and a priority stop/error survive a mailbox
        // transaction already in flight.  ARM is not admitted until the ascal
        // side has consumed and acknowledged these stable tuples.
        if (!life_busy && !life_ack_event && (life_abort_pending || life_latest_valid)) begin
            if (life_abort_pending) begin
                cap_life <= life_abort;
                cap_life_toggle <= ~cap_life_toggle;
                life_abort_pending <= 1'b0;
                if (life_latest_valid && life_latest == life_abort)
                    life_latest_valid <= 1'b0;
            end else if (life_latest_valid) begin
                cap_life <= life_latest;
                cap_life_toggle <= ~cap_life_toggle;
                life_latest_valid <= 1'b0;
            end
        end

        if (life_event) begin
            life_initialized <= 1'b1;
            observed_count <= cab_completed;
            observed_state <= cab_state;
            observed_error <= cab_error;
            observed_active <= cab_state == CAB_ARMED || cab_state == CAB_RUNNING ||
                               cab_state == CAB_DONE;
            tag_seen <= 1'b0;
            last_tag_checkpoint <= 15'd0;
            if (cab_state==CAB_ARMED && observed_state==CAB_IDLE && cab_error==0)
                tag_error_clear_pending <= 1'b1;
            if (!life_busy && life_ack_sync[1] == life_ack_seen &&
                !life_abort_pending && !life_latest_valid) begin
                cap_life <= life_next;
                cap_life_toggle <= ~cap_life_toggle;
            end else begin
                life_latest <= life_next;
                life_latest_valid <= 1'b1;
                if (life_abort_event) begin
                    life_abort <= life_next;
                    life_abort_pending <= 1'b1;
                end
            end
        end
    end
end

endmodule
