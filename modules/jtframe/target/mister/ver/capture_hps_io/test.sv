`timescale 1ns/1ps

module test;

reg clk=0, rst=1, uio_extra_rst=0;
reg io_strobe=0, io_enable=0, fp_enable=0;
reg [15:0] host_word=0;
tri [48:0] HPS_BUS;
tri [35:0] EXT_BUS;
tri [21:0] gamma_bus;
wire response_enable;
wire [15:0] response_word;
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

wire uio_start, uio_finish, uio_active, uio_bad_word;
wire [15:0] uio_command;
wire [6:0] uio_words, uio_bad_index;
wire [95:0] uio_payload;
wire [127:0] uio_cab_caps, uio_cap_caps;
wire [255:0] uio_snapshot;
wire uio_snapshot_valid, uio_result_valid;
wire [5:0] result_index;
wire [7:0] result_byte;
jtframe_mister_uio transport(.rst(rst | uio_extra_rst), .clk(clk), .io_enable(EXT_BUS[34] && !EXT_BUS[35]), .io_strobe(EXT_BUS[33]), .host_word(EXT_BUS[31:16]),
    .cab_caps(uio_cab_caps), .cap_caps(uio_cap_caps), .cab_snapshot(uio_snapshot),
    .cap_result_index(result_index), .cap_result_byte(result_byte),
    .cab_snapshot_valid(uio_snapshot_valid), .cap_result_valid(uio_result_valid),
    .response_enable(response_enable), .response_word(response_word), .start(uio_start), .finish(uio_finish), .active(uio_active), .command(uio_command),
    .words(uio_words), .payload(uio_payload), .bad_word(uio_bad_word), .bad_index(uio_bad_index));

/* verilator lint_off PINMISSING */
jtframe_mister_capture capture(
    .rst              ( rst                ),
    .clk              ( clk                ),
    .host_word        ( EXT_BUS[31:16]     ),
    .uio_start        ( uio_start          ),
    .uio_finish       ( uio_finish         ),
    .uio_active       ( uio_active         ),
    .uio_command      ( uio_command        ),
    .uio_words        ( uio_words          ),
    .uio_payload      ( uio_payload[63:0]  ),
    .uio_bad_word     ( uio_bad_word       ),
    .uio_bad_index    ( uio_bad_index      ),
    .uio_caps         ( uio_cap_caps       ),
    .uio_result_valid ( uio_result_valid   ),
    .result_index     ( result_index       ),
    .result_byte      ( result_byte        ),
    .lvbl             ( lvbl               ),
    .cab_frame_start  ( cab_frame_start    ),
    .cab_frame_index  ( cab_frame_index    ),
    .cab_completed    ( cab_frame          ),
    .cab_state        ( cab_state          ),
    .cab_error        ( cab_error          ),
    .pxl_cen          ( 1'b0               ),
    .red              ( 8'd0               ),
    .green            ( 8'd0               ),
    .blue             ( 8'd0               ),
    .de               ( 1'b0               ),
    .video_ok         ( 1'b1               ),
    .ddr_busy         ( 1'b0               )
);
/* verilator lint_on PINMISSING */

jtframe_mister_cab cab(
    .uio_start(uio_start), .uio_finish(uio_finish), .uio_active(uio_active),
    .uio_command(uio_command), .uio_words(uio_words), .uio_payload(uio_payload), .uio_bad_word(uio_bad_word), .uio_bad_index(uio_bad_index),
    .rst             ( rst             ),
    .clk_rom         ( clk             ),
    .clk_sys         ( clk             ),
    .lvbl            ( lvbl            ),
    .io_strobe       ( EXT_BUS[33]     ),
    .io_enable       ( EXT_BUS[34] && !EXT_BUS[35] ),
    .host_word       ( EXT_BUS[31:16]  ),
    .uio_caps        ( uio_cab_caps ),
    .uio_snapshot    ( uio_snapshot ),
    .uio_snapshot_valid ( uio_snapshot_valid ),
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


initial begin
    repeat(4) tick(); rst=0; repeat(4) tick();

    // A capture-only reset can interrupt a foreign UIO transaction while
    // the CAB backend remains running. Neither reset-time words nor the tail
    // after reset may be decoded as new CAB commands.
    packet_begin(16'h0000);
    @(negedge clk); uio_extra_rst=1;
    host_word_pulse(16'h0087);
    @(negedge clk); uio_extra_rst=0;
    host_word_pulse(16'h0087);
    host_word_pulse(16'h0085);
    packet_end(); repeat(8) tick();
    if(cab.fault_code!==0 || cab.abort_pending || cab.command_toggle_rom || response_enable)
        $fatal(1,"capture-only reset decoded a foreign packet tail as CAB traffic");

    // Full 16-bit command 0x0190 must not alias CAP_CAPS 0x0090.
    packet_begin(16'h0190);
    repeat(8) host_word_pulse(16'd0);
    packet_end();
    if(capture.owner || capture.fault!=0 || response_enable) $fatal(1,"0x0190 was claimed by capture");

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
    if(response_enable || capture.fault!=0) $fatal(1,"ordinary UIO traffic touched capture");
    @(negedge clk); fp_enable=1; io_enable=1;
    host_word_pulse(16'h0053); host_word_pulse(16'h00AA); packet_end();
    fp_enable=0;
    if(response_enable || capture.fault!=0) $fatal(1,"FP transfer traffic touched capture");

    // Real HPS bus command, eight dummies, and post-transaction deassertion.
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin
        host_word_pulse(16'd0);
        words[j]=HPS_BUS[15:0];
    end
    packet_end();
    if(words[0]!==16'hCA50 || words[1]!==16'd2 || words[2]!==16'd64)
        $fatal(1,"real hps_io CAP_CAPS response mismatch: %h %h %h",words[0],words[1],words[2]);
    if(words[3][15:0]!==16'h0040) $fatal(1,"unexpected initial capture flags %h",words[3]);

    // A nonzero upper byte in a payload word must fault before ARM publishes
    // anything, even through the real hps_io EXT_BUS serializer.
    packet_begin(16'h0091);
    send_byte(8'd10); send_byte(8'd0);
    host_word_pulse(16'h0100);
    repeat(5) send_byte(8'd0);
    packet_end();
    if(capture.owner) $fatal(1,"real HPS malformed high-byte ARM was accepted");
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][15:8]!==8'd2 || !words[3][3])
        $fatal(1,"real HPS payload high-byte fault missing: %h",words[3]);
    rst=1; repeat(3) tick(); rst=0; repeat(4) tick();

    // ARM through the real bus with no CAB session: rejected, not owned.
    packet_begin(16'h0091); send_arm(16'd10, 32'd1000); packet_end();
    packet_begin(16'h0090);
    for(j=0;j<8;j=j+1) begin host_word_pulse(16'd0); words[j]=HPS_BUS[15:0]; end
    packet_end();
    if(words[3][1] || words[3][15:8]!==8'd3 || words[4]!==16'd1)
        $fatal(1,"ARM without a CAB session: flags=%h freshness=%h",words[3],words[4]);

    // RESULT_READ without a result: 64 zero words, high bytes zero.
    packet_begin(16'h0092);
    for(j=0;j<64;j=j+1) begin
        host_word_pulse(16'd0);
        result_word=HPS_BUS[15:0];
        if(result_word!==16'd0) $fatal(1,"RESULT_READ without a result returned %h",result_word);
    end
    packet_end();
    if(response_enable) $fatal(1,"response driver remained enabled after deassertion");
    $display("PASS");
    $finish;
end

endmodule
