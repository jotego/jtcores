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
    if(blanks==3) $finish;
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

wire SCREN, LSCREN, phiSC, phiMAIN;
wire [3:0] AB = 4'd0;
wire [7:0] DB = 8'd0;

reg scr_csn;

initial begin
    scr_csn = 1'b1;
    #5000 scr_csn = 1'b0;
    #5100 scr_csn = 1'b1;
end

pcb uut(
    .CLK12  ( CLK12   ),
    .phiB   ( phiB    ),
    .H      ( H       ), 
    .V      ( V       ),
    .HINIT  ( HINIT   ), 
    .LHBL   ( LHBL    ), 
    .LVBL   ( LVBL    ),
    // SCROLLH
    .FLIP   ( 1'b0    ),
    .AB     ( AB      ),
    .DB     ( DB      ),
    .SCREN  ( SCREN   ),
    .LSCREN ( LSCREN  ),
    .phiSC  ( phiSC   ),
    .phiMAIN( phiMAIN ),
    .C8CS   ( 1'b1    ),
    .D8CS   ( scr_csn )
);

endmodule
