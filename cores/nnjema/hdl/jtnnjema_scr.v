/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

// background, 16x16 tiles, map in ROM
// galivan: 128x128 map, row scan. ninjemak: 512x32 map, column scan
module jtnnjema_scr(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             m4_en,
    input             flip,
    input             hs,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,
    input             blankn,
    input      [12:0] scrx,
    input      [10:0] scry,

    // map ROM, {attr,code}
    output     [14:1] map_addr,
    output            map_cs,
    input             map_ok,
    input      [15:0] map_data,

    output     [16:2] rom_addr,
    output            rom_cs,
    input             rom_ok,
    input      [31:0] rom_data,

    output     [ 7:0] pxl        // {pal[3:0],px[3:0]}
);

wire [15:0] vram_addr;
wire [ 9:0] code;
wire [ 3:0] pal;
wire [14:0] pre_addr;
wire [31:0] sorted;
wire [ 7:0] attr;
reg  [12:0] heff;
reg  [10:0] veff, vfull;
reg  [ 9:0] hdf;
reg  [ 8:0] vdf;
reg         hsl;

assign map_cs   = 1;
assign attr     = map_data[15:8];
// {veff[10:4] (7b), heff[12:4] (9b)}
assign map_addr = m4_en ? {vram_addr[8:0],vram_addr[13:9]}  // col*32+row
                        : {vram_addr[15:9],vram_addr[6:0]}; // row*128+col
assign code     = {attr[1:0],map_data[7:0]};
assign pal      = m4_en ? {attr[6:5],attr[3:2]} : attr[6:3];
// gfx rows are packed by V first: {code, v[3:0], h[3]}
assign rom_addr = {pre_addr[14:5],pre_addr[3:0],pre_addr[4]};

genvar i;
generate
    for(i=0;i<8;i=i+1) begin : nibble2plane
        assign sorted[ 7-i] = rom_data[i*4+0];
        assign sorted[15-i] = rom_data[i*4+1];
        assign sorted[23-i] = rom_data[i*4+2];
        assign sorted[31-i] = rom_data[i*4+3];
    end
endgenerate

// scroll offset, veff latched once per line
always @* begin
    hdf  = {hdump[8],hdump} ^ {2'd0,{8{flip}}};
    heff = {3'd0,hdf} + scrx + 13'd9; // same pipeline offset as the char layer
    vdf  = vdump ^ {1'b0,{8{flip}}};
    vfull= {2'd0,vdf} + scry;
end

always @(posedge clk) begin
    hsl <= hs;
    if( !hs && hsl ) veff <= vfull;
end

jtframe_tilemap #(
    .SIZE       ( 16 ),
    .VA         ( 16 ),
    .CW         ( 10 ),
    .PW         (  8 ),
    .MAP_HW     ( 13 ),
    .MAP_VW     ( 11 ),
    .HDUMPW     ( 13 ),
    .VDUMPW     ( 11 ),
    .FLIP_HDUMP (  0 ),
    .FLIP_VDUMP (  0 ),
    .FLIP_MSB   (  0 ),
    .HJUMP      (  0 )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( veff      ),
    .hdump      ( heff      ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .vram_addr  ( vram_addr ),
    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( pre_addr  ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( pxl       )
);

endmodule
