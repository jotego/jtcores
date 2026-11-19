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

    force uut.reset_req = 1'b0;
    force uut.CAP_IO_RST = 1'b0;
    force uut.CAP_TAG_RST = 1'b0;
    #1;
    check(uut.ascal_reset_na === 1'b1,
          "capture endpoints and ascal start from a deasserted common reset");
`ifdef JTFRAME_REGRESSION
`ifndef MISTER_DEBUG_NOHDMI
`ifndef JTFRAME_CRT480I
`ifndef JTFRAME_INTERLACED
    check(uut.ascal.capture_generic_enabled === 1'b1,
          "enabled full-HDMI build sets the actual ascal CAPTURE generic");
    force uut.CAP_IO_RST = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b0,
          "capture IO reset asserts the ascal capture/controller reset");
    check(uut.vbuf_user_reset === 1'b1,
          "capture IO reset notifies the VBUF safe terminator");
    force uut.CAP_IO_RST = 1'b0;
    force uut.CAP_TAG_RST = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b0,
          "capture tag reset asserts the ascal capture/controller reset");
    check(uut.vbuf_user_reset === 1'b1,
          "capture tag reset notifies the VBUF safe terminator");
`else
    check(uut.ascal.capture_generic_enabled === 1'b0,
          "interlaced capture remains disabled in the actual ascal generic");
    force uut.CAP_TAG_RST = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b1,
          "interlaced build keeps capture reset unavailable");
    check(uut.vbuf_user_reset === 1'b0,
          "interlaced build keeps VBUF terminator on the legacy reset path");
`endif
`else
    check(uut.ascal.capture_generic_enabled === 1'b0,
          "CRT480I capture remains disabled in the actual ascal generic");
    force uut.CAP_TAG_RST = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b1,
          "CRT480I build keeps capture reset unavailable");
    check(uut.vbuf_user_reset === 1'b0,
          "CRT480I build keeps VBUF terminator on the legacy reset path");
`endif
`else
    force uut.CAP_IO_RST = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b1,
          "NOHDMI build keeps capture reset unavailable");
    check(uut.vbuf_user_reset === 1'b0,
          "NOHDMI build keeps VBUF terminator on the legacy reset path");
`endif
`else
`ifndef MISTER_DEBUG_NOHDMI
    check(uut.ascal.capture_generic_enabled === 1'b0,
          "explicitly disabled full-HDMI build sets CAPTURE false");
`endif
    force uut.CAP_IO_RST = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b1,
          "regression-disabled build keeps capture reset unavailable");
    check(uut.vbuf_user_reset === 1'b0,
          "regression-disabled build keeps VBUF terminator on the legacy reset path");
`endif
    force uut.CAP_IO_RST = 1'b0;
    force uut.CAP_TAG_RST = 1'b0;
    force uut.reset_req = 1'b1;
    #1;
    check(uut.ascal_reset_na === 1'b0,
          "system reset asserts the ascal and capture endpoint reset");
    check(uut.vbuf_user_reset === 1'b0,
          "VBUF-only reset does not feed back into global reset request");
    force uut.reset_req = 1'b0;
    #1;
    release uut.reset_req;
    release uut.CAP_IO_RST;
    release uut.CAP_TAG_RST;

`ifdef JTFRAME_REGRESSION
`ifndef MISTER_DEBUG_NOHDMI
`ifndef JTFRAME_CRT480I
`ifndef JTFRAME_INTERLACED
        force uut.CAP_VIDEO_OK = 1'b1;
        force uut.direct_video = 1'b0;
        force uut.lowlat = 1'b0;
        force uut.FB_EN = 1'b0;
        #1;
        check(uut.cap_mode_supported === 1'b1,
              "native wrapper qualification reaches ascal with all downstream mode gates clear");
        force uut.direct_video = 1'b1;
        #1;
        check(uut.cap_mode_supported === 1'b0,
              "direct-video mode excludes native capture");
        force uut.direct_video = 1'b0;
        force uut.lowlat = 1'b1;
        #1;
        check(uut.cap_mode_supported === 1'b0,
              "low-latency mode excludes native capture");
        force uut.lowlat = 1'b0;
        force uut.FB_EN = 1'b1;
        #1;
        check(uut.cap_mode_supported === 1'b0,
              "framebuffer mode excludes native capture");
        release uut.CAP_VIDEO_OK;
        release uut.direct_video;
        release uut.lowlat;
        release uut.FB_EN;
`endif
`endif
`endif
`endif

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
