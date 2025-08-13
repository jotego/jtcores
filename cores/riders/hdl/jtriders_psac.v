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
                       pxl_cen, pxl2_cen, // use cen instead (see below)
                       hs, vs, dtackn, enable, lvbl,
                       cs, // cs always writes
    input       [ 8:0] hdump, vdump,

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
    output reg     [20:0] rom_addr,
    input       [ 7:0] rom_data,
    output             rom_cs,
    input              rom_ok,

    output /*reg*/  [ 7:0] pxl,

    // IOCTL dump
    input      [4:0] ioctl_addr,
    output     [7:0] ioctl_din
);

reg  [ 7:0] buf_din;
wire [ 8:0] la, wr_addr, rd_addr;
wire [ 2:1] lh;
wire [12:0] x, y;
wire        xh,yh,ob;
wire [13:0] code;
wire        hflip, vflip, cen;
wire [ 3:0] /*pal,*/ vf, hf, dmux;
reg  [ 3:0] pal;
reg         rst2, we, cen_cen;

assign line_addr = {la[7:0],lh};
assign vram_addr = {tmap_bank,y[12:4], x[12:4]};
assign code      = vram_dout[13:0];
assign hflip     = 0;
assign vflip     = 0;
// assign pal       = vram_dout[14+:4];
assign vf        = {4{vflip}} ^ {y[3:0]};
assign hf        = {4{hflip}} ^ {x[3:0]};

assign rom_cs    = 1;
// assign rom_addr  = {code,vf,hf[3:1]}; // 13+4+4=21
assign dmux      = hf[0] ? rom_data[3:0] : rom_data[7:4];

// assign buf_din   = {pal,dmux};
initial cen_cen =0;
always @(posedge clk) rst2 <= rst | ~enable;
always @(posedge clk) cen_cen <= ~cen_cen;

always @(clk) // if(cen)
    begin
    if(rom_ok) buf_din <= {pal,dmux};
    if(vram_ok) begin
        rom_addr  <= {code,vf,hf[3:1]};
        pal       <= vram_dout[14+:4];
    end
    we <= rom_ok & vram_ok  || vram_dout==0;
end

jt053936 u_xy(
    .rst        ( rst2      ),
    .clk        ( clk       ),
    .cen        ( cen /*pxl2_cen*/ /*cen_cen & vram_ok*/       ),

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

jtframe_linebuf_gate #(.RD_DLY(9'h15), .WR_STRT(9'h025)) u_truelinebuf(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      (  /*cen_cen*/ /*1'b1*/ pxl2_cen /*cen*/       ),
    .lvbl     ( /*lvbl*/ 1'b1     ),
    .hs       (  hs       ),
    .cnt_cen (cen),
  //  New line writting
    .we         (   /*pxl2_cen & */ /*rom_ok*/ cen /*we*/    ),
    .hdump      ( hdump   ),
    .vdump      ( vdump   ),
  //  Previous line reading
    .rom_ok     ( rom_ok /*& vram_ok*/  /*|| vram_dout==0*/  ),
    .rom_cs     ( rom_cs    ),
    .pxl_data   ( buf_din   ),
    .pxl_dump   ( pxl       )
);


endmodule
