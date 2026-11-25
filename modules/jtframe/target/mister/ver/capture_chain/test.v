`timescale 1ns/1ps
// Full regression chain: HPS words through jtframe_mister_uio, a real CAB
// replay (jtframe_cab_stream) and jtframe_mister_capture, with a video
// pipeline delay and 40% DDR stalls. Main's order: CAB ARM, pushes, capture
// ARM, CAB START. Session 1 captures frame 3 (armed while the CAB stream is
// ARMED), one frame in the middle and the last frame M. Session 2 clears the
// frame number and misses frame M on purpose: the count goes on after the
// replay ends, so Main sees the frame pass the target.
module test;

`include "test_tasks.vh"

localparam [31:0] BASE=32'h3FE0_0000, STRIDE=32'h0020_0000;
localparam M=12;
reg clk=0, rst=1, io_strobe=0, io_enable=0;
reg [15:0] host_word=0;
always #5 clk=~clk;
// video
integer W=13,H=6,HB=30,VB=5, frame=0, hc=0, vc=0;
reg [1:0] cen_cnt=0; wire pxl_cen=cen_cnt==0;
reg [23:0] rgb, rgb1, rgb2; reg de=0,de1=0,de2=0, lvbl=0, video_ok=1;
function [23:0] pix(input integer f, input integer x, input integer y);
    pix = {f[7:0]^y[7:0], x[7:0]+8'd3*y[7:0], f[7:0]*8'd7+x[7:0]};
endfunction
always @(posedge clk) begin
    cen_cnt<=cen_cnt+1'd1;
    if(pxl_cen) begin
        if(hc==W+HB-1) begin hc<=0; if(vc==H+VB-1) begin vc<=0; frame<=frame+1; end else vc<=vc+1; end else hc<=hc+1;
        lvbl <= vc<H;                       // game LVBL
        de2 <= vc<H && hc<W; rgb2<=pix(frame,hc,vc);
        de1 <= de2; rgb1<=rgb2; de<=de1; rgb<=rgb1; // pipeline delay to the writer
    end
end
// DDR
reg [63:0] mem[0:STRIDE/8-1];
wire ddr_we; wire [28:0] ddr_addr; wire [63:0] ddr_din;
reg ddr_busy=0; integer beats=0; reg [28:0] waddr;
always @(posedge clk) begin
    ddr_busy <= ($urandom%100)<40;
    if(ddr_we && !ddr_busy) begin
        if(beats==0) waddr=ddr_addr;
        mem[waddr-(BASE>>3)+beats] <= ddr_din;
        beats = beats==31 ? 0 : beats+1;
    end
