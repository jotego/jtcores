`timescale 1ns/1ps

module test;

wire [1:0] cen, cenb;
reg        clk;
wire       cen_3p57, cen_1p78;
wire       cen6, cen3;

localparam [9:0] N=10'd5;
localparam [9:0] M=10'd12;

jtframe_frac_cen uut(
    .clk    ( clk   ),
    .n      ( N     ),         // numerator
    .m      ( M     ),         // denominator
    .cen    ( cen   ),
    .cenb   ( cenb  )  // 180 shifted
);

jtframe_cen3p57 #(1) uut3p57(
    .clk     ( clk      ),
    .cen_3p57( cen_3p57 ),
    .cen_1p78( cen_1p78 )
);

jtframe_cen24 u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen12b (           ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 (           )
);

initial begin
    clk = 0;
    forever #20.834 clk = ~clk;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #2000 $finish;
end

endmodule
