// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1fs
module si5332_startup_tb;
    reg clk=0, reset=1;
    always #10 clk = ~clk;
    tri1 scl, sda;
    bit pull_sda;
    assign sda = pull_sda ? 1'b0 : 1'bz;
    wire ready;
    reg [7:0] regs[0:255];
    reg [7:0] shift, pointer;
    bit active, selected, reading;
    integer bits, phase, writes, scenario, bank;
    real half_period=10.0;
    reg clock1=0;
    always #(half_period) clock1 = ~clock1;

    de25_platform_v2_clock_service dut(.clock0_50(clk), .clock1_si5332(clock1),
        .clock2_si5332(clk), .reset(reset), .si5332_scl(scl), .si5332_sda(sda),
        .external_clocks_ready(ready));
    // Speed up the bus and initial probe in simulation.
    defparam dut.si5332.CLOCK_HZ=1000000, dut.si5332.I2C_HZ=25000;

    always @(negedge sda) if (scl) begin
        active=1; bits=0; phase=0; selected=0; reading=0;
    end
    always @(posedge sda) if (scl) active=0;

    always @(posedge scl) if (active) begin
        if (bits < 8) shift = {shift[6:0],sda};
        bits = bits+1;
    end

    // Slave decodes actual START, repeated START, register, data and ACK bits.
    always @(negedge scl) if (active) begin
        if (bits == 8) begin
            if (phase == 0) begin selected=(shift[7:1]==7'h6a); reading=shift[0]; end
            pull_sda = selected && (phase == 0 || !reading);
            if (phase==2 && scenario==2) pull_sda=0; // NACK first data write
        end else if (bits == 9) begin
            if (phase==1 && selected && !reading) pointer=shift;
            if (phase==2 && selected && !reading && scenario!=2) begin
                if (!((pointer >= bank && pointer <= bank+6) ||
                      pointer==8'h35 || pointer==8'h25))
                    $fatal(1,"unexpected write %h",pointer);
                regs[pointer]=shift;
                writes=writes+1;
                if (pointer==8'h25) begin : update_clock
                    real divider, hz;
                    if (shift!=(scenario==5 ? 8'h63 : 8'h53) ||
                        regs[8'h35]!=(scenario==5 ? 8'h01 : 8'h41) ||
                        regs[bank+6]!=8'hc0)
                        $fatal(1,"wrong mux or bank");
                    divider=(512.0+{regs[bank],regs[bank+1]}+
                        1.0*{regs[bank+2],regs[bank+3]}/{regs[bank+4],regs[bank+5]})/128.0;
                    hz=2500000000.0/(divider*2);
                    if ($abs(hz-49152000)>1.0) $fatal(1,"programmed %f Hz",hz);
                    if (scenario!=3) half_period=5.0e8/hz;
                end
            end
            phase=phase+1;
            bits=0;
            pull_sda=selected && reading && phase==1 && !regs[pointer][7];
        end else if (selected && reading && phase==1 && bits<8)
            pull_sda=!regs[pointer][7-bits];
    end

    initial begin
        if (!$value$plusargs("case=%d",scenario)) scenario=0;
        for (integer i=0; i<256; i=i+1) regs[i]=0;
        regs[7]=2; regs['h21]='h6a;
        regs['h25]='h03; regs['h26]='h10; regs['h80]=2;
        regs['h35]=1; regs['h2d]=25; regs['h7b]=2;
        if (scenario==1) begin regs['h27]='h50; regs['h29]='h60; end
        if (scenario==4) half_period=5.0e8/49152000;
        if (scenario==5) begin regs['h27]='h50; regs['h35]='h81; end
        if (scenario==6) regs['hba]='h60;
        bank = scenario==5 ? 'h4e : 'h42;
        regs[bank+6] = 'hc1;
        writes=0;
        repeat (5) @(negedge clk);
        reset=0;
        repeat (330000) @(negedge clk);
        if (ready !== (scenario==0 || scenario==4 || scenario==5)) $fatal(1,"ready=%b writes=%d",ready,writes);
        if (scenario==2 && !dut.profile_error) $fatal(1,"missing I2C fault");
        if (writes != ((scenario==0 || scenario==3 || scenario==5) ? 9 : 0)) $fatal(1,"unexpected write count %d",writes);
        if (scenario==0) begin
            half_period=10;
            repeat (110000) @(negedge clk);
            if (ready) $fatal(1,"lost clock accepted");
        end
        $display("PASS startup case %0d, writes %0d",scenario,writes);
        $finish;
    end
endmodule

module mister_pll(input refclk_clk,reset_reset, output locked_export,outclk0_clk,outclk1_clk,outclk2_clk);
    assign {locked_export,outclk0_clk,outclk1_clk,outclk2_clk}={~reset_reset,{3{refclk_clk}}};
endmodule
