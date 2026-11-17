`timescale 1ns/1ps

module test;

reg clk=0, rst=1;
reg io_strobe=0, io_enable=0, fp_enable=0;
reg [15:0] host_word=0;
tri [48:0] HPS_BUS;
tri [35:0] EXT_BUS;
tri [21:0] gamma_bus;
wire capture_response_enable, cab_response_enable, response_enable;
wire [15:0] capture_response_word, cab_response_word, response_word;
reg [7:0] cap_state=0, cap_fault=0;
wire req_toggle, release_toggle, abort_toggle, result_ack;
wire [31:0] req;
wire [15:0] release_tuple, abort_tuple;
reg req_ack=0, release_ack=0, abort_ack=0, result_toggle=0;
reg [511:0] result_data=0;
reg lvbl=1;
wire cab_active, cab_hold_reset, cab_dipsw_valid, cab_frame_start;
wire [20:0] cab_inputs;
wire [31:0] cab_dipsw;
wire [14:0] cab_frame, cab_frame_index;
wire [2:0] cab_state;
wire [7:0] cab_error;
wire ioctl_download, ioctl_upload, ioctl_wr, ioctl_rd;
wire [15:0] ioctl_index;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_dout;

always #5 clk=~clk;

assign response_enable = capture_response_enable || cab_response_enable;
assign response_word = capture_response_enable ? capture_response_word : cab_response_word;

assign HPS_BUS[35:33] = {fp_enable,io_enable,io_strobe};
assign HPS_BUS[31:16] = host_word;
assign HPS_BUS[48:38] = 0;
assign EXT_BUS[32] = response_enable;
assign EXT_BUS[15:0] = response_enable ? response_word : 16'hzzzz;

/* verilator lint_off PINMISSING */
hps_io #(.WIDE(0),.PS2DIV(0),.STRLEN(1),.CONF_STR_BRAM(0)) hps(
    .clk_sys          ( clk             ),
    .HPS_BUS          ( HPS_BUS         ),
    .joy_raw          ( 16'd0           ),
    .gamma_bus        ( gamma_bus       ),
    .new_vmode        ( 1'b0            ),
    .video_rotated    ( 1'b0            ),
    .ioctl_download   ( ioctl_download  ),
    .ioctl_upload     ( ioctl_upload    ),
    .ioctl_wr         ( ioctl_wr        ),
    .ioctl_index      ( ioctl_index     ),
    .ioctl_addr       ( ioctl_addr      ),
    .ioctl_dout       ( ioctl_dout      ),
    .ioctl_din        ( 8'd0            ),
    .ioctl_rd         ( ioctl_rd        ),
    .ioctl_wait       ( 1'b0            ),
    .ioctl_upload_req ( 1'b0            ),
    .ioctl_upload_index ( 8'd0          ),
    .EXT_BUS          ( EXT_BUS         )
);
/* verilator lint_on PINMISSING */

jtframe_mister_capture_io capture(
    .clk_rom              ( clk              ),
    .rst                  ( rst              ),
    .io_strobe            ( EXT_BUS[33]      ),
    .io_enable            ( EXT_BUS[34] && !EXT_BUS[35] ),
    .host_word            ( EXT_BUS[31:16]   ),
    .response_enable      ( capture_response_enable ),
    .response_word        ( capture_response_word   ),
    .cap_state_in         ( cap_state        ),
    .cap_fault_in         ( cap_fault        ),
    .cap_req_toggle       ( req_toggle       ),
    .cap_req              ( req              ),
    .cap_req_ack_toggle   ( req_ack          ),
    .cap_release_toggle   ( release_toggle   ),
    .cap_release          ( release_tuple    ),
    .cap_release_ack_toggle ( release_ack    ),
    .cap_abort_toggle     ( abort_toggle     ),
    .cap_abort            ( abort_tuple      ),
    .cap_abort_ack_toggle ( abort_ack        ),
    .cap_result_toggle    ( result_toggle    ),
    .cap_result           ( result_data      ),
    .cap_result_ack_toggle( result_ack       )
);

jtframe_mister_cab cab(
    .rst             ( rst             ),
    .clk_rom         ( clk             ),
    .clk_sys         ( clk             ),
    .lvbl            ( lvbl            ),
    .io_strobe       ( EXT_BUS[33]     ),
    .io_enable       ( EXT_BUS[34] && !EXT_BUS[35] ),
    .host_word       ( EXT_BUS[31:16]  ),
    .response_enable ( cab_response_enable ),
    .response_word   ( cab_response_word   ),
    .cab_active      ( cab_active      ),
    .cab_hold_reset  ( cab_hold_reset  ),
    .cab_inputs      ( cab_inputs      ),
    .cab_dipsw_valid ( cab_dipsw_valid ),
    .cab_dipsw       ( cab_dipsw       ),
    .cab_frame       ( cab_frame       ),
    .cab_frame_start ( cab_frame_start ),
    .cab_frame_index ( cab_frame_index ),
    .cab_state       ( cab_state       ),
    .cab_error       ( cab_error       )
);

task tick;
begin @(posedge clk); #1; end
endtask

task host_word_pulse(input [15:0] value);
begin
    @(negedge clk); host_word=value; io_strobe=1;
    @(posedge clk); #1;
    if(capture_response_enable && cab_response_enable)
        $fatal(1,"capture and CAB response owners overlap");
    if(response_enable && $isunknown(HPS_BUS[15:0]))
        $fatal(1,"HPS response bus contains X/Z while capture owns the read");
    io_strobe=0;
    @(negedge clk);
end
endtask

task packet_begin(input [15:0] command);
begin
    @(negedge clk); fp_enable=0; io_enable=1;
    host_word_pulse(command);
end
endtask

task packet_end;
begin
    @(negedge clk); io_strobe=0; io_enable=0;
    @(posedge clk); #1;
end
endtask

task send_byte(input [7:0] value);
begin host_word_pulse({8'd0,value}); end
endtask

task send_arm(input [15:0] checkpoint, input [31:0] hold_ms);
integer j;
begin
    send_byte(checkpoint[7:0]); send_byte(checkpoint[15:8]);
    send_byte(8'd0); send_byte(8'd0);
    for(j=0;j<4;j=j+1) send_byte(hold_ms[j*8 +: 8]);
end
endtask

task send_tuple(input [15:0] checkpoint);
integer j;
begin
    send_byte(checkpoint[7:0]); send_byte(checkpoint[15:8]);
    send_byte(8'd0); send_byte(8'd0);
end
endtask

integer j;
reg [15:0] words [0:7];
reg [15:0] result_word;

task set_result;
begin
    result_data=0;
    result_data[31:0]=32'h3243544A; // JTC2
    result_data[47:32]=16'd2;
    result_data[63:48]=16'd64;
    result_data[8*8 +: 16]=16'd10;
    result_data[8*10 +: 16]=16'd9;
    result_data[8*60 +: 32]="RDY2";
end
endtask

initial begin
    repeat(4) tick(); rst=0; repeat(4) tick();

    // Full 16-bit command 0x0190 must not alias CAP_CAPS 0x0090.
    packet_begin(16'h0190);
    repeat(8) host_word_pulse(16'd0);
    packet_end();
    if(req_toggle || response_enable) $fatal(1,"0x0190 was claimed by capture");

    packet_begin(16'h0180); repeat(8) host_word_pulse(16'd0); packet_end();
    if(response_enable) $fatal(1,"0x0180 was claimed by CAB");

    // Existing CAB CAPS continues to use the same single EXT_BUS response mux.
    packet_begin(16'h0080);
    for(j=0;j<8;j=j+1) begin
        host_word_pulse(16'd0);
        words[j]=HPS_BUS[15:0];
    end
    packet_end();
    if(words[0]!==16'hCA4D || words[1]!==16'd2)
        $fatal(1,"real CAB CAPS response mismatch: %h %h",words[0],words[1]);

    // Ordinary UIO and FPGA-file traffic bypass capture response ownership.
    packet_begin(16'h0000); host_word_pulse(16'h1234); packet_end();
    if(response_enable || req_toggle) $fatal(1,"ordinary UIO traffic touched capture");
    @(negedge clk); fp_enable=1; io_enable=1;
    host_word_pulse(16'h0053); host_word_pulse(16'h00AA); packet_end();
    fp_enable=0;
    if(response_enable || req_toggle) $fatal(1,"FP transfer traffic touched capture");

    // Real HPS bus command, eight dummies, and post-transaction deassertion.
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin
        host_word_pulse(16'd0);
        words[j]=HPS_BUS[15:0];
    end
    packet_end();
    if(words[0]!==16'hCA50 || words[1]!==16'd2 || words[2]!==16'd64)
        $fatal(1,"real hps_io CAP_CAPS response mismatch: %h %h %h",words[0],words[1],words[2]);
    if(words[3][15:0]!==0) $fatal(1,"unexpected initial capture flags %h",words[3]);

    // A nonzero upper byte in a payload word must fault before ARM publishes
    // anything, even through the real hps_io EXT_BUS serializer.
    packet_begin(16'h0091);
    send_byte(8'd10); send_byte(8'd0);
    host_word_pulse(16'h0100);
    repeat(5) send_byte(8'd0);
    packet_end();
    if(req_toggle) $fatal(1,"real HPS malformed high-byte ARM was published");
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][15:8]!==8'd2 || !words[3][3])
        $fatal(1,"real HPS payload high-byte fault missing: %h",words[3]);
    rst=1; repeat(3) tick(); rst=0; repeat(4) tick();
    if(req_toggle || release_toggle || abort_toggle || result_ack)
        $fatal(1,"high-byte fault reset left capture mailbox toggles set");

    // The internal quiescence barrier uses state 5, but the public protocol
    // has only states 0..4. Report draining through CAPS.flags bit 5 without
    // leaking that internal state or raising an unrelated fault/owner flag.
    cap_state=5;
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin
        host_word_pulse(16'd0);
        words[j]=HPS_BUS[15:0];
    end
    packet_end();
    if(words[3]!==16'h0020 || words[4]!==16'd0 || words[5]!==16'd0 ||
       words[6]!==16'd0 || words[7]!==16'd0)
        $fatal(1,"internal drain state was not serialized as CAPS bit5 only: flags=%h",words[3]);
    cap_state=0;
    repeat(4) tick();

    // Exact 8-byte ARM reaches the request bundle only after io_enable falls.
    packet_begin(16'h0091);
    send_arm(16'd10,32'd1000);
    if(req_toggle) $fatal(1,"ARM published before HPS transaction deassertion");
    packet_end();
    if(!req_toggle || req!=={5'd0,11'd1000,1'b0,15'd10})
        $fatal(1,"real hps_io ARM payload packing wrong: %h",req);
    cap_state=1; repeat(4) tick(); req_ack=req_toggle; repeat(4) tick();

    // READY may arrive before the independent result mailbox. CAPS must not
    // advertise READY, or a readable result, until this request's descriptor is
    // validated and cached.
    cap_state=3;
    set_result();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][2] || words[6]!==16'd0)
        $fatal(1,"READY advertised before the owned result cache: flags=%h result_freshness=%h",words[3],words[7]);

    // Once the matching result toggle is consumed, READY appears and an
    // exact 64-dummy RESULT_READ returns the stable cached low-byte view.
    result_toggle=1; wait(result_ack==result_toggle); repeat(2) tick();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(!words[3][2] || words[6]!==16'd1 || words[7]!==16'd0)
        $fatal(1,"READY missing after matching result cache: flags=%h freshness=%h:%h",words[3],words[6],words[7]);
    packet_begin(16'h0092);
    for(j=0;j<64;j=j+1) begin
        host_word_pulse(16'd0);
        result_word=HPS_BUS[15:0];
        if(result_word[15:8]!==0) $fatal(1,"RESULT_READ response high byte is not zero");
        if(j==0 && result_word[7:0]!=="J") $fatal(1,"RESULT_READ first byte wrong: %h",result_word);
        if(j==8 && result_word[7:0]!==8'd10) $fatal(1,"RESULT_READ checkpoint byte8 wrong: %h",result_word);
    end
    packet_end();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][15:8]!==0 || words[3][3])
        $fatal(1,"valid exact64 RESULT_READ was faulted: %h",words[3]);
    result_data[7:0]="X";
    if(response_enable) $fatal(1,"response driver remained enabled after deassertion");

    // Complete release, then reuse checkpoint 10. The previous result must remain invalid until a fresh publication.
    packet_begin(16'h0093); send_tuple(16'd10); packet_end();
    cap_state=0; release_ack=release_toggle; repeat(4) tick();
    if(release_toggle!==1'b1)
        $fatal(1,"clean release was not acknowledged");
    packet_begin(16'h0091); send_arm(16'd10,32'd1000); packet_end();
    cap_state=1; repeat(4) tick(); req_ack=req_toggle; repeat(4) tick();
    cap_state=3;
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][2] || words[6]!==16'd1 || words[7]!==16'd0)
        $fatal(1,"reused checkpoint exposed stale READY/cache: flags=%h freshness=%h",words[3],words[6],words[7]);
    set_result();
    result_toggle=0; wait(result_ack==result_toggle); repeat(2) tick();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(!words[3][2] || words[6]!==16'd2 || words[7]!==16'd0)
        $fatal(1,"fresh reused-checkpoint result did not restore READY: flags=%h freshness=%h",words[3],words[6],words[7]);

    // Shared system reset while READY discards the cached descriptor, owner,
    // transport counters, and mailbox toggles. No pre-reset result is visible.
    rst=1; cap_state=0; cap_fault=0; result_toggle=0;
    req_ack=0; release_ack=0; abort_ack=0;
    repeat(3) tick();
    rst=0; repeat(4) tick();
    if(req_toggle || release_toggle || abort_toggle || result_ack)
        $fatal(1,"READY reset left stale controller/result toggle state");
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3]!==16'd0 || words[4]!==16'd0 || words[5]!==16'd0 ||
       words[6]!==16'd0 || words[7]!==16'd0)
        $fatal(1,"READY reset retained cached result/CAPS ownership: %h",words[3]);

    // Re-establish a valid owner/result so the following short-read case
    // exercises length validation rather than the no-owner state error.
    packet_begin(16'h0091); send_arm(16'd10,32'd1000); packet_end();
    cap_state=1; repeat(4) tick(); req_ack=req_toggle; repeat(4) tick();
    cap_state=3;
    set_result();
    result_toggle=1; wait(result_ack==result_toggle); repeat(2) tick();

    // A clean 63-dummy read is rejected; the exact 64-dummy response above
    // must not have passed only because a prior fault was already sticky.
    packet_begin(16'h0092); repeat(63) host_word_pulse(16'd0); packet_end();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][15:8]!==8'd1 || !words[3][3])
        $fatal(1,"short real RESULT_READ not rejected: %h",words[3]);

    // Reset both ends before the independent 65-dummy long-read negative.
    rst=1; cap_state=0; result_toggle=0; req_ack=0; release_ack=0; abort_ack=0; repeat(3) tick();
    rst=0; repeat(3) tick();
    packet_begin(16'h0091); send_arm(16'd10,32'd1000); packet_end();
    cap_state=1; repeat(4) tick(); req_ack=req_toggle; repeat(4) tick();
    set_result(); result_toggle=1;
    wait(result_ack==result_toggle); repeat(2) tick();
    packet_begin(16'h0092); repeat(65) host_word_pulse(16'd0); packet_end();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][15:8]!==8'd1 || !words[3][3])
        $fatal(1,"long real RESULT_READ not rejected: %h",words[3]);

    // Independently prove the eight-word CAPS read rejects seven dummies.
    rst=1; cap_state=0; result_toggle=0; req_ack=0; release_ack=0; abort_ack=0; repeat(3) tick();
    rst=0; repeat(3) tick();
    packet_begin(16'h0090); repeat(7) host_word_pulse(16'd0); packet_end();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][15:8]!==8'd1 || !words[3][3])
        $fatal(1,"real hps_io malformed read fault missing: %h",words[3]);

    $display("PASS");
    $finish;
end

initial begin #3000000 $fatal(1,"timeout"); end

endmodule
