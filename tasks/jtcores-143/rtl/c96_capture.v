/* SPDX-License-Identifier: GPL-3.0-or-later */
// Finite synthetic acquisition, controlled through the HPS general-purpose port.
// Request: toggle[31], reserved[30], opcode[29:24], argument[23:0].
// Reply:   toggle[31], error[30],    opcode[29:24], result[23:0].
module c96_capture #(parameter AW=15)(
    input             clk,
    input             rst,
    input      [3:0]   pins,
    input      [31:0]  gp_out,
    output reg [31:0]  gp_in
);

localparam [23:0] CAPACITY = 24'd1 << AW;
localparam [2:0] IDLE=0, SETTLE=1, EXEC=2, REPLY=3, ACK=4;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [31:0] request_meta, request_sync;
reg  [31:0] command;
reg  [23:0] limit, period, timer, count, capture_id;
reg  [23:0] result, framing_errors;
reg  [15:0] seed, lfsr;
reg  [ 2:0] state;
reg         busy, done, full, stopped, error, read_pending;
reg  [ 3:0] invert;
reg  [ 1:0] mode, format;
reg  [ 9:0] frame_skip;
reg         select_frame;
wire [15:0] ram_q, nx_lfsr, ram_data, pcm_word, yamaha_word, serial_word;
wire [ 3:0] pins_raw;
wire [AW-1:0] ram_addr;
wire        take_sample, stop_command, pcm_valid, pcm_channel, bad_frame, sampler_clear;
wire        pcm_bad, yamaha_bad, yamaha_valid, yamaha_channel;
wire        serial_valid, serial_channel;
wire        keep_word;
wire [11:0] yamaha_half_period;

assign stop_command = state==EXEC && !command[30] && command[29:24]==6'd7;
assign take_sample  = busy && !stop_command && !rst &&
                      (mode>=2 ? serial_valid && keep_word &&
                       (count!=0 || !serial_channel) : timer==0);
assign keep_word    = mode!=3 || (serial_channel ? select_frame : frame_skip==0);
assign sampler_clear = state==EXEC && !command[30] && !busy &&
                       (command[29:24]==6 || command[29:24]==14 ||
                        command[29:24]==16 || command[29:24]==18);
assign serial_word  = mode==3 ? yamaha_word : pcm_word;
assign serial_valid = mode==3 ? yamaha_valid : pcm_valid;
assign serial_channel = mode==3 ? yamaha_channel : pcm_channel;
assign bad_frame    = mode==3 ? yamaha_bad : mode==2 ? pcm_bad : 1'b0;
assign ram_data     = mode==0 ? lfsr : mode==1 ? {12'd0,pins_raw} : serial_word;
assign ram_addr     = busy ? count[AW-1:0] : command[AW-1:0];
// Fibonacci LFSR x^16 + x^14 + x^13 + x^11 + 1, nonzero seed.
assign nx_lfsr      = {lfsr[14:0],lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10]};

always @(posedge clk) begin
    request_meta <= gp_out;
    request_sync <= request_meta;
end

