module jtargus_scroll #(
    parameter CW=10,
    parameter TEXT=0
)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,
    input             blankn,
    input             flip,
    input      [ 8:0] vdump,
    input      [ 8:0] hdump,
    input      [ 8:0] scrx,
    input      [ 8:0] scry,

    output     [ 9:0] ram_addr,
    input      [15:0] ram_data,

    output            rom_cs,
    output     [14:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl
);

localparam SIZE   = TEXT ? 8 : 16;
localparam MAP_HW = TEXT ? 8 : 9;
localparam MAP_VW = TEXT ? 8 : 9;
localparam VA     = 10;
localparam PW     = 8;

wire [31:0] sorted_argus, sorted_jtframe;
wire [31:0] sorted = TEXT ? sorted_jtframe : sorted_argus;
wire [CW-1:0] code;
wire [ 9:0] ram_code = {ram_data[15:14],ram_data[7:0]};
wire [MAP_HW-1:0] scrx_eff = scrx[MAP_HW-1:0];
wire [MAP_VW-1:0] scry_eff = scry[MAP_VW-1:0];
wire [ 3:0] pal;
wire        hflip, vflip;

assign code  = ram_code[CW-1:0];
assign pal   = ram_data[11:8];
assign hflip = ram_data[12];
assign vflip = ram_data[13];

jtargus_8x8x4_packed_msb u_conv_argus(
    .raw    ( rom_data     ),
    .sorted ( sorted_argus )
);

jtframe_8x8x4_packed_msb u_conv_jtframe(
    .raw    ( rom_data       ),
    .sorted ( sorted_jtframe )
);

jtframe_scroll #(
    .SIZE       ( SIZE       ),
    .VA         ( VA         ),
    .CW         ( CW         ),
    .PW         ( PW         ),
    .MAP_HW     ( MAP_HW     ),
    .MAP_VW     ( MAP_VW     ),
    .SCAN_COLS  ( 1          ),
    .HJUMP      ( 0          )
) u_scroll(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .hs         ( hs         ),
    .vdump      ( vdump      ),
    .hdump      ( hdump      ),
    .blankn     ( blankn     ),
    .flip       ( flip       ),
    .scrx       ( scrx_eff   ),
    .scry       ( scry_eff   ),
    .vram_addr  ( ram_addr   ),
    .code       ( code       ),
    .pal        ( pal        ),
    .hflip      ( hflip      ),
    .vflip      ( vflip      ),
    .rom_addr   ( rom_addr   ),
    .rom_data   ( sorted     ),
    .rom_cs     ( rom_cs     ),
    .rom_ok     ( rom_ok     ),
    .pxl        ( pxl        )
);

endmodule
