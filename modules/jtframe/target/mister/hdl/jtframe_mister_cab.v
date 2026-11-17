/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-11-2026 */

// MiSTer HPS transport for the framework CAB playback stream.
// MiSTer regression HPS UIO v2. Commands use full 16-bit IDs and feed native
// 15-bit frame/event fields; generic SiDi/MiST stream behavior stays in the
// shared stream's default parameter. CAB command/snapshot counters are 16-bit
// freshness only, with one outstanding command and modulo wrap.
module jtframe_mister_cab(
    input              rst,
    input              clk_rom,
    input              clk_sys,
    input              lvbl,
    input              io_strobe,
    input              io_enable,
    input       [15:0] host_word,
    output             response_enable,
    output reg  [15:0] response_word,
    output             cab_active,
    output             cab_hold_reset,
    output      [20:0] cab_inputs,
    output             cab_dipsw_valid,
    output      [31:0] cab_dipsw,
    output      [14:0] cab_frame,
    output             cab_frame_start,
    output      [14:0] cab_frame_index,
    output      [ 2:0] cab_state,
    output      [ 7:0] cab_error
);

localparam [15:0] CAPS=16'h0080, STATUS=16'h0081, ARM=16'h0082,
                  PUSH=16'h0083, START=16'h0084, STOP=16'h0085,
                  PUSH_DIP=16'h0086, SNAPSHOT_READ=16'h0087;
localparam [2:0] RD_NONE=0, RD_CAPS=1, RD_SNAPSHOT=2;
localparam [2:0] ST_IDLE=0, ST_FEED=1, ST_SNAPSHOT=2, ST_SNAPSHOT_ACK=3;
localparam [7:0] F_NONE=0, F_BAD_LENGTH=1, F_UNSUPPORTED=2,
                 F_OVERRUN=3, F_BAD_FLAGS=4, F_BAD_WORD=5, F_NO_SNAPSHOT=6,
                 F_BAD_EVENT=7;

// Read response ownership is arbitrated by jtframe_mister at EXT_BUS.
wire [511:0] stream_snapshot;
wire [7:0]  stream_rx_cmd, stream_rx_byte;
wire [4:0]  stream_rx_index;
wire        stream_rx_strobe;
wire        stream_frame_start;
wire        stream_cab_active, stream_hold_reset, stream_dipsw_valid;
wire [ 2:0] stream_state_out;
wire [ 7:0] stream_error_out;
wire [20:0] stream_inputs;
wire [31:0] stream_dipsw, stream_frame;
wire [31:0] stream_frame_index;

reg [15:0] tx_command;
reg [95:0] tx_payload;
reg [4:0] expected_bytes, received_bytes;
reg [6:0] txn_words;
reg [7:0] tx_error;
reg txn_active, txn_owned;
reg [2:0] read_mode;
reg [5:0] read_index;
reg [127:0] caps_latch;
reg [255:0] snapshot_read_latch;
reg [95:0] command_box;
reg [15:0] command_id_box;
reg [4:0] command_bytes_box;
reg command_toggle_rom;
reg command_seq_pending, command_is_internal_stop;
reg abort_pending, abort_has_sequence;
reg [15:0] completed_seq, snapshot_seq;
reg snapshot_valid;
reg [7:0] fault_code;
reg [1:0] command_ack_sync, snapshot_toggle_sync;
reg [1:0] command_toggle_sync_sys, snapshot_ack_sync_sys;
reg command_ack_seen, snapshot_seen;
reg [255:0] snapshot_cache;
reg command_ready_sys;
reg [2:0] stream_state;
reg [4:0] feed_index;
reg command_ack_toggle_sys, snapshot_toggle_sys, snapshot_ack_toggle_rom;
reg [15:0] flags_caps;
reg [15:0] active_sequence_rom;
reg active_meta_rom, active_sync_rom;

assign response_enable = io_enable && read_mode!=RD_NONE;

