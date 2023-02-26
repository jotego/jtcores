`timescale 1ns/1ps

module jtgng_vga_test;

`ifndef NCVERILOG
    initial begin
        $DUMPFILE("test.lxt");
        `ifndef SIMPLL
        $dumpvars;
        `else
        //$dumpvars;
        $dumpvars(0,UUT);
        $dumpvars(0,timer);
        $dumpvars(0,clk_rom);
        $dumpvars(0,clk_rgb);
        `endif
        $dumpon;
    end
`else
    initial begin
        $display("NC Verilog: will dump all signals");
        $shm_open("test.shm");
        $shm_probe(jtgng_vga_test,"AS");
    end
`endif

initial begin
    #(4*1000*1000) $finish;
end

reg rst;

initial begin
    rst = 0;
    #10 rst=1;
    #800 rst = 0;
end

`ifndef SIMPLL
reg clk_rgb;
reg clk_vga;

initial begin
    clk_vga = 1'b0;
    forever #20.063 clk_vga = ~clk_vga; // 25MHz
end

initial begin
    clk_rgb = 1'b0;
    forever #20.833 clk_rgb = ~clk_rgb; // 24 MHz
end
`else
reg clk27;
wire clk_rom; // 81
wire clk_rgb; // 36
wire clk_vga; // 25
wire locked;

initial begin
    clk27 = 1'b0;
    forever #18.52 clk27 = ~clk27; // 27MHz
end

jtgng_pll0 clk_gen (
    .inclk0 ( clk27     ),
    .c1     ( clk_rgb   ), //  6
    .c2     ( clk_rom   ), // 36
    .locked ( locked    )
);


jtgng_pll1 clk_gen2 (
    .inclk0 ( clk_rgb   ),
    .c0     ( clk_vga   ) // 25
);

`endif


wire cen6, cen3, cen1p5;

jtgng_cen u_cen(
    .clk    ( clk_rgb   ),    // 24 MHz
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);


reg [3:0] red=4'd0, green=4'd0, blue=4'd0;
wire [4:0] vga_red;
wire [4:0] vga_green;
wire [4:0] vga_blue;
wire LHBL, LVBL;

always @(posedge clk_rgb) if(cen6) begin
    red   <= LHBL&&LVBL ? (red   + (($random%4)==3 ? 1 : 0)) : 0;
    green <= LHBL&&LVBL ? (green + (($random%4)==3 ? 1 : 0)) : 0;
    blue  <= LHBL&&LVBL ? (blue  + (($random%4)==3 ? 1 : 0)) : 0;
end

`define SIM_SYNCONLY


wire [8:0] V;
wire [8:0] H;

jtgng_timer timer (
    .clk      (clk_rgb),
    .clk_en   (cen6   ),
    .V        (V      ),
    .H        (H      ),
    .Hinit    (Hinit  ),
    .LHBL     (LHBL   ),
    .LVBL     (LVBL   ),
    .LHBL_obj (),
    .Vinit    ()
);


jtgng_vga UUT (
    .clk_rgb  (clk_rgb  ),
    .cen6     (cen6     ),
    .clk_vga  (clk_vga  ),
    .en_mixing( 1'b1    ),
    .rst      (rst      ),
    .red      (red      ),
    .green    (green    ),
    .blue     (blue     ),
    .LHBL     (LHBL     ),
    .LVBL     (LVBL     ),
    .vga_red  (vga_red  ),
    .vga_green(vga_green),
    .vga_blue (vga_blue ),
    .vga_hsync(vga_hsync),
    .vga_vsync(vga_vsync)
);


endmodule // jtgng_vga_test
