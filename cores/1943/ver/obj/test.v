`timescale 1ns/1ps

module test(
    input               rst,
    input               clk,
    // PROM access
    input       [7:0]   prog_addr,
    input       [3:0]   prog_din,
    input               prom_hi_we,
    input               prom_lo_we,
    // DMA
    output      [ 8:0]  obj_AB,
    input       [ 7:0]  obj_DB,
    input               OKOUT,
    output              bus_req,   // Request bus
    input               bus_ack,   // bus acknowledge
    output              blen,      // bus line counter enable
    // SDRAM interface
    output       [16:0] obj_addr,
    input        [15:0] obj_data,
    input               obj_ok,
    // video
    input               flip,
    output              LHBL,    
    output              LVBL,
    output              pxl_cen,
    output      [ 7:0]  obj_pxl
);

    // From objects
parameter
    OBJMAX         = 10'h200, // DMA buffer 512 bytes = 4*128
    OBJMAX_LINE    = 6'd32,
    OBJ_LAYOUT     = 1, // 1 for 1943, 2 for GunSmoke
    OBJ_ROM_AW     = 17,
    OBJ_PALHI      = "../../../rom/1943/bm7.7c",
    OBJ_PALLO      = "../../../rom/1943/bm8.8c";


wire cen1p5, cen3, cen6, cen8, cen12;
wire [8:0] V;
wire [8:0] H;
wire HINIT;
wire LHBL_obj, LVBL_obj, HS, VS;

assign pxl_cen = cen6;


jtgng_cen #(.CLK_SPEED(48)) u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen12b (           ),
    .cen8   ( cen8      ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
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
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

integer frame_cnt=0;
always @(negedge LVBL) frame_cnt=frame_cnt+1;

jtgng_obj #(
    .OBJMAX          ( OBJMAX      ),
    .OBJMAX_LINE     ( OBJMAX_LINE ),
    .PXL_DLY         ( 8           ),

    .ROM_AW          ( OBJ_ROM_AW  ),
    .LAYOUT          ( OBJ_LAYOUT  ),
    .PALW            (  4          ),
    .PALETTE         (  1          ),
    .PALETTE1_SIMFILE( OBJ_PALHI   ),
    .PALETTE0_SIMFILE( OBJ_PALLO   ))
u_obj(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .dma_cen        ( cen8          ),  // 8MHz!!
    .draw_cen       ( cen12         ),
    .pxl_cen        ( cen6          ),
    // screen
    .HINIT          ( HINIT         ),
    .LHBL           ( LHBL_obj      ),
    .LVBL           ( LVBL          ),
    .LVBL_obj       ( LVBL_obj      ),
    .V              ( V[7:0]        ),
    .H              ( H             ),
    .flip           ( flip          ),
    // CPU bus
    .AB             ( obj_AB        ),
    .DB             ( obj_DB        ),
    // shared bus
    .OKOUT          ( OKOUT         ),
    .bus_req        ( bus_req       ),   // Request bus
    .bus_ack        ( bus_ack       ),   // bus acknowledge
    .blen           ( blen          ),   // bus line counter enable
    // SDRAM interface
    .obj_addr       ( obj_addr      ),
    .obj_data       ( obj_data      ),
    .rom_ok         ( obj_ok        ),
    // PROMs
    .OBJON          ( 1'b1          ),
    .prog_addr      ( prog_addr     ),
    .prom_hi_we     ( prom_hi_we    ),
    .prom_lo_we     ( prom_lo_we    ),
    .prog_din       ( prog_din      ),
    // pixel output
    .obj_pxl        ( obj_pxl       )
);

endmodule
