`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, hold_req=0, screen_req=0, screen_org=0;
    reg [13:0] screen_srfaddr=0;
    reg [15:0] screen_dpytap=0;
    reg refresh_req=0, refresh_cbr=0;
    reg [7:0] refresh_row=0;
    reg host_mem_req=0,host_mem_we=0,host_mem_is_io=0;
    reg [31:0] host_mem_addr=0;
    reg [15:0] host_mem_wdata=0,host_mem_io_rdata=0;
    wire [15:0] host_mem_rdata;
    wire host_mem_ack;
    reg word_req=0,word_we=0,word_iaq=0,word_lock=0,word_pixel=0;
    reg [31:0] word_addr=0;
    reg [15:0] word_wdata=0;
    reg is_io=0,pixel_srt=0;
    reg [15:0] io_rdata=0,cyc_rdata=0;
    reg cyc_ack=0;
    wire hold_ack,screen_ack,word_ack,word_restart,cyc_req,cyc_iaq,cyc_org;
    wire [15:0] word_rdata,cyc_wdata,cyc_io_rdata,cyc_dpytap;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [13:0] cyc_srfaddr;
    wire [7:0] cyc_dram_row;
    wire fetch_grid_ready;
    jttms10_bus dut(.*);
    task tick; begin @(posedge clk); #1; end endtask
    task wait_target;
        integer n;
        begin
            n=0;
            while (!cyc_req && n<64) begin tick(); n=n+1; end
            if (!cyc_req) $fatal(1,"target request timeout state=%0d phase=%0d addr=%0d ack=%b",
                                 dut.state,dut.phase_data,dut.phase_addr,cyc_ack);
        end
    endtask
    task reset_bus;
        begin
            @(negedge clk); rst=1; hold_req=0; screen_req=0;
            refresh_req=0; refresh_cbr=0;
            word_req=0; word_we=0; word_iaq=0; word_lock=0;
            word_pixel=0; is_io=0; pixel_srt=0; cyc_ack=0;
            tick(); @(negedge clk); rst=0;
        end
    endtask
    task complete_cycle;
        integer kind, n;
        begin
            wait_target();
            kind=32'(cyc_kind);
            @(negedge clk); cyc_ack=1; #1;
            if (!cyc_req) $fatal(1,"ack without active cycle");
            tick();
            if (cyc_req) $fatal(1,"target request must drop at ACK capture");
            @(negedge clk); cyc_ack=0;
            n=0;
            case (kind)
                0,1,5,6,7,8: begin
                    while (!word_ack && n<12) begin tick(); n=n+1; end
                    if (!word_ack) $fatal(1,"CPU response missing after target ACK");
                    tick();
                    if (word_ack) $fatal(1,"CPU response repeated");
                end
                2: begin
                    while (!screen_ack && n<12) begin tick(); n=n+1; end
                    if (!screen_ack) $fatal(1,"screen response missing after target ACK");
                    tick();
                    if (screen_ack) $fatal(1,"screen response repeated");
                end
                default: begin
                    repeat (4) tick();
                    if (word_ack || screen_ack || host_mem_ack)
                        $fatal(1,"DRAM cycle emitted a client response");
                end
            endcase
            if (cyc_req) $fatal(1,"target reissued before release boundary");
        end
    endtask
    task wait_screen_response;
        integer n;
        begin
            n=0;
            while (!screen_ack && n<12) begin tick(); n=n+1; end
            if (!screen_ack) $fatal(1,"screen response missing after target ACK");
        end
    endtask
    task wait_hold_ack;
        integer n;
        begin
            n=0;
            while (!hold_ack && n<12) begin tick(); n=n+1; end
            if (!hold_ack) $fatal(1,"HOLD acknowledgement timeout");
        end
    endtask
    initial begin
        tick(); @(negedge clk); rst=0;
        // Screen beats a simultaneous DRAM event and CPU request. Every
        // selected payload remains stable while the external controller waits.
        screen_req=1; screen_srfaddr=14'h1234; screen_dpytap=16'h8765;
        screen_org=1; refresh_req=1; refresh_row=8'h55; refresh_cbr=1;
        word_req=1; word_addr=32'h11112220; word_wdata=16'hbeef;
        wait_target();
        if (cyc_kind!==4'd2 || cyc_srfaddr!==14'h1234 ||
            cyc_dpytap!==16'h8765 || !cyc_org)
            $fatal(1,"screen priority/payload");
        @(negedge clk);
        refresh_req=0; screen_srfaddr=14'h2222; screen_dpytap=0;
        screen_org=0; word_addr=32'hdeadbeef;
        repeat (3) tick();
        if (cyc_kind!==4'd2 || cyc_srfaddr!==14'h1234 ||
            cyc_dpytap!==16'h8765 || !cyc_org)
            $fatal(1,"screen payload changed while waiting");
        @(negedge clk); cyc_ack=1; #1;
        wait_screen_response();
        if (!screen_ack || word_ack) $fatal(1,"screen response owner");
        tick();
        if (screen_ack || cyc_req) $fatal(1,"screen ack repeated");
        repeat (2) tick(); // held external ack cannot create a second cycle
        @(negedge clk); cyc_ack=0;
        wait_target();
        if (cyc_kind!==4'd4 || cyc_dram_row!==8'h55)
            $fatal(1,"queued CBR refresh priority/payload");
        @(negedge clk); refresh_req=1; refresh_row=8'h66;
        refresh_cbr=0; tick();
        if (cyc_kind!==4'd4 || cyc_dram_row!==8'h55)
            $fatal(1,"in-flight refresh payload changed");
        @(negedge clk); refresh_req=0;
        complete_cycle();
        wait_target();
        if (cyc_kind!==4'd3 || cyc_dram_row!==8'h66)
            $fatal(1,"new refresh event lost during old cycle");
        complete_cycle();
        // Screen request is deliberately still high: it was already served.
        // CPU I/O read wins, and live I/O data is captured at grant.
        @(negedge clk);
        word_addr=32'hc0000100; is_io=1; io_rdata=16'ha5a5;
        wait_target();
        if (cyc_kind!==4'd5 || cyc_io_rdata!==16'ha5a5 ||
            cyc_iaq) $fatal(1,"I/O read selection");
        @(negedge clk); io_rdata=16'hffff; word_addr=0;
        tick();
        if (cyc_addr!==32'hc0000100 || cyc_io_rdata!==16'ha5a5)
            $fatal(1,"I/O command changed during wait");
        @(negedge clk); cyc_rdata=16'ha5a5;
        complete_cycle();
        if (word_rdata!==16'ha5a5) $fatal(1,"CPU I/O response data");
        @(negedge clk); word_addr=32'hc0000100;
        repeat (3) tick();
        if (cyc_req) $fatal(1,"held identical CPU word reissued");
        // A distinct physical request can follow without word_req dropping.
        @(negedge clk); is_io=0; word_we=1; word_addr=32'h2000;
        word_wdata=16'h1234; word_iaq=1;
        wait_target();
        if (cyc_kind!==4'd1 || cyc_wdata!==16'h1234 || !cyc_iaq)
            $fatal(1,"word write/IAQ");
        complete_cycle();
        @(negedge clk); word_req=0; screen_req=0;
        tick();
        // Pixel conversion is a captured request tag, with I/O precedence.
        @(negedge clk); word_req=1; word_we=0; word_pixel=1;
        pixel_srt=1; word_iaq=1; word_addr=32'h4000;
        wait_target();
        if (cyc_kind!==4'd7 || cyc_iaq)
            $fatal(1,"pixel MTR/IAQ suppression");
        complete_cycle();
        @(negedge clk); word_req=0; tick();
        @(negedge clk); word_req=1; word_we=1; word_addr=32'h4010;
        wait_target();
        if (cyc_kind!==4'd8) $fatal(1,"pixel RTM");
        complete_cycle();
        @(negedge clk); word_req=0; tick();
        @(negedge clk); word_req=1; is_io=1; word_we=0;
        word_addr=32'hc0000020; io_rdata=16'h7777;
        wait_target();
        if (cyc_kind!==4'd5 || cyc_io_rdata!==16'h7777)
            $fatal(1,"I/O must precede pixel SRT tag");
        complete_cycle();
        // Reset before testing a partial-word read/write reservation.
        reset_bus();
        word_req=1; word_lock=1; word_we=0; word_addr=32'h8000;
        wait_target();
        if (cyc_kind!==4'd0) $fatal(1,"RMW read start");
        complete_cycle();
        @(negedge clk); word_we=1; word_wdata=16'h77ff;
        screen_req=1; screen_srfaddr=14'h0033;
        refresh_req=1; refresh_row=8'h22;
        wait_target();
        if (cyc_kind!==4'd1 || cyc_addr!==32'h8000)
            $fatal(1,"reserved partial write must beat screen/DRAM");
        @(negedge clk); hold_req=1; // HOLD cannot truncate active write
        tick();
        if (!cyc_req || word_restart || hold_ack)
            $fatal(1,"HOLD truncated active CPU write");
        complete_cycle();
        @(negedge clk); word_req=0; word_lock=0;
        wait_hold_ack();
        if (!hold_ack || word_restart) $fatal(1,"HOLD after completed pair");
        @(negedge clk); hold_req=0;
        tick();
        // Separate partial read: HOLD at the read/write boundary pulses
        // restart, then screen/DRAM traffic may change unprotected bits.
        reset_bus();
        word_req=1; word_lock=1; word_we=0; word_addr=32'h9000;
        tick(); complete_cycle();
        @(negedge clk); word_we=1; word_wdata=16'h5555; hold_req=1;
        #1;
        if (!word_restart || cyc_req)
            $fatal(1,"HOLD boundary must restart stale partial write");
        tick();
        if (!hold_ack || word_restart) $fatal(1,"one-clock restart pulse");
        @(negedge clk); word_req=0; word_lock=0;
        screen_req=1; screen_srfaddr=14'h123;
        tick();
        @(negedge clk); hold_req=0;
        wait_target();
        if (cyc_kind!==4'd2) $fatal(1,"screen after HOLD release");
        complete_cycle();
        @(negedge clk); screen_req=0; tick();
        @(negedge clk); word_req=1; word_we=0; word_lock=1;
        wait_target();
        if (cyc_kind!==4'd0 || cyc_addr!==32'h9000)
            $fatal(1,"fresh RMW reread after HOLD");
        $display("jttms10_bus PASS"); $finish;
    end
endmodule
