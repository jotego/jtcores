`timescale 1ns/1ps

module test;

reg clk = 0;
reg rst = 1;
reg cen6 = 0;
reg [10:0] pal_addr = 0;
reg [10:0] pal_wr_addr = 0;
reg [15:0] pal_din = 0;
reg [1:0] pal_we = 0;
reg [1:0] renderer_source = 0;
reg [3:0] gfx_en = 0;
reg preLHBL = 1;
reg preLVBL = 1;
wire [15:0] pal_q;
wire [4:0] red5, green5, blue5;
wire [7:0] red, green, blue;
wire [14:0] rgb, rgb_blank;
wire old_lhbl, old_lvbl, lhbl, lvbl;
wire [7:0] ref_red_lut, ref_green_lut, ref_blue_lut;
wire [7:0] ref_red, ref_green, ref_blue;
wire ref_visible;
reg [1:0] ref_source_lut;
integer n;

always #5 clk = ~clk;

jtframe_dual_ram16 #(.AW(11)) u_palette(
    .clk0(clk), .data0(pal_din), .addr0(pal_wr_addr), .we0(pal_we), .q0(),
    .clk1(clk), .data1(16'd0), .addr1(pal_addr), .we1(2'b00), .q1(pal_q)
);

// The rest of main is intentionally disabled, but this is its actual RGB
// output register and the production module's NOMAIN path keeps it live.
/* verilator lint_off PINMISSING */
/* verilator lint_off PINCONNECTEMPTY */
jtnemsis_main uut(
    .rst(rst), .clk(clk), .pxl_cen(cen6), .cen_9(1'b0), .vblank(1'b0),
    .v256(1'b0), .clk6(1'b0), .h1_n(1'b1), .h2(1'b0),
    .main_addr(), .main_cs(), .main_data(16'd0), .main_ok(1'b0),
    .video_addr(), .video_din(16'd0), .video_dout(),
    .pal_cpu_addr(), .pal_cpu_din(), .pal_cpu_we(), .pal_cpu_dout(16'd0),
    .pal_video_dout(pal_q),
    .red(red5), .green(green5), .blue(blue5),
    .joystick1(7'd0), .joystick2(7'd0), .coin(2'd0), .cab_1p(2'd0),
    .dipsw(24'd0), .service(1'b1), .dip_pause(1'b0),
    .debug_bus(8'd0), .st_dout(), .ioctl_addr(4'd0)
);
/* verilator lint_on PINCONNECTEMPTY */
/* verilator lint_on PINMISSING */

assign rgb = { red5, green5, blue5 };
// Reference the original game pipeline: blank first, then the color LUT.
jtframe_blank #(.DLY(0), .DW(15)) u_old_blank(
    .clk      ( clk      ),
    .pxl_cen  ( cen6     ),
    .preLHBL  ( preLHBL  ),
    .preLVBL  ( preLVBL  ),
    .LHBL     ( old_lhbl ),
    .LVBL     ( old_lvbl ),
    .preLBL   (          ),
    .rgb_in   ( rgb      ),
    .rgb_out  ( rgb_blank)
);

reg [1:0] source_rgb;
always @(posedge clk or posedge rst) begin
    if (rst) source_rgb <= 2'd0;
    else if (cen6) source_rgb <= renderer_source;
end

always @(posedge clk or posedge rst) begin
    if (rst) ref_source_lut <= 2'd0;
    else     ref_source_lut <= source_rgb;
end

jtnemsis_colour_lut #(.SYNFILE("colmix.hex")) u_old_lut(
    .clk       ( clk              ),
    .in_red    ( rgb_blank[14:10] ),
    .in_green  ( rgb_blank[ 9: 5] ),
    .in_blue   ( rgb_blank[ 4: 0] ),
    .out_red   ( ref_red_lut      ),
    .out_green ( ref_green_lut    ),
    .out_blue  ( ref_blue_lut     )
);

assign ref_visible = (ref_source_lut == 2'd1) ? gfx_en[1] :
                     (ref_source_lut == 2'd2) ? gfx_en[2] : gfx_en[3];
assign ref_red   = ref_visible ? ref_red_lut   : 8'd0;
assign ref_green = ref_visible ? ref_green_lut : 8'd0;
assign ref_blue  = ref_visible ? ref_blue_lut  : 8'd0;

jtnemsis_colmix uut_colmix(
    .rst(rst), .clk(clk), .pxl_cen(cen6), .source(source_rgb),
    .red5(red5), .green5(green5), .blue5(blue5),
    .preLHBL(preLHBL), .preLVBL(preLVBL), .LHBL(lhbl), .LVBL(lvbl),
    .gfx_en(gfx_en),
    .red(red), .green(green), .blue(blue)
);

task check_equivalent;
begin
    #1;
    if ({red,green,blue} !== {ref_red,ref_green,ref_blue})
        $fatal(1, "FAIL: relocated blanking changed LUT RGB (%h != %h)",
            {red,green,blue}, {ref_red,ref_green,ref_blue});
    if ({lhbl,lvbl} !== {old_lhbl,old_lvbl})
        $fatal(1, "FAIL: relocated blanking changed blank flags (%b != %b)",
            {lhbl,lvbl}, {old_lhbl,old_lvbl});
end
endtask

task check_pixel;
    input [23:0] expected;
    input [8*80-1:0] message;
begin
    check_equivalent;
    if ({red,green,blue} !== expected)
        $fatal(1, "FAIL: %0s got %h expected %h", message, {red,green,blue}, expected);
end
endtask

initial begin
    #12 rst = 0;
    #1;
    if (uut.u11k_latch_din !== 8'd0 || uut.u13j_latch_din !== 8'd0)
        $fatal(1, "FAIL: NOMAIN MMR data inputs are not tied to zero");
    // Write two distinct palette values: A is red, B is blue.
    @(negedge clk); pal_we=2'b11; pal_din=16'h001f; pal_wr_addr=11'd1;
    @(negedge clk); pal_din=16'h7c00; pal_wr_addr=11'd2;
    @(negedge clk); pal_we=0; pal_addr=11'd1; gfx_en=4'b0010;
    renderer_source=2'd1; cen6=1;
    @(posedge clk); #1; // palette q becomes A; main reads prior q
    @(negedge clk); pal_addr=11'd2;
    @(posedge clk); #1; renderer_source=2'd2; // main RGB/tag now both A
    @(negedge clk); cen6=0;
    @(posedge clk); #1;
    check_pixel(24'hff0000, "tile A red pixel survives its matching A tag");

    for (n=0; n<20; n=n+1) begin
        if ((n & 1)==0) begin
            // Main and source pipeline both hold B from the prior pixel.
            @(negedge clk); cen6=1; gfx_en=4'b0100; pal_addr=11'd1;
            @(posedge clk); #1; renderer_source=2'd1;
            @(negedge clk); cen6=0;
            @(posedge clk); #1;
            check_pixel(24'h0000ff, "alternating B source/color alignment");
        end else begin
            @(negedge clk); cen6=1; gfx_en=4'b0010; pal_addr=11'd2;
            @(posedge clk); #1; renderer_source=2'd2;
            @(negedge clk); cen6=0;
            @(posedge clk); #1;
            check_pixel(24'hff0000, "alternating A source/color alignment");
        end
    end

    // Exercise all H/V blank combinations and transitions while source and
    // palette tags alternate. Include pixel-enable stalls to catch any
    // latency change at the relocated blanking boundary.
    for (n=0; n<4; n=n+1) begin
        @(negedge clk);
        preLHBL = (n[0] == 0);
        preLVBL = (n[1] == 0);
        gfx_en = (n[0] == 0) ? 4'b0010 : 4'b0100;
        renderer_source = (n[0] == 0) ? 2'd1 : 2'd2;
        pal_addr = (n[0] == 0) ? 11'd1 : 11'd2;
        cen6 = n[1];
        @(posedge clk);
        check_equivalent;
        if (!preLHBL || !preLVBL)
            if ({red,green,blue} !== 24'd0)
                $fatal(1, "FAIL: blanked pixel is not black for H/V state %b%b",
                    preLHBL, preLVBL);
        @(negedge clk);
        cen6 = 0;
        preLHBL = ~preLHBL;
        preLVBL = ~preLVBL;
        @(posedge clk);
        check_equivalent;
    end
    $display("PASS: synchronous palette, main RGB register, and source-tag/LUT latency");
    $finish;
end

endmodule
