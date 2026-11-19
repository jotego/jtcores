`timescale 1ns/1ps

module test;
reg clk=0, rst=1, lvbl=0, frame_start=0, tag_ready=0;
reg [14:0] frame_index=0, completed=0;
reg [2:0] cab_state=0;
reg [7:0] cab_error=0;
reg life_ack=0;
wire tag_valid, tag_overflow, tag_seq_error, tag_error, life_toggle;
wire [14:0] tag;
wire [31:0] life;
always #5 clk=~clk;

jtframe_mister_capture_tags uut(
    .clk_sys(clk), .rst(rst), .lvbl(lvbl), .cab_frame_start(frame_start),
    .cab_frame_index(frame_index), .cab_completed(completed), .cab_state(cab_state),
    .cab_error(cab_error), .cap_tag_valid(tag_valid), .cap_tag(tag),
    .cap_tag_ready(tag_ready), .cap_tag_overflow(tag_overflow),
    .cap_tag_sequence_error(tag_seq_error), .cap_tag_error(tag_error),
    .cap_life_toggle(life_toggle), .cap_life(life), .cap_life_ack_toggle(life_ack)
);

task tick; begin @(posedge clk); #1; end endtask
task ack_life; begin
    wait(life_toggle!=life_ack); repeat(4) tick(); life_ack=life_toggle; repeat(4) tick();
end endtask
task interval(input [14:0] n); begin
    frame_index=n; lvbl=1; frame_start=1; tick(); frame_start=0;
    lvbl=0; tick();
end endtask

initial begin
    repeat(3) tick(); rst=0; ack_life();
    if(life[17:15]!==0 || life[25:18]!==0) $fatal(1,"initial IDLE lifecycle mismatch");
    cab_state=1; tick(); ack_life();
    cab_state=2; tick(); ack_life();

    interval(15'd4);
    if(!tag_valid || tag!==15'd5) $fatal(1,"interval 4 did not produce checkpoint 5: %h",tag);
    tag_ready=1; tick(); tag_ready=0;
    completed=5; cab_state=3; tick();
    wait(life_toggle!=life_ack); repeat(3) tick();
    if(life[17:15]!==3 || life[14:0]!==5)
        $fatal(1,"DONE lifecycle snapshot was not stable while ACK was delayed");
    if(tag_error) $fatal(1,"legal tag sequence raised an error");

    // Delay DONE's mailbox ACK across STOP.  The priority IDLE event must be
    // delivered and acknowledged before a same-checkpoint next run can start.
    cab_state=0; completed=0; tick(); repeat(3) tick();
    if(life[17:15]!==3 || life[14:0]!==5)
        $fatal(1,"unacknowledged DONE was overwritten by delayed STOP");
    life_ack=life_toggle; repeat(4) tick();
    wait(life_toggle!=life_ack); repeat(3) tick();
    if(life[17:15]!==0 || life[14:0]!==0)
        $fatal(1,"STOP/IDLE lifecycle was not preserved behind delayed DONE");
    life_ack=life_toggle; repeat(4) tick();
    cab_state=1; tick(); ack_life();
    cab_state=2; tick(); ack_life();
    interval(15'd0);
    if(!tag_valid || tag!==15'd1 || tag_error) $fatal(1,"new run first checkpoint invalid");

    // A held output never backpressures video; loss is sticky and visible.
    interval(15'd1);
    if(!tag_overflow || !tag_error || tag!==15'd1) $fatal(1,"tag overflow was not fail-closed");

    // Explicit checkpoints cannot wrap or skip while a lifecycle is active.
    tag_ready=1; tick(); tag_ready=0;
    interval(15'd2);
    if(!tag_seq_error || !tag_error) $fatal(1,"checkpoint discontinuity not detected over=%b seq=%b",tag_overflow,tag_seq_error);
    tag_ready=1; tick(); tag_ready=0;
    cab_state=0; completed=0; tick(); ack_life();
    if(!tag_error) $fatal(1,"failed session error cleared before a fresh ARM ACK");
    cab_state=1; tick();
    wait(life_toggle!=life_ack); repeat(4) tick();
    if(!tag_error || life[17:15]!==3'd1)
        $fatal(1,"tag fault cleared before the fresh ARMED lifecycle was acknowledged");
    life_ack=life_toggle; repeat(4) tick();
    if(tag_error || tag_overflow || tag_seq_error)
        $fatal(1,"acknowledged fresh ARM did not clear prior tag-session errors");
    cab_state=2; tick(); ack_life();
    interval(15'd0);
    if(!tag_valid || tag!==15'd1 || tag_error)
        $fatal(1,"fresh acknowledged session did not restart at checkpoint 1");
    $display("PASS"); $finish;
end
initial begin #100000 $fatal(1,"timeout"); end
endmodule
