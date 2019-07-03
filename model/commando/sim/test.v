`timescale 1ns/1ps

module test;

reg  CLK12;
wire phiB;
wire [8:0] H;
wire [8:0] V;
wire HINIT;
wire LHBL;
wire LVBL;

initial begin
    CLK12 = 1'b0;
    forever #(1000.000/12/2) CLK12 = ~CLK12;    // 12 MHz
end

integer blanks=0;

always @(negedge LVBL) begin
    $display("Vertical blank");
    blanks <= blanks+1;
    if(blanks==4) $finish;
end

`ifdef SIMTIME
real simtime = `SIMTIME;
initial begin
    $display("Simulation will finish after %.1f ms", simtime );
    simtime = simtime * 1000_000;
    #(simtime) $finish;
end
`endif

initial begin
    `ifdef VCD
    $dumpfile("test.vcd");
    `else 
    $dumpfile("test.lxt");
    `endif
    `ifdef DUMPALL
    $dumpvars;
    `else
    $dumpvars(1,test.uut);
    $dumpvars(1,test);
    `endif
    $dumpon;
end

pcb uut(
    .CLK12  ( CLK12 ),
    .phiB   ( phiB  ),
    .H      ( H     ), 
    .V      ( V     ),
    .HINIT  ( HINIT ), 
    .LHBL   ( LHBL  ), 
    .LVBL   ( LVBL  )
);

endmodule
