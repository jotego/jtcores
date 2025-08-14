/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-8-2025 */

module jtriders_psac(
    input              rst, clk,
                       pxl_cen,  // use cen instead (see below)
                       hs, vs, dtackn, enable,
                       cs, // cs always writes
    input       [ 8:0] hdump,

    input       [15:0] din,        // from CPU
    input       [ 4:1] addr,
    input       [ 1:0] dsn,
    input              tmap_bank,
    output             dma_n,
    // Lines RAM
    output      [10:1] line_addr,
    input       [15:0] line_dout,
    // Tile map
    output      [18:0] vram_addr, // 19
    input       [23:0] vram_dout,
    input              vram_ok,

    // Tiles
    output      [20:0] rom_addr,
    input       [ 7:0] rom_data,
    output             rom_cs,
    input              rom_ok,

    output /*reg*/  [ 7:0] pxl,

    // IOCTL dump
    input      [4:0] ioctl_addr,
    output     [7:0] ioctl_din
);

wire [71:0] tblock;
reg  [20:0] rom_addr_l;
wire [ 8:0] la;
wire [ 2:1] lh;
wire [12:0] x, y, encoded;
wire        xh,yh,ob;
/*wire*/reg [13:0] code;
wire        hflip, vflip, cen;
reg [ 3:0] pal;
wire [ 3:0] /*pal,*/ vf, hf, dmux;
reg         rst2, cen2, newroma, newroma_l, rom_ok_l;

assign line_addr = {la[7:0],lh};
assign vram_addr = {tmap_bank,y[12:4], x[12:4]};
// assign code      = vram_dout[13:0];
assign hflip     = 0;
assign vflip     = 0;
// assign pal       = vram_dout[14+:4];
assign vf        = {4{vflip}} ^ {y[3:0]};
assign hf        = {4{hflip}} ^ {x[3:0]};
// assign cen       = /*pxl_cen & */rom_ok/*& vram_ok & rom_ok*/;

assign rom_cs    = 1 ^ (newroma | newroma_l);
assign rom_addr  = {code,vf,hf[3:1]}; // 13+4+4=21
assign dmux      = hf[0] ? rom_data[3:0] : rom_data[7:4];

initial cen2 = 0;
always @(posedge clk) rst2 <= rst | ~enable;
always @(posedge clk) cen2 <= ~cen2;
always @(posedge clk) begin
    rom_addr_l <= rom_addr;
    rom_ok_l   <= rom_ok;
    newroma_l  <= newroma;
end

// always @(posedge clk) if(cen) begin
//     pxl <= {pal,dmux};
// end

always @(*) begin
    newroma   = rom_addr != rom_addr_l && rom_ok_l;
    case({y[4],x[4]})
        0: {pal, code} = tblock[ 0+:18];
        1: {pal, code} = tblock[18+:18];
        2: {pal, code} = tblock[36+:18];
        3: {pal, code} = tblock[54+:18];
    endcase
end

jt053936 u_xy(
    .rst        ( rst2      ),
    .clk        ( clk       ),
    .cen        ( rom_cs & rom_ok & cen2 /*cen*/       ),

    .din        ( din       ),        // from CPU
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs        ),
    .cs         ( cs        ),
    .dtackn     ( dtackn    ),
    .dsn        ( dsn       ),
    .dma_n      ( dma_n     ),

    .ldout      ( line_dout ),  // shared with CPU data pins on original
    .lh         ( lh        ),  // lh[0] always zero for 16-bit memories
    .la         ( la        ),

    .x          ( x         ),
    .xh         ( xh        ),
    .y          ( y         ),
    .yh         ( yh        ),
    .ob         ( ob        ), // out of bonds, original pin: NOB

    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

jtframe_ram #(.AW(17),.DW(13),.SIMHEXFILE("reference_tilemap.hex"),.SYNFILE("reference_tilemap.hex")) u_rtmap (
    .clk        ( clk       ),
    .cen        ( /*rom_ok*/ cen /*1'b1*/       ),
    .addr       ( {vram_addr[18:10],vram_addr[8:1]}   ),
    .data       ( 13'b0  ),
    .we         ( 1'b0   ),
    .q          ( encoded)
);

jtframe_ram #(.AW(13),.DW(72),.SIMHEXFILE("compressed_tilemap.hex"),.SYNFILE("compressed_tilemap.hex")) u_ctmap (
    .clk        ( clk       ),
    .cen        ( /*cen*/ 1'b1       ),
    .addr       ( encoded   ),
    .data       ( 72'b0  ),
    .we         ( 1'b0   ),
    .q          ( tblock)
);



jtframe_linebuf_gate #(.RD_DLY(9'h15), .WR_STRT(9'h004D)/*, .RST_CT(9'h065)*/) u_linebuf(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      (  /*1'b1*/ cen2      ),
    .lvbl     ( 1'b1     ),
    .hs       (  hs       ),
    .cnt_cen  ( cen       ),
  //  New line writting
    .we         ( cen /*rom_ok*/  ),
    .hdump      ( hdump   ),
    .vdump      ( 9'h0    ),
  //  Previous line reading
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok  ),

    .pxl_data   ( {pal,dmux}   ),
    .pxl_dump   ( pxl       )
);

endmodule
