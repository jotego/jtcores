`timescale 1ns / 1ps

module test;

`include "../../hdl/jt5232.vh"

reg           clk=0, we, rst, clk_ref=0;
wire          cen1, cen2;
wire [TW-1:0] tone_a, tone_b;
reg  [   1:0] div=0;
reg  [   7:0] din;
reg  [   3:0] addr;
reg  [   4:0] dtime=0;
reg           loop=0;
real          t0,t1;
wire [  11:0] eg;
reg  [  11:0] eg_l;

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

task meas_decay;
begin
    we=0; din=0; addr=0;
    // reset
    rst=1;
    repeat(20) @(negedge clk);
    @(negedge uut.cen256);
    rst=0;
    repeat(20) @(negedge clk);
    // enable harmonics and EG, decay mode
    addr=GCTL1; din=8'h2f; we=1; @(negedge clk);
                           we=0; @(negedge clk);
    // set decay time
    addr=DTIME1; din={5'd0,dtime[3:0]}; we=1; @(negedge clk);
                                   we=0; @(negedge clk);
    // program 440 Hz signal
    @(negedge clk);
    addr=0; din=8'hA1; we=1; @(negedge clk);
                       we=0; @(negedge clk);
    // wait for attack phase to finish
    loop = 1;
    for(;loop;) begin
        eg_l = eg;
        @(negedge uut.cen256);
        if(eg<eg_l) begin
            t1=$time;
            loop=0;
        end
    end
    // measure decay
    loop = 1;
    for(;loop;) begin
        @(negedge uut.cen256);
        if(eg<5 ) begin
            t1=$time;
            loop=0;
        end
    end
    $display("Decay time: $%d -> %.0f ms",dtime[3:0],(t1-t0)/1e6);
    case(dtime[3:0])
        4'd0:    check_time(t1-t0,40);
        4'd1:    check_time(t1-t0,80);
        4'd2:    check_time(t1-t0,160);
        4'd3:    check_time(t1-t0,320);
        4'b01?0: check_time(t1-t0,640);
        4'b01?1: check_time(t1-t0,1300);
        4'd8:    check_time(t1-t0,250);
        4'd9:    check_time(t1-t0,500);
        4'd10:   check_time(t1-t0,1000);
        4'd11:   check_time(t1-t0,2000);
        4'b11?0: check_time(t1-t0,4000);
        4'b11?1: check_time(t1-t0,8000);
    endcase
end
endtask

initial begin
`ifdef SINGLE
    dtime=`SINGLE;
    meas_decay;
`else
    $display("Simulating all 16 cases");
    for(dtime = 0; dtime<16;dtime=dtime+1) meas_decay;
`endif
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
`ifdef KEEP
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
`endif
`ifdef SINGLE
    #8_500_000_000; // 8.5s
`else
    #33_000_000_000; // 33 s
`endif
    $fatal(1,"Time over\nFAIL"); // fallback
end

endmodule