assign cab_active      = stream_cab_active;
assign cab_hold_reset  = stream_hold_reset;
assign cab_inputs      = stream_inputs;
assign cab_dipsw_valid = stream_dipsw_valid;
assign cab_dipsw       = stream_dipsw;
assign cab_frame       = stream_frame[14:0];
assign cab_frame_start = stream_frame_start;
assign cab_frame_index = stream_frame_index[14:0];
assign cab_state       = stream_state_out;
assign cab_error       = stream_error_out;
assign stream_rx_strobe = stream_state==ST_FEED;
assign stream_rx_cmd    = command_id_box[7:0];
assign stream_rx_index  = feed_index;
assign stream_rx_byte   = feed_index==0 ? command_id_box[7:0] : command_box[{(feed_index[3:0]-1'b1),3'b000} +: 8];

always @* begin
    flags_caps = 16'd0;
    flags_caps[0] = (command_toggle_rom!=command_ack_sync[1]) || abort_pending || command_seq_pending;
    flags_caps[1] = snapshot_valid;
    flags_caps[2] = fault_code!=F_NONE;
    flags_caps[15:8] = fault_code;
end

wire [7:0] complete_error = tx_error!=F_NONE ? tx_error :
    tx_command==ARM && (|tx_payload[7:1] || tx_payload[23:8]==0 || tx_payload[39:24]==0 ||
                         tx_payload[39:24]>tx_payload[23:8] || tx_payload[23] || tx_payload[39]) ? F_BAD_LENGTH :
    tx_command==PUSH && (tx_payload[31:16]==0 || tx_payload[15] || tx_payload[31] ||
                         |tx_payload[63:53]) ? F_BAD_EVENT :
    tx_command==PUSH_DIP && (tx_payload[31:16]==0 || tx_payload[15] || tx_payload[31] ||
                             tx_payload[54] || |tx_payload[63:55]) ? F_BAD_EVENT : F_NONE;

always @(posedge clk_rom) begin
    if(rst) begin
        txn_active<=0; txn_owned<=0; tx_command<=0; tx_payload<=0;
        expected_bytes<=0; received_bytes<=0; txn_words<=0; tx_error<=0;
        read_mode<=RD_NONE; read_index<=0; caps_latch<=0; snapshot_read_latch<=0;
        command_box<=0; command_id_box<=0; command_bytes_box<=0;
        command_toggle_rom<=0; command_seq_pending<=0;
        command_is_internal_stop<=0; abort_pending<=0; abort_has_sequence<=0;
        completed_seq<=0; snapshot_seq<=0; snapshot_valid<=0; fault_code<=F_NONE;
        command_ack_sync<=0; snapshot_toggle_sync<=0;
        command_ack_seen<=0; snapshot_seen<=0; snapshot_cache<=0;
        snapshot_ack_toggle_rom<=0; active_meta_rom<=0; active_sync_rom<=0;
        active_sequence_rom<=0;
        response_word<=0;
    end else begin
        command_ack_sync  <= {command_ack_sync[0],command_ack_toggle_sys};
        snapshot_toggle_sync <= {snapshot_toggle_sync[0],snapshot_toggle_sys};
        active_meta_rom <= stream_cab_active;
        active_sync_rom <= active_meta_rom;

        if(snapshot_toggle_sync[1]!=snapshot_seen) begin
            snapshot_seen <= snapshot_toggle_sync[1];
            snapshot_cache <= stream_snapshot[255:0];
            snapshot_valid <= 1;
            snapshot_seq <= active_sequence_rom;
            snapshot_ack_toggle_rom <= ~snapshot_ack_toggle_rom;
        end

        if(command_ack_sync[1]!=command_ack_seen) begin
            command_ack_seen <= command_ack_sync[1];
            if(command_seq_pending) completed_seq <= completed_seq+1'd1;
            command_seq_pending <= 0;
            command_is_internal_stop <= 0;
            if(command_is_internal_stop) abort_has_sequence <= 0;
        end

        if(!io_enable) begin
            if(txn_active && txn_owned && read_mode==RD_NONE) begin
                if((command_toggle_rom!=command_ack_sync[1]) || command_seq_pending || abort_pending) begin
                    if(fault_code==F_NONE) fault_code <= F_OVERRUN;
                    abort_pending <= 1;
                    abort_has_sequence <= 0;
                end else if(complete_error!=F_NONE || received_bytes!=expected_bytes) begin
                    if(fault_code==F_NONE) fault_code <= complete_error!=F_NONE ? complete_error : F_BAD_LENGTH;
                    abort_pending <= 1;
                    abort_has_sequence <= 1;
                end else begin
                    command_box <= tx_payload;
                    command_id_box <= tx_command;
                    // feed_bytes is the final rx_index: the stream sees index 0
                    // plus one strobe for every payload byte, inclusive.
                    command_bytes_box <= expected_bytes;
                    active_sequence_rom <= completed_seq+1'd1;
                    command_toggle_rom <= ~command_toggle_rom;
                    command_seq_pending <= 1;
                    if(tx_command==STATUS) snapshot_valid <= 0;
                    if(tx_command==ARM) begin
                        snapshot_valid <= 0;
                        snapshot_seq <= 0;
                        if(!active_sync_rom) fault_code <= F_NONE;
                    end
                end
            end else if(txn_active && txn_owned && read_mode==RD_CAPS && txn_words!=9) begin
                if(fault_code==F_NONE) fault_code<=F_BAD_LENGTH;
                abort_pending<=1;
                abort_has_sequence<=0;
            end else if(txn_active && txn_owned && read_mode==RD_SNAPSHOT && txn_words!=33) begin
                if(fault_code==F_NONE) fault_code<=F_BAD_LENGTH;
                abort_pending<=1;
                abort_has_sequence<=0;
            end
            txn_active<=0; txn_owned<=0; expected_bytes<=0; received_bytes<=0;
            txn_words<=0; read_mode<=RD_NONE; read_index<=0; tx_error<=F_NONE;
        end else if(io_strobe) begin
            if(!txn_active) begin
                txn_active<=1; txn_words<=1; tx_command<=host_word;
                tx_payload<=0; received_bytes<=0; tx_error<=F_NONE;
                expected_bytes<=0; txn_owned<=0; read_mode<=RD_NONE;
                if(host_word==CAPS) begin
                    txn_owned<=1; read_mode<=RD_CAPS; read_index<=0;
                    caps_latch<={16'd0,snapshot_seq,16'd0,completed_seq,flags_caps,16'h0008,16'h0002,16'hCA4D};
                end else if(host_word==SNAPSHOT_READ) begin
                    txn_owned<=1; read_mode<=RD_SNAPSHOT; read_index<=0;
                    if(snapshot_valid) snapshot_read_latch<=snapshot_cache;
                    else begin
                        snapshot_read_latch<=0;
                        if(fault_code==F_NONE) fault_code<=F_NO_SNAPSHOT;
                        abort_pending<=1; abort_has_sequence<=0;
                    end
                end else if(host_word==STATUS) begin
                    txn_owned<=1; expected_bytes<=0;
                end else if(host_word==ARM) begin
                    txn_owned<=1; expected_bytes<=5;
                end else if(host_word==PUSH) begin
                    txn_owned<=1; expected_bytes<=8;
                end else if(host_word==START) begin
                    txn_owned<=1; expected_bytes<=0;
                end else if(host_word==STOP) begin
                    txn_owned<=1; expected_bytes<=0;
                end else if(host_word==PUSH_DIP) begin
                    txn_owned<=1; expected_bytes<=12;
                end else if(host_word==16'h0088 || host_word==16'h0089) begin
                    txn_owned<=1; tx_error<=F_UNSUPPORTED;
                end
            end else begin
                if(txn_words!=7'h7f) txn_words<=txn_words+1'd1;
                if(read_mode==RD_CAPS) begin
                    response_word<=caps_latch[{read_index[2:0],4'b0000} +: 16];
                    read_index<=read_index+1'd1;
                end else if(read_mode==RD_SNAPSHOT) begin
                    response_word<={8'd0,snapshot_read_latch[{read_index[4:0],3'b000} +: 8]};
                    read_index<=read_index+1'd1;
                end
                else if(txn_owned && received_bytes<20) begin
                    if(received_bytes<expected_bytes)
                        tx_payload[{received_bytes[3:0],3'b000} +: 8]<=host_word[7:0];
                    received_bytes<=received_bytes+1'd1;
                    if(host_word[15:8]!=0 && tx_error==F_NONE) tx_error<=F_BAD_WORD;
                    if(received_bytes>=expected_bytes && tx_error==F_NONE) tx_error<=F_BAD_LENGTH;
                end else if(txn_owned && tx_error==F_NONE) tx_error<=F_BAD_LENGTH;
            end
        end

        if(abort_pending && command_toggle_rom==command_ack_sync[1] && !command_seq_pending) begin
            command_box<=0; command_id_box<=STOP; command_bytes_box<=0;
            active_sequence_rom<=abort_has_sequence ? completed_seq+1'd1 : completed_seq;
            command_toggle_rom<=~command_toggle_rom;
            command_seq_pending<=abort_has_sequence;
            command_is_internal_stop<=1;
            abort_pending<=0;
            abort_has_sequence<=0;
        end
    end
end

always @(posedge clk_sys) begin
    if(rst) begin
        command_ack_toggle_sys<=0; snapshot_toggle_sys<=0;
        command_ready_sys<=0; stream_state<=ST_IDLE; feed_index<=0;
        command_toggle_sync_sys<=0; snapshot_ack_sync_sys<=0;
    end else begin
        command_toggle_sync_sys <= {command_toggle_sync_sys[0],command_toggle_rom};
        snapshot_ack_sync_sys <= {snapshot_ack_sync_sys[0],snapshot_ack_toggle_rom};
        case(stream_state)
            ST_IDLE: if(command_toggle_sync_sys[1]!=command_ready_sys) begin
                command_ready_sys<=command_toggle_sync_sys[1];
                feed_index<=0;
                stream_state<=ST_FEED;
            end
            ST_FEED: if(feed_index==command_bytes_box) begin
                if(command_id_box==STATUS) stream_state<=ST_SNAPSHOT;
                else begin
                    command_ack_toggle_sys<=command_ready_sys;
                    stream_state<=ST_IDLE;
                end
            end else feed_index<=feed_index+1'd1;
            ST_SNAPSHOT: begin
                snapshot_toggle_sys<=~snapshot_toggle_sys;
                stream_state<=ST_SNAPSHOT_ACK;
            end
            ST_SNAPSHOT_ACK: if(snapshot_ack_sync_sys[1]==snapshot_toggle_sys) begin
                command_ack_toggle_sys<=command_ready_sys;
                stream_state<=ST_IDLE;
            end
            default: stream_state<=ST_IDLE;
        endcase
    end
end

jtframe_cab_stream #(.REGRESSION_V2(1)) u_cab_stream(
    .rst           ( rst                ),
    .clk           ( clk_sys            ),
    .lvbl          ( lvbl               ),
    .capture_hold  ( 1'b0               ),
    .capture_frame ( stream_frame       ),
    .cab_epoch     (                    ),
    .frame_start   ( stream_frame_start ),
    .frame_index   ( stream_frame_index ),
    .rx_strobe     ( stream_rx_strobe   ),
    .rx_cmd        ( stream_rx_cmd      ),
    .rx_byte       ( stream_rx_byte     ),
    .rx_index      ( stream_rx_index    ),
    .active        ( stream_cab_active  ),
    .hold_reset    ( stream_hold_reset  ),
    .state_out     ( stream_state_out   ),
    .error_out     ( stream_error_out   ),
    .inputs        ( stream_inputs      ),
    .dipsw_valid   ( stream_dipsw_valid ),
    .dipsw         ( stream_dipsw       ),
    .dump_pause    (                     ),
    .snapshot      ( stream_snapshot    )
);

endmodule
