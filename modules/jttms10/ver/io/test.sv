`timescale 1ns/1ps
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, vclk_cen=0, hcs_n=0, hsync_n=1, vsync_n=1;
    reg lint1_n=1, lint2_n=1, word_req=0, word_we=0, word_ack=0;
    reg [31:0] word_addr=0;
    reg [15:0] word_wdata=0;
    reg nmi_clear=0, wvp_set=0, screen_ack=0;
    reg host_req=0,host_we=0,host_mem_ack=0;
    reg [1:0] host_reg=0,host_be=0;
    reg [15:0] host_wdata=0,host_mem_rdata=0;
    wire [15:0] host_rdata,host_mem_wdata,host_mem_io_rdata;
    wire [31:0] host_mem_addr;
    wire host_ack,host_busy,host_mem_req,host_mem_we,host_mem_is_io;
    wire is_io, irq_pending, nmi_pending, nmi_nmim, halt, hint_n;
    wire [15:0] io_rdata, psize, convsp, convdp, control, pmask;
    wire pixel_srt;
    wire [15:0] intenb, intpend, hstctlh, hcount, vcount, dpyadr, refcnt;
    wire [31:0] irq_vector;
    wire hs,vs,hblank,vblank,blank,screen_req,screen_org,refresh_req,refresh_cbr;
    wire [13:0] screen_srfaddr;
    wire [15:0] screen_dpytap;
    wire [7:0] refresh_row;
    jttms10_io #(.CLKS_PER_STATE(8)) dut(.*);

    task tick;
        begin @(posedge clk); #1; end
    endtask
    task write_io(input [4:0] regno,input [15:0] data);
        begin
            @(negedge clk);
            word_addr=32'hc0000000 | {23'd0,regno,4'd0};
            word_wdata=data; word_req=1; word_we=1; word_ack=1;
            tick();
            @(negedge clk); word_req=0; word_we=0; word_ack=0;
        end
    endtask
    task read_check(input [4:0] regno,input [15:0] expected);
        begin
            word_addr=32'hc0000000 | {23'd0,regno,4'd0};
            #1;
            if (io_rdata!==expected)
                $fatal(1,"I/O %02x: expected %04x got %04x",regno,expected,io_rdata);
        end
    endtask
    task video_tick;
        begin
            @(negedge clk); vclk_cen=1;
            tick();
            @(negedge clk); vclk_cen=0;
        end
    endtask
    initial begin
        tick(); @(negedge clk); rst=0;
        if (halt!==0) $fatal(1,"HCS low must self bootstrap");
        write_io(5'h08,16'hffff); read_check(5'h08,16'hfffd);
        write_io(5'h0b,16'hffff); read_check(5'h0b,16'hfffc);
        write_io(5'h11,16'hffff); read_check(5'h11,16'h0e06);
        write_io(5'h1b,16'hffff); read_check(5'h1b,16'h3fff);
        write_io(5'h17,16'hcafe); read_check(5'h17,16'h0000);
        write_io(5'h0d,16'hffff); read_check(5'h0d,16'hfff0);
        write_io(5'h0f,16'hffff); read_check(5'h0f,16'h00f0);
        if (hint_n!==0) $fatal(1,"INTOUT set by CPU");
        write_io(5'h0f,16'h0000); read_check(5'h0f,16'h0080);
        write_io(5'h10,16'hffff); read_check(5'h10,16'hfb00);
        if (!halt || !nmi_pending || !nmi_nmim) $fatal(1,"HSTCTLH taps");
        nmi_clear=1; tick(); nmi_clear=0;
        if (nmi_pending) $fatal(1,"NMI auto clear");
        write_io(5'h10,16'h0000);
        write_io(5'h1c,16'h1234); read_check(5'h1c,16'h1234);
        write_io(5'h1d,16'h4321); read_check(5'h1d,16'h4321);
        write_io(5'h1e,16'h2800); read_check(5'h1e,16'h2800);
        // No VCLK pulse occurred during these completed live writes.
        if (hcount!==16'h1234 || vcount!==16'h4321 || dpyadr!==16'h2800)
            $fatal(1,"off-VCLK live write lost");
        lint1_n=0; repeat (20) tick();
        if (!intpend[1] || !irq_pending || irq_vector!==32'hffff_ffc0)
            $fatal(1,"external interrupt level/vector");
        lint1_n=1; repeat (20) tick();
        if (intpend[1]) $fatal(1,"external interrupt must follow level");
        wvp_set=1; tick(); wvp_set=0;
        if (!intpend[11] || irq_vector!==32'hffff_fe80)
            $fatal(1,"WVP set/vector");
        write_io(5'h12,16'hffff);
        if (!intpend[11]) $fatal(1,"write 1 retains WVP");
        write_io(5'h12,16'h0000);
        if (intpend[11]) $fatal(1,"write 0 clears WVP");
        @(negedge clk);
        word_addr=32'hc0000120; word_wdata=0;
        word_req=1; word_we=1; word_ack=1; wvp_set=1;
        tick();
        if (!intpend[11]) $fatal(1,"hardware set must win write-zero clear");
        @(negedge clk); word_req=0; word_we=0; word_ack=0; wvp_set=0;
        // Reinitialize timing and display. ORG=0: stored address decrements;
        // NARC inverts the raw SRFADR on the screen-refresh bus.
        @(negedge clk); rst=1; tick(); @(negedge clk); rst=0;
        write_io(5'h01,16'd0); // HEBLNK
        write_io(5'h02,16'd1); // HSBLNK
        write_io(5'h03,16'd3); // HTOTAL
        write_io(5'h05,16'd0); // VEBLNK
        write_io(5'h06,16'd3); // VSBLNK
        write_io(5'h07,16'd4); // VTOTAL
        write_io(5'h09,16'h2800); // DPYSTRT raw SRFADR=A00
        write_io(5'h1b,16'h00a5);
        write_io(5'h1e,16'h2800);
        write_io(5'h08,16'hf004); // ENV/NIL/DXV/SRE, DUDATE=1, ORG=0
        video_tick(); video_tick();
        if (!screen_req || screen_srfaddr!==14'h0a00 ||
            screen_dpytap!==16'h00a5 || screen_org!==0)
            $fatal(1,"screen request payload/hold");
        tick(); tick();
        if (!screen_req || dpyadr!==16'h2800)
            $fatal(1,"screen request changed before ack");
        @(negedge clk); screen_ack=1; tick();
        if (screen_req || dpyadr!==16'h27fc)
            $fatal(1,"off-VCLK screen ack/address update");
        tick();
        if (dpyadr!==16'h27fc) $fatal(1,"held ack duplicated transfer");
        if (((~screen_srfaddr)&14'h3fff)!==14'h35ff)
            $fatal(1,"ORG=0 NARC pin inversion");
        @(negedge clk); screen_ack=0;
        // A fresh DIP pulse sets the latch despite ENV and VCLK partitioning.
        tick();
        if (!intpend[10]) $fatal(1,"video DIP latch");
        write_io(5'h12,16'h0000);
        if (intpend[10]) $fatal(1,"DIP write-zero clear");
        write_io(5'h0b,16'h0018); // disable refresh
        write_io(5'h1f,16'h010c);
        read_check(5'h1f,16'h010c);
        repeat (8) tick();
        read_check(5'h1f,16'h010c);
        write_io(5'h0b,16'h0008); // RR=01: subtract one unit per state
        repeat (8) tick();
        read_check(5'h1f,16'h0108);
        @(negedge clk); rst=1; hcs_n=1; tick(); @(negedge clk); rst=0;
        if (!halt) $fatal(1,"HCS high must set reset HLT");
        write_io(5'h1e,16'h2800);
        write_io(5'h08,16'hf404); // same timing but ORG=1
        write_io(5'h01,16'd0); write_io(5'h02,16'd1);
        write_io(5'h03,16'd3); write_io(5'h05,16'd0);
        write_io(5'h06,16'd3); write_io(5'h07,16'd4);
        video_tick(); video_tick();
        if (!screen_req || !screen_org || screen_srfaddr!==14'h0a00)
            $fatal(1,"ORG=1 raw screen address");
        @(negedge clk); screen_ack=1; tick();
        if (dpyadr!==16'h27fc) $fatal(1,"ORG=1 stored decrement");
        $display("jttms10_io PASS"); $finish;
    end
endmodule
