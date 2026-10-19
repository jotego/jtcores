/* SPDX-License-Identifier: GPL-3.0-or-later */
// NARC abstract local-cycle arbiter for the jttms10 physical 16-bit word bus.
// Priority: HOLD, reserved CPU partial RMW pair, screen, DRAM, host, CPU.
// Follows TI TMS34010 User's Guide 11.3 and the GPL tms34010_bus_arbiter.
module jttms10_bus #(
    parameter integer RESET_REFRESH=0,
    parameter integer CLKS_PER_STATE=8,
    parameter integer TIMING=0
)(
`ifdef JTTMS10_REGRESSION
    output            obs_bus_start, obs_bus_complete,
    output     [15:0] obs_bus_rdata,
`endif
    input clk, rst,
    input hold_req,
    output hold_ack,
    input screen_req,
    input [13:0] screen_srfaddr,
    input [15:0] screen_dpytap,
    input screen_org,
    output screen_ack,
    input refresh_req,
    input [7:0] refresh_row,
    input refresh_cbr,
    input host_mem_req, host_mem_we,
    input [31:0] host_mem_addr,
    input [15:0] host_mem_wdata,
    input host_mem_is_io,
    input [15:0] host_mem_io_rdata,
    output [15:0] host_mem_rdata,
    output host_mem_ack,
    input word_req, word_pending, word_early, word_we, word_iaq, word_lock, word_pixel,
    input [31:0] word_addr,
    input [15:0] word_wdata,
    input is_io, pixel_srt,
    input [15:0] io_rdata,
    output [15:0] word_rdata,
    output word_ack, word_restart, word_wait,
    output cyc_req,
    output reg [3:0] cyc_kind,
    output reg [31:0] cyc_addr,
    output reg [15:0] cyc_wdata,
    output reg [15:0] cyc_io_rdata,
    output reg cyc_iaq,
    output reg [13:0] cyc_srfaddr,
    output reg [15:0] cyc_dpytap,
    output reg cyc_org,
    output reg [7:0] cyc_dram_row,
    input [15:0] cyc_rdata,
    input cyc_ack
);
    localparam [1:0] IDLE=0, ACTIVE=1, DRAIN=2, HOLD=3;
    localparam [1:0] CPU=0, SCREEN=1, DRAM=2, HOST=3;
    reg [1:0] state, owner;
    reg reservation;
    reg screen_served;
    reg host_served;
    reg dram_pending;
    reg [7:0] dram_row_pending;
    reg dram_cbr_pending;
    reg cpu_seen;
    reg last_we, last_iaq, last_lock, last_pixel;
    reg [31:0] last_addr;
    reg [15:0] last_wdata;
    reg active_we;
    reg [3:0] init_left;
    reg active_init;
    reg queued_cpu, queued_screen, queued_dram, queued_host, cycle_queued;
    wire same_word=word_we==last_we && word_iaq==last_iaq &&
        word_lock==last_lock && word_pixel==last_pixel &&
        word_addr==last_addr && word_wdata==last_wdata;
    wire cpu_ready=word_req && (!cpu_seen || !same_word);
    wire grant_hold=state==IDLE && hold_req;
    wire grant_init=state==IDLE && !hold_req && init_left!=0;
    wire grant_cpu=state==IDLE && !hold_req && init_left==0 && cpu_ready &&
        (reservation || (!screen_req || screen_served) &&
         !dram_pending && !refresh_req &&
         (!host_mem_req || host_served));
    wire grant_screen=state==IDLE && !hold_req && init_left==0 && !reservation &&
        screen_req && !screen_served;
    wire grant_dram=state==IDLE && !hold_req && init_left==0 && !reservation &&
        !(screen_req && !screen_served) && (dram_pending || refresh_req);
    wire grant_host=state==IDLE && !hold_req && init_left==0 && !reservation &&
        !(screen_req && !screen_served) && !dram_pending && !refresh_req &&
        host_mem_req && !host_served;
    wire cycle_ack;
    wire cycle_wait;
    wire [15:0] cycle_rdata;
    wire cycle_req=state==ACTIVE;
    wire complete=cycle_req && cycle_ack;
