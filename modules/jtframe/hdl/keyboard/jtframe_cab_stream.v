/* SPDX-License-Identifier: GPL-3.0-or-later
 * Frame-clocked cabinet input stream. Eight run-length entries, not a frame RAM.
 */

module jtframe_cab_stream #(
    parameter AW = 3
)(
    input              rst, clk,
    input              lvbl,
    input              capture_hold,
    output      [31:0] capture_frame, capture_epoch,
    input              rx_strobe,
    input       [ 7:0] rx_cmd, rx_byte,
    input       [ 4:0] rx_index,
    output             active, hold_reset,
    output reg  [20:0] inputs,
    output             dipsw_valid,
    output reg  [31:0] dipsw,
    output             dump_pause,
    output reg [511:0] snapshot
);

localparam [2:0] IDLE=0, ARMED=1, RUNNING=2, DONE=3, ERROR=4,
                 DUMP_WAIT=5, RESUME_WAIT=6;
localparam [AW:0] DEPTH = {1'b1,{AW{1'b0}}};
localparam [7:0] UNDERRUN=1, STALE=2, SEQUENCE=3, FULL=4,
                 BAD_EVENT=5, BAD_LENGTH=6, BAD_STATE=7;

reg [159:0] payload;
reg [95:0] queue[0:(1<<AW)-1];
reg [AW-1:0] wr_ptr, rd_ptr;
reg [AW:0] queued;
reg [31:0] epoch, frames, raster, accepted, applied, accepted_frames,
           total_frames, total_events, remaining, dump_seq, dump_frame, dump_raster;
reg [ 7:0] error;
reg [ 2:0] state;
reg [ 1:0] lvbl_sync;
reg lvbl_l, reset_on_arm, dipsw_set, dump_each_frame;

wire [159:0] packet;
wire [95:0] head;
wire [32:0] frame_sum;
wire [31:0] start_epoch;
wire [ 7:0] push_error;
wire [ 4:0] payload_index;
wire [AW:0] credits;
wire tick, arm_packet, start_packet, push_packet, stop_packet,
     enqueue, pop, start_ok, next_boundary, finish_boundary, ack_packet;