end
// chain
wire uio_finish, uio_bad_word, response_enable;
wire [15:0] uio_command, response_word; wire [6:0] uio_words; wire [95:0] uio_payload;
wire [127:0] cap_caps, cap_result;
reg cab_rx_strobe=0; reg [7:0] cab_rx_cmd=0, cab_rx_byte=0; reg [4:0] cab_rx_index=0;
wire cab_frame_start; wire [31:0] cab_frame_index; wire [2:0] cab_state;
jtframe_mister_uio transport(.rst(rst),.clk(clk),.io_enable(io_enable),.io_strobe(io_strobe),.host_word(host_word),.start(),
    .cab_caps(128'd0),.cap_caps(cap_caps),.cap_result(cap_result),.cab_snapshot(256'd0),.cab_snapshot_valid(1'b0),
    .response_enable(response_enable),.response_word(response_word),.finish(uio_finish),.active(),.command(uio_command),
    .words(uio_words),.payload(uio_payload),.bad_word(uio_bad_word),.bad_index());
jtframe_mister_capture uut(.rst(rst),.clk(clk),.uio_finish(uio_finish),.uio_command(uio_command),.uio_words(uio_words),
    .uio_payload(uio_payload[14:0]),.uio_bad_word(uio_bad_word),.uio_caps(cap_caps),.uio_result(cap_result),
    .lvbl(lvbl),.cab_frame_start(cab_frame_start),.cab_frame_index(cab_frame_index[14:0]),.cab_state(cab_state),
    .pxl_cen(pxl_cen),.red(rgb[7:0]),.green(rgb[15:8]),.blue(rgb[23:16]),.de(de),
    .video_ok(video_ok),.ddr_sel(),.ddr_lock(),.ddr_busy(ddr_busy),.ddr_burstcnt(),.ddr_addr(ddr_addr),
    .ddr_we(ddr_we),.ddr_be(),.ddr_din(ddr_din));
jtframe_cab_stream #(.REGRESSION_V2(1)) u_cab(.rst(rst),.clk(clk),.lvbl(lvbl),.capture_hold(1'b0),.capture_frame(),.cab_epoch(),.frame_start(cab_frame_start),
    .frame_index(cab_frame_index),.rx_strobe(cab_rx_strobe),.rx_cmd(cab_rx_cmd),.rx_byte(cab_rx_byte),.rx_index(cab_rx_index),.rx_parallel(96'd0),.active(),
    .hold_reset(),.state_out(cab_state),.error_out(),.inputs(),.dipsw_valid(),.dipsw(),.dump_pause(),.snapshot());
// generator frame drawn in CAB interval i, which is frame i+1
integer gen[0:63];
always @(posedge clk) if(cab_frame_start) gen[cab_frame_index+1] = frame;
task tick; begin @(posedge clk); #1; end endtask
task word(input [15:0] w); begin @(negedge clk); host_word=w; io_strobe=1; @(posedge clk); #1; io_strobe=0; end endtask
task begin_tx(input [15:0] cmd); begin @(negedge clk); io_enable=1; word(cmd); end endtask
task end_tx; begin @(negedge clk); io_enable=0; @(posedge clk); #1; end endtask
reg [63:0] st; reg [127:0] res;
wire ready=st[47]; wire [14:0] sframe=st[46:32], starget=st[62:48];
task read_status; integer i; begin begin_tx(16'h0090); for(i=0;i<4;i=i+1) begin word(0); st[i*16 +: 16]=response_word; end end_tx(); end endtask
task read_result; integer i; begin begin_tx(16'h0092); for(i=0;i<8;i=i+1) begin word(0); res[i*16 +: 16]=response_word; end end_tx(); end endtask
task arm(input [14:0] t); begin begin_tx(16'h0091); word({8'd0,t[7:0]}); word({9'd0,t[14:8]}); end_tx(); end endtask
task cab_byte_in(input [7:0] cmd, input [4:0] idx, input [7:0] data); begin @(negedge clk); cab_rx_cmd=cmd; cab_rx_index=idx; cab_rx_byte=data; cab_rx_strobe=1; @(negedge clk); cab_rx_strobe=0; end endtask
task cab_arm(input [14:0] frames, input [14:0] events); reg [39:0] data; integer b; begin data=0; data[23:8]=frames; data[38:24]=events; cab_byte_in(8'h82,0,0); for(b=0;b<5;b=b+1) cab_byte_in(8'h82,b+1,data[b*8 +: 8]); end endtask
task cab_push(input [15:0] seqno, input [14:0] duration); reg [63:0] data; integer b; begin data=0; data[15:0]=seqno; data[30:16]=duration; cab_byte_in(8'h83,0,0); for(b=0;b<8;b=b+1) cab_byte_in(8'h83,b+1,data[b*8 +: 8]); end endtask
task cab_start; begin cab_byte_in(8'h84,0,0); end endtask
task wait_target(input [14:0] t); begin read_status; while(!ready && sframe<=t) read_status; end endtask
task check(input [14:0] t);
    integer y, b, f; reg [23:0] p; reg [7:0] got;
begin
    wait_target(t);
    if(!ready) begin $display("frame %0d missed (status frame %0d)", t, sframe); fail(); end
    read_result;
    f = gen[t];
    assert_msg(res[15:0]==16'h544A && res[47:32]==t && res[63:48]==W && res[79:64]==H, "JTC3 descriptor");
    for(y=0;y<H;y=y+1) for(b=0;b<W*3;b=b+1) begin
        got = mem[32+(y*256+b)/8][((y*256+b)%8)*8+:8]; p=pix(f,b/3,y);
        if(got!==p[(b%3)*8+:8]) begin $display("frame %0d pixel y=%0d b=%0d got %02x want %02x", t, y, b, got, p[(b%3)*8+:8]); fail(); end
    end
end endtask
integer t;
initial begin
    repeat(5) tick(); rst=0; repeat(20) tick();
    // session 1
    cab_arm(M,1); cab_push(0,M); repeat(10) tick();
    arm(3);
    repeat(200) tick();
    read_status;
    assert_msg(cab_state==1 && starget==3 && sframe==0, "target armed while the CAB stream is ARMED");
    cab_start();
    check(3);
    t = cab_frame_index[14:0]+15'd4;
    arm(t); check(t);
    arm(M); check(M);
    assert_msg(cab_state==3, "replay DONE after the last frame");
    arm(0);
    repeat(4) begin wait(vc==0); wait(vc==1); end
    read_status;
    assert_msg(!ready && sframe>M, "frame count goes on after DONE");
    // session 2: the frame number restarts; frame M is missed
    cab_arm(M,1); cab_push(0,M); repeat(10) tick();
    read_status;
    assert_msg(sframe==0, "new CAB session clears the frame number");
    arm(M); cab_start();
    wait(cab_frame_index==M-1);
    video_ok=0;
    wait_target(M);
    assert_msg(!ready && sframe==M+1, "missed last frame shows after DONE");
    pass();
end
initial begin #400_000_000 $display("timeout"); fail(); end
endmodule
