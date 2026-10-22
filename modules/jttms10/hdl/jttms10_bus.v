/* SPDX-License-Identifier: GPL-3.0-or-later */
// NARC abstract local-cycle arbiter for the jttms10 physical 16-bit word bus.
// Priority: HOLD, reserved CPU partial RMW pair, screen, DRAM, host, CPU.
// Follows TI TMS34010 User's Guide 11.3 and the GPL tms34010_bus_arbiter.
module jttms10_bus #(
    parameter integer RESET_REFRESH=0
)(
    input clk, rst,
`ifdef JTTMS10_REGRESSION
    output            obs_bus_start, obs_bus_complete,
    output     [15:0] obs_bus_rdata,
`endif
    input hold_req,
    output hold_ack,
    output fetch_grid_ready,
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
    input word_req, word_we, word_iaq, word_lock, word_pixel,
    input [31:0] word_addr,
    input [15:0] word_wdata,
    input is_io, pixel_srt,
    input [15:0] io_rdata,
    output [15:0] word_rdata,
    output word_ack, word_restart,
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
    localparam [1:0] IDLE=0, ACTIVE=1, HOLD=2;
    localparam [1:0] CPU=0, SCREEN=1, DRAM=2, HOST=3;
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_bus_phase_param.vh"
    /* verilator lint_on UNUSEDPARAM */
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
    reg [4:0] phase_addr;
    reg [3:0] phase_data;
    reg [15:0] response_data;
    reg target_captured;
    wire cen=1'b1;
    wire [4:0] uaddr=phase_addr;
    wire [3:0] phase_sel;
    wire unused_phase_sel=&phase_sel;
    `include "tms10_bus_phase.vh"
`ifdef JTTMS10_REGRESSION
    reg cyc_req_l;
    assign obs_bus_start = cyc_req && !cyc_req_l;
    assign obs_bus_complete = phase_data==RELEASE_PHASE && state==ACTIVE;
    assign obs_bus_rdata = response_data;
    always @(posedge clk) begin
        if(rst) cyc_req_l<=1'b0;
        else cyc_req_l<=cyc_req;
    end
`endif
    reg active_init;
    wire same_word=word_we==last_we && word_iaq==last_iaq &&
        word_lock==last_lock && word_pixel==last_pixel &&
        word_addr==last_addr && word_wdata==last_wdata;
    wire cpu_ready=word_req && (!cpu_seen || !same_word);
    wire complete=state==ACTIVE && phase_data==RELEASE_PHASE;
    wire idle_alloc=state==IDLE && phase_data==ALLOC_PHASE;
    // The previous DRAIN state waited for the target ACK to fall before a
    // new request could launch. Keep that protection at both boundaries.
    wire grant_boundary=(idle_alloc || complete) && !cyc_ack;
    assign fetch_grid_ready=grant_boundary;
    wire init_due=init_left!=0 && !(complete && active_init && init_left==1);
    wire regular_due=init_left==0 ||
        (complete && active_init && init_left==1);
    wire grant_hold=grant_boundary && hold_req;
    wire grant_init=grant_boundary && !hold_req && init_due;
    wire grant_cpu=grant_boundary && !hold_req && regular_due && cpu_ready &&
        (reservation || (!screen_req || screen_served) &&
         !dram_pending && !refresh_req &&
         (!host_mem_req || host_served));
    wire grant_screen=grant_boundary && !hold_req && regular_due && !reservation &&
        screen_req && !screen_served;
    wire grant_dram=grant_boundary && !hold_req && regular_due && !reservation &&
        !(screen_req && !screen_served) && (dram_pending || refresh_req);
    wire grant_host=grant_boundary && !hold_req && regular_due && !reservation &&
        !(screen_req && !screen_served) && !dram_pending && !refresh_req &&
        host_mem_req && !host_served;
    wire grant_start=grant_init || grant_cpu || grant_screen || grant_dram || grant_host;
    wire target_req=state==ACTIVE &&
        (phase_data==TARGET_PHASE ||
         (phase_data==WAITCAP_PHASE && !target_captured));
    wire target_capture=target_req && cyc_ack;
    wire respond=state==ACTIVE && phase_data==RESPOND_PHASE;
    assign cyc_req=target_req;
    assign hold_ack=state==HOLD;
    assign word_ack=respond && owner==CPU;
    assign screen_ack=respond && owner==SCREEN;
    assign host_mem_ack=respond && owner==HOST;
    assign host_mem_rdata=response_data;
    assign word_restart=grant_hold && reservation;
    assign word_rdata=response_data;

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
            phase_addr<=GRID0_SEQA;
            phase_data<=GRID_PHASE;
            response_data<=0;
            target_captured<=0;
            cyc_kind<=0; cyc_addr<=0; cyc_wdata<=0; cyc_io_rdata<=0;
            cyc_iaq<=0; cyc_srfaddr<=0; cyc_dpytap<=0;
            cyc_org<=0; cyc_dram_row<=0;
        end else begin
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
                    if (phase_data==ALLOC_PHASE) begin
                        if (!grant_start) begin
                            phase_data<=ucode_rom[GRID0_SEQA];
                            phase_addr<=GRID1_SEQA;
                        end
                    end else if (phase_data==GRID_PHASE) begin
                        phase_data<=ucode_rom[phase_addr];
                        phase_addr<=phase_addr+1'b1;
                    end else begin
                        phase_data<=ucode_rom[GRID0_SEQA];
                        phase_addr<=GRID1_SEQA;
                    end
                    if (grant_hold) state<=HOLD;
                    else if (grant_start) state<=ACTIVE;
                end
                ACTIVE: begin
                    if (target_capture) begin
                        response_data<=cyc_rdata;
                        target_captured<=1'b1;
                    end
                    if (phase_data==WAITCAP_PHASE && !target_captured &&
                        !target_capture) begin
                        phase_data<=phase_data;
                    end else if (phase_data==RELEASE_PHASE) begin
                        if (grant_hold) state<=HOLD;
                        else if (grant_start) state<=ACTIVE;
                        else state<=IDLE;
                        if (!grant_start) begin
                            phase_data<=ucode_rom[GRID0_SEQA];
                            phase_addr<=GRID1_SEQA;
                        end
                        if (active_init) init_left<=init_left-4'd1;
                    end else begin
                        phase_data<=ucode_rom[phase_addr];
                        phase_addr<=phase_addr+1'b1;
                    end
                end
                HOLD: begin
                    if (phase_data==ALLOC_PHASE) begin
                        phase_data<=ucode_rom[GRID0_SEQA];
                        phase_addr<=GRID1_SEQA;
                    end else if (phase_data==GRID_PHASE) begin
                        phase_data<=ucode_rom[phase_addr];
                        phase_addr<=phase_addr+1'b1;
                    end else begin
                        phase_data<=ucode_rom[GRID0_SEQA];
                        phase_addr<=GRID1_SEQA;
                    end
                    if (!hold_req) state<=IDLE;
                end
                default: state<=IDLE;
            endcase

            if (grant_start) begin
                state<=ACTIVE;
                owner<=grant_cpu ? CPU : grant_screen ? SCREEN :
                       grant_dram || grant_init ? DRAM : HOST;
                active_init<=grant_init;
                phase_data<=ucode_rom[ALLOC_SEQA+1'b1];
                phase_addr<=ALLOC_SEQA+5'd2;
                target_captured<=1'b0;
                if (grant_init) begin
                    // TI 8.8: initialize external DRAM with eight
                    // RAS-only cycles before ordinary local traffic.
                    cyc_kind<=4'd3; cyc_addr<=0; cyc_wdata<=0;
                    cyc_io_rdata<=0; cyc_iaq<=0;
                    cyc_srfaddr<=0; cyc_dpytap<=0;
                    cyc_org<=0; cyc_dram_row<=0;
                end else if (grant_cpu) begin
                    active_we<=word_we;
                    cyc_kind<=is_io ? (word_we ? 4'd6 : 4'd5) :
                        (word_pixel && pixel_srt) ?
                        (word_we ? 4'd8 : 4'd7) :
                        (word_we ? 4'd1 : 4'd0);
                    cyc_addr<=word_addr;
                    cyc_wdata<=word_wdata;
                    cyc_io_rdata<=is_io ? io_rdata : 16'd0;
                    cyc_iaq<=word_iaq && !is_io && !(word_pixel && pixel_srt);
                    cyc_srfaddr<=0; cyc_dpytap<=0; cyc_org<=0;
                    cyc_dram_row<=0;
                    cpu_seen<=1;
                    last_we<=word_we; last_iaq<=word_iaq;
                    last_lock<=word_lock; last_pixel<=word_pixel;
                    last_addr<=word_addr; last_wdata<=word_wdata;
                    if (word_lock) reservation<=1;
                end else if (grant_screen) begin
                    cyc_kind<=4'd2; cyc_addr<=0; cyc_wdata<=0;
                    cyc_io_rdata<=0; cyc_iaq<=0;
                    cyc_srfaddr<=screen_srfaddr;
                    cyc_dpytap<=screen_dpytap;
                    cyc_org<=screen_org; cyc_dram_row<=0;
                end else if (grant_dram) begin
                    cyc_kind<=(dram_pending ? dram_cbr_pending : refresh_cbr)
                        ? 4'd4 : 4'd3;
                    cyc_addr<=0; cyc_wdata<=0; cyc_io_rdata<=0;
                    cyc_iaq<=0; cyc_srfaddr<=0; cyc_dpytap<=0;
                    cyc_org<=0;
                    cyc_dram_row<=dram_pending ? dram_row_pending : refresh_row;
                end else if (grant_host) begin
                    cyc_kind<=host_mem_is_io ?
                        (host_mem_we ? 4'd6 : 4'd5) :
                        (host_mem_we ? 4'd1 : 4'd0);
                    cyc_addr<=host_mem_addr;
                    cyc_wdata<=host_mem_wdata;
                    cyc_io_rdata<=host_mem_is_io ? host_mem_io_rdata : 0;
                    cyc_iaq<=0; cyc_srfaddr<=0; cyc_dpytap<=0;
                    cyc_org<=0; cyc_dram_row<=0;
                end
            end
            if (respond && owner==CPU && active_we && reservation)
                reservation<=0;
        end
    end
endmodule
