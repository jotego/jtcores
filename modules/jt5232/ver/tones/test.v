`timescale 1ns / 1ps

module test;

`include "../../hdl/jt5232.vh"

reg           clk=0, we, rst, clk_ref=0;
wire          cen1, cen2;
wire [TW-1:0] tone_a, tone_b;
reg  [   1:0] div=0;
reg  [   7:0] din;
reg  [   3:0] addr;

assign cen1 = clk & div[0]; // 2119040 Hz
assign cen2 = clk && div==1; // 2119040/2 Hz

initial forever #117.978       clk =~clk; // 2*2119040 Hz


always @(posedge clk) begin
    div <= div+2'd1;
end

integer fsel;
wire fsignal = uut.u_tg0.pipes[fsel];

task check_freq(input integer sel, input real freq);
    real t0,t1,fo;
    begin
        fsel=sel;
        repeat(2) @(posedge fsignal);
        t0=$time;
        repeat(10) @(posedge fsignal);
        t1=$time;
        fo=10.0/(t1-t0)*1e9;
        assert(fo>freq*0.9 && fo<freq*1.1) else $fatal(1,"Reference tone (%0d) should be %.0f Hz +/-10%%. Found %.0f Hz",fsel,freq,fo);
        $display("%0d -> %.0f Hz (should be %.0f)",fsel,fo,freq);
    end
endtask

initial begin
    we=0; din=0; addr=0;
    // reset
    rst=1;
    repeat(20) @(negedge clk);
    rst=0;
    repeat(20) @(negedge clk);
    // program 440 Hz signal
    addr=0; din=8'h21|8'h80; we=1; @(negedge clk);
                             we=0; @(negedge clk);
    // repeat(20) assert(uut.u_tg0.harmonics==0) else $fatal(1,"harmonics should be zero at %t",$time);
    // enable harmonics
    addr=12; din=8'hf; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    repeat(20) @(negedge clk);
    // check the frequency for each harmonic output
    $display("440Hz test");
    check_freq(1,440*1);
    check_freq(0,440/2);
    check_freq(2,440*2);
    check_freq(3,440*4);
    // program 261.74 Hz
    @(negedge clk);
    addr=0; din=8'h19|8'h80; we=1; @(negedge clk);
                             we=0; @(negedge clk);
    repeat(20) @(negedge clk);
    // check the frequency for each harmonic output
    $display("277Hz test");
    check_freq(1,277*1);
    check_freq(0,277/2);
    check_freq(3,277*4);
    check_freq(2,277*2);
    $display("PASS");
    $finish;
end

jt5232 uut(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen1   ( cen1      ),
    .cen2   ( cen2      ),
    .din    ( din       ),
    .addr   ( addr      ),
    .we     ( we        ),
    .snd1   ( tone_a    ),
    .snd2   ( tone_b    )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #600_000_000;
    $fatal(1,"Time over\nFAIL"); // fallback
end

endmodule
