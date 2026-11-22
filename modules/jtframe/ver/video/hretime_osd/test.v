`timescale 1ns/1ps

// Rungun's 416/512 video timing at 8 MHz on the 96 MHz MiSTer video clock.
// The vertical test period is shortened while retaining a full OSD height.
module test;
`include "test_tasks.vh"

`ifdef OSD_NARC480I
localparam DIV=9, HACTIVE=512, HTOTAL=682, HSTART=111;
`elsif OSD_NARC480I48
localparam DIV=5, HACTIVE=512, HTOTAL=682, HSTART=111;
`elsif OSD_NARROW
localparam DIV=8, HACTIVE=256, HTOTAL=384, HSTART=64;
`elsif OSD_CPS3
localparam DIV=14, HACTIVE=384, HTOTAL=455, HSTART=53;
`elsif OSD_S18
localparam DIV=8, HACTIVE=320, HTOTAL=424, HSTART=64;
`else
localparam DIV=12, HACTIVE=416, HTOTAL=512, HSTART=88;
`endif
localparam VACTIVE=144, VTOTAL=152;
`ifdef OSD_NARC480I
localparam NATIVE_DIV=6, ALT_X2=18, ALT=1, DEPTH=128;
`elsif OSD_NARC480I48
localparam NATIVE_DIV=8, ALT_X2=9, ALT=1, DEPTH=128;
`else
localparam NATIVE_DIV=DIV, ALT_X2=DIV<<1, ALT=0, DEPTH=64;
`endif
reg retime_on=0;
reg signed [3:0] scale=0;
reg [3:0] ce_pipe=0;
reg clk=0;
always #5 clk=~clk;

reg [3:0] divcnt=0;
reg pixel_alt=0;
wire [3:0] pixel_last;
`ifdef OSD_NARC480I
assign pixel_last = pixel_alt ? 4'd9 : 4'd7;
`elsif OSD_NARC480I48
assign pixel_last = pixel_alt ? 4'd4 : 4'd3;
`else
assign pixel_last = DIV-1;
`endif
reg [9:0] hcnt=0, vcnt=0;
reg ce_in=0;
always @(posedge clk) ce_pipe <= {ce_pipe[2:0],ce_in};

reg io_osd=0, io_strobe=0;
reg [15:0] io_din=0;
wire hs_in=hcnt<32;
wire vs_in=vcnt>=VACTIVE;
wire de_in=(hcnt>=HSTART && hcnt<HSTART+HACTIVE && vcnt<VACTIVE);
wire [23:0] din={16'd0,hcnt[7:0]};
wire [23:0] video_hz, video_osd;
wire ce_out;
reg ce_out_l=0;
always @(posedge clk) ce_out_l <= ce_out;
wire hs_hz, vs_hz, de_hz, hs_osd, vs_osd, de_osd;

always @(posedge clk) begin
    ce_in <= divcnt==pixel_last;
    divcnt <= divcnt==pixel_last ? 0 : divcnt+1'b1;
    if (divcnt==pixel_last) pixel_alt <= ~pixel_alt;
    if (ce_in) begin
        hcnt <= hcnt==HTOTAL-1 ? 0 : hcnt+1'b1;
        if (hcnt==HTOTAL-1) vcnt <= vcnt==VTOTAL-1 ? 0 : vcnt+1'b1;
    end
end

jtframe_hretime #(.DIV(NATIVE_DIV),.DIV_ALT_X2(ALT_X2),.DEPTH(DEPTH)) uut(
    .clk(clk), .ce_in(ce_pipe[3]), .enable(retime_on), .div_alt(ALT[0]), .scale(scale),
    .din(video_osd), .hs_in(hs_osd), .vs_in(vs_osd), .de_in(de_osd),
    .ce_out(ce_out), .dout(video_hz), .hs_out(hs_hz), .vs_out(vs_hz), .de_out(de_hz)
);

osd #(.NATIVE_PIXEL(1)) uut_osd(
    .clk_sys(clk), .io_osd(io_osd), .io_strobe(io_strobe), .io_din(io_din),
    .clk_video(clk), .ce_in(ce_in), .din(din), .de_in(de_in),
    .vs_in(vs_in), .hs_in(hs_in), .dout(video_osd),
    .de_out(de_osd), .vs_out(vs_osd), .hs_out(hs_osd), .osd_status()
);

// Compare native composited pixels with the emitted retimed sequence.
reg check_line=0;
reg [23:0] expected[0:511];
integer sent=0, got=0, native_osd=0, retimed_osd=0;
always @(posedge clk) if (check_line) begin
    if (ce_pipe[3] && de_osd) begin
        if (!video_osd[22] && video_osd[7:0]!==((HSTART+sent)&255)) begin
            $display("Game pixel alignment mismatch at %0d",sent);
            fail();
        end
        expected[sent]=video_osd;
        sent=sent+1;
        if (video_osd[22]) begin
            if (video_osd[23] !== native_osd[0]) begin
                $display("Repeated/skipped OSD column at native pixel %0d",sent);
                fail();
            end
            if (native_osd==0 && sent-1!=(HACTIVE-256)/2) begin
                $display("OSD centering mismatch: first pixel %0d",sent-1);
                fail();
            end
            native_osd=native_osd+1;
        end
    end
    if (ce_out_l && de_hz) begin
        if (got>=sent || video_hz!==expected[got]) begin
            $display("Retimer sequence mismatch scale=%0d pixel=%0d",scale,got);
            fail();
        end
        got=got+1;
        if (video_hz[22]) retimed_osd=retimed_osd+1;
    end
end

initial begin
    integer i;
    for (i=0; i<4096; i=i+1) uut_osd.osd_buffer[i]=i[0] ? 8'hff : 8'h00;
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
    uut_osd.highres=1;
    // Settle geometry, then exercise bypass and all 16 encoded scales.
    repeat(6*VTOTAL*HTOTAL*DIV) @(negedge clk);
    // Enter the middle of the OSD; four lines per setting fit in its
    // 128-line high-resolution box without waiting whole frames per case.
    wait(vcnt==20 && hcnt==0);
    for (i=-1; i<16; i=i+1) begin
        retime_on=i>=0;
        scale=i;
        repeat(3) @(posedge hs_osd);
        repeat(3) @(negedge clk);
        sent=0; got=0; native_osd=0; retimed_osd=0;
        check_line=1;
        @(posedge hs_osd);
        @(negedge clk);
        check_line=0;
        $display("DIV=%0d scale=%0d enable=%b input=%0d output=%0d OSD=%0d/%0d",
            DIV,scale,retime_on,sent,got,native_osd,retimed_osd);
        $fflush();
        if (sent!=HACTIVE || native_osd!=256 || retimed_osd!=256) fail();
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
