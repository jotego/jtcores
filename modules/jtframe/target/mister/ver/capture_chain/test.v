`timescale 1ns/1ps
// Full regression chain: HPS words through jtframe_mister_uio, a real CAB
// replay (jtframe_cab_stream) and jtframe_mister_capture, with a video
// pipeline delay and 40% DDR stalls. Checks three captures, the first armed
// before CAB START and the last on the final checkpoint of the replay.
module test;
localparam [31:0] BASE=32'h3FE0_0000, STRIDE=32'h0020_0000;
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
wire ddr_sel, ddr_we; wire [7:0] ddr_burstcnt, ddr_be; wire [28:0] ddr_addr; wire [63:0] ddr_din;
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
wire uio_start, uio_finish, uio_active, uio_bad_word, response_enable, uio_result_valid;
wire [15:0] uio_command, response_word; wire [6:0] uio_words, uio_bad_index; wire [95:0] uio_payload;
wire [127:0] uio_cap_caps; wire [5:0] result_index; wire [7:0] result_byte;
reg cab_rx_strobe=0; reg [7:0] cab_rx_cmd=0, cab_rx_byte=0; reg [4:0] cab_rx_index=0;
wire cab_frame_start; wire [31:0] cab_frame, cab_frame_index; wire [2:0] cab_state; wire [7:0] cab_error;
jtframe_mister_uio transport(.rst(rst),.clk(clk),.io_enable(io_enable),.io_strobe(io_strobe),.host_word(host_word),.start(uio_start),
    .cab_caps(128'd0),.cap_caps(uio_cap_caps),.cab_snapshot(256'd0),.cap_result_index(result_index),.cap_result_byte(result_byte),.cab_snapshot_valid(1'b0),.cap_result_valid(uio_result_valid),
    .response_enable(response_enable),.response_word(response_word),.finish(uio_finish),.active(uio_active),.command(uio_command),
    .words(uio_words),.payload(uio_payload),.bad_word(uio_bad_word),.bad_index(uio_bad_index));
jtframe_mister_capture uut(.rst(rst),.clk(clk),.host_word(host_word),.uio_start(uio_start),.uio_finish(uio_finish),.uio_active(uio_active),
    .uio_command(uio_command),.uio_words(uio_words),.uio_payload(uio_payload[63:0]),.uio_bad_word(uio_bad_word),.uio_bad_index(uio_bad_index),
    .uio_caps(uio_cap_caps),.uio_result_valid(uio_result_valid),.result_index(result_index),.result_byte(result_byte),
    .lvbl(lvbl),.cab_frame_start(cab_frame_start),.cab_frame_index(cab_frame_index[14:0]),.cab_completed(cab_frame[14:0]),
    .cab_state(cab_state),.cab_error(cab_error),.pxl_cen(pxl_cen),.red(rgb[7:0]),.green(rgb[15:8]),.blue(rgb[23:16]),.de(de),
    .video_ok(video_ok),.ddr_sel(ddr_sel),.ddr_lock(),.ddr_busy(ddr_busy),.ddr_burstcnt(ddr_burstcnt),.ddr_addr(ddr_addr),
    .ddr_we(ddr_we),.ddr_be(ddr_be),.ddr_din(ddr_din));
jtframe_cab_stream #(.REGRESSION_V2(1)) u_cab(.rst(rst),.clk(clk),.lvbl(lvbl),.capture_hold(1'b0),.capture_frame(cab_frame),.cab_epoch(),.frame_start(cab_frame_start),
    .frame_index(cab_frame_index),.rx_strobe(cab_rx_strobe),.rx_cmd(cab_rx_cmd),.rx_byte(cab_rx_byte),.rx_index(cab_rx_index),.rx_parallel(96'd0),.active(),
    .hold_reset(),.state_out(cab_state),.error_out(cab_error),.inputs(),.dipsw_valid(),.dipsw(),.dump_pause(),.snapshot());
// which generator frame carried each tag
integer tag_frame[0:63];
always @(posedge clk) if(uut.tag_new) tag_frame[uut.tag_cp] = frame;
task tick; begin @(posedge clk); #1; end endtask
task word(input [15:0] w); begin @(negedge clk); host_word=w; io_strobe=1; @(posedge clk); #1; io_strobe=0; end endtask
task begin_tx(input [15:0] cmd); begin @(negedge clk); io_enable=1; word(cmd); end endtask
task end_tx; begin @(negedge clk); io_enable=0; @(posedge clk); #1; end endtask
task put_byte(input [7:0] b); begin word({8'd0,b}); end endtask
task put_u16(input [15:0] v); begin put_byte(v[7:0]); put_byte(v[15:8]); end endtask
task read_caps(output reg [127:0] c); integer i; begin c=0; begin_tx(16'h0090); for(i=0;i<8;i=i+1) begin word(0); c[i*16 +: 16]=response_word; end end_tx(); end endtask
task arm(input [15:0] cp, input [31:0] hold_ms); integer i; begin begin_tx(16'h0091); put_u16(cp); put_u16(0); for(i=0;i<4;i=i+1) put_byte(hold_ms[i*8 +: 8]); end_tx(); end endtask
task keyed(input [15:0] cmd, input [15:0] cp); begin begin_tx(cmd); put_u16(cp); put_u16(0); end_tx(); end endtask
task read_result(output reg [511:0] d); integer i; begin d=0; begin_tx(16'h0092); for(i=0;i<64;i=i+1) begin word(0); d[i*8 +: 8]=response_word[7:0]; end end_tx(); end endtask
task cab_byte_in(input [7:0] cmd, input [4:0] idx, input [7:0] data); begin @(negedge clk); cab_rx_cmd=cmd; cab_rx_index=idx; cab_rx_byte=data; cab_rx_strobe=1; @(negedge clk); cab_rx_strobe=0; end endtask
task cab_arm(input [14:0] frames, input [14:0] events); reg [39:0] data; integer b; begin data=0; data[23:8]=frames; data[38:24]=events; cab_byte_in(8'h82,0,0); for(b=0;b<5;b=b+1) cab_byte_in(8'h82,b+1,data[b*8 +: 8]); end endtask
task cab_push(input [15:0] seqno, input [14:0] duration); reg [63:0] data; integer b; begin data=0; data[15:0]=seqno; data[30:16]=duration; cab_byte_in(8'h83,0,0); for(b=0;b<8;b=b+1) cab_byte_in(8'h83,b+1,data[b*8 +: 8]); end endtask
task cab_start; begin cab_byte_in(8'h84,0,0); end endtask
reg [127:0] caps; reg [511:0] d; integer n, errs=0, f, x, y, b, pitch; reg [23:0] p; reg [7:0] got;
task capture(input [15:0] cp); begin
    arm(cp, 500); repeat(8) tick(); read_caps(caps);
    $display("ARM cp=%0d: caps flags=%04x state=%0d fault=%02x", cp, caps[63:48], uut.st, uut.fault);
    n=0; while(!caps[50] && !caps[51] && n<400) begin repeat(200) tick(); read_caps(caps); n=n+1; end
    $display("cp=%0d result: flags=%04x (ready=%b fault=%b code=%02x) state=%0d", cp, caps[63:48], caps[50], caps[51], caps[63:56], uut.st);
    if(!caps[50]) begin errs=errs+1; end else begin
        read_result(d);
        f = tag_frame[cp];
        $display("  descriptor cp=%0d interval=%0d w=%0d h=%0d pitch=%0d payload=%0d mode=%x blocks=%0d", d[64+:16], d[80+:16], d[160+:16], d[176+:16], d[192+:32], d[224+:32], d[256+:32], d[288+:32]);
        if(d[64+:16]!=cp || d[160+:16]!=W || d[176+:16]!=H) begin $display("  BAD descriptor"); errs=errs+1; end
        pitch=((W*3+255)/256)*256;
        for(y=0;y<H;y=y+1) for(b=0;b<W*3;b=b+1) begin
            got = mem[32+(y*pitch+b)/8][((y*pitch+b)%8)*8+:8]; p=pix(f,b/3,y);
            if(got!==p[(b%3)*8+:8]) begin if(errs<5) $display("  pixel mismatch y=%0d b=%0d got %02x want %02x (frame %0d)",y,b,got,p[(b%3)*8+:8],f); errs=errs+1; end
        end
        keyed(16'h0093, cp); repeat(8) tick(); read_caps(caps);
        $display("  release: flags=%04x state=%0d fault=%02x", caps[63:48], uut.st, uut.fault);
        if(!caps[52] || caps[51]) errs=errs+1;
    end
end endtask
initial begin
    repeat(5) tick(); rst=0; repeat(20) tick();
    read_caps(caps); $display("idle caps flags=%04x state=%0d", caps[63:48], uut.st);
    cab_arm(12,1); cab_push(0,12); repeat(10) tick();
    $display("cab_state=%0d uut.st=%0d", cab_state, uut.st);
    arm(3,500); repeat(8) tick(); read_caps(caps);
    $display("ARM cp=3 before START: flags=%04x state=%0d fault=%02x", caps[63:48], uut.st, uut.fault);
    cab_start();
    n=0; while(!caps[50] && !caps[51] && n<400) begin repeat(200) tick(); read_caps(caps); n=n+1; end
    $display("cp=3: flags=%04x state=%0d fault=%02x", caps[63:48], uut.st, uut.fault);
    if(caps[50]) begin read_result(d); f=tag_frame[3]; pitch=256;
        $display("  descriptor cp=%0d w=%0d h=%0d", d[64+:16], d[160+:16], d[176+:16]);
        for(y=0;y<H;y=y+1) for(b=0;b<W*3;b=b+1) begin got = mem[32+(y*pitch+b)/8][((y*pitch+b)%8)*8+:8]; p=pix(f,b/3,y);
            if(got!==p[(b%3)*8+:8]) begin if(errs<5) $display("  pixel mismatch y=%0d b=%0d got %02x want %02x (frame %0d)",y,b,got,p[(b%3)*8+:8],f); errs=errs+1; end end
        keyed(16'h0093, 3); repeat(8) tick(); read_caps(caps); $display("  release: flags=%04x state=%0d fault=%02x", caps[63:48], uut.st, uut.fault);
    end else errs=errs+1;
    capture(cab_frame_index[14:0]+15'd4);
    capture(12);            // last checkpoint of the script
    if(errs==0) $display("PASS"); else $display("FAIL (%0d errors)", errs);
    $finish;
end
initial begin #400_000_000 $display("timeout"); $display("FAIL"); $finish; end
endmodule
