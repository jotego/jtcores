`timescale 1ns/1ps

module test;

reg  clk, rst;
wire cen6;

wire [8:0] V;
wire [8:0] H;
reg  [4:0] objcnt;
wire       HINIT, LHBL, LVBL, HS, VS, LHBL_obj;

integer framecnt=0;

initial begin
    clk=0;
    forever #10.416 clk = ~clk;
end

initial #(16000000*4) $finish;
initial begin
    rst=1;
    #100 rst=0;
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen6   ( cen6      ),
    .cen3   (           ),
    .cen1p5 (           )
);

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

always @(posedge LVBL) begin
    framecnt <= framecnt+1;
    if( framecnt==1 ) $finish;
end

always @(*) begin
    // 1942 scan sequence from schematics
    objcnt[4] = H[8]^~H[7];
    objcnt[3] = (V[7] & objcnt[4]) ^ ~H[7];
    objcnt[2:0] = H[6:4];
end

jt1942_objtiming u_timing(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .cen6        ( cen6          ),    //  6 MHz
    // screen
    .LHBL        ( LHBL          ),
    .HINIT       ( HINIT         ),
    .flip        ( 1'b0          ),
    .V           ( V[7:0]        ),
    .H           ( H             ),
    .obj_ok      ( 1'b1          ),
    .over        (               ),
    // Timing PROM
    .prog_addr   (               ),
    .prom_m11_we (               ),
    .prog_din    (               ),
    .pxlcnt      (               ),
    .pxlcnt_lsb  (               ),
    .objcnt      (               ),
    .bufcnt      (               ),
    .line        (               )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

endmodule