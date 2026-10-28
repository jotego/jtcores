`timescale 1ns/1ps
module test;

reg clk=0, rst=1, lvbl=0, rx_strobe=0, capture_hold=0;
reg [7:0] rx_cmd=0, rx_byte=0;
reg [4:0] rx_index=0;
wire active, hold_reset;
wire [20:0] inputs;
wire [511:0] snapshot;
wire dump_pause;
wire dipsw_valid;
wire [31:0] dipsw;
integer k;
reg [31:0] epoch;

always #5 clk=~clk;
`include "test_tasks.vh"

task byte_in(input [7:0] cmd, input [4:0] idx, input [7:0] data);
begin
    @(negedge clk); rx_cmd=cmd; rx_index=idx; rx_byte=data; rx_strobe=1;
    @(negedge clk); rx_strobe=0;
end endtask
task push_dip(input [31:0] seqno, duration, mask, value);
begin
    byte_in('h86,0,0); word_in('h86,1,epoch); word_in('h86,5,seqno);
    word_in('h86,9,duration); word_in('h86,13,mask); word_in('h86,17,value);
end endtask

task word_in(input [7:0] cmd, input [4:0] idx, input [31:0] data);
begin
    byte_in(cmd,idx,data[7:0]); byte_in(cmd,idx+1,data[15:8]);
    byte_in(cmd,idx+2,data[23:16]); byte_in(cmd,idx+3,data[31:24]);
end endtask

task snap;
begin byte_in('h81,0,0); @(negedge clk); end endtask
task arm(input [31:0] frames, events);
begin
    byte_in('h82,0,0); word_in('h82,1,frames); word_in('h82,5,events);
    byte_in('h82,9,1); snap(); epoch=snapshot[63:32];
    assert_msg(active && hold_reset,"arm must hold the game in reset");
end endtask
task push(input [31:0] seqno, duration, mask);
begin
    byte_in('h83,0,0); word_in('h83,1,epoch); word_in('h83,5,seqno);
    word_in('h83,9,duration); word_in('h83,13,mask);
end endtask
task start;
begin byte_in('h84,0,0); word_in('h84,1,epoch); @(negedge clk); end endtask
task ack_dump;
begin
    byte_in('h89,0,0); @(negedge clk);
    byte_in('h88,0,0); word_in('h88,1,epoch); word_in('h88,5,snapshot[351:320]);
end endtask
task frame;
begin
    lvbl=0; repeat(5) @(negedge clk); lvbl=1;
    repeat(5) @(negedge clk); lvbl=0;
end endtask

initial begin
    $dumpfile("test.lxt"); $dumpvars;
    repeat(8) @(negedge clk); rst=0;
    arm(5,3); push(0,2,1); push(1,1,4); push(2,2,0);
    start(); assert_msg(inputs==1 && !hold_reset,"frame zero preload");
    frame(); assert_msg(inputs==1,"duration must hold across one frame");
    frame(); assert_msg(inputs==4,"next event must start at frame 2");
    frame(); assert_msg(inputs==0,"idle event at frame 3");
    frame(); assert_msg(active,"run is not finished before frame 5");
    frame(); snap();
    assert_msg(snapshot[23:16]==3 && snapshot[95:64]==5,"exact normal completion");
    assert_msg(!active && inputs==0,"completion releases all inputs");
    arm(3,3); push(0,1,8); start(); frame(); snap();
    assert_msg(snapshot[23:16]==4 && snapshot[31:24]==1,"underrun must fail explicitly");
    assert_msg(inputs==0 && !hold_reset,"underrun releases input and reset");
    arm(2,2); push(1,1,0); snap();
    assert_msg(snapshot[31:24]==3,"out of order event rejected");
    arm(2,2); push(0,0,1); snap();
    assert_msg(snapshot[31:24]==5,"zero duration rejected");
    arm(2,1); push(0,1,1); snap();
    assert_msg(snapshot[31:24]==6,"last record must match declared frame count");
    arm(8,8);
    for(k=0;k<8;k=k+1) push(k,1,k);
    snap(); assert_msg(snapshot[199:192]==8 && snapshot[207:200]==0,"credits when full");
    start();
    for(k=1;k<8;k=k+1) begin
        frame(); assert_msg(inputs==k,"FIFO ordering and duration one");
    end
    frame(); snap(); assert_msg(snapshot[23:16]==3,"full FIFO finishes");
    // Refill while running, crossing both read/write pointer wraps repeatedly.
    arm(24,24); for(k=0;k<8;k=k+1) push(k,1,k);
    start();
    for(k=1;k<24;k=k+1) begin
        frame(); assert_msg(inputs==k-1+1,"refill order across pointer wraps");
        if(k+7<24) push(k+7,1,k+7);
    end
    frame(); snap();
    assert_msg(snapshot[23:16]==3 && snapshot[127:96]==24 && snapshot[159:128]==24,"all refilled events accepted/applied");
    arm(9,9); for(k=0;k<8;k=k+1) push(k,1,k);
    push(8,1,0); snap(); assert_msg(snapshot[31:24]==4,"overflow must not drop events silently");
    arm(1,1); push(0,1,1); epoch=epoch-1; start(); snap();
    assert_msg(snapshot[31:24]==2,"stale start epoch rejected");
    arm(1,1); byte_in('h85,0,0); snap();
    assert_msg(!active && !hold_reset,"stop releases an armed game");
    // DIP changes must share exact input boundaries and survive absent directives.
    arm(7,5);
    push_dip(0,2,0,0);
    push_dip(1,1,'h200001,'h89abcdef);
    push_dip(2,1,4,0);
    push_dip(3,1,'h200100,0);
    push_dip(4,2,'h200000,'hffffffff);
    assert_msg(!dipsw_valid,"queued future DIP is not applied while armed");
    start(); frame(); assert_msg(!dipsw_valid,"no override before first DIP statement");
    frame(); assert_msg(dipsw_valid && dipsw=='h89abcdef && inputs==1,"DIP/input update together at frame 2");
    byte_in('h87,0,0); @(negedge clk);
    assert_msg(snapshot[15:8]==2 && snapshot[287:256]=='h89abcdef && snapshot[288],"extended coherent DIP snapshot");
    snap(); assert_msg(snapshot[15:8]==1,"legacy snapshot remains version 1");
    frame(); assert_msg(dipsw_valid && dipsw=='h89abcdef && inputs==4,"DIP persists without a directive");
    frame(); assert_msg(dipsw_valid && dipsw==0,"zero is a valid explicit DIP value");
    frame(); assert_msg(dipsw=='hffffffff,"full 32-bit DIP values supported");
    frame(); assert_msg(dipsw_valid,"DIP holds for complete duration");
    frame(); assert_msg(!dipsw_valid && !active,"DONE restores configured DIPs");
    arm(2,1); push_dip(0,2,'h200000,'h12345678); start();
    assert_msg(dipsw_valid && dipsw=='h12345678,"DIP at frame zero");
    byte_in('h85,0,0); assert_msg(!dipsw_valid,"STOP restores configured DIPs");
    arm(1,1); push(0,1,'h200000); snap();
    assert_msg(snapshot[31:24]==5,"legacy input masks cannot claim DIP flag");
    arm(1,1); push(0,1,0); start();
    assert_msg(!dipsw_valid,"new epoch has no stale DIP override"); frame();
    arm(24,24);
    for(k=0;k<8;k=k+1) push_dip(k,1,'h200000+k,'h80000000+k);
    start();
    for(k=1;k<24;k=k+1) begin
        frame();
        assert_msg(dipsw_valid && dipsw=='h80000000+k && inputs==k,"DIP and input ordering across refill/pointer wraps");
        if(k+7<24) push_dip(k+7,1,'h200000+k+7,'h80000000+k+7);
    end
    frame(); snap(); assert_msg(snapshot[23:16]==3 && !dipsw_valid,"extended refill completes and restores DIPs");
    arm(2,2); push_dip(0,1,'h200000,'h12345678); start(); frame(); snap();
    assert_msg(snapshot[31:24]==1 && !dipsw_valid,"underrun releases the DIP override");
    arm(1,1); push_dip(0,1,'h800000,0); snap();
    assert_msg(snapshot[31:24]==5,"reserved extended mask bits rejected");
    arm(5,3);
    push_dip(0,2,'h600001,'h1234); push_dip(1,2,0,0); push_dip(2,1,'h400004,0);
    start(); snap();
    assert_msg(snapshot[23:16]==5 && dump_pause && inputs==1 && dipsw=='h1234,"frame-zero dump/input/DIP barrier");
    frame(); frame(); snap();
    assert_msg(snapshot[95:64]==0 && snapshot[351:320]==1,"dump holds CAB cursor while raster advances");
    ack_dump(); snap();
    assert_msg(snapshot[23:16]==6 && dump_pause,"ACK must wait for a raster boundary");
    frame(); snap();
    assert_msg(snapshot[23:16]==2 && !dump_pause && snapshot[95:64]==0,"resume preserves the full pending frame");
    frame(); snap();
    assert_msg(snapshot[23:16]==5 && snapshot[95:64]==1 && snapshot[351:320]==2,"duration-two dump emits a request for each CAB frame");
    ack_dump(); frame(); frame(); snap();
    assert_msg(snapshot[95:64]==2 && !dump_pause && inputs==0,"normal next event after dump duration");
    frame(); frame(); snap();
    assert_msg(snapshot[95:64]==4 && dump_pause && inputs==4 && snapshot[383:352]==4,"later dump is scheduled at exact CAB frame");
    ack_dump(); frame(); frame(); snap();
    assert_msg(snapshot[23:16]==3 && snapshot[95:64]==5 && snapshot[351:320]==3,"dump on final frame completes exactly once");
    assert_msg(!dump_pause && !dipsw_valid && !active,"completion releases all overrides");
    arm(1,1); push_dip(0,1,'h400000,0); start();
    byte_in('h88,0,0); word_in('h88,1,epoch); word_in('h88,5,99); snap();
    assert_msg(snapshot[23:16]==4 && !dump_pause,"stale dump ACK must fail and release pause");
    arm(1,1); push_dip(0,1,'h400000,0); start(); byte_in('h85,0,0);
    assert_msg(!active && !dump_pause,"STOP cancels a dump barrier");
    arm(1,1); push(0,1,0); start(); snap();
    assert_msg(snapshot[351:320]==0 && !dump_pause,"new epoch clears dump requests"); frame();
    // Confirmed capture holds logical duration, never the physical raster.
    arm(3,2); push(0,2,1); push(1,1,4); start();
    capture_hold=1; frame(); frame(); snap();
    assert_msg(snapshot[95:64]==0 && inputs==1,"capture hold preserves frame-zero input duration");
    capture_hold=0; frame(); snap();
    assert_msg(snapshot[95:64]==1 && inputs==1,"resume consumes exactly one duration");
    capture_hold=1; frame(); frame(); capture_hold=0; frame();
    assert_msg(inputs==4,"pending CAB event applied once after held duration");
    frame();snap();assert_msg(snapshot[23:16]==3,"held stream completes normally");
    pass();
end

initial begin #5000000; fail(); end

jtframe_cab_stream uut(
    .capture_hold(capture_hold), .capture_frame(),
    .rst(rst), .clk(clk), .lvbl(lvbl), .rx_strobe(rx_strobe),
    .rx_cmd(rx_cmd), .rx_byte(rx_byte), .rx_index(rx_index),
    .active(active), .hold_reset(hold_reset), .inputs(inputs),
    .dipsw_valid(dipsw_valid), .dipsw(dipsw), .dump_pause(dump_pause), .snapshot(snapshot)
);
endmodule
