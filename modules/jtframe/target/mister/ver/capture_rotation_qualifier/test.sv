`timescale 1ns/1ps
module test;
    reg clk=0;
    wire [63:0] status;
    reg [63:0] hps_status_drive=0;
    tri [48:0] HPS_BUS;
    wire [1:0] rotate;
    wire cap_video_ok = uut.g_capture.cap_video_ok;
    wire [7:0] scan2x_r,scan2x_g,scan2x_b;
    wire scan2x_hs,scan2x_vs,scan2x_clk,scan2x_cen,scan2x_de;
    wire [1:0] scan2x_sl;
    wire FB_EN, DDRAM_WE;
    integer i;
    reg [1:0] rotate_drive;
    reg flip_drive;
    reg vs_drive;
    reg forced_scan;
    reg [21:0] gamma_drive;

    always #5 clk=~clk;
    assign HPS_BUS[48:38]=11'd0;
    assign HPS_BUS[35:32]=4'd0;
    assign HPS_BUS[31:16]=16'd0;

    jtframe_mister uut(
        .clk_sys(clk), .clk_rom(clk), .clk_pico(clk), .pll_locked(1'b1),
        .status(status), .HPS_BUS(HPS_BUS), .rst_req(1'b0),
        .rotate(rotate),
        .scan2x_r(scan2x_r),.scan2x_g(scan2x_g),.scan2x_b(scan2x_b),
        .scan2x_hs(scan2x_hs),.scan2x_vs(scan2x_vs),.scan2x_clk(scan2x_clk),
        .scan2x_cen(scan2x_cen),.scan2x_de(scan2x_de),.scan2x_sl(scan2x_sl),
        .FB_EN(FB_EN),.DDRAM_WE(DDRAM_WE)
    );

    task tick(input integer n);
        repeat(n) begin @(posedge clk); #1; end
    endtask

    task frame_rise;
    begin
        force uut.scan2x_cen=1'b1;
        force uut.scan2x_de=1'b1;
        force uut.scan2x_vs=1'b0;
        tick(2);
        force uut.scan2x_vs=1'b1;
        tick(2);
        force uut.scan2x_vs=1'b0;
        tick(2);
    end
    endtask

    task settle_frames;
        integer n;
    begin
        for(n=0;n<3;n=n+1) frame_rise();
        tick(3);
    end
    endtask

    task check_case(input [1:0] rot,input flip,input expected_ok,input expected_fb);
    begin
        @(negedge clk);
        force uut.rotate=rot;
        force uut.framebuf_flip=flip;
        hps_status_drive=0;
        force uut.hps_status_full=hps_status_drive;
        force uut.force_scan2x=1'b0;
        force uut.gamma_bus=22'd0;
        settle_frames();
        if(cap_video_ok!==expected_ok)
            $fatal(1,"CAP_VIDEO_OK rotate=%b flip=%b got %b expected %b",rot,flip,cap_video_ok,expected_ok);
        if(FB_EN!==expected_fb)
            $fatal(1,"real screen_rotate FB_EN rotate=%b flip=%b got %b expected %b",rot,flip,FB_EN,expected_fb);
        if(uut.rot_we!==expected_fb)
            $fatal(1,"real screen_rotate rot_we rotate=%b flip=%b got %b expected %b",rot,flip,uut.rot_we,expected_fb);
    end
    endtask

    task check_rejected_gate(input integer gate_id);
    begin
        @(negedge clk);
        force uut.rotate=2'b10;
        force uut.framebuf_flip=1'b0;
        force uut.force_scan2x=1'b0;
        force uut.gamma_bus=22'd0;
        hps_status_drive=0;
        force uut.hps_status_full=hps_status_drive;
        case(gate_id)
            0: hps_status_drive[5:3]=3'b001;
            1: force uut.force_scan2x=1'b1;
            2: force uut.gamma_bus=22'h80000;
            default: $fatal(1,"bad gate id");
        endcase
        settle_frames();
        if(cap_video_ok!==1'b0) $fatal(1,"upstream gate %0d failed to reject capture",gate_id);
        if(FB_EN!==1'b0 || DDRAM_WE!==1'b0)
            $fatal(1,"upstream mode gate unexpectedly enabled real framebuffer writer");
    end
    endtask

    initial begin
        force uut.hps_status_full=hps_status_drive;
        force uut.rotate=2'b00;
        force uut.framebuf_flip=1'b0;
        force uut.scan2x_cen=1'b1;
        force uut.scan2x_de=1'b1;
        force uut.scan2x_vs=1'b0;
        force uut.force_scan2x=1'b0;
        force uut.gamma_bus=22'd0;
        tick(5);
        check_case(2'b00,1'b0,1'b1,1'b0);
        check_case(2'b10,1'b0,1'b1,1'b0);
        check_case(2'b01,1'b0,1'b0,1'b1);
        check_case(2'b11,1'b0,1'b0,1'b1);
        check_case(2'b00,1'b1,1'b0,1'b1);
        check_case(2'b10,1'b1,1'b0,1'b1);
        check_rejected_gate(0);
        check_rejected_gate(1);
        check_rejected_gate(2);
        $display("PASS: actual jtframe_mister qualifier and real screen_rotate native-direction truth table");
        $finish;
    end
endmodule
