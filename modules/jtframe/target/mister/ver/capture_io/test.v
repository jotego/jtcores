`timescale 1ns/1ps

module test;
reg clk=0, rst=1, io_strobe=0, io_enable=0;
reg [15:0] host_word=0;
reg [7:0] cap_state=0, cap_fault=0;
reg req_ack=0, release_ack=0, abort_ack=0, result_toggle=0;
reg [511:0] result_data=0;
wire response_enable, req_toggle, release_toggle, abort_toggle, result_ack;
wire [15:0] response_word, release_cp, abort_cp;
wire [31:0] req;
reg cab_lvbl=0, cab_rx_strobe=0, cap_tag_ready=0, cap_life_ack=0;
reg [7:0] cab_rx_cmd=0, cab_rx_byte=0;
reg [4:0] cab_rx_index=0;
wire cab_active, cab_hold_reset, cab_dipsw_valid, cab_frame_start, dump_pause;
wire [20:0] cab_inputs;
wire [31:0] cab_frame;
wire [31:0] cab_epoch, cab_frame_index, cab_dipsw;
wire [2:0] cab_state;
wire [7:0] cab_error;
wire [511:0] cab_snapshot;
wire cap_tag_valid, cap_tag_error, cap_life_toggle;
wire [14:0] cap_tag;
wire [31:0] cap_life;
always #5 clk=~clk;

always @(posedge clk) begin
    if(rst) cap_life_ack<=1'b0;
    else if(cap_life_toggle!=cap_life_ack) cap_life_ack<=cap_life_toggle;
end

jtframe_mister_capture_io uut(
    .clk_rom(clk), .rst(rst), .io_strobe(io_strobe), .io_enable(io_enable),
    .host_word(host_word), .response_enable(response_enable), .response_word(response_word),
    .cap_state_in(cap_state), .cap_fault_in(cap_fault),
    .cap_req_toggle(req_toggle), .cap_req(req), .cap_req_ack_toggle(req_ack),
    .cap_release_toggle(release_toggle), .cap_release(release_cp),
    .cap_release_ack_toggle(release_ack), .cap_abort_toggle(abort_toggle),
    .cap_abort(abort_cp), .cap_abort_ack_toggle(abort_ack),
    .cap_result_toggle(result_toggle), .cap_result(result_data),
    .cap_result_ack_toggle(result_ack)
);

jtframe_cab_stream #(.REGRESSION_V2(1)) u_cab(
    .rst(rst), .clk(clk), .lvbl(cab_lvbl), .capture_hold(1'b0),
    .capture_frame(cab_frame), .cab_epoch(cab_epoch), .frame_start(cab_frame_start),
    .frame_index(cab_frame_index), .rx_strobe(cab_rx_strobe), .rx_cmd(cab_rx_cmd),
    .rx_byte(cab_rx_byte), .rx_index(cab_rx_index), .active(cab_active),
    .hold_reset(cab_hold_reset), .state_out(cab_state), .error_out(cab_error),
    .inputs(cab_inputs), .dipsw_valid(cab_dipsw_valid), .dipsw(cab_dipsw),
    .dump_pause(dump_pause), .snapshot(cab_snapshot)
);

jtframe_mister_capture_tags u_tags(
    .clk_sys(clk), .rst(rst), .lvbl(cab_lvbl), .cab_frame_start(cab_frame_start),
    .cab_frame_index(cab_frame_index[14:0]), .cab_completed(cab_frame[14:0]),
    .cab_state(cab_state), .cab_error(cab_error), .cap_tag_valid(cap_tag_valid),
    .cap_tag(cap_tag), .cap_tag_ready(cap_tag_ready), .cap_tag_overflow(),
    .cap_tag_sequence_error(), .cap_tag_error(cap_tag_error),
    .cap_life_toggle(cap_life_toggle), .cap_life(cap_life),
    .cap_life_ack_toggle(cap_life_ack)
);

task tick; begin @(posedge clk); #1; end endtask
task word(input [15:0] w); begin
    @(negedge clk); host_word=w; io_strobe=1;
    @(posedge clk); #1; io_strobe=0;
end endtask
task begin_tx(input [15:0] cmd); begin
    @(negedge clk); io_enable=1; word(cmd);
end endtask
task end_tx; begin @(negedge clk); io_enable=0; @(posedge clk); #1; end endtask
task put_byte(input [7:0] b); begin word({8'd0,b}); end endtask
task put_u16(input [15:0] v); begin put_byte(v[7:0]); put_byte(v[15:8]); end endtask
task read_caps(output reg [127:0] c); integer i; begin
    c=0; begin_tx(16'h0090);
    for(i=0;i<8;i=i+1) begin word(0); c[i*16 +: 16]=response_word; end
    end_tx();
end endtask
task arm(input [15:0] cp, input [31:0] hold_ms); integer i; begin
    begin_tx(16'h0091); put_u16(cp); put_u16(0);
    for(i=0;i<4;i=i+1) put_byte(hold_ms[i*8 +: 8]); end_tx();
end endtask
task keyed(input [15:0] cmd, input [15:0] cp); begin
    begin_tx(cmd); put_u16(cp); put_u16(0); end_tx();
end endtask
task read_result(output reg [511:0] d); integer i; begin
    d=0; begin_tx(16'h0092);
    for(i=0;i<64;i=i+1) begin word(0); d[i*8 +: 8]=response_word[7:0]; end
    end_tx();
end endtask

reg [127:0] caps;
reg [511:0] desc;
integer i;
task reset_clean; begin
    rst=1; cap_state=0; cap_fault=0; result_toggle=0; result_data=0;
    req_ack=0; release_ack=0; abort_ack=0; io_enable=0; io_strobe=0;
    cab_lvbl=0; cab_rx_strobe=0; cap_tag_ready=0;
    repeat(4) tick(); rst=0; repeat(5) tick();
end endtask
task cab_byte_in(input [7:0] cmd, input [4:0] idx, input [7:0] data); begin
    @(negedge clk); cab_rx_cmd=cmd; cab_rx_index=idx; cab_rx_byte=data; cab_rx_strobe=1;
    @(negedge clk); cab_rx_strobe=0;
end endtask
task cab_arm(input [14:0] frames, input [14:0] events); reg [39:0] data; integer b; begin
    data=0; data[23:8]=frames; data[38:24]=events;
    cab_byte_in(8'h82,0,0);
    for(b=0;b<5;b=b+1) cab_byte_in(8'h82,b+1,data[b*8 +: 8]);
end endtask
task cab_push(input [15:0] seqno, input [14:0] duration); reg [63:0] data; integer b; begin
    data=0; data[15:0]=seqno; data[30:16]=duration;
    cab_byte_in(8'h83,0,0);
    for(b=0;b<8;b=b+1) cab_byte_in(8'h83,b+1,data[b*8 +: 8]);
end endtask
task cab_start; begin cab_byte_in(8'h84,0,0); end endtask
task cab_native_frame; begin
    cab_lvbl=0; repeat(5) @(negedge clk);
    cab_lvbl=1; repeat(5) @(negedge clk);
    cab_lvbl=0; repeat(5) @(negedge clk);
end endtask
initial begin
    repeat(3) tick(); rst=0; repeat(3) tick();
    read_caps(caps);
    if(caps[15:0]!==16'hCA50 || caps[31:16]!==2 || caps[47:32]!==64 ||
       caps[63:48]!==0 || caps[95:64]!==0 || caps[127:96]!==0)
        $fatal(1,"CAPS v2 layout mismatch: %h",caps);

    // A valid request contains one nonzero 15-bit checkpoint and an 11-bit hold budget.
    uut.command_freshness=16'hffff;
    arm(16'h7fff,2000);
    if(req_toggle!==1 || req!=={5'd0,11'd2000,1'b0,15'h7fff})
        $fatal(1,"v2 ARM tuple mismatch: %h",req);
    cap_state=1; repeat(4) tick(); req_ack=req_toggle; repeat(4) tick();
    read_caps(caps);
    if(!caps[49] || caps[50] || caps[51] || caps[95:80]!==16'd0)
        $fatal(1,"ARM ownership/freshness CAPS flags wrong at ffff->0: %h",caps);

    // A matching result is acknowledged, but the result data remains owned until RELEASE.
    result_data=0;
    result_data[31:0]="JTC2"; result_data[47:32]=2; result_data[63:48]=64;
    result_data[79:64]=16'h7fff; result_data[95:80]=16'h7ffe;
    result_data[8*60 +: 32]="RDY2";
    uut.result_freshness=16'hffff;
    result_toggle=~result_toggle; wait(result_ack==result_toggle); repeat(3) tick();
    cap_state=3;
    read_caps(caps);
    if(!caps[49] || !caps[50] || caps[127:112]!==16'd0)
        $fatal(1,"READY/freshness CAPS flags wrong at ffff->0: %h",caps);
    read_result(desc);
    if(desc[31:0]!=="JTC2" || desc[79:64]!==16'h7fff || desc[95:80]!==16'h7ffe ||
       desc[8*60 +: 32]!=="RDY2") $fatal(1,"stable JTC2 descriptor changed during owner lifetime");

    keyed(16'h0093,16'h7fff);
    if(release_toggle!==1 || release_cp!==16'h7fff) $fatal(1,"release key mismatch");
    cap_state=0; repeat(4) tick(); release_ack=release_toggle; repeat(4) tick();
    read_caps(caps);
    if(caps[49] || !caps[52] || caps[63:56]!==0) $fatal(1,"clean release evidence wrong: %h",caps[63:48]);

    arm(16'h8000,1000);
    if(req_toggle!==1) $fatal(1,"checkpoint high bit was accepted");
    read_caps(caps);
    if(caps[63:56]!==3) $fatal(1,"invalid checkpoint not rejected: %h",caps[63:48]);

    // A bad release key faults but does not unlock the owner. A matching
    // checkpoint ABORT remains available and cannot report a clean release.
    rst=1; cap_state=0; cap_fault=0; result_toggle=0;
    req_ack=0; release_ack=0; abort_ack=0;
    repeat(3) tick(); rst=0; repeat(4) tick();
    arm(16'd10,1000);
    cap_state=1; repeat(4) tick(); req_ack=req_toggle; repeat(4) tick();
    result_data=0; result_data[31:0]="JTC2"; result_data[47:32]=2; result_data[63:48]=64;
    result_data[79:64]=16'd10; result_data[95:80]=16'd9;
    result_data[8*60 +: 32]="RDY2";
    result_toggle=~result_toggle; wait(result_ack==result_toggle); repeat(3) tick();
    cap_state=3;
    keyed(16'h0093,16'd9);
    read_caps(caps);
    if(release_toggle!==0 || !caps[49] || !caps[51] || caps[63:56]!==8'd12)
        $fatal(1,"wrong release key did not retain ownership/fault: %h release=%b",caps,release_toggle);
    keyed(16'h0094,16'd10);
    if(abort_toggle!==1 || abort_cp!==16'd10) $fatal(1,"matching abort key not issued");
    cap_state=0; abort_ack=abort_toggle; repeat(4) tick();
    read_caps(caps);
    if(caps[49] || caps[50] || !caps[51] || caps[63:56]!==8'd12)
        $fatal(1,"matching abort did not clear ownership while retaining first fault: %h",caps);

    rst=1; cap_state=0; cap_fault=0; result_toggle=0;
    req_ack=0; release_ack=0; abort_ack=0;
    repeat(3) tick(); rst=0; repeat(4) tick();
    begin_tx(16'h0091);
    word(16'h010a); // Nonzero upper byte is malformed even when low byte is legal.
    put_byte(8'd0); put_u16(16'd0); put_byte(8'hE8); put_byte(8'h03);
    put_byte(8'd0); put_byte(8'd0); end_tx();
    read_caps(caps);
    if(req_toggle!==0 || caps[63:56]!==8'd2)
        $fatal(1,"nonzero upper payload byte was accepted or misclassified: %h req=%b",caps,req_toggle);

    // Independent frozen-source parser probes, not product changes.
    reset_clean();
    begin_tx(16'h0191); put_u16(10); put_u16(0); end_tx();
    read_caps(caps);
    if(req_toggle || caps[63:48] || caps[79:64]) $fatal(1,"unknown full command aliased ARM");
    begin_tx(16'h0091); put_u16(10); put_u16(0); put_byte(100); put_byte(0); put_byte(0); end_tx();
    read_caps(caps);
    if(req_toggle || caps[63:56]!==1 || caps[79:64]!==0) $fatal(1,"short ARM side effect or wrong length fault");
    reset_clean();
    begin_tx(16'h0091); put_u16(10); put_u16(0); put_byte(100); put_byte(0); put_byte(0); put_byte(0); put_byte(0); end_tx();
    read_caps(caps);
    if(req_toggle || caps[63:56]!==1) $fatal(1,"long ARM published");
    reset_clean(); arm(0,100); read_caps(caps);
    if(req_toggle || !caps[51]) $fatal(1,"zero checkpoint accepted");
    reset_clean(); arm(10,99); read_caps(caps);
    if(req_toggle || !caps[51]) $fatal(1,"low hold accepted");
    reset_clean(); arm(10,2001); read_caps(caps);
    if(req_toggle || !caps[51]) $fatal(1,"high hold accepted");
    reset_clean(); arm(10,32'h010003e8); read_caps(caps);
    if(req_toggle || !caps[51]) $fatal(1,"hold high bits silently narrowed");
    reset_clean();
    begin_tx(16'h0091); put_u16(10); put_u16(1); put_byte(100); put_byte(0); put_byte(0); put_byte(0); end_tx();
    read_caps(caps);
    if(req_toggle || !caps[51]) $fatal(1,"nonzero reserved accepted");

    reset_clean(); arm(10,1000);
    // A wrong-channel ACK cannot complete the one pending ARM.
    release_ack=1; abort_ack=1; repeat(8) tick(); read_caps(caps);
    if(!caps[48] || caps[79:64]!==0 || !uut.action_busy) $fatal(1,"unknown-channel ACK completed ARM");
    release_ack=0; abort_ack=0; repeat(5) tick();
    // Lost ACK remains BUSY; an overrun must preserve that first tuple.
    arm(11,1000); repeat(4) tick(); read_caps(caps);
    if(req!=={5'd0,11'd1000,1'b0,15'd10} || req_toggle!==1 || !caps[48] ||
       caps[63:56]!==3 || caps[79:64]!==0) $fatal(1,"busy overrun replaced/retired request");
    cap_state=1; req_ack=req_toggle; repeat(6) tick();
    if(!abort_toggle || abort_cp!==10 || !uut.action_internal) $fatal(1,"busy overrun did not issue matching internal abort");
    // Put the unrelated ACKs back so the internal command has a real ACK edge.
    abort_ack=0; repeat(4) tick(); cap_state=0; abort_ack=abort_toggle; repeat(6) tick();
    read_caps(caps);
    if(caps[48] || caps[49] || caps[50] || caps[79:64]!==1 || caps[63:56]!==3)
        $fatal(1,"internal abort changed host freshness or retained owner: %h",caps);

    reset_clean(); arm(10,1000); cap_state=1; req_ack=req_toggle; repeat(6) tick();
    result_data=512'h0123456789abcdef; result_data[79:64]=10;
    result_toggle=1; wait(result_ack==1); cap_state=3; repeat(4) tick();
    keyed(16'h0094,9); read_caps(caps);
    if(abort_toggle || !caps[49] || !caps[51]) $fatal(1,"wrong abort unlocked owner");
    desc=0; begin_tx(16'h0092);
    for(i=0;i<64;i=i+1) begin
        if(i==31) cap_fault=11;
        word(0); desc[i*8 +: 8]=response_word[7:0];
    end
    end_tx();
    if(desc!==result_data) $fatal(1,"fault changed immutable result read");

    // An ascal reject ACK retires the action, but must not unlock a capture
    // that still reports a non-IDLE state. A correct retry can then clean it.
    reset_clean(); arm(10,1000); cap_state=1; req_ack=req_toggle; repeat(6) tick();
    cap_state=4; cap_fault=12;
    keyed(16'h0094,10); abort_ack=abort_toggle; repeat(5) tick();
    read_caps(caps);
    if(caps[48] || !caps[49] || caps[63:56]!==12)
        $fatal(1,"non-IDLE rejected ABORT ACK lost its owner or remained busy: %h",caps);
    cap_state=0;
    keyed(16'h0094,10); abort_ack=abort_toggle; repeat(5) tick();
    read_caps(caps);
    if(caps[48] || caps[49] || !caps[51] || caps[63:56]!==12)
        $fatal(1,"confirmed IDLE ABORT cleanup did not release owner: %h",caps);
    arm(11,1000); cap_fault=0; cap_state=1; req_ack=req_toggle; repeat(6) tick();
    read_caps(caps);
    if(!caps[49] || caps[63:56]!==0)
        $fatal(1,"accepted fresh ARM did not clear sticky CAP fault: %h",caps);

    // Compose the real CAB stream, tag mailbox and CAP transport around a
    // small ascal boundary contract. Actual ascal reject paths are covered by
    // the GHDL ascal_capture test; this proves their returned toggles release
    // transport ownership and permit the following CAB/CAP session.
    reset_clean();
    cab_arm(2,1); cab_push(0,2); cab_start(); cab_native_frame();
    if(cab_state!==3'd2 || !cap_tag_valid || cap_tag!==15'd1 || cap_tag_error)
        $fatal(1,"first CAB interval did not produce native checkpoint 1: state=%0d tag=%0d valid=%b error=%b",
            cab_state,cap_tag,cap_tag_valid,cap_tag_error);
    cab_native_frame(); cab_native_frame(); repeat(10) tick();
    if(cab_state!==3'd3 || cap_life[17:15]!==3'd3 || cap_life[14:0]!==15'd2)
        $fatal(1,"CAB completion lifecycle did not reach the capture boundary: state=%0d life=%h",cab_state,cap_life);
    arm(10,1000);
    cap_state=1; cap_fault=0; req_ack=req_toggle; repeat(6) tick();
    if(!uut.owner_valid || cap_life[17:15]!==3'd3)
        $fatal(1,"CAP ARM did not acquire the completed CAB session");
    cap_state=0; cap_fault=11; repeat(6) tick(); // watchdog self-clean contract
    keyed(16'h0094,10);
    if(abort_toggle!==1) $fatal(1,"post-watchdog ABORT was not submitted");
    abort_ack=abort_toggle; repeat(6) tick();
    read_caps(caps);
    if(caps[48] || caps[49] || !caps[51] || caps[63:56]!==11)
        $fatal(1,"post-watchdog ABORT ACK did not retire owner with sticky fault: %h",caps);
    cap_tag_ready=1; repeat(4) tick(); cap_tag_ready=0;

    cab_byte_in(8'h85,0,0); repeat(5) tick();
    cab_arm(2,1); cab_push(0,2); cab_start();
    cab_native_frame(); cab_native_frame(); cab_native_frame(); repeat(10) tick();
    if(cab_state!==3'd3 || cap_life[17:15]!==3'd3 || cap_life[14:0]!==15'd2)
        $fatal(1,"second CAB session failed after clean capture cleanup: state=%0d life=%h",cab_state,cap_life);
    arm(11,1000);
    cap_state=1; cap_fault=0; req_ack=req_toggle; repeat(6) tick();
    read_caps(caps);
    if(!caps[49] || caps[63:56]!==0 || req[14:0]!==15'd11)
        $fatal(1,"second CAP session did not ARM after watchdog cleanup: %h",caps);
    $display("PASS"); $finish;
end
initial begin #100000 $fatal(1,"timeout"); end
endmodule
