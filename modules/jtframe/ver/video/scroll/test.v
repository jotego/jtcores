module test;

`include "test_tasks.vh"
`include "video_tasks.vh"

wire          rst, clk, pxl_cen, vs, hs;
wire    [8:0] hdump, vdump;
wire    [9:0] vram_addr;
reg     [7:0] scry=0;
wire          flip=0;
wire    [9:5] vpart;
wire    [4:0] hpart;
reg     [9:5] vref;

integer test=0;

assign {vpart,hpart}=vram_addr;

initial begin
    @(negedge rst);

    wait_for_line(9'h20);
    scry=8'h0;
    wait_for_col(9'h80);
    vref = vpart;
    adv_lines(16);
    vref = vref+2;
    wait_for_col(9'h80);
    assert_msg(vref == vpart, "should match for scroll 0");

    // add scroll
    test=1;
    scry=8'h40;
    @(posedge vs)
    wait_for_col(9'h40);
    vref = vpart;
    wait_for_col(9'h48);
    assert_msg(vref == vpart, "should match previous scroll");
    scry = 8'h50;
    wait_for_col(9'h51);
    assert_msg(vref != vpart, "column scroll must change");
    vref = vref+(8'h10>>3);
    assert_msg(vref == vpart, "column scroll mismatch");

    pass();
end

jtframe_scroll #(
    .SIZE        (    8 ),
    .CW          (   12 ),
    .VA          (   10 ),
    .MAP_VW      (    8 ),
    .MAP_HW      (    8 ),
    .PW          (   10 ),
    .XOR_HFLIP   (    1 ),
    .HJUMP       (    1 ),
    .COL_SCROLL  (    1 )
)uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .blankn     ( 1'b1          ),
    .flip       ( flip          ),
    .scrx       ( 8'd0          ),
    .scry       ( scry          ),
    .vram_addr  ( vram_addr     )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vs         ( vs            ),
    .h          ( hdump         ),
    .v          ( vdump         )
);

endmodule
