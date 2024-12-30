`timescale 1ns / 1ps

module test;

`include "../../hdl/jt5232.vh"

reg           clk=0, we, rst, clk_ref=0;
wire          cen1, cen2;
wire [TW-1:0] tone_a, tone_b;
reg  [   1:0] div=0;
reg  [   7:0] din;
reg  [   3:0] addr;
reg  [   3:0] atime=0;
reg           loop=0;
real          t0,t1;
wire [  11:0] eg;

assign cen1 = clk & div[0];
assign cen2 = clk && div==1;
assign eg   = uut.eg[0+:12];

initial forever #10.416 clk =~clk; // 48 MHz

always @(posedge clk) begin
    div <= div+2'd1;
end

integer fsel;
wire fsignal = uut.u_tg0.pipes[fsel];

task check_time;
    input real tdiff;
    input real exp;
begin
    assert(exp*0.9<(tdiff/1e6)&&exp*1.1>(tdiff/1e6)) else
        $fatal(1,"attack time not met. %.0f ms expected, got %.0f ms",exp,tdiff/1e6);
end
endtask

task meas_attack;
begin
    we=0; din=0; addr=0;
    // reset
    rst=1;
    repeat(20) @(negedge clk);
    @(negedge uut.cen256);
    rst=0;
    repeat(20) @(negedge clk);
    // enable harmonics and EG, sustained mode
    addr=GCTL1; din=8'h3f; we=1; @(negedge clk);
                           we=0; @(negedge clk);
    // set attack time
    addr=ATIME1; din={5'd0,atime[2:0]}; we=1; @(negedge clk);
                                   we=0; @(negedge clk);
    // program 440 Hz signal
    @(negedge clk);
    addr=0; din=8'hA1; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    t0 = $time;
    loop = 1;
    for(;loop;) begin
        @(negedge uut.cen256);
        if(eg>=3685) begin
            t1=$time;
            loop=0;
        end
    end
    $display("Attack time: $%d -> %.0f ms",atime[2:0],(t1-t0)/1e6);
    case(atime[2:0])
        0: check_time(t1-t0,2);
        1: check_time(t1-t0,4);
        2: check_time(t1-t0,8);
        3: check_time(t1-t0,16);
        3'b1?0: check_time(t1-t0,32);
        3'b1?1: check_time(t1-t0,64);
    endcase
end
endtask

initial begin
    for(atime = 0; atime<8;atime=atime+1) meas_attack;
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
    #500_000_000;
    $fatal(1,"Time over\nFAIL"); // fallback
end

endmodule
