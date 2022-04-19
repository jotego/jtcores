`timescale 1ns/1ps

module test;

wire [13:0] map_addr;
reg  [15:0] hpos=8'd0;
wire [8:0] V,H;
wire LHBL, LVBL, HINIT;
reg rst,clk;
wire flip=1'b0;

initial begin
    rst=1'b0;
    #20 rst=1'b1;
    #40 rst=1'b0;
end

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

always @(posedge LHBL) begin
    hpos <= hpos + 16'd16;
    if( hpos >= 16'h1000 ) $finish;
end

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( 1'b1     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  (          ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  (          ),
    .HS        (          ),
    .VS        (          ),
    .Vinit     (          )
);

jt1943_scroll #( 
    .LAYOUT(3), // 0 = 1943, 3 = Bionic Commando
    .PALETTE(0)
) uut(
    .rst        ( rst   ),
    .clk        ( clk   ),  // >12 MHz
    .cen6       ( 1'b1  ),
    .V128       ( V     ), // V128-V1
    .H          ( H     ), // H256-H1

    .hpos       ( hpos  ),
    .vpos       ( hpos  ),
    .SCxON      (1'b1),
    .flip       (flip),
    // Palette PROMs D1, D2
    .prog_addr  (),
    .prom_hi_we (),
    .prom_lo_we (),
    .prom_din   (),

    // Map ROM
    .map_addr   ( map_addr  ),
    .map_data   ( 16'h0     ),
    // Gfx ROM
    .scr_addr   (),
    .scrom_data (),
    .scr_pxl    ()
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;    
end

endmodule