assign active     = state==ARMED || state==RUNNING || dump_pause;
assign dump_pause = state==DUMP_WAIT || state==RESUME_WAIT;
assign dipsw_valid= active && dipsw_set;
assign hold_reset = state==ARMED && reset_on_arm;
assign tick       = lvbl_sync[1] && !lvbl_l;
assign capture_frame=frames;
assign capture_epoch=epoch;
assign packet     = rx_cmd==8'h86 ? {rx_byte,payload[151:0]} : {32'd0,rx_byte,payload[119:0]};
assign payload_index = rx_index-5'd1;
assign start_epoch= {rx_byte,payload[23:0]};
assign arm_packet = rx_strobe && rx_cmd==8'h82 && rx_index==9;
assign start_packet=rx_strobe && rx_cmd==8'h84 && rx_index==4;
assign push_packet= rx_strobe && ((rx_cmd==8'h83 && rx_index==16) || (rx_cmd==8'h86 && rx_index==20));
assign stop_packet= rx_strobe && rx_cmd==8'h85 && rx_index==0;
assign ack_packet = rx_strobe && rx_cmd==8'h88 && rx_index==8;
assign credits    = DEPTH-queued;
assign frame_sum  = {1'b0,accepted_frames}+{1'b0,packet[95:64]};
assign push_error = !active                         ? BAD_STATE :
                    packet[31:0]!=epoch             ? STALE :
                    packet[63:32]!=accepted         ? SEQUENCE :
                    queued==DEPTH                   ? FULL :
                    packet[95:64]==0 || |packet[127:119] || (rx_cmd==8'h83 && |packet[118:117]) ? BAD_EVENT :
                    accepted>=total_events || frame_sum>{1'b0,total_frames} ||
                    (accepted==total_events-1 && frame_sum!={1'b0,total_frames})
                                                    ? BAD_LENGTH : 8'd0;
assign enqueue    = push_packet && push_error==0;
assign start_ok   = start_packet && state==ARMED && start_epoch==epoch && queued!=0;
assign finish_boundary = state==RUNNING && tick && !capture_hold && frames==total_frames-1;
assign next_boundary   = state==RUNNING && tick && !capture_hold && remaining==1 && !finish_boundary;
assign pop        = start_ok || (next_boundary && (queued!=0 || enqueue));
assign head       = queued!=0 ? queue[rd_ptr] : packet[159:64];

always @(posedge clk) begin
    lvbl_sync <= {lvbl_sync[0],lvbl};
    lvbl_l    <= lvbl_sync[1];
end

always @(posedge clk) begin
    if(rst) payload <= 0;
    else if(rx_strobe) begin
        if(rx_index==0) payload <= 0;
        else if(rx_index<=20) payload[{payload_index,3'b000} +: 8] <= rx_byte;
    end
end

// Eight duration/input/DIP records, independent of script length.
always @(posedge clk) if(enqueue) queue[wr_ptr] <= packet[159:64];

always @(posedge clk) begin
    if(rst) begin
        state<=IDLE; error<=0; epoch<=0; frames<=0; raster<=0;
        accepted<=0; applied<=0; accepted_frames<=0;
        total_frames<=0; total_events<=0; remaining<=0;
        wr_ptr<=0; rd_ptr<=0; queued<=0; inputs<=0; reset_on_arm<=0;
        dipsw<=0; dipsw_set<=0;
        dump_seq<=0; dump_frame<=0; dump_raster<=0; dump_each_frame<=0;
    end else begin
        if(tick) raster <= raster+1'd1;
        if(enqueue) begin
            wr_ptr <= wr_ptr+1'd1;
            accepted <= accepted+1'd1;
            accepted_frames <= frame_sum[31:0];
        end
        if(pop) begin
            rd_ptr <= rd_ptr+1'd1;
            applied <= applied+1'd1;
            remaining <= head[31:0];
            inputs <= head[52:32];
            if(head[53]) begin dipsw<=head[95:64]; dipsw_set<=1; end
            dump_each_frame <= head[54];
            if(head[54]) begin
                state<=DUMP_WAIT; dump_seq<=dump_seq+1'd1;
                dump_frame<=start_ok ? 32'd0 : frames+1'd1;
                dump_raster<=raster+{31'd0,tick};
            end
        end
        case ({enqueue,pop})
            2'b10: queued <= queued+1'd1;
            2'b01: queued <= queued-1'd1;
            default: ;
        endcase
        if(start_ok && !head[54]) state <= RUNNING;
        if(state==RUNNING && tick && !capture_hold) begin
            frames <= frames+1'd1;
            if(finish_boundary) begin
                state <= accepted==total_events ? DONE : ERROR;
                error <= accepted==total_events ? 8'd0 : BAD_LENGTH;
                inputs <= 0;
            end else if(remaining>1) begin
                remaining <= remaining-1'd1;
                if(dump_each_frame) begin
                    state<=DUMP_WAIT; dump_seq<=dump_seq+1'd1;
                    dump_frame<=frames+1'd1; dump_raster<=raster+1'd1;
                end
            end
            else if(queued==0 && !enqueue) begin
                state <= ERROR; error <= UNDERRUN; inputs <= 0;
            end
        end
        if(push_packet && push_error!=0) begin
            state<=ERROR; error<=push_error; inputs<=0;
        end
        if(start_packet && !start_ok) begin
            state<=ERROR; error<=start_epoch!=epoch ? STALE : BAD_STATE; inputs<=0;
        end
        if(ack_packet) begin
            if(state!=DUMP_WAIT || payload[31:0]!=epoch || {rx_byte,payload[55:32]}!=dump_seq) begin
                state<=ERROR; error<=STALE; inputs<=0;
            end else state<=RESUME_WAIT;
        end
        // Keep this CAB frame intact; resume its duration on the next raster.
        if(state==RESUME_WAIT && tick) state<=RUNNING;
        if(stop_packet) begin
            state<=IDLE; inputs<=0; queued<=0; wr_ptr<=0; rd_ptr<=0;
        end
        if(arm_packet) begin
            epoch<=epoch+1'd1; state<=ARMED; error<=0;
            frames<=0; accepted<=0; applied<=0; accepted_frames<=0;
            total_frames<=payload[31:0]; total_events<=payload[63:32];
            remaining<=0; queued<=0; wr_ptr<=0; rd_ptr<=0; inputs<=0;
            reset_on_arm<=rx_byte[0];
            dipsw<=0; dipsw_set<=0;
            dump_seq<=0; dump_frame<=0; dump_raster<=0; dump_each_frame<=0;
            if(payload[31:0]==0 || payload[63:32]==0 || |rx_byte[7:1]) begin
                state<=ERROR; error<=BAD_LENGTH;
            end
        end
    end
end

// The MCU reads a stable snapshot, not counters changing underneath its SPI read.
// Existing SPI receive CDC provides the request in clk_sys; two guard bytes on
// the read response allow the snapshot to settle before counter bytes are read.
always @(posedge clk) begin
    if(rst) snapshot <= 0;
    else if(rx_strobe && (rx_cmd==8'h81 || rx_cmd==8'h87 || rx_cmd==8'h89) && rx_index==0)
        snapshot <= {96'd0,dump_raster,dump_frame,dump_seq,31'd0,dipsw_valid,dipsw,11'd0,inputs,16'd0,{{(7-AW){1'b0}},credits},
                     {{(7-AW){1'b0}},queued},raster,applied,accepted,frames,epoch,
                     error,5'd0,state,(rx_cmd==8'h89 ? 8'd3 : rx_cmd==8'h87 ? 8'd2 : 8'd1),8'hca};
end

endmodule
