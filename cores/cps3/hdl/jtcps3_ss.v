/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-3-2026 */

module jtcps3_ss(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               lhbl,
    input               lvbl,
    input       [ 9:0]  hdump,
    input       [ 9:0]  vdump,
    input       [ 9:0]  h_blank_end,
    input       [ 9:0]  v_blank_end,
    input       [15:0]  ss_vscroll,
    input       [ 7:0]  ss_pal_base,
    input       [ 1:0]  ss_flip,

    output      [13:1]  sschar_vaddr,
    input       [15:0]  sschar_vdata,
    output      [12:1]  ssmap_vaddr,
    input       [15:0]  ssmap_vdata,
    output      [12:1]  ssscr_vaddr,
    input       [15:0]  ssscr_vdata,

    output      [16:0]  pxl,
    input       [ 7:0]  debug_bus
);

`ifndef NOVIDEO
localparam [8:0] SS_H_OFFSET = 9'd61,
                 SS_V_OFFSET = 9'd2;

wire [ 8:0] scrolly;
wire [ 8:0] hdump_raw, vdump_raw, ss_vdump;
wire [ 8:0] hdump_eff, vdump_eff;
wire [ 8:0] row_idx;
wire [11:0] map_addr;
wire [11:0] char_addr;
wire        char_half, hflip, vflip;
wire [31:0] char_raw, r, char_sorted;
wire [15:0] scroll_y_neg;
wire [ 8:0] code;
wire [12:0] pal;
wire [ 7:0] rowscroll;

assign scroll_y_neg = -ss_vscroll;
assign scrolly      = { scroll_y_neg[8], 8'd0 };
assign vdump_raw    = vdump[8:0] - v_blank_end[8:0];
assign hdump_raw    = hdump[8:0] - SS_H_OFFSET + {1'b0,debug_bus};
assign ss_vdump     = vdump_raw - SS_V_OFFSET;
assign hdump_eff    = ss_flip[0] ? ~hdump_raw : hdump_raw;
assign vdump_eff    = ss_flip[1] ? ~ss_vdump  : ss_vdump;
assign row_idx      = ss_vdump + scrolly + 9'h1ff;
assign rowscroll   = ssscr_vdata[15:8] + 8'd7;
assign ssscr_vaddr = { 3'd0, row_idx };

assign code        = ssmap_vdata[8:0];
assign pal         = { ss_pal_base, ssmap_vdata[13:9] };
assign ssmap_vaddr = map_addr;
assign sschar_vaddr = { char_addr, char_half };
assign hflip       = ssmap_vdata[15] ^ ss_flip[0];
assign vflip       = ssmap_vdata[14] ^ ss_flip[1];

jtframe_bram_burst u_char_burst(
    .clk    ( clk          ),
    .sel    ( char_half    ),
    .din16  ( sschar_vdata ),
    .dout32 ( char_raw     )
);

assign r = {char_raw[0+:8], char_raw[8+:8],char_raw[16+:8],char_raw[24+:8]};
assign char_sorted={
      r[27], r[31], r[19], r[23], r[11], r[15], r[ 3], r[ 7],
      r[26], r[30], r[18], r[22], r[10], r[14], r[ 2], r[ 6],
      r[25], r[29], r[17], r[21], r[ 9], r[13], r[ 1], r[ 5],
      r[24], r[28], r[16], r[20], r[ 8], r[12], r[ 0], r[ 4]
};

jtframe_scroll #(
    .VA         ( 12        ),
    .CW         (  9        ),
    .PW         ( 17        ),
    .MAP_HW     (  9        ),
    .MAP_VW     (  9        ),
    .HJUMP      (  0        )
) u_scroll(
    .rst        ( rst                ),
    .clk        ( clk                ),
    .pxl_cen    ( pxl_cen            ),
    .hs         ( hs                 ),
    .vdump      ( vdump_eff          ),
    .hdump      ( hdump_eff          ),
    .blankn     ( 1'b1               ),
    .flip       ( 1'b0               ),
    .scrx       ( {1'b0, rowscroll}  ),
    .scry       ( scrolly            ),
    .vram_addr  ( map_addr           ),
    .code       ( code               ),
    .pal        ( pal                ),
    .hflip      ( hflip              ),
    .vflip      ( vflip              ),
    .rom_addr   ( char_addr          ),
    .rom_data   ( char_sorted        ),
    .rom_cs     (                    ),
    .rom_ok     ( 1'b1               ),
    .pxl        ( pxl                )
);

`else
assign sschar_vaddr = 13'd0;
assign ssmap_vaddr  = 12'd0;
assign ssscr_vaddr  = 12'd0;
assign pxl          = 17'd0;
`endif

endmodule
