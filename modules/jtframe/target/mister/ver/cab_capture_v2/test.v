`timescale 1ns/1ps

module test;
reg clk=0, rst=1, io_strobe=0, io_enable=0, lvbl=0;
reg clk_sys=0;
reg [15:0] host_word=0;
reg probe_rst=1, probe_lvbl=0, probe_rx_strobe=0;
reg [7:0] probe_rx_cmd=0, probe_rx_byte=0;
reg [4:0] probe_rx_index=0;
wire probe_active, probe_hold_reset, probe_dipsw_valid, probe_dump_pause;
wire [31:0] probe_capture_frame, probe_epoch, probe_frame_index, probe_dipsw;
wire [2:0] probe_state;
wire [7:0] probe_error;
wire [20:0] probe_inputs;
wire [511:0] probe_snapshot;
wire response_enable, cab_active, cab_hold_reset, cab_dipsw_valid, cab_frame_start;
wire [15:0] response_word;
wire [20:0] cab_inputs;
wire [31:0] cab_dipsw;
wire [14:0] cab_frame, cab_frame_index;
wire [2:0] cab_state;
wire [7:0] cab_error;
always #5 clk=~clk;
always #7 clk_sys=~clk_sys;

wire uio_start, uio_finish, uio_active, uio_bad_word;
wire [15:0] uio_command;
wire [6:0] uio_words, uio_bad_index;
wire [95:0] uio_payload;
wire [127:0] uio_cab_caps;
wire [255:0] uio_snapshot;
wire uio_snapshot_valid;
jtframe_mister_uio transport(.rst(rst), .clk(clk), .io_enable(io_enable), .io_strobe(io_strobe), .host_word(host_word),
    .cab_caps(uio_cab_caps), .cap_caps(128'd0), .cab_snapshot(uio_snapshot),
    .cap_result(512'd0), .cab_snapshot_valid(uio_snapshot_valid), .cap_result_valid(1'b0),
    .response_enable(response_enable), .response_word(response_word), .start(uio_start), .finish(uio_finish), .active(uio_active), .command(uio_command),
    .words(uio_words), .payload(uio_payload), .bad_word(uio_bad_word), .bad_index(uio_bad_index));

jtframe_mister_cab uut(
    .uio_start(uio_start), .uio_finish(uio_finish), .uio_active(uio_active),
    .uio_command(uio_command), .uio_words(uio_words), .uio_payload(uio_payload), .uio_bad_word(uio_bad_word), .uio_bad_index(uio_bad_index),
    .rst(rst), .clk_rom(clk), .clk_sys(clk_sys), .lvbl(lvbl),
    .io_strobe(io_strobe), .io_enable(io_enable), .host_word(host_word),
    .uio_caps(uio_cab_caps), .uio_snapshot(uio_snapshot), .uio_snapshot_valid(uio_snapshot_valid),
    .cab_active(cab_active), .cab_hold_reset(cab_hold_reset),
    .cab_inputs(cab_inputs), .cab_dipsw_valid(cab_dipsw_valid), .cab_dipsw(cab_dipsw),
    .cab_frame(cab_frame), .cab_frame_start(cab_frame_start),
    .cab_frame_index(cab_frame_index), .cab_state(cab_state), .cab_error(cab_error)
);

jtframe_cab_stream #(.REGRESSION_V2(1)) empty_fifo_probe(
    .rst(probe_rst), .clk(clk), .lvbl(probe_lvbl), .capture_hold(1'b0),
    .capture_frame(probe_capture_frame), .cab_epoch(probe_epoch),
    .frame_start(), .frame_index(probe_frame_index),
    .rx_strobe(probe_rx_strobe), .rx_cmd(probe_rx_cmd), .rx_byte(probe_rx_byte),
    .rx_index(probe_rx_index), .rx_parallel(96'd0), .active(probe_active), .hold_reset(probe_hold_reset),
    .state_out(probe_state), .error_out(probe_error), .inputs(probe_inputs),
    .dipsw_valid(probe_dipsw_valid), .dipsw(probe_dipsw), .dump_pause(probe_dump_pause),
    .snapshot(probe_snapshot)
);

task tick; begin @(posedge clk); #1; end endtask
task word(input [15:0] w); begin
    @(negedge clk); host_word=w; io_strobe=1;
    @(posedge clk); #1; io_strobe=0;
end endtask
task begin_tx(input [15:0] cmd); begin @(negedge clk); io_enable=1; word(cmd); end endtask
task end_tx; begin @(negedge clk); io_enable=0; repeat(32) tick(); end endtask
task byte_out(input [7:0] b); begin word({8'd0,b}); end endtask
task u16(input [15:0] v); begin byte_out(v[7:0]); byte_out(v[15:8]); end endtask
task u32(input [31:0] v); begin
    byte_out(v[7:0]); byte_out(v[15:8]); byte_out(v[23:16]); byte_out(v[31:24]);
end endtask
task arm(input [15:0] frames, input [15:0] events); begin
    begin_tx(16'h0082); byte_out(1); u16(frames); u16(events); end_tx();
end endtask
task push(input [15:0] ordinal, input [15:0] duration, input [31:0] flags); begin
    begin_tx(16'h0083); u16(ordinal); u16(duration); u32(flags); end_tx();
end endtask
task push_dip(input [15:0] ordinal, input [15:0] duration,
              input [31:0] flags, input [31:0] dip); begin
    begin_tx(16'h0086); u16(ordinal); u16(duration); u32(flags); u32(dip); end_tx();
end endtask
task start_run; begin begin_tx(16'h0084); end_tx(); end endtask
task status_refresh; begin begin_tx(16'h0081); end_tx(); end endtask
task read_caps(output reg [127:0] c); integer i; begin
    c=0; begin_tx(16'h0080);
    for(i=0;i<8;i=i+1) begin word(0); c[i*16 +:16]=response_word; end
    end_tx();
end endtask
task read_snapshot(output reg [255:0] s); integer i; begin
    s=0; begin_tx(16'h0087);
    for(i=0;i<32;i=i+1) begin word(0); s[i*8 +:8]=response_word[7:0]; end
    end_tx();
end endtask
task frame_tick; begin
    @(negedge clk); lvbl=0; repeat(7) tick();
    @(negedge clk); lvbl=1; repeat(7) tick();
end endtask

task check_empty_fifo_boundary(input [7:0] command, input [31:0] dip_value);
reg [95:0] next_event;
begin
    next_event={dip_value,10'd0,(command==8'h86),21'h00155,16'd1,16'd1};
    probe_rst=1; probe_lvbl=0; probe_rx_strobe=0; repeat(3) tick();
    probe_rst=0; repeat(3) tick();
    // Event one arrives on the same edge as the empty-FIFO next boundary.
    empty_fifo_probe.state=3'd2;
    empty_fifo_probe.remaining=15'd1;
    empty_fifo_probe.frames=15'd0;
    empty_fifo_probe.total_frames=15'd2;
    empty_fifo_probe.accepted=15'd1;
    empty_fifo_probe.applied=15'd1;
    empty_fifo_probe.accepted_frames=15'd1;
    empty_fifo_probe.total_events=15'd2;
    empty_fifo_probe.queued=0;
    empty_fifo_probe.wr_ptr=0;
    empty_fifo_probe.rd_ptr=0;
    empty_fifo_probe.inputs=0;
    empty_fifo_probe.dipsw=0;
    empty_fifo_probe.dipsw_set=0;
    empty_fifo_probe.serial_payload.payload_reg=next_event[87:0];
    probe_rx_byte=next_event[95:88];
    probe_rx_cmd=command;
    probe_rx_index=(command==8'h86) ? 5'd12 : 5'd8;
    probe_rx_strobe=0;
    probe_lvbl=1;
    repeat(2) tick();
    @(negedge clk); probe_rx_strobe=1;
    tick();
    @(negedge clk); probe_rx_strobe=0; probe_lvbl=0;
    repeat(3) tick();
    if(probe_state!==3'd2 || probe_error!==0 || empty_fifo_probe.queued!==0 ||
       empty_fifo_probe.accepted!==2 || empty_fifo_probe.applied!==2 ||
       probe_inputs!==21'h00155 || empty_fifo_probe.remaining!==15'd1)
        $fatal(1,"empty-FIFO simultaneous enqueue/pop lost event command=%h state=%d err=%d input=%h",command,probe_state,probe_error,probe_inputs);
    if(command==8'h86 && (!probe_dipsw_valid || probe_dipsw!==dip_value))
        $fatal(1,"empty-FIFO PUSH_DIP bypass lost DIP payload/validity: %h",probe_dipsw);
    if(command==8'h83 && probe_dipsw_valid)
        $fatal(1,"ordinary empty-FIFO PUSH spuriously set DIP-valid");
end
endtask

reg [127:0] caps;
reg [255:0] snap;
integer i;
initial begin
    repeat(4) tick(); rst=0; repeat(4) tick();
    read_caps(caps);
    if(caps[15:0]!==16'hCA4D || caps[31:16]!==2 || caps[47:32]!==8 || caps[63:48]!==0)
        $fatal(1,"CAB CAPS v2 header mismatch: %h",caps[63:0]);

    arm(4,2);
    if(cab_state!==1 || !cab_hold_reset) $fatal(1,"ARM did not enter v2 ARMED: state=%d error=%d frames=%h events=%h packet=%h",cab_state,cab_error,uut.u_cab_stream.total_frames,uut.u_cab_stream.total_events,uut.u_cab_stream.packet);
    push(0,1,32'h00000155);
    push_dip(1,3,32'h002002aa,32'h12345678);
    if(cab_error!=0) $fatal(1,"valid compact event rejected: %d accepted=%d frames=%d sum=%d packet=%h",cab_error,uut.u_cab_stream.accepted,uut.u_cab_stream.accepted_frames,uut.u_cab_stream.frame_sum,uut.u_cab_stream.packet);
    start_run();
    for(i=0;i<8 && cab_state!=3;i=i+1) frame_tick();
    if(cab_state!==3 || cab_error!==0 || cab_frame!==4) $fatal(1,"CAB run did not complete: state=%d err=%d frames=%d",cab_state,cab_error,cab_frame);
    if(cab_dipsw_valid || cab_inputs!==0 || cab_dipsw!==32'h12345678)
        $fatal(1,"natural DONE retained the DIP override or non-neutral inputs");

    status_refresh(); read_caps(caps);
    if(caps[79:64]!==5 || caps[95:80]!==0 || caps[111:96]!==5 || caps[127:112]!==0 || !caps[49])
        $fatal(1,"command/snapshot freshness or snapshot-valid flags wrong: %h words=%h/%h/%h",caps,caps[95:80],caps[111:96],caps[63:48]);
    read_snapshot(snap);
    if(snap[7:0]!==8'hca || snap[15:8]!==2 || snap[23:16]!==3 || snap[31:24]!==0 ||
       snap[47:32]!==4 || snap[63:48]!==4 || snap[79:64]!==2 || snap[95:80]!==2 ||
       snap[111:96]!==2 || snap[199:192]!==0 || snap[203] ||
       snap[191:160]!==32'h12345678 || snap[255:208]!==0)
        $fatal(1,"v2 CAB snapshot fields mismatch: %h",snap);
    check_empty_fifo_boundary(8'h83,32'd0);
    check_empty_fifo_boundary(8'h86,32'h12345678);
    $display("PASS"); $finish;
end
initial begin #2000000 $fatal(1,"timeout"); end
endmodule
