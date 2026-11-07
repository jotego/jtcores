`timescale 1ns/1ps

// Test-only runtime timing source. The counter and sync pipeline follow
// jtframe_vtimer; only the line/frame limits are selected at a frame edge.
module geometry_switch_vtimer(
    input             clk,
    input             pxl_cen,
    input      [1:0]  request_mode,
    input             request_valid,
    output reg [1:0]  active_mode = 0,
    output reg        timing_change = 0,
    output reg [8:0]  vdump = 9'h0df,
    output reg [8:0]  vrender = 9'h0e0,
    output reg [8:0]  vrender1 = 9'h0e1,
    output reg [8:0]  H = 9'h1ff,
    output reg        Hinit = 0,
    output reg        Vinit = 0,
    output reg        LHBL = 1,
    output reg        LVBL = 0,
    output reg        HS = 0,
    output reg        VS = 0,
    output wire [9:0] line_pixels,
    output wire [8:0] frame_lines
);

reg LVBL2 = 0, LVBL1 = 0;
wire [8:0] hcnt_start = active_mode==0 ? 9'h070 : 9'h080;
wire [8:0] vb_end = active_mode==0 ? 9'h105 :
    active_mode==1 ? 9'h103 : 9'h104;
wire [8:0] vs_start = active_mode==0 ? 9'h0ef :
    active_mode==1 ? 9'h0ed : 9'h0ee;
wire [8:0] vs_end = active_mode==0 ? 9'h0f3 :
    active_mode==1 ? 9'h0f1 : 9'h0f2;
wire [8:0] requested_hstart = request_mode==0 ? 9'h070 : 9'h080;
wire commit = request_valid && request_mode!=active_mode && H==9'h1ff &&
    vdump==9'h0e0 && !LVBL;

assign line_pixels = active_mode==0 ? 10'd400 : 10'd384;
assign frame_lines = active_mode==0 ? 9'd262 :
    active_mode==1 ? 9'd260 : 9'd261;

always @(posedge clk) if (pxl_cen) begin
    timing_change <= 0;
    if (commit) begin
        active_mode <= request_mode;
        timing_change <= 1;
    end
end

always @(posedge clk) if (pxl_cen) begin
    Hinit <= H==9'h080;
    H <= H==9'h1ff ? (commit ? requested_hstart : hcnt_start) : H+9'd1;

    if (H==9'h080) begin
        Vinit <= vdump==vb_end;
        vrender1 <= vrender1==vb_end ? 9'd0 : vrender1+9'd1;
        vrender <= vrender1;
        vdump <= vrender;
    end

    if (H==9'h1ff) begin
        LHBL <= 0;
        {LVBL,LVBL1} <= {LVBL1,LVBL2};
        case (vrender1)
            9'h0df: LVBL2 <= 0;
            vb_end: LVBL2 <= 1;
            default:;
        endcase
    end else if (H==9'h0bf) begin
        LHBL <= 1;
    end

    if (H==9'h080) HS <= 1;
    if (H==9'h0a0) begin
        HS <= 0;
        if (vdump==vs_start) VS <= 1;
        if (vdump==vs_end) VS <= 0;
    end
end

endmodule
