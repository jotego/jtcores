`timescale 1ns/1ps

module test;
    reg clk_sys = 0;
    reg clk_audio = 0;
    reg vs = 0;
    always #5 clk_sys = ~clk_sys;
    always #7 clk_audio = ~clk_audio;

    sys_top uut();

    task check;
        input condition;
        input [8*120-1:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("FAIL: %0s", message);
                $fatal(1);
            end
            $display("PASS: %0s", message);
        end
    endtask

    task command;
        input [7:0] value;
        begin
            force uut.io_strobe = 1'b0;
            force uut.io_uio = 1'b0;
            @(posedge clk_sys); #1;
            force uut.io_uio = 1'b1;
            force uut.io_din = {8'h00, value};
            force uut.io_strobe = 1'b1;
            @(posedge clk_sys); #1;
            force uut.io_strobe = 1'b0;
            @(posedge clk_sys); #1;
        end
    endtask

    task pulse_vs;
        begin
            force uut.vs_fix = 1'b0;
            repeat (4) @(posedge clk_sys);
            force uut.vs_fix = 1'b1;
            repeat (4) @(posedge clk_sys);
            #1;
        end
    endtask

    initial begin
        force uut.clk_sys = clk_sys;
        force uut.clk_audio = clk_audio;
        force uut.vs_fix = 1'b0;
        uut.frame_cnt = 8'h00;
        force uut.av_dis = 1'b0;
        force uut.mcp_en = 1'b0;
        force uut.SW = 4'b0000;
        force uut.analog_l = 1'b0;
        force uut.analog_r = 1'b1;
        force uut.spdif = 1'b0;
        force uut.HDMI_SCLK = 1'b1;
        force uut.HDMI_I2S = 1'b0;
        force uut.HDMI_LRCLK = 1'b1;
        force uut.HDMI_TX_INT = 1'b0;

        repeat (3) @(posedge clk_audio);
        #1;
        check(uut.AUDIO_L === 1'b0 && uut.AUDIO_R === 1'b1 &&
              uut.AUDIO_SPDIF === 1'b0,
              "analog audio route is sampled on clk_audio");

        force uut.SW = 4'b0001;
        #1;
        check(uut.AUDIO_L === 1'b0 && uut.AUDIO_R === 1'b1,
              "audio route does not change between clk_audio edges");
        @(posedge clk_audio); #1;
        check(uut.AUDIO_L === 1'b1 && uut.AUDIO_R === 1'b0 &&
              uut.AUDIO_SPDIF === 1'b1,
              "HDMI audio route is sampled on clk_audio");

        force uut.av_dis = 1'b1;
        #1;
        check(uut.aud_l_q === 1'b1 && uut.aud_r_q === 1'b0 &&
              uut.AUDIO_L === 1'b0 && uut.AUDIO_R === 1'b0 &&
              uut.AUDIO_SPDIF === 1'b0,
              "av_dis gates audio output pins (Verilator models Z as 0)");
        force uut.av_dis = 1'b0;

        check(uut.gp_in[20] === 1'b1,
              "active low HDMI_TX_INT is reflected in gp_in[20]");
        force uut.HDMI_TX_INT = 1'b1;
        #1;
        check(uut.gp_in[20] === 1'b0,
              "inactive HDMI_TX_INT clears gp_in[20]");
        force uut.HDMI_TX_INT = 1'b0;

        repeat (4) @(posedge clk_sys);
        pulse_vs();
        check(uut.frame_cnt === 8'h01,
              "frame count increments once on a sampled VS rising edge");
        repeat (5) @(posedge clk_sys);
        check(uut.frame_cnt === 8'h01,
              "frame count does not repeat while VS stays high");

        command(8'h44);
        check(uut.io_dout_sys === 16'h0001,
              "command 0x44 reports HDMI interrupt capability");
        command(8'h42);
        check(uut.io_dout_sys === 16'h0101,
              "command 0x42 reports the frame count");

        uut.frame_cnt = 8'hff;
        pulse_vs();
        check(uut.frame_cnt === 8'h00,
              "frame count wraps at 8 bits");
        $display("sys_top_platform: PASS");
        $finish;
    end
endmodule
