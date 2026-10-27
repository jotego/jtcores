/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

// Native-raster logical time and typed CPU interrupt evidence are independent.

module jtframe_capture_progress #(
    parameter QUIET_CYCLES=256
)(
    input             rst, clk, game_reset,
    input             pxl_cen, lvbl,
    input             irq_level, irq_taken_toggle,
    input             feedback_valid, contract_valid,
    input             pause_request, step,
    output            raster_tick, pause_gate,
    output reg        pause_effective,
    output reg        contract_lost, step_done, step_failed,
    output reg [63:0] epoch, raster_frame, game_frame, irq_count,
    output reg [63:0] irq_generation,
    output reg [31:0] raster_period,
    output            irq_observed, service_observed,
    output     [63:0] raster_now, game_now, irq_now
);

localparam QW=$clog2(QUIET_CYCLES+1);
reg [1:0] irq_sync, taken_sync;
reg [1:0] reset_quiet, service_age;
reg lvbl_l, reset_l, taken_l, irq_l, reset_sync;
reg [QW-1:0] quiet;
reg [31:0] cycles;
reg step_pending, step_running, step_settling;
reg [63:0] step_frame;
wire accepted, can_confirm;

assign raster_tick = pxl_cen && lvbl && !lvbl_l;
assign irq_observed = feedback_valid && irq_sync[1];
// Recent accepted VBL service identifies the normal IRQ-driven game phase.
// Keep that evidence while paused; otherwise expire it after three rasters.
assign service_observed = feedback_valid && service_age!=3;
assign accepted = feedback_valid && reset_quiet==0 && taken_sync[1]!=taken_l;
assign pause_gate = pause_request && !step_running;
assign can_confirm = pause_gate && feedback_valid && contract_valid && service_observed && !irq_sync[1] && !accepted;
assign raster_now = raster_frame+{63'd0,raster_tick};
assign game_now = game_frame+{63'd0,raster_tick && !reset_sync && !pause_effective};
assign irq_now = irq_count+{63'd0,accepted && !reset_sync};

always @(posedge clk) begin
    reset_sync<=game_reset;
    irq_sync   <= {irq_sync[0],irq_level};
    taken_sync <= {taken_sync[0],irq_taken_toggle};
end

always @(posedge clk) begin
    if(rst) begin
        epoch<=0; raster_frame<=0; game_frame<=0; irq_count<=0; irq_generation<=0;
        raster_period<=0; cycles<=0; lvbl_l<=0; reset_l<=0;
        reset_quiet<=3; service_age<=3; taken_l<=0; irq_l<=0; quiet<=0;
        pause_effective<=0; contract_lost<=0;
        step_pending<=0; step_running<=0; step_settling<=0; step_frame<=0;
        step_done<=0; step_failed<=0;
    end else begin
        if(pxl_cen) lvbl_l<=lvbl;
        reset_l<=reset_sync;
        taken_l<=taken_sync[1]; irq_l<=irq_sync[1];
        cycles<=cycles+1'd1;
        contract_lost<=0; step_done<=0; step_failed<=0;
        if(raster_tick) begin
            raster_frame<=raster_frame+1'd1;
            raster_period<=cycles+1'd1; cycles<=0;
            if(!reset_sync && !pause_effective) game_frame<=game_frame+1'd1;
        end
        if(feedback_valid && irq_sync[1] && !irq_l) irq_generation<=raster_now;
        if(reset_quiet!=0) reset_quiet<=reset_quiet-1'd1;
        if(accepted && !reset_sync) begin
            irq_count<=irq_count+1'd1;
            service_age<=0;
        end else if(raster_tick && !pause_effective && service_age!=3)
            service_age<=service_age+1'd1;

        if(!can_confirm) begin
            quiet<=0;
            if(pause_effective && pause_gate) contract_lost<=1;
            pause_effective<=0;
        end else if(!pause_effective) begin
            if(quiet==QUIET_CYCLES-1) begin
                pause_effective<=1;
                if(step_settling) begin
                    if(game_now==step_frame+1'd1) step_done<=1;
                    else step_failed<=1;
                    step_settling<=0;
                end
            end else quiet<=quiet+1'd1;
        end
        if(step) begin
            if(pause_effective && !step_pending && !step_running && !step_settling) begin
                step_pending<=1; step_frame<=game_frame;
            end else step_failed<=1;
        end
        if(raster_tick && step_pending) begin
            step_pending<=0; step_running<=1; pause_effective<=0; quiet<=0;
        end else if(raster_tick && step_running) begin
            step_running<=0; step_settling<=1; quiet<=0;
        end else if(raster_tick && step_settling && game_now>step_frame+1'd1) begin
            step_settling<=0; step_failed<=1;
        end
        if(!pause_request) begin
            step_pending<=0; step_running<=0;
            if(step_settling) step_failed<=1;
            step_settling<=0;
        end
        if(reset_sync) begin
            if(!reset_l) epoch<=epoch+1'd1;
            game_frame<=0; irq_count<=0; irq_generation<=0;
            reset_quiet<=3; service_age<=3; quiet<=0; pause_effective<=0;
            step_pending<=0; step_running<=0; step_settling<=0;
        end
    end
end

endmodule
