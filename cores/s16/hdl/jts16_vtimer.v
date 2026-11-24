/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

// S16 video timer with a frame-boundary selectable original/short raster.
module jts16_vtimer #(
    parameter DUAL_RATE = 0,
    parameter [8:0] HB_END = 9'h0bf,
    parameter [8:0] HS_END = 9'h09e
)(
    input             clk,
    input             pxl_cen,
    input             req_57Hz,
    output            is_57Hz,
    output reg [8:0]  vdump,
    output reg [8:0]  vrender,
    output reg [8:0]  vrender1,
    output reg [8:0]  H,
    output reg        Hinit,
    output reg        Vinit,
    output reg        LHBL,
    output reg        LVBL,
    output reg        HS,
    output reg        VS
);

reg LVBL2, LVBL1;
reg active_original = 1'b0;
assign is_57Hz = DUAL_RATE ? active_original : 1'b1;

wire [8:0] hcnt_start = is_57Hz ? 9'h070 : 9'h080;
wire [8:0] vb_end     = is_57Hz ? 9'h105 : 9'h103;
wire [8:0] vs_start   = is_57Hz ? 9'h0ef : 9'h0ed;
wire [8:0] vs_end     = is_57Hz ? 9'h0f3 : 9'h0f1;
wire       commit     = DUAL_RATE && req_57Hz != is_57Hz &&
                        H==9'h1ff && vdump==9'h0e0 && !LVBL;

`ifdef SIMULATION
initial begin
    H        = 9'h1ff;
    vdump    = 9'h0df;
    vrender  = 9'h0e0;
    vrender1 = 9'h0e1;
    Hinit    = 0;
    Vinit    = 0;
    LHBL     = 1;
    LVBL     = 0;
    LVBL1    = 0;
    LVBL2    = 0;
    HS       = 0;
    VS       = 0;
end
`endif

always @(posedge clk) if (pxl_cen) begin
    if (commit) active_original <= req_57Hz;
end

always @(posedge clk) if (pxl_cen) begin
    Hinit <= H==9'h080;
    H <= H==9'h1ff ? (commit ? (req_57Hz ? 9'h070 : 9'h080) : hcnt_start) : H+9'd1;

    if (H==9'h080) begin
        Vinit    <= vdump==vb_end;
        vrender1 <= vrender1==vb_end ? 9'd0 : vrender1+9'd1;
        vrender  <= vrender1;
        vdump    <= vrender;
    end

    if (H==9'h1ff) begin
        LHBL <= 0;
        {LVBL,LVBL1} <= {LVBL1,LVBL2};
        case (vrender1)
            9'h0df: LVBL2 <= 0;
            vb_end: LVBL2 <= 1;
            default:;
        endcase
    end else if (H==HB_END) begin
        LHBL <= 1;
    end

    if (H==9'h080) HS <= 1;
    if (H==HS_END) begin
        HS <= 0;
        if (vdump==vs_start) VS <= 1;
        if (vdump==vs_end)   VS <= 0;
    end
end

endmodule
