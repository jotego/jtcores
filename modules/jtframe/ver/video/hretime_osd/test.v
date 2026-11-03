`timescale 1ns/1ps

// Rungun's 416/512 video timing at 8 MHz on the 96 MHz MiSTer video clock.
// The vertical test period is shortened while retaining a full OSD height.
module test;
`include "test_tasks.vh"

localparam DIV=12, HACTIVE=416, HTOTAL=512, VACTIVE=144, VTOTAL=152;
reg retime_on=0;
reg signed [3:0] scale=0;
reg [3:0] ce_pipe=0;
reg clk=0;
always #5 clk=~clk;

reg [3:0] divcnt=0;
reg [9:0] hcnt=0, vcnt=0;
reg ce_in=0;
always @(posedge clk) ce_pipe <= {ce_pipe[2:0],ce_in};

reg io_osd=0, io_strobe=0;
reg [15:0] io_din=0;
wire hs_in=hcnt<32;
wire vs_in=vcnt>=VACTIVE;
wire de_in=(hcnt>=88 && hcnt<504 && vcnt<VACTIVE);
wire [23:0] din=24'd0;
wire [23:0] video_hz, video_osd;
wire hs_hz, vs_hz, de_hz, hs_osd, vs_osd, de_osd;

always @(posedge clk) begin
    ce_in <= divcnt==DIV-1;
    divcnt <= divcnt==DIV-1 ? 0 : divcnt+1'b1;
    if (ce_in) begin
        hcnt <= hcnt==HTOTAL-1 ? 0 : hcnt+1'b1;
        if (hcnt==HTOTAL-1) vcnt <= vcnt==VTOTAL-1 ? 0 : vcnt+1'b1;
    end
end

jtframe_hretime #(.DIV(DIV),.STEP(64),.DEPTH(64),.HW(10)) uut(
    .clk(clk), .ce_in(ce_pipe[3]), .enable(retime_on), .scale(scale),
    .din(video_osd), .hs_in(hs_osd), .vs_in(vs_osd), .de_in(de_osd),
    .ce_out(), .dout(video_hz), .hs_out(hs_hz), .vs_out(vs_hz), .de_out(de_hz)
);

osd uut_osd(
    .clk_sys(clk), .io_osd(io_osd), .io_strobe(io_strobe), .io_din(io_din),
    .clk_video(clk), .din(din), .de_in(de_in),
    .vs_in(vs_in), .hs_in(hs_in), .dout(video_osd),
    .de_out(de_osd), .vs_out(vs_osd), .hs_out(hs_osd), .osd_status()
);

integer osd_clocks=0, osd_lines=0, de_clocks=0, overlay_clocks=0, visible_clocks=0, frame=0;
reg osd_line=0;
always @(posedge clk) begin
    if (vcnt==VTOTAL-1 && hcnt==HTOTAL-1 && ce_in) begin
        frame=frame+1;
        osd_clocks=0;
        osd_lines=0;
        de_clocks=0;
        overlay_clocks=0;
        visible_clocks=0;
    end else if (frame>=5) begin
        if (uut_osd.osd_de[2]) osd_clocks=osd_clocks+1;
        if (de_osd) de_clocks=de_clocks+1;
        if (uut_osd.osd_de[2] && de_osd) overlay_clocks=overlay_clocks+1;
        if (de_hz && video_hz!=0) visible_clocks=visible_clocks+1;
        if (hcnt==0 && ce_in) begin
            if (osd_line) osd_lines=osd_lines+1;
            osd_line=0;
        end
        if (uut_osd.osd_de[2]) osd_line=1;
    end
end

initial begin
    integer i;
    for (i=0; i<4096; i=i+1) uut_osd.osd_buffer[i]=8'hff;
    // Mimic zero-valued FPGA power-up registers needed by the legacy OSD.
    uut_osd.GEOMETRY.h_cnt=0;
    uut_osd.GEOMETRY.dsp_width=0;
    uut_osd.v_cnt=0;
    uut_osd.GEOMETRY.osd_vcnt=0;
    uut_osd.GEOMETRY.osd_div=0;
    uut_osd.GEOMETRY.multiscan=0;
    uut_osd.GEOMETRY.osd_en=0;
    uut_osd.GEOMETRY.f1=0;
    uut_osd.GEOMETRY.h_osd_start=0;
    uut_osd.GEOMETRY.v_osd_start=0;
    uut_osd.GEOMETRY.osd_hcnt=0;
    uut_osd.GEOMETRY.osd_hcnt2=0;
    uut_osd.GEOMETRY.half=0;
    uut_osd.osd_enable=0;
    // Issue the same enable command used by the HPS OSD protocol.
    repeat(10) @(negedge clk);
    io_osd=1;
    io_din=16'h0041;
    repeat(2) @(negedge clk);
    io_strobe=1;
    repeat(2) @(negedge clk);
    io_strobe=0;
    repeat(2) @(negedge clk);
    io_osd=0;
    // Settle geometry, then exercise bypass and all 16 encoded scales.
    repeat(6*VTOTAL*HTOTAL*DIV) @(negedge clk);
    for (i=-1; i<16; i=i+1) begin
        retime_on=i>=0;
        scale=i;
        repeat(2*VTOTAL*HTOTAL*DIV) @(negedge clk);
        // Measure the same complete active frame for every setting.
        wait(vcnt==0 && hcnt==0);
        wait(vcnt==VACTIVE);
        @(negedge clk);
        $display("scale=%0d enable=%b visible=%0d OSD=%0d overlay=%0d width=%0d",
            scale,retime_on,visible_clocks,osd_clocks,overlay_clocks,uut_osd.GEOMETRY.dsp_width);
        $fflush();
        if (visible_clocks<=0 || osd_clocks<=0 || overlay_clocks!=osd_clocks) fail();
    end
    pass();
end

initial begin
    #1_000_000_000;
    $display("timeout");
    fail();
end
endmodule

// Logo content is irrelevant to OSD geometry and pixel cadence.
module jtframe_logo #(parameter COLORW=1)(
    input rst, clk, pxl_cen,
    input [8:0] vdump, hdump,
    output [2:0] rgb
);
assign rgb=0;
endmodule