always @(posedge clk) begin
    if (rst) begin
        command <= 0;
        gp_in <= 0;
        state <= IDLE;
        limit <= CAPACITY;
        period <= 24'd2083;
        timer <= 0;
        count <= 0;
        capture_id <= 0;
        seed <= 16'd1;
        lfsr <= 16'd1;
        result <= 0;
        busy <= 0;
        done <= 0;
        full <= 0;
        stopped <= 0;
        error <= 0;
        read_pending <= 0;
        mode <= 0;
        invert <= 0;
        format <= 0;
        framing_errors <= 0;
        frame_skip <= 0;
        select_frame <= 0;
    end else begin
        if (busy && bad_frame && framing_errors!=24'hffffff)
            framing_errors <= framing_errors+24'd1;
        if (busy && !stop_command) begin
            // Decimate complete stereo pairs; framing checks still see every word.
            if (mode==3 && serial_valid && !serial_channel) begin
                select_frame <= frame_skip==0;
                frame_skip <= frame_skip==0 ? period[9:0]-10'd1 : frame_skip-10'd1;
            end
            if (take_sample) begin
                lfsr <= nx_lfsr;
                count <= count+24'd1;
                timer <= period-24'd1;
                if (count+24'd1==limit) begin
                    busy <= 0;
                    done <= 1;
                    full <= limit==CAPACITY;
                end
            end else if (mode<2) timer <= timer-24'd1;
        end
        case (state)
            IDLE: if (request_sync[31]!=gp_in[31]) begin
                state <= SETTLE;
            end
            SETTLE: begin
                // Let bundled data settle after detecting its synchronized toggle.
                // The HPS holds the complete request until acknowledgement.
                command <= request_sync;
                state <= EXEC;
            end
            EXEC: begin
                result <= 0;
                error <= 0;
                read_pending <= 0;
                state <= REPLY;
                if (command[30]) begin
                    error <= 1;
                    result <= 24'd1;
                end else case (command[29:24])
                    0: result <= 24'h960104; // Yamaha stereo-frame stride
                    1: result <= CAPACITY;
                    2: result <= count;
                    3: result <= {20'd0,stopped,full,done,busy};
                    4: if (busy || command[23:16]!=0 || command[15:0]==0) begin
                        error <= 1;
                        result <= 24'd2;
                    end else seed <= command[15:0];
                    5: if (busy || command[23:0]==0 || command[23:0]>CAPACITY) begin
                        error <= 1;
                        result <= 24'd2;
                    end else limit <= command[23:0];
                    6: if (busy || (mode==3 && period>24'd1024)) begin
                        error <= 1;
                        result <= 24'd3;
                    end else begin
                        capture_id <= command[23:0];
                        lfsr <= seed;
                        count <= 0;
                        timer <= 0;
                        busy <= 1;
                        done <= 0;
                        full <= 0;
                        stopped <= 0;
                        framing_errors <= 0;
                        frame_skip <= 0;
                        select_frame <= 0;
                    end
                    7: if (busy) begin
                        busy <= 0;
                        done <= 1;
                        stopped <= 1;
                    end
                    8: if (busy || !done || command[23:0]>=count) begin
                        error <= 1;
                        result <= 24'd4;
                    end else read_pending <= 1;
                    9: if (busy || command[23:0]==0 ||
                           (mode==3 && command[23:0]>24'd1024)) begin
                        error <= 1;
                        result <= 24'd2;
                    end else period <= command[23:0];
                   10: result <= capture_id;
                   11: result <= {8'd0,seed};
                   12: result <= limit;
                   13: result <= period;
                   14: if (busy || command[23:0]>3) begin
                       error <= 1; result <= 24'd2;
                   end else mode <= command[1:0];
                   15: result <= {22'd0,mode};
                   16: if (busy || command[23:0]>15) begin
                       error <= 1; result <= 24'd2;
                   end else invert <= command[3:0];
                   17: result <= {20'd0,invert};
                   18: if (busy || command[23:0]>3) begin
                       error <= 1; result <= 24'd2;
                   end else format <= command[1:0];
                   19: result <= {22'd0,format};
                   20: result <= {20'd0,pins_raw};
                   21: result <= framing_errors;
                   22: result <= {11'd0,yamaha_half_period,1'b0};
                   default: begin
                       error <= 1;
                       result <= 24'd1;
                   end
                endcase
            end
            REPLY: begin
                gp_in[30:0] <= {error,command[29:24],
                               read_pending ? {8'd0,ram_q} : result};
                state <= ACK;
            end
            ACK: begin
                // Publish data before the acknowledgement crosses back to HPS.
                gp_in[31] <= command[31];
                state <= IDLE;
            end
            default: state <= IDLE;
        endcase
    end
end

c96_pcm_sampler u_pcm_sampler(
    .clk          ( clk           ),
    .rst          ( rst           ),
    .clear        ( sampler_clear ),
    .pins         ( pins          ),
    .invert       ( invert        ),
    .format       ( format        ),
    .pins_raw     ( pins_raw      ),
    .word         ( pcm_word      ),
    .word_valid   ( pcm_valid     ),
    .word_channel ( pcm_channel   ),
    .bad_frame    ( pcm_bad       )
);

c96_yamaha_sampler u_yamaha_sampler(
    .clk          ( clk            ),
    .rst          ( rst            ),
    .clear        ( sampler_clear  ),
    .pins         ( pins_raw       ),
    .invert       ( invert         ),
    .word         ( yamaha_word    ),
    .word_valid   ( yamaha_valid   ),
    .word_channel ( yamaha_channel ),
    .half_period  ( yamaha_half_period ),
    .bad_frame    ( yamaha_bad     )
);

jtframe_ram #(.DW(16), .AW(AW)) u_ram(
    .clk  ( clk         ),
    .cen  ( 1'b1        ),
    .data ( ram_data    ),
    .addr ( ram_addr    ),
    .we   ( take_sample ),
    .q    ( ram_q       )
);

endmodule
