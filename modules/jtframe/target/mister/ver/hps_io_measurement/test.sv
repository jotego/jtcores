`timescale 1ns/1ps

module test;
reg clk_sys=0, clk_vid=0, clk_100=0;
reg ce_pix=1, de=0, hs=0, vs=0, vs_hdmi=0, f1=0, new_vmode=0, video_rotated=0;
reg [4:0] par_num=0;
wire [15:0] dout;
reg [15:0] lo, hi;
reg [31:0] measured;
integer cycle_count=0, last_frame_edge=-1, actual_frame_period=0, frame_events=0;
reg previous_vs=0;
integer field_period_cfg=70003, pixel_div_cfg=1, field_pos=0;
reg interlaced_cfg=0, field_idx=0;
integer reference_count=0, last_reference_edge=-1, actual_reference_period=0;
reg previous_vs_reference=0;
reg io_enable=0, io_strobe=0, fp_enable=0;
reg [15:0] host_data=0;
tri [48:0] HPS_BUS;
tri [35:0] EXT_BUS;
tri [21:0] gamma_bus;
reg [15:0] hps_info[0:20];
reg [63:0] phase_base, phase_estimate, phase_expected, phase_error;
integer n;

always #7 clk_sys=~clk_sys;
always #4 clk_vid=~clk_vid;
always #5 clk_100=~clk_100;

always @(posedge clk_vid) begin
    cycle_count <= cycle_count+1;
    if(previous_vs && !vs && ce_pix && !f1) begin
        if(last_frame_edge>=0) begin
            actual_frame_period <= cycle_count-last_frame_edge;
        end
        last_frame_edge <= cycle_count;
        frame_events <= frame_events+1;
    end
    previous_vs <= vs;
end

always @(posedge clk_100) begin
    reference_count <= reference_count+1;
    if(previous_vs_reference && !vs && !f1) begin
        if(last_reference_edge>=0) actual_reference_period <= reference_count-last_reference_edge;
        last_reference_edge <= reference_count;
    end
    previous_vs_reference <= vs;
end

// Keep the source timing free-running while video-info words are sampled.
always @(negedge clk_vid) begin
    ce_pix <= field_pos % pixel_div_cfg == 0;
    hs <= (field_pos%80)<8;
    de <= (field_pos%80)>=16 && (field_pos%80)<24;
    if(field_pos==0) begin
        vs <= 1;
        f1 <= interlaced_cfg && field_idx;
    end
    if(field_pos==8) vs <= 0;
    if(field_pos==field_period_cfg-1) begin
        field_pos <= 0;
        field_idx <= interlaced_cfg ? ~field_idx : 1'b0;
    end else field_pos <= field_pos+1;
end

video_calc uut(
    .clk_100       ( clk_100        ),
    .clk_vid       ( clk_vid        ),
    .clk_sys       ( clk_sys        ),
    .ce_pix        ( ce_pix         ),
    .de            ( de             ),
    .hs            ( hs             ),
    .vs            ( vs             ),
    .vs_hdmi       ( vs_hdmi        ),
    .f1            ( f1             ),
    .new_vmode     ( new_vmode      ),
    .video_rotated ( video_rotated  ),
    .par_num       ( par_num        ),
    .dout          ( dout           )
);

assign HPS_BUS[48:38] = {3'd0,f1,vs_hdmi,clk_100,clk_vid,ce_pix,de,hs,vs};
assign HPS_BUS[35:33] = {fp_enable,io_enable,io_strobe};
assign HPS_BUS[31:16] = host_data;
assign EXT_BUS[32] = 0;

/* verilator lint_off PINMISSING */
hps_io #(.WIDE(0),.PS2DIV(0),.STRLEN(1),.CONF_STR_BRAM(0)) hps(
    .clk_sys        ( clk_sys       ),
    .HPS_BUS        ( HPS_BUS       ),
    .joy_raw        ( 16'd0         ),
    .gamma_bus      ( gamma_bus     ),
    .new_vmode      ( new_vmode     ),
    .video_rotated  ( video_rotated ),
    .ioctl_din      ( 8'd0          ),
    .ioctl_wait     ( 1'b0          ),
    .EXT_BUS        ( EXT_BUS       )
);
/* verilator lint_on PINMISSING */

task fail(input [8*112-1:0] message);
    $display("FAIL: %0s",message);
    $fatal(1);
endtask

task wait_frames(input integer count);
    integer target;
    begin
        target=frame_events+count;
        while(frame_events<target) @(posedge clk_vid);
    end
endtask

task send_host_word(input [15:0] value);
    begin
        @(negedge clk_sys);
        io_enable=1; host_data=value; io_strobe=1;
        @(negedge clk_sys); io_strobe=0;
        @(negedge clk_sys);
    end
endtask

task read_hps_video_info;
    begin
        send_host_word(16'h0023);
        if(HPS_BUS[15:0]!==16'd0) fail("video-info command zero reply changed");
        for(n=1;n<=20;n=n+1) begin
            send_host_word(16'd0);
            hps_info[n]=HPS_BUS[15:0];
        end
        @(negedge clk_sys); io_enable=0;
    end
endtask

task read_count(output [31:0] value);
    begin
        par_num=5'd19;
        @(posedge clk_sys); #1 lo=dout;
        @(negedge clk_sys); par_num=5'd20;
        @(posedge clk_sys); #1 hi=dout;
        value={hi[7:0],lo};
    end
endtask

task check_measurement(input [31:0] expected, input [8*112-1:0] name);
    begin
        read_count(measured);
        if(actual_frame_period!==expected) begin
            $display("%0s: expected driven boundary spacing %0d, measured %0d",
                name,expected,actual_frame_period);
            fail("video timing fixture boundary period mismatch");
        end
        if(measured!==expected) begin
            $display("%0s: expected %0d (0x%06x), got %0d (0x%06x)",
                name,expected,expected[23:0],measured,measured[23:0]);
            fail("full-frame clk_vid measurement mismatch");
        end
        if(hi[15:8]!==8'd0) fail("video-info word 20 reserved high byte changed");
    end
endtask

initial begin
    // At least three complete frames are needed to settle startup, detect the
    // initial timing and then measure a complete frame.
    wait_frames(4);
    check_measurement(70003,"progressive 70,003-cycle frame");

    // Once settled, the full-frame count must stay latched while timing holds.
    wait_frames(1);
    check_measurement(70003,"progressive held result");

    // Toggle the reported mode and use two interlace fields. Pixel enable is
    // half-rate, but the clock measurement must include every clk_vid edge.
    @(negedge clk_vid);
    new_vmode=1;
    interlaced_cfg=1; field_period_cfg=36002; pixel_div_cfg=2;
    wait_frames(3);
    check_measurement(72004,"interlaced two-field frame");

    // A further mode/timing change must invalidate the held count and remeasure.
    @(negedge clk_vid);
    new_vmode=0;
    field_period_cfg=40002;
    wait_frames(3);
    check_measurement(80004,"changed interlaced frame");

    // Exercise word 20's full high byte, including bits above the stale 21-bit
    // description, using independent video, system and 100 MHz reference clocks.
    @(negedge clk_vid);
    new_vmode=1;
    interlaced_cfg=0; field_period_cfg=2100003; pixel_div_cfg=1;
    wait_frames(3);
    check_measurement(2100003,"progressive count above bit 20");
    read_hps_video_info();
    read_count(measured);
    if(hps_info[19]!==measured[15:0] || hps_info[20][7:0]!==measured[23:16] ||
       hps_info[20][15:8]!==8'd0)
        fail("HPS command 0x23 must return the complete 24-bit count in words 19/20");
    if(hps_info[1]!=={video_rotated,|hps.video_calc.vid_int,hps.video_calc.vid_nres})
        fail("HPS video-info word 1 mapping changed");
    if(hps_info[2]!==hps.video_calc.vid_hcnt[15:0])
        fail("HPS video-info word 2 mapping changed");
    if(hps_info[18]!==hps.video_calc.vid_de_v)
        fail("HPS video-info word 18 mapping changed");
    if(hps_info[20][7:5]==0)
        fail("video-info word 20 did not preserve count bits above bit 20");

    // Convert the measured frame count against the independent 125 MHz
    // reference period and compare with the known 100 MHz input PHASE_INC.
    phase_base=(64'd4294967296*64'd3579545)/64'd100000000;
    phase_estimate=(phase_base*actual_reference_period+measured/2)/measured;
    phase_expected=(64'd4294967296*64'd3579545+64'd62500000)/64'd125000000;
    phase_error=phase_estimate>phase_expected ? phase_estimate-phase_expected : phase_expected-phase_estimate;
    if(phase_error>64) begin
        $display("phase estimate %0d expected %0d; ref edges %0d video edges %0d",
            phase_estimate,phase_expected,actual_reference_period,measured);
        fail("known-clock PHASE_INC calculation is outside tolerance");
    end

    par_num=0;
    @(posedge clk_sys); #1;
    if(dout!==16'd0) fail("default video-info word must remain zero");
    $display("PASS");
    $finish;
end

initial begin
    #120000000;
    fail("video clock measurement test timed out");
end
endmodule
