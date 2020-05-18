`timescale 1ns/1ps


module test;

reg           clk;     // 24 MHz
reg           rst;
wire   [11:0] AB = 12'd0;
wire    [8:0] V; // V128-V1
wire    [8:0] H; // H256-H1
wire   [10:0] hpos=11'd0;
wire   [10:0] vpos=11'h0;
wire          scr_cs = 1'b0;
wire          layout = 1'b0;
wire    [1:0] bank = 2'b0;
wire          flip = 1'b0;
reg     [7:0] din = 8'd0;
wire    [7:0] dout;
reg           wr_n = 1'b1;
wire          busy;
wire   [16:0] scr_addr;
wire   [15:0] rom_data = 16'hdead;
wire          rom_ok = 1'b1;
wire   [ 7:0] scr_pxl;

wire cen6;

initial begin
    clk = 0;
    forever #(1/10.416) clk = ~clk;
end

initial begin
    rst=1;
    #30 rst=0;
end

integer framecnt=0;

always @(posedge LVBL) begin
    framecnt <= framecnt+1;
    if (framecnt==1) $finish;
end

jtgng_cen #(.CLK_SPEED(48)) u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   (           ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   (           ),
    .cen1p5 (           )
);

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     (          ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  (          ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  (          ),
    .HS        (          ),
    .VS        (          ),
    .Vinit     (          )
);

jtbtiger_scroll uut(
    .clk        (  clk      ),
    .pxl_cen    (  cen6     ),
    .cpu_cen    (  cen6     ),
    .AB         (  AB       ),
    .V          (  V[7:0]   ), // V128-V1
    .H          (  H        ), // H256-H1
    .hpos       (  hpos     ),
    .vpos       (  vpos     ),
    .scr_cs     (  scr_cs   ),
    .layout     (  layout   ),
    .bank       (  bank     ),
    .flip       (  flip     ),
    .din        (  din      ),
    .dout       (  dout     ),
    .wr_n       (  wr_n     ),
    .busy       (  busy     ),
    .scr_addr   (  scr_addr ),
    .rom_data   (  rom_data ),
    .rom_ok     (  rom_ok   ),
    .scr_pxl    (  scr_pxl  )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
