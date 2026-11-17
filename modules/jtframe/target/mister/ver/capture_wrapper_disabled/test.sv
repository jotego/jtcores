`timescale 1ns/1ps

module test;
    reg clk=0;
    reg io_strobe=0, io_enable=0, fp_enable=0;
    reg [15:0] host_word=0;
    tri [48:0] HPS_BUS;
    wire [63:0] status;
    wire [9:0] game_joystick1;
    wire [26:0] ioctl_addr;
    wire [7:0] ioctl_dout;
    wire ioctl_wr;
    wire [31:0] dipsw;
    wire cap_io_clk, cap_tag_clk, cap_io_rst, cap_tag_rst, cap_video_ok;
    wire cap_req_toggle, cap_release_toggle, cap_abort_toggle, cap_life_toggle;
    wire [31:0] cap_req, cap_life;
    wire [15:0] cap_release, cap_abort, cap_tag;
    wire cap_tag_valid, cap_tag_error, cap_result_ack_toggle;
    reg [511:0] cap_result=0;
    reg cap_result_toggle=0;
    reg cap_req_ack_toggle=0, cap_release_ack_toggle=0, cap_abort_ack_toggle=0;
    reg cap_life_ack_toggle=0, cap_tag_ready=0;
    reg [7:0] cap_state=0, cap_fault=0;
    integer i, write_count=0;
    reg [26:0] write_addr[0:3];
    reg [7:0] write_data[0:3];
    reg [15:0] response_word;

    always #5 clk=~clk;
    assign HPS_BUS[48:38]=11'd0;
    assign HPS_BUS[35:33]={fp_enable,io_enable,io_strobe};
    assign HPS_BUS[31:16]=host_word;

    jtframe_mister uut(
        .clk_sys(clk), .clk_rom(clk), .clk_pico(clk), .pll_locked(1'b1),
        .status(status), .HPS_BUS(HPS_BUS), .game_joystick1(game_joystick1),
        .ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_dout), .ioctl_wr(ioctl_wr), .dipsw(dipsw),
        .rst_req(1'b0), .cap_system_reset(1'b0),
        .cap_io_clk(cap_io_clk), .cap_tag_clk(cap_tag_clk), .cap_io_rst(cap_io_rst), .cap_tag_rst(cap_tag_rst),
        .cap_video_ok(cap_video_ok), .cap_req_toggle(cap_req_toggle), .cap_req(cap_req),
        .cap_req_ack_toggle(cap_req_ack_toggle), .cap_release_toggle(cap_release_toggle), .cap_release(cap_release),
        .cap_release_ack_toggle(cap_release_ack_toggle), .cap_abort_toggle(cap_abort_toggle), .cap_abort(cap_abort),
        .cap_abort_ack_toggle(cap_abort_ack_toggle), .cap_life_toggle(cap_life_toggle), .cap_life(cap_life),
        .cap_life_ack_toggle(cap_life_ack_toggle), .cap_tag_valid(cap_tag_valid), .cap_tag(cap_tag),
        .cap_tag_ready(cap_tag_ready), .cap_tag_error(cap_tag_error), .cap_result_toggle(cap_result_toggle),
        .cap_result(cap_result), .cap_result_ack_toggle(cap_result_ack_toggle),
        .cap_state(cap_state), .cap_fault(cap_fault)
    );

    task tick(input integer count);
        repeat(count) begin @(posedge clk); #1; end
    endtask

    task send_word(input [15:0] value, output [15:0] sampled);
    begin
        @(negedge clk); host_word=value; io_strobe=1;
        @(posedge clk); #1; sampled=HPS_BUS[15:0];
        if($isunknown(sampled)) $fatal(1,"HPS response contains X/Z for host word %h",value);
        @(negedge clk); io_strobe=0;
    end
    endtask

    task begin_uio(input [15:0] command);
    begin
        @(negedge clk); fp_enable=0; io_enable=1;
        send_word(command,response_word);
    end
    endtask

    task end_packet;
    begin
        @(negedge clk); io_strobe=0; io_enable=0; fp_enable=0;
        tick(3);
    end
    endtask

    task check_unowned;
    begin
        if(uut.hps_ext_bus[32] !== 1'b0 || uut.cap_response_enable !== 1'b0 ||
           uut.cab_response_enable !== 1'b0)
            $fatal(1,"disabled wrapper claimed EXT_BUS response ownership");
        if(uut.cab_active !== 1'b0 || uut.cab_hold_reset !== 1'b0 ||
           uut.cab_inputs !== 21'd0 || uut.cab_dipsw_valid !== 1'b0 ||
           uut.cab_dipsw !== 32'd0 ||
           uut.cab_frame !== 15'd0 || uut.cab_frame_index !== 15'd0 ||
           uut.cab_frame_start !== 1'b0 || uut.cab_state !== 3'd0 || uut.cab_error !== 8'd0)
            $fatal(1,"disabled wrapper changed CAB controls, reset, DIPs, or tags");
        if(cap_io_clk !== 1'b0 || cap_tag_clk !== 1'b0 || cap_io_rst !== 1'b0 ||
           cap_tag_rst !== 1'b0 || cap_video_ok !== 1'b0 || cap_req_toggle !== 1'b0 ||
           cap_req !== 32'd0 || cap_release_toggle !== 1'b0 || cap_release !== 16'd0 ||
           cap_abort_toggle !== 1'b0 || cap_abort !== 16'd0 || cap_life_toggle !== 1'b0 ||
           cap_life !== 32'd0 || cap_tag_valid !== 1'b0 || cap_tag !== 15'd0 ||
           cap_tag_error !== 1'b0 || cap_result_ack_toggle !== 1'b0)
            $fatal(1,"disabled wrapper capture sideband was not neutral");
        if(status[0] !== uut.hps_status_full[0])
            $fatal(1,"CAB reset/input override leaked into ordinary status bit zero");
    end
    endtask

    task probe_local(input [15:0] command, input read_response);
        integer n;
        reg [15:0] sampled;
    begin
        begin_uio(command);
        for(n=0;n<8;n=n+1) begin
            send_word(read_response ? 16'd0 : (16'hA500+n),sampled);
            if(sampled===16'hCA4D || sampled===16'hCA50)
                $fatal(1,"disabled command %h returned capability magic",command);
            check_unowned();
        end
        end_packet();
        check_unowned();
    end
    endtask

    task ordinary_status_and_joystick;
        reg [15:0] sampled;
    begin
        begin_uio(16'h001e);
        send_word(16'h1122,sampled); send_word(16'h3344,sampled);
        send_word(16'h5566,sampled); send_word(16'h7788,sampled);
        end_packet();
        if(status!==64'h7788_5566_3344_1122)
            $fatal(1,"ordinary status path changed: %h",status);

        begin_uio(16'h0002);
        send_word(16'h0234,sampled);
        end_packet();
        if(game_joystick1!==10'h234)
            $fatal(1,"ordinary joystick input changed: %h",game_joystick1);
        check_unowned();
    end
    endtask

    task file_download(input [15:0] low_address, input [7:0] payload);
        reg [15:0] sampled;
        integer timeout;
    begin
        // Select ordinary ROM index zero, then start a byte download.
        @(negedge clk); fp_enable=1; io_enable=1;
        send_word(16'h0055,sampled); send_word(16'h0000,sampled); end_packet();

        @(negedge clk); fp_enable=1; io_enable=1;
        send_word(16'h0053,sampled); // transfer command
        send_word(16'h0001,sampled); // download, not upload
        send_word(low_address,sampled);
        send_word(16'h0001,sampled);
        end_packet();
        tick(3);
        if(uut.hps_download!==1'b1) $fatal(1,"ordinary HPS download did not start");

        write_count=0;
        @(negedge clk); fp_enable=1; io_enable=1;
        send_word(16'h0054,sampled);
        send_word({8'd0,payload},sampled);
        end_packet();
        for(timeout=0;timeout<8 && write_count==0;timeout=timeout+1) tick(1);
        if(write_count!=1 || write_addr[0]!=={11'd1,low_address} || write_data[0]!==payload)
            $fatal(1,"ordinary FPGA file byte/address path changed count=%0d addr=%h data=%h",
                   write_count,write_addr[0],write_data[0]);
        check_unowned();
        // Stop the transfer so the next epoch starts from a known HPS state.
        @(negedge clk); fp_enable=1; io_enable=1;
        send_word(16'h0053,sampled); send_word(16'h0000,sampled); end_packet();
    end
    endtask

    always @(posedge clk) begin
        if(ioctl_wr && write_count<4) begin
            write_addr[write_count] <= ioctl_addr;
            write_data[write_count] <= ioctl_dout;
            write_count <= write_count+1;
        end
    end

    initial begin
        tick(5);
        ordinary_status_and_joystick();
        file_download(16'h3456,8'hA7);

        for(i=0;i<8;i=i+1) probe_local(16'h0080+i,(i==0));
        for(i=0;i<5;i=i+1) probe_local(16'h0090+i,(i==0));
        probe_local(16'h0180,1'b1);
        probe_local(16'h0190,1'b1);

        ordinary_status_and_joystick();
        file_download(16'h4567,8'h5C);
        $display("PASS: disabled jtframe_mister wrapper leaves real hps_io commands and ordinary paths intact");
        $finish;
    end
endmodule
