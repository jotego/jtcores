// SPDX-License-Identifier: GPL-3.0-or-later
// Preloaded, case-local external stimulus. No host input is sampled in RUN.
// Table words are {reserved[12:0], trigger[2:0], control[15:0], argument[31:0]}.
module jttms10_fpga_stimulus(
    input clk, rst, clear, armed, measuring,
    input [31:0] relative_clock,
    input cfg_write,
    input [3:0] cfg_index,
    input [63:0] cfg_data,
    input [4:0] cfg_count,
    input write_complete, decode,
    input [31:0] decode_pc,
    input hold_ack, host_ack,
    output lint1_n, lint2_n, hold_req, emu_run, cen_enable,
    output reg host_req,
    output reg [15:0] host_wdata,
    output reg event_valid,
    output reg [4:0] event_index,
    output reg [31:0] event_clock,
    output reg [63:0] event_data,
    output [4:0] applied_count,
    output [31:0] write_count, hold_count, host_count,
    output error
);

localparam [2:0] CLOCK_TRIGGER=0, WRITE_TRIGGER=1, PC_TRIGGER=2,
                 DELAY_TRIGGER=3, HOLD_TRIGGER=4, HOST_TRIGGER=5;
localparam [15:0] CONTROL_MASK=16'h833f;

reg [63:0] entries [0:15];
reg [63:0] entry_q;
reg [4:0] next_index, case_count;
reg [5:0] levels;
reg [31:0] writes, holds, hosts, previous_clock;
reg decode_q;
reg [31:0] decode_pc_q;
reg load_error, run_error;
wire [2:0] trigger;
wire [15:0] control;
wire [31:0] argument;
wire trigger_now, trigger_late, entry_bad;

assign trigger=entry_q[50:48];
assign control=entry_q[47:32];
assign argument=entry_q[31:0];
assign entry_bad=entry_q[63:51]!=0 || trigger>HOST_TRIGGER ||
                 (control & ~CONTROL_MASK)!=0 ||
                 (control[15:8]!=0 && !control[4]) ||
                 (trigger==PC_TRIGGER && argument[3:0]!=0) ||
                 ((trigger==DELAY_TRIGGER || trigger==WRITE_TRIGGER ||
                   trigger==HOLD_TRIGGER || trigger==HOST_TRIGGER) && argument==0);
assign trigger_now=trigger==CLOCK_TRIGGER ? relative_clock==argument :
                   trigger==WRITE_TRIGGER ? writes==argument :
                   trigger==PC_TRIGGER ? decode_q && decode_pc_q==argument :
                   trigger==DELAY_TRIGGER ? relative_clock-previous_clock==argument :
                   trigger==HOLD_TRIGGER ? holds==argument :
                   trigger==HOST_TRIGGER && hosts==argument;
assign trigger_late=trigger==CLOCK_TRIGGER ? relative_clock>argument :
                    trigger==WRITE_TRIGGER ? writes>argument :
                    trigger==DELAY_TRIGGER ? relative_clock-previous_clock>argument :
                    trigger==HOLD_TRIGGER ? holds>argument :
                    trigger==HOST_TRIGGER && hosts>argument;
assign lint1_n=!(armed && !error && levels[0]);
assign lint2_n=!(armed && !error && levels[1]);
assign hold_req=armed && !error && levels[2];
assign emu_run=!(armed && !error && levels[3]);
assign cen_enable=!(armed && !error && levels[5]);
assign applied_count=next_index;
assign write_count=writes;
assign hold_count=holds;
assign host_count=hosts;
assign error=load_error || run_error;

// Exactly one synchronous RAM write/read port. RUN never changes the table.
// Prefetch the next entry on the rising edge after advancing next_index.
always @(posedge clk) begin
    if(cfg_write && !armed) entries[cfg_index]<=cfg_data;
    entry_q<=entries[next_index[3:0]];
end

always @(posedge clk) begin
    if(rst) case_count<=0;
    else if(!armed) case_count<=cfg_count;
end

always @(posedge clk) begin
    if(rst || clear) begin
        writes<=0;
        holds<=0;
        hosts<=0;
        decode_q<=0;
        decode_pc_q<=0;
        load_error<=0;
    end else begin
        decode_q<=armed && measuring && decode;
        decode_pc_q<=decode_pc;
        if(cfg_write && armed) load_error<=1;
        if(armed && case_count>16) load_error<=1;
        if(armed && measuring) begin
            if(write_complete) writes<=writes+1'b1;
            if(hold_ack) holds<=holds+1'b1;
            if(host_ack) hosts<=hosts+1'b1;
        end
    end
end

// Outputs change between CPU sample edges, matching the original CEN bench.
// Observations remain frozen after disarm, until the next case's clear.
always @(negedge clk) begin
    if(rst || clear) begin
        next_index<=0;
        levels<=0;
        previous_clock<=0;
        host_req<=0;
        host_wdata<=0;
        event_valid<=0;
        event_index<=0;
        event_clock<=0;
        event_data<=0;
        run_error<=0;
    end else begin
        event_valid<=0;
        host_req<=0;
        if(!armed) levels<=0;
        else if(measuring && !load_error && !run_error) begin
            // HSTCTL acknowledges after the next rising edge. Consecutive
            // host writes require a low request cycle for its seen latch.
            if(host_req && !host_ack) run_error<=1;
            if(next_index<case_count) begin
                if(entry_bad || trigger_late) run_error<=1;
                else if(trigger_now) begin
                    if(control[4] && host_req) run_error<=1;
                    else begin
                        levels<=control[5:0];
                        host_req<=control[4];
                        host_wdata<=control & 16'h8300;
                        event_valid<=1;
                        event_index<=next_index;
                        event_clock<=relative_clock;
                        event_data<=entry_q;
                        next_index<=next_index+1'b1;
                        previous_clock<=relative_clock;
                    end
                end
            end
        end
    end
end

endmodule
