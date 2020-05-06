`timescale 1ns / 1ps

module test;

parameter AW = 9, OBJMAX=512;

wire [AW-1:0]  AB;

reg  rst, clk, OKOUT, cen;
wire bus_req;
reg  bus_ack;

always @(posedge clk) begin
    bus_ack <= bus_req;
    cen     <= ~cen;
end

initial begin
    rst = 1;
    OKOUT = 0;
    #100 rst=0;
    #400 OKOUT = 1;
    #500 OKOUT = 0;
end

initial begin
    clk = 0;
    cen = 0;
    forever #10 clk = ~clk;
end

always @(negedge blen ) begin
    if(!rst) #100 $finish;
end

jtgng_objdma #(.AW(AW),.OBJMAX(OBJMAX)) UUT  (
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    // screen
    // shared bus
    .AB     ( AB        ),
    .DB     ( AB[7:0]   ),
    .OKOUT  ( OKOUT     ),
    .bus_req( bus_req   ),  // Request bus
    .bus_ack( bus_ack   ),  // bus acknowledge
    .blen   ( blen      ),     // bus line counter enable
    // output data
    .pre_scan( AB       ),
    .dma_dout(          )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;
end

endmodule
