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
                       hs, vs, dtackn,
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
    output      [19:1] psclo_addr,
    input       [15:0] psclo_data,
    input              psclo_ok,
    output             psclo_cs,

    output      [17:1] pschi_addr,
    input       [15:0] pschi_data,
    input              pschi_ok,
    output             pschi_cs,
    // Tiles
    output      [20:0] rom_addr,
    input       [ 7:0] rom_data,
    output reg         rom_cs,
    input              rom_ok,

    output      [ 7:0] pxl,
    output             enc_done,

    // Tilemap 2x2
    output      [17:1] t2x2_addr,
    output      [15:0] t2x2_din,
    output      [ 1:0] t2x2_we,
    output      [17:1] tmap_addr,
    input       [15:0] encoded,


    // IOCTL dump
    input       [ 4:0] ioctl_addr,
    output      [ 7:0] ioctl_din
);

wire [71:0] tblock;
reg  [16:0] tmapaddr_l;
reg  [20:0] rom_addr_l;
wire [18:0] full_addr;
wire [ 8:0] la;
wire [ 2:1] lh;
reg  [13:0] code;
wire [12:0] x, y;
wire        xh,yh,ob;
wire        hflip, vflip, cen;
wire [ 7:0] buf_din;
reg  [ 3:0] pal;
wire [ 3:0] vf, hf, dmux;
wire [ 1:0] tile;
reg         cen2;
// encoder
wire        dec_we, t2x2_we_pre;
wire [12:0] dec_addr;
wire [71:0] dec_dout, dec_din;
reg  [ 4:0] tmap_sh;

assign line_addr = {la[7:0],lh};
assign full_addr = {tmap_bank,y[12:4], x[12:4]};
assign tmap_addr = {full_addr[18:10],full_addr[8:1]};
assign tile      = {y[4],x[4]};
assign hflip     = 0;
assign vflip     = 0;
assign vf        = {4{vflip}} ^ {y[3:0]};
assign hf        = {4{hflip}} ^ {x[3:0]};

assign rom_addr  = {code,vf,hf[3:1]}; // 13+4+4=21
assign dmux      = hf[0] ? rom_data[3:0] : rom_data[7:4];
assign buf_din   = ob    ? 8'b0          : {pal,dmux};
assign t2x2_we   = {2{t2x2_we_pre}};

initial cen2 = 0;

always @(posedge clk) begin
    cen2 <= ~cen2;

    tmapaddr_l <= tmap_addr;
    rom_cs     <= tmapaddr_l == tmap_addr;
end

always @(*) begin
    case(tile)
        0: {pal, code} = tblock[ 0+:18];
        1: {pal, code} = tblock[18+:18];
        2: {pal, code} = tblock[36+:18];
        3: {pal, code} = tblock[54+:18];
    endcase
end
/* verilator tracing_on */
jt053936 u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),

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
/* verilator tracing_on */
jtglfgreat_encoder u_encoder(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .done       ( enc_done  ),
    // SDRAM
    .psclo_addr ( psclo_addr),
    .psclo_data ( psclo_data),
    .psclo_ok   ( psclo_ok  ),
    .psclo_cs   ( psclo_cs  ),

    .pschi_addr ( pschi_addr),
    .pschi_data ( pschi_data),
    .pschi_ok   ( pschi_ok  ),
    .pschi_cs   ( pschi_cs  ),
    // Compressed tilemap in VRAM
    .t2x2_addr  ( t2x2_addr ),
    .t2x2_din   ( t2x2_din  ),
    .t2x2_we    (t2x2_we_pre),
    // Decoder
    .dec_addr   ( dec_addr  ),
    .dec_dout   ( dec_dout  ),
    .dec_din    ( dec_din   ),
    .dec_we     ( dec_we    )
);
/* verilator tracing_off */
jtframe_dual_ram #(.AW(13),.DW(72),.SIMHEXFILE("decoder.hex")) u_decoder (
    // Port 0 - programming during power up
    .clk0       ( clk       ),
    .addr0      ( dec_addr  ),
    .data0      ( dec_din   ),
    .we0        ( dec_we    ),
    .q0         ( dec_dout  ),
    // Port 1 - regular access during gameplay
    .clk1       ( clk       ),
    .addr1      (encoded[12:0]),
    .data1      ( 72'b0     ),
    .we1        ( 1'b0      ),
    .q1         ( tblock    )
);

jtframe_linebuf_gate #(.RD_DLY(15), .RST_CT(9'h041)) u_linebuf(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .cen      ( cen2      ),
    .lvbl     ( 1'b1      ),
    .hs       ( hs        ),
    .cnt_cen  ( cen       ),
  //  New line writting
    .we       ( cen       ),
    .hdump    ( hdump     ),
    .vdump    ( 9'h0      ),
  //  Previous line reading
    .rom_cs   ( rom_cs    ),
    .rom_ok   ( rom_ok    ),

    .pxl_data ( buf_din   ),
    .pxl_dump ( pxl       )
);

endmodule
