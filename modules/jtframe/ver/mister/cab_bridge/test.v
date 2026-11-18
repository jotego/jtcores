`timescale 1ns/1ps
module test;
    reg clk_rom=0, clk_sys=0, pll_locked=0, lvbl=0, sys_clk_en=1;
    wire rst, rst_n, game_rst, game_rst_n;
    reg io_clk=0, io_uio=0, io_fpga=0;
    reg [15:0] io_din=0;
    reg rack=0, io_ack=0;
    wire io_strobe=!rack && io_clk;
    tri [48:0] HPS_BUS;
    tri [35:0] EXT_BUS;
    tri [21:0] gamma_bus;
    wire [31:0] joystick_0;
    wire cab_active, cab_hold_reset, cab_dipsw_valid, cab_frame_start;
    wire [20:0] cab_inputs;
    wire [31:0] cab_dipsw;
    wire [14:0] cab_frame, cab_frame_index;
    wire [2:0] cab_state;
    wire [7:0] cab_error;
    wire cab_response_enable;
    wire [15:0] cab_response_word;
    integer i, timeout;
    integer sys_half=7;
    reg [15:0] response;
    reg response_valid;
    reg [159:0] payload;
    reg frame_start_seen=0;
    reg frame_start_while_reset=0;
    reg [31:0] frame_index_seen=0;
    reg count_stream=0;
    integer stream_cycles=0;
    reg [4:0] stream_last_index=31;

    always #5 clk_rom=~clk_rom;
    always #(sys_half) if(sys_clk_en) clk_sys=~clk_sys; else clk_sys=0;
    assign HPS_BUS[35:33]={io_fpga,io_uio,io_strobe};
    assign HPS_BUS[31:16]=io_din;
    assign HPS_BUS[48:38]=0;
    assign EXT_BUS[32]=cab_response_enable;
    assign EXT_BUS[15:0]=cab_response_enable ? cab_response_word : 16'hzzzz;
    always @(posedge clk_rom) begin rack<=io_clk; io_ack<=rack; end
    always @(posedge clk_sys) if(cab_frame_start) begin
        frame_start_seen<=1;
        frame_index_seen<=cab_frame_index;
        if(game_rst) frame_start_while_reset<=1;
    end
    always @(posedge clk_sys) if(count_stream && dut.stream_rx_strobe) begin
        stream_cycles<=stream_cycles+1;
        stream_last_index<=dut.stream_rx_index;
    end

    task start_tx;
        begin @(negedge clk_rom); io_uio=1; end
    endtask
    task end_tx;
        begin @(negedge clk_rom); io_uio=0; repeat(2) @(negedge clk_rom); end
    endtask
    task transfer(input [15:0] word, output [15:0] rdata, output rvalid);
        begin
            @(negedge clk_rom); io_din=word;
            @(negedge clk_rom); io_clk=1;
            wait(io_ack===1'b1);
            @(negedge clk_rom); io_clk=0;
            wait(io_ack===1'b0);
            @(negedge clk_rom); rdata=HPS_BUS[15:0]; rvalid=EXT_BUS[32];
        end
    endtask
    task write_cmd(input [15:0] cmd, input [5:0] nbytes, input [159:0] data);
        integer b;
        reg [15:0] rd; reg rv;
        begin
            start_tx(); transfer(cmd,rd,rv);
            for(b=0;b<nbytes;b=b+1) transfer({8'd0,data[b*8 +: 8]},rd,rv);
            end_tx();
        end
    endtask
    task read_caps(output [127:0] caps);
        integer w;
        reg [15:0] rd; reg rv;
        begin
            caps=0; start_tx(); transfer(16'h0080,rd,rv);
            for(w=0;w<8;w=w+1) begin
                transfer(16'd0,rd,rv);
                if(rv!==1'b1 || ^rd===1'bx) $fatal(1,"CAPS response invalid word %0d: %h rv=%b",w,rd,rv);
                caps[w*16 +: 16]=rd;
            end
            end_tx();
        end
    endtask
    task wait_idle;
        integer n;
        reg [127:0] c;
        begin
            n=0; read_caps(c);
            while(c[48]) begin
                read_caps(c); n=n+1;
                if(n>40) $fatal(1,"bridge BUSY did not drain: %h",c);
            end
        end
    endtask
    task count_begin;
        begin @(negedge clk_sys); stream_cycles=0; stream_last_index=31; count_stream=1; end
    endtask
    task count_end(input integer expected_cycles, input [4:0] expected_last);
        begin
            @(negedge clk_sys); count_stream=0;
            if(stream_cycles!=expected_cycles || stream_last_index!=expected_last)
                $fatal(1,"CAB feed framing: cycles=%0d last-index=%0d expected=%0d/%0d",stream_cycles,stream_last_index,expected_cycles,expected_last);
        end
    endtask
    task read_snapshot(output [255:0] bytes);
        integer b;
        reg [15:0] rd; reg rv;
        begin
            bytes=0; start_tx(); transfer(16'h0087,rd,rv);
            for(b=0;b<32;b=b+1) begin
                transfer(16'd0,rd,rv);
                if(rv!==1'b1 || rd[15:8]!==0 || ^rd===1'bx) $fatal(1,"bad snapshot response word %0d: %h rv=%b",b,rd,rv);
                bytes[b*8 +: 8]=rd[7:0];
            end
            end_tx();
        end
    endtask
    task read_invalid_snapshot_while_status_completes(output [255:0] bytes);
        integer b;
        reg [15:0] rd; reg rv;
        begin
            bytes=0; start_tx(); transfer(16'h0087,rd,rv);
            for(b=0;b<32;b=b+1) begin
                transfer(16'd0,rd,rv);
                if(rv!==1'b1 || rd[15:8]!==0 || ^rd===1'bx)
                    $fatal(1,"bad invalid snapshot response word %0d: %h rv=%b",b,rd,rv);
                bytes[b*8 +: 8]=rd[7:0];
                if(b==0) sys_clk_en=1;
            end
            end_tx();
        end
    endtask
    task write_bad_arm_word;
        integer b;
        reg [15:0] rd; reg rv;
        begin
            start_tx(); transfer(16'h0082,rd,rv);
            transfer(16'h0101,rd,rv); // nonzero upper byte is forbidden
            for(b=1;b<5;b=b+1) transfer(16'd0,rd,rv);
            end_tx();
        end
    endtask
    task write_valid_arm;
        reg [159:0] arm_payload;
        begin
            arm_payload=0;
            arm_payload[7:0]=1;       // request reset while CAB is ARMED
            arm_payload[23:8]=1;      // one frame
            arm_payload[39:24]=1;     // one input event
            write_cmd(16'h0082,5,arm_payload);
        end
    endtask
    task write_arm_count(input [14:0] count);
        reg [159:0] arm_payload;
        begin
            arm_payload=0;
            arm_payload[23:8]=count;
            arm_payload[38:24]=count;
            write_cmd(16'h0082,5,arm_payload);
            wait_idle();
        end
    endtask
    task write_partial(input [15:0] cmd, input [5:0] nbytes, input [159:0] data);
        integer b;
        reg [15:0] rd; reg rv;
        begin
            start_tx(); transfer(cmd,rd,rv);
            for(b=0;b<nbytes;b=b+1) transfer({8'd0,data[b*8 +: 8]},rd,rv);
            end_tx();
        end
    endtask
    task native_frame;
        begin
            @(negedge clk_sys); lvbl=0;
            repeat(4) @(negedge clk_sys);
            lvbl=1; repeat(4) @(negedge clk_sys);
            lvbl=0; repeat(4) @(negedge clk_sys);
        end
    endtask
wire uio_start, uio_finish, uio_active, uio_bad_word;
wire [15:0] uio_command;
wire [6:0] uio_words, uio_bad_index;
wire [95:0] uio_payload;
wire [127:0] uio_cab_caps;
wire [255:0] uio_snapshot;
wire uio_snapshot_valid;
jtframe_mister_uio transport(.rst(rst), .clk(clk_rom), .io_enable(EXT_BUS[34] && !EXT_BUS[35]), .io_strobe(EXT_BUS[33]), .host_word(EXT_BUS[31:16]),
    .cab_caps(uio_cab_caps), .cap_caps(128'd0), .cab_snapshot(uio_snapshot),
    .cap_result(512'd0), .cab_snapshot_valid(uio_snapshot_valid), .cap_result_valid(1'b0),
    .response_enable(cab_response_enable), .response_word(cab_response_word), .start(uio_start), .finish(uio_finish), .active(uio_active), .command(uio_command),
    .words(uio_words), .payload(uio_payload), .bad_word(uio_bad_word), .bad_index(uio_bad_index));

    jtframe_mister_cab dut(
    .uio_start(uio_start), .uio_finish(uio_finish), .uio_active(uio_active),
    .uio_command(uio_command), .uio_words(uio_words), .uio_payload(uio_payload), .uio_bad_word(uio_bad_word), .uio_bad_index(uio_bad_index),
        .rst(rst),.clk_rom(clk_rom),.clk_sys(clk_sys),.lvbl(lvbl),
        .io_strobe(EXT_BUS[33]),.io_enable(EXT_BUS[34]&&!EXT_BUS[35]),
        .host_word(EXT_BUS[31:16]),.uio_caps(uio_cab_caps), .uio_snapshot(uio_snapshot), .uio_snapshot_valid(uio_snapshot_valid),
        .cab_active(cab_active),.cab_hold_reset(cab_hold_reset),.cab_inputs(cab_inputs),
        .cab_dipsw_valid(cab_dipsw_valid),.cab_dipsw(cab_dipsw),
        .cab_frame(cab_frame),
        .cab_frame_start(cab_frame_start),.cab_frame_index(cab_frame_index),
        .cab_state(cab_state),.cab_error(cab_error)
    );

    jtframe_reset u_reset(
        .clk_sys(clk_sys),.clk_rom(clk_rom),.pxl_cen(1'b1),
        .sdram_init(1'b0),.ioctl_rom(1'b0),.dip_flip(1'b0),.soft_rst(1'b0),
        .rst_req(cab_hold_reset | cab_inputs[12]),.pll_locked(pll_locked),
        .rst(rst),.rst_n(rst_n),.game_rst(game_rst),.game_rst_n(game_rst_n)
    );

    hps_io #(.WIDE(0),.PS2DIV(0),.STRLEN(1),.CONF_STR_BRAM(0)) uio(
        .clk_sys(clk_rom),.HPS_BUS(HPS_BUS),.EXT_BUS(EXT_BUS),.gamma_bus(gamma_bus),
        .joy_raw(16'd0),.new_vmode(1'b0),.video_rotated(1'b0),.joystick_0(joystick_0),
        .ioctl_wait(1'b0),.ioctl_din(8'd0)
    );

    reg [127:0] caps;
    reg [255:0] status_bytes;
    initial begin
        repeat(8) @(negedge clk_rom); pll_locked=1;
        wait(!rst); repeat(10) @(negedge clk_rom);
        start_tx(); transfer(16'h0002,response,response_valid);
        transfer(16'h1234,response,response_valid); transfer(16'h5678,response,response_valid);
        if(EXT_BUS[32]!==1'b0 || joystick_0!==32'h56781234)
            $fatal(1,"ordinary UIO joystick command intercepted or corrupted");
        end_tx();

        @(negedge clk_rom); io_fpga=1; io_uio=1;
        transfer(16'h0080,response,response_valid); transfer(16'd0,response,response_valid);
        if(EXT_BUS[32]!==1'b0) $fatal(1,"FPGA file-transfer traffic intercepted");
        @(negedge clk_rom); io_fpga=0; io_uio=0; repeat(3) @(negedge clk_rom);

        read_caps(caps);
        if(caps[15:0]!==16'hCA4D || caps[31:16]!==2 || caps[47:32]!==8)
            $fatal(1,"CAPS header mismatch: %h",caps[47:0]);
        if(cab_state!==3'd0 || cab_error!==8'd0)
            $fatal(1,"read-only CAB observation not idle/clean: state=%0d error=%0d",cab_state,cab_error);

        count_begin(); write_cmd(16'h0081,0,0);
        timeout=0;
        do begin
            read_caps(caps); timeout=timeout+1;
            if(timeout>40) $fatal(1,"STATUS_REFRESH timeout CAPS=%h",caps);
        end while(caps[95:64]!==1 || caps[127:96]!==1 || caps[48]!==1'b0);
        count_end(1,0);
        read_snapshot(status_bytes);
        if(status_bytes[7:0]!=8'hca || status_bytes[15:8]!=2)
            $fatal(1,"snapshot byte ordering/magic incorrect: %h",status_bytes[15:0]);
        read_caps(caps);
        if(caps[95:64]!==1 || caps[63:48]!==16'h0002)
            $fatal(1,"valid SNAPSHOT_READ changed sequence or raised fault");

        // Refresh returns while the eight-word CAPS response is in flight.
        // The response must remain the header-edge snapshot, including BUSY.
        sys_half=40;
        write_cmd(16'h0081,0,0);
        read_caps(caps);
        if(caps[48]!==1'b1 || caps[95:64]!==1 || caps[127:96]!==1)
            $fatal(1,"CAPS response tore during asynchronous status return: %h",caps);
        sys_half=7; wait_idle(); read_caps(caps);
        if(caps[48]!==1'b0 || caps[95:64]!==2 || caps[127:96]!==2 || caps[49]!==1'b1)
            $fatal(1,"second STATUS_REFRESH did not publish a fresh snapshot: %h",caps);

        // A valid packet reaches the shared stream only after its whole payload.
        payload=0;
        payload[7:0]=1; payload[23:8]=1; payload[39:24]=1;
        count_begin(); write_cmd(16'h0082,5,payload); // ARM: one frame, one event, reset requested
        wait_idle();
        count_end(1,5);
        if(cab_state!==3'd1 || cab_error!==8'd0)
            $fatal(1,"read-only CAB observation missed ARMED: state=%0d error=%0d",cab_state,cab_error);
        payload=0;
        payload[31:16]=1; payload[52:32]=1; payload[53]=1; payload[95:64]=32'h12345678;
        count_begin(); write_cmd(16'h0086,12,payload); // PUSH_DIP: frame-zero input and DIP override
        wait_idle();
        count_end(1,12);
        count_begin(); write_cmd(16'h0084,0,0);
        wait_idle();
        count_end(1,0);
        repeat(10) @(negedge clk_sys);
        if(cab_hold_reset!==1'b1 || cab_inputs!==0) $fatal(1,"controls changed before frame boundary");
        if(game_rst!==1'b1) $fatal(1,"framework reset did not assert for armed CAB playback");
        frame_start_seen=0; frame_start_while_reset=0;
        native_frame();
        if(cab_hold_reset!==1'b0 || cab_inputs!==1 || cab_dipsw_valid!==1'b1 || cab_dipsw!==32'h12345678 ||
           frame_start_seen!==1'b1 || frame_index_seen!==0 || frame_start_while_reset!==1'b1 ||
           cab_state!==3'd2 || cab_error!==8'd0)
            $fatal(1,"frame-zero mismatch hold=%b inputs=%h seen=%b idx=%d active=%b state=%d err=%d accepted=%d queued=%d seq=%d fault=%d",cab_hold_reset,cab_inputs,frame_start_seen,frame_index_seen,cab_active,dut.u_cab_stream.state,dut.u_cab_stream.error,dut.u_cab_stream.accepted,dut.u_cab_stream.queued,dut.completed_seq,dut.fault_code);
        timeout=0;
        while(game_rst===1'b1 && timeout<80) begin @(negedge clk_rom); timeout=timeout+1; end
        if(game_rst!==1'b0 || cab_inputs!==1 || cab_dipsw_valid!==1'b1 || cab_dipsw!==32'h12345678)
            $fatal(1,"frame-zero controls/DIP not stable before game reset release");
        native_frame();
        if(cab_active!==1'b0 || cab_frame!==1 || cab_frame_start!==1'b0 || cab_state!==3'd3)
            $fatal(1,"terminal tick must complete without starting frame 1");

        // Full 16-bit IDs prevent accidental aliasing with a recognized command.
        write_cmd(16'h0182,9,payload);
        read_caps(caps);
        if(caps[95:64]!==5 || caps[63:48]!==0)
            $fatal(1,"0182 alias intercepted or altered state caps=%h",caps);

        payload=0; payload[54]=1; // Reserved PUSH_DIP flag is unsupported
        write_cmd(16'h0086,12,payload); wait_idle(); read_caps(caps);
        if(caps[95:64]!==6 || caps[63:48]!==16'h0704)
            $fatal(1,"reserved PUSH_DIP flags were not rejected with BAD_EVENT: %h",caps[63:48]);

        write_valid_arm(); wait_idle(); read_caps(caps);
        if(caps[63:48]!==0 || caps[95:64]!==7 || cab_state!==3'd1)
            $fatal(1,"valid ARM did not clear fault and restore ARMED state caps=%h state=%d stream_err=%d",caps,cab_state,dut.u_cab_stream.error);

        write_bad_arm_word(); wait_idle(); read_caps(caps);
        if(caps[63:48]!==16'h0504 || caps[95:64]!==8)
            $fatal(1,"high payload byte was not rejected with BAD_WORD: %h",caps[63:48]);

        write_valid_arm(); wait_idle(); read_caps(caps);
        if(caps[63:48]!==0 || caps[95:64]!==9 || cab_state!==3'd1)
            $fatal(1,"ARM did not recover from BAD_WORD");

        // Incomplete ARM is rejected before the stream sees any ARM byte.
        payload=0; payload[7:0]=1; payload[23:8]=3; payload[39:24]=1;
        write_partial(16'h0082,4,payload); wait_idle(); read_caps(caps);
        if(caps[63:48]!==16'h0104 || caps[95:64]!==10 || cab_active!==1'b0)
            $fatal(1,"truncated ARM had side effects or wrong fault: %h",caps[63:48]);

        write_valid_arm(); wait_idle(); read_caps(caps);
        if(caps[63:48]!==0 || caps[95:64]!==11 || cab_state!==3'd1)
            $fatal(1,"ARM did not recover from truncated ARM");

        // Incomplete PUSH and an overlong PUSH must not enqueue a partial event.
        payload=0; payload[31:16]=4;
        write_partial(16'h0083,7,payload); wait_idle(); read_caps(caps);
        if(caps[63:48]!==16'h0104 || caps[95:64]!==12 || dut.u_cab_stream.accepted!==0)
            $fatal(1,"truncated PUSH changed stream state: %h",caps[63:48]);

        write_valid_arm(); wait_idle(); read_caps(caps);
        if(caps[63:48]!==0 || caps[95:64]!==13 || cab_state!==3'd1)
            $fatal(1,"ARM did not recover from truncated PUSH");

        payload=0; payload[31:16]=5; payload[95:64]=1;
        write_cmd(16'h0083,9,payload); wait_idle(); read_caps(caps);
        if(caps[63:48]!==16'h0104 || caps[95:64]!==14 || dut.u_cab_stream.accepted!==0)
            $fatal(1,"overlong PUSH changed stream state: %h",caps[63:48]);

        // Freeze clk_sys to keep the first command's mailbox stable, then
        // submit a second command. It must fail closed without allocating seq.
        write_valid_arm(); wait_idle(); read_caps(caps);
        if(caps[95:64]!==15 || cab_state!==3'd1)
            $fatal(1,"ARM did not recover from overlong PUSH");
        sys_clk_en=0; repeat(4) @(negedge clk_rom);
        write_valid_arm();
        repeat(3) @(negedge clk_rom);
        write_cmd(16'h0085,0,0);
        sys_clk_en=1; wait_idle(); read_caps(caps);
        if(caps[63:48]!==16'h0304 || caps[95:64]!==16 || cab_active!==1'b0)
            $fatal(1,"BUSY overrun replaced in-flight command or allocated a sequence: %h",caps[63:48]);

        // Reset in the middle of a payload discards the uncompleted packet.
        start_tx(); transfer(16'h0082,response,response_valid);
        transfer(16'h0001,response,response_valid); transfer(16'h0000,response,response_valid);
        transfer(16'h0000,response,response_valid); transfer(16'h0000,response,response_valid);
        @(negedge clk_rom); pll_locked=0; repeat(4) @(negedge clk_rom);
        end_tx(); pll_locked=1; wait(!rst); repeat(8) @(negedge clk_rom);
        read_caps(caps);
        if(caps[63:48]!==0 || caps[95:64]!==0 || caps[127:96]!==0 || cab_active!==1'b0)
            $fatal(1,"reset during upload retained bridge or CAB state: %h",caps);

        // Commit a fresh status, then reset with its replacement request in
        // flight. Reset must clear its prior cache and all sequence numbers.
        write_cmd(16'h0081,0,0); wait_idle(); read_caps(caps);
        if(caps[95:64]!==1 || caps[127:96]!==1 || caps[49]!==1'b1)
            $fatal(1,"post-reset STATUS_REFRESH did not become fresh");
        sys_clk_en=0; repeat(4) @(negedge clk_rom); write_cmd(16'h0081,0,0);
        repeat(3) @(negedge clk_rom); pll_locked=0; repeat(4) @(negedge clk_rom);
        pll_locked=1; sys_clk_en=1; wait(!rst); repeat(8) @(negedge clk_rom);
        read_caps(caps);
        if(caps[63:48]!==0 || caps[95:64]!==0 || caps[127:96]!==0 || cab_active!==1'b0)
            $fatal(1,"reset during mailbox/snapshot retained stale state: %h",caps);

        // The invalid-read decision is atomic even when an asynchronous
        // STATUS completion publishes a snapshot during the 32-byte read.
        sys_clk_en=0; repeat(4) @(negedge clk_rom);
        write_cmd(16'h0081,0,0);
        read_invalid_snapshot_while_status_completes(status_bytes);
        if(status_bytes!==0)
            $fatal(1,"invalid SNAPSHOT_READ changed after asynchronous completion: %h",status_bytes);
        wait_idle(); read_caps(caps);
        if(caps[63:48]!==16'h0606 || caps[95:64]!==1 || caps[127:96]!==1)
            $fatal(1,"invalid SNAPSHOT_READ completion did not preserve its fault/sequence: %h",caps);

        // V2 ARM carries 5 data bytes. Exercise totals on both sides of the
        // 8-bit and 9-bit boundaries before the long playback.
        write_arm_count(15'd255);
        if(cab_state!==3'd1 || dut.u_cab_stream.total_events!==15'd255)
            $fatal(1,"255-event ARM decode mismatch: state=%0d events=%0d",cab_state,dut.u_cab_stream.total_events);
        write_cmd(16'h0085,0,0); wait_idle();
        write_arm_count(15'd256);
        if(cab_state!==3'd1 || dut.u_cab_stream.total_events!==15'd256)
            $fatal(1,"256-event ARM decode mismatch: state=%0d events=%0d",cab_state,dut.u_cab_stream.total_events);
        write_cmd(16'h0085,0,0); wait_idle();
        write_arm_count(15'd512);
        if(cab_state!==3'd1 || dut.u_cab_stream.total_events!==15'd512)
            $fatal(1,"512-event ARM decode mismatch: state=%0d events=%0d",cab_state,dut.u_cab_stream.total_events);
        write_cmd(16'h0085,0,0); wait_idle();
        payload=0; payload[23:8]=15'd255; payload[38:24]=15'd256;
        write_cmd(16'h0082,5,payload); wait_idle(); read_caps(caps);
        if(cab_state!==3'd0 || cab_error!==0 || caps[63:56]!==8'd1)
            $fatal(1,"events beyond total_frames were not rejected cleanly: state=%0d stream_error=%0d bridge_fault=%0d",
                cab_state,cab_error,caps[63:56]);

        // Replay 300 one-frame records through CAB, checking every input and
        // native-frame index as well as the final event/frame tallies.
        write_arm_count(15'd300);
        if(cab_state!==3'd1 || dut.u_cab_stream.total_events!==15'd300)
            $fatal(1,"300-event ARM was not accepted: state=%0d events=%0d bridge_fault=%0d",
                cab_state,dut.u_cab_stream.total_events,dut.fault_code);
        payload=0; payload[30:16]=1;
        write_cmd(16'h0083,8,payload); wait_idle();
        write_cmd(16'h0084,0,0); wait_idle(); native_frame();
        if(cab_state!==3'd2 || cab_frame_index!==0 || cab_inputs!==0)
            $fatal(1,"300-event frame zero mismatch: state=%0d index=%0d inputs=%h",cab_state,cab_frame_index,cab_inputs);
        for(i=1;i<300;i=i+1) begin
            payload=0; payload[15:0]=i; payload[30:16]=1; payload[52:32]=i;
            write_cmd(16'h0083,8,payload); wait_idle(); native_frame();
            if(i<299 && (cab_state!==3'd2 || cab_frame_index!==i || cab_inputs!==i))
                $fatal(1,"300-event frame/input mismatch at %0d: state=%0d index=%0d inputs=%h",i,cab_state,cab_frame_index,cab_inputs);
        end
        native_frame();
        if(cab_state!==3'd3 || dut.u_cab_stream.total_events!==15'd300 ||
           dut.u_cab_stream.accepted!==15'd300 || dut.u_cab_stream.applied!==15'd300 ||
           dut.u_cab_stream.frames!==15'd300 || cab_error!==0 || cab_inputs!==0 || cab_frame!==15'd300)
            $fatal(1,"300-event playback incomplete: state=%0d error=%0d total=%0d accepted=%0d applied=%0d frames=%0d",
                cab_state,cab_error,dut.u_cab_stream.total_events,dut.u_cab_stream.accepted,
                dut.u_cab_stream.applied,dut.u_cab_stream.frames);

        // V2 DIP override is scoped to its playback session; OSD fallback
        // must resume immediately on STOP and after natural DONE.
        payload=0; payload[23:8]=2; payload[38:24]=1;
        write_cmd(16'h0082,5,payload); wait_idle();
        payload=0; payload[30:16]=2; payload[52:32]=1; payload[53]=1;
        payload[95:64]=32'h12345678;
        write_cmd(16'h0086,12,payload); wait_idle();
        write_cmd(16'h0084,0,0); wait_idle(); native_frame();
        if(!cab_dipsw_valid || cab_dipsw!==32'h12345678 || cab_inputs!==1)
            $fatal(1,"V2 frame-zero DIP override was not active");
        write_cmd(16'h0085,0,0); wait_idle();
        if(cab_dipsw_valid || cab_state!==3'd0 || cab_inputs!==0)
            $fatal(1,"V2 STOP retained the DIP override or non-neutral inputs");

        payload=0; payload[23:8]=2; payload[38:24]=1;
        write_cmd(16'h0082,5,payload); wait_idle();
        payload=0; payload[30:16]=2; payload[52:32]=1; payload[53]=1;
        payload[95:64]=32'h89abcdef;
        write_cmd(16'h0086,12,payload); wait_idle();
        write_cmd(16'h0084,0,0); wait_idle(); native_frame();
        if(!cab_dipsw_valid || cab_dipsw!==32'h89abcdef)
            $fatal(1,"V2 DONE test did not install its DIP override");
        native_frame(); native_frame();
        if(cab_state!==3'd3 || cab_dipsw_valid || cab_inputs!==0)
            $fatal(1,"V2 DONE retained the DIP override or non-neutral inputs");

        $display("PASS: MiSTer CAB bridge transport, status and frame boundary");
        $finish;
    end
initial begin #5000000; $fatal(1,"timeout"); end
endmodule