`ifdef JTTMS10_REGRESSION
    assign obs_bus_complete = complete;
    assign obs_bus_rdata    = cycle_rdata;
`endif
    generate if(TIMING!=0) begin : g_timing
        jttms10_bus_timer #(.CLKS_PER_STATE(CLKS_PER_STATE)) u_timer(
`ifdef JTTMS10_REGRESSION
            .obs_bus_start           ( obs_bus_start           ),
`endif
            .clk(clk),.rst(rst),.req(cycle_req),.queued(cycle_queued),
            .blocked(hold_ack),
            .io_cycle(cyc_kind==4'd5 || cyc_kind==4'd6),
            .io_rdata(owner==HOST ? host_mem_io_rdata : io_rdata),
            .ack(cycle_ack),.wait_active(cycle_wait),.rdata(cycle_rdata),
            .ext_req(cyc_req),.ext_ack(cyc_ack),.ext_rdata(cyc_rdata)
        );
    end else begin : g_raw
`ifdef JTTMS10_REGRESSION
        // Pin timing is meaningful only for the timed physical bus.
        assign obs_bus_start = 1'b0;
`endif
        wire unused_queued=cycle_queued;
        assign cyc_req=cycle_req;
        assign cycle_ack=cyc_ack;
        assign cycle_wait=1'b0;
        assign cycle_rdata=cyc_rdata;
    end endgenerate
    assign hold_ack=state==HOLD;
    assign word_ack=complete && owner==CPU;
    assign word_wait=cycle_wait && owner==CPU;
    assign screen_ack=complete && owner==SCREEN;
    assign host_mem_ack=complete && owner==HOST;
    assign host_mem_rdata=cycle_rdata;
    assign word_restart=grant_hold && reservation;
    assign word_rdata=cycle_rdata;

    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; owner<=CPU;
            reservation<=0; screen_served<=0; host_served<=0;
            dram_pending<=0; dram_row_pending<=0; dram_cbr_pending<=0;
            cpu_seen<=0; last_we<=0; last_iaq<=0;
            last_lock<=0; last_pixel<=0; last_addr<=0; last_wdata<=0;
            active_we<=0;
            init_left<=RESET_REFRESH!=0 ? 4'd8 : 4'd0;
            active_init<=0;
            queued_cpu<=0; queued_screen<=0; queued_dram<=0; queued_host<=0; cycle_queued<=0;
            cyc_kind<=0; cyc_addr<=0; cyc_wdata<=0; cyc_io_rdata<=0;
            cyc_iaq<=0; cyc_srfaddr<=0; cyc_dpytap<=0;
            cyc_org<=0; cyc_dram_row<=0;
        end else begin
            // Requests waiting before the preceding bus boundary can use
            // its next state despite the arbiter's registered handoff.
            if(!word_pending) queued_cpu<=0;
            else if(state==ACTIVE) queued_cpu<=1;
            if(!screen_req || screen_ack) queued_screen<=0;
            else if(state==ACTIVE) queued_screen<=1;
            if(!host_mem_req || host_mem_ack) queued_host<=0;
            else if(state==ACTIVE) queued_host<=1;
            if(state==ACTIVE && (dram_pending || refresh_req)) queued_dram<=1;
            if(grant_dram) queued_dram<=0;
            if (!word_req) cpu_seen<=0;
            if (!screen_req) screen_served<=0;
            if (screen_ack) screen_served<=1;
            if (!host_mem_req) host_served<=0;
            if (host_mem_ack) host_served<=1;
            if (word_restart) reservation<=0;

            // One pending refresh event beyond an active cycle. If a newer
            // event arrives while the slot is occupied, keep the latest row.
            if (grant_dram && dram_pending) dram_pending<=0;
            if (refresh_req && !(grant_dram && !dram_pending)) begin
                dram_pending<=1;
                dram_row_pending<=refresh_row;
                dram_cbr_pending<=refresh_cbr;
            end

            case (state)
                IDLE: begin
                    active_init<=0;
                    if (grant_hold) state<=HOLD;
                    else if (grant_init) begin
                        // TI 8.8: initialize external DRAM with eight
                        // RAS-only cycles before ordinary local traffic.
                        state<=ACTIVE; owner<=DRAM; active_init<=1;
                        cycle_queued<=init_left<4'd8;
                        cyc_kind<=4'd3; cyc_addr<=0; cyc_wdata<=0;
                        cyc_io_rdata<=0; cyc_iaq<=0;
                        cyc_srfaddr<=0; cyc_dpytap<=0;
                        cyc_org<=0; cyc_dram_row<=0;
                    end
                    else if (grant_cpu) begin
                        state<=ACTIVE; owner<=CPU; active_we<=word_we;
                        cycle_queued<=queued_cpu || cpu_seen || word_early;
                        cyc_kind<=is_io ? (word_we ? 4'd6 : 4'd5) :
                            (word_pixel && pixel_srt) ?
                            (word_we ? 4'd8 : 4'd7) :
                            (word_we ? 4'd1 : 4'd0);
                        cyc_addr<=word_addr;
                        cyc_wdata<=word_wdata;
                        cyc_io_rdata<=TIMING==0 && is_io ? io_rdata : 16'd0;
                        cyc_iaq<=word_iaq && !is_io && !(word_pixel && pixel_srt);
                        cyc_srfaddr<=0; cyc_dpytap<=0; cyc_org<=0;
                        cyc_dram_row<=0;
                        cpu_seen<=1;
                        last_we<=word_we; last_iaq<=word_iaq;
                        last_lock<=word_lock; last_pixel<=word_pixel;
                        last_addr<=word_addr; last_wdata<=word_wdata;
                        if (word_lock) reservation<=1;
                    end else if (grant_screen) begin
                        state<=ACTIVE; owner<=SCREEN;
                        cycle_queued<=queued_screen;
                        cyc_kind<=4'd2; cyc_addr<=0; cyc_wdata<=0;
                        cyc_io_rdata<=0; cyc_iaq<=0;
                        cyc_srfaddr<=screen_srfaddr;
                        cyc_dpytap<=screen_dpytap;
                        cyc_org<=screen_org; cyc_dram_row<=0;
                    end else if (grant_dram) begin
                        state<=ACTIVE; owner<=DRAM;
                        cycle_queued<=queued_dram;
                        cyc_kind<=(dram_pending ? dram_cbr_pending : refresh_cbr)
                            ? 4'd4 : 4'd3;
                        cyc_addr<=0; cyc_wdata<=0; cyc_io_rdata<=0;
                        cyc_iaq<=0; cyc_srfaddr<=0; cyc_dpytap<=0;
                        cyc_org<=0;
                        cyc_dram_row<=dram_pending ? dram_row_pending : refresh_row;
                    end else if (grant_host) begin
                        state<=ACTIVE; owner<=HOST;
                        cycle_queued<=queued_host;
                        cyc_kind<=host_mem_is_io ?
                            (host_mem_we ? 4'd6 : 4'd5) :
                            (host_mem_we ? 4'd1 : 4'd0);
                        cyc_addr<=host_mem_addr;
                        cyc_wdata<=host_mem_wdata;
                        cyc_io_rdata<=TIMING==0 && host_mem_is_io ? host_mem_io_rdata : 16'd0;
                        cyc_iaq<=0; cyc_srfaddr<=0; cyc_dpytap<=0;
                        cyc_org<=0; cyc_dram_row<=0;
                    end
                end
                ACTIVE: if (cycle_ack) begin
                    state<=DRAIN;
                    if (active_init) init_left<=init_left-4'd1;
                    if (owner==CPU && active_we && reservation)
                        reservation<=0;
                end
                DRAIN: if (!cycle_ack) state<=IDLE;
                HOLD: if (!hold_req) state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
