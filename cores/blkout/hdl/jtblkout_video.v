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

    Block Out video: vtimer -> framebuffer scanout (two-plane composite) ->
    1bpp overlay (pen 512) -> palette (xBGR-444) -> RGB. Visible 320x240.
*/

module jtblkout_video(
    input               rst,
    input               clk,
    input               pxl_cen,

    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,

    // pen-512 dynamic colour (from main, 0x280002)
    input        [11:0] frontcol,

    // back framebuffer — SDRAM bank 2 video read
    output       [17:1] fbrd_addr,
    output              fbrd_cs,
    input        [15:0] fbrd_data,
    input               fbrd_ok,

    // palette BRAM video read (512 x xBGR-444)
    output       [ 8:0] palrd_addr,
    input        [15:0] pal_data,

    // front 1bpp overlay BRAM video read
    output       [13:0] fvrd_addr,
    input        [15:0] fvram_data,

    output reg   [ 3:0] red,
    output reg   [ 3:0] green,
    output reg   [ 3:0] blue
);

wire [8:0] hdump, vdump, vrender, vrender1;
wire [8:0] fb_pxl;

// 8 MHz pxl, H-total 512 (15.625 kHz), V-total 269 -> 58.1 Hz (board is 58 Hz).
jtframe_vtimer #(
    .V_START  ( 9'd0   ),
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd268 ),   // VCNT_END=268 -> V-total 269
    .VS_START ( 9'd250 ),
    .VS_END   ( 9'd253 ),
    .HB_END   ( 9'd511 ),   // HCNT_END=511 -> H-total 512
    .HB_START ( 9'd319 ),
    .HS_START ( 9'd350 ),
    .HS_END   ( 9'd377 )
) u_vtimer(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .vdump    ( vdump    ),
    .vrender  ( vrender  ),
    .vrender1 ( vrender1 ),
    .H        ( hdump    ),
    .Hinit    (          ),
    .Vinit    (          ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

jtblkout_fb u_fb(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hdump      ( hdump     ),
    .vrender    ( vrender   ),
    .HS         ( HS        ),
    .fbrd_addr  ( fbrd_addr ),
    .fbrd_cs    ( fbrd_cs   ),
    .fbrd_data  ( fbrd_data ),
    .fbrd_ok    ( fbrd_ok   ),
    .fb_pxl     ( fb_pxl    )
);

wire [8:0] hovl = hdump + 9'd2;

// Overlay line buffer: the CPU rewrites the 1bpp overlay VRAM continuously, so
// its 64 words for the next line are fetched a line ahead (during HBLANK) and
// scanned out from the buffer, like the bitmap.
reg        HSov, ov_busy, ov_ph;
reg [ 5:0] ov_col;
reg [ 7:0] ov_row;
reg [ 7:0] ovlb_din;
reg [ 5:0] ovlb_wa;
reg        ovlb_we;
wire [7:0] ovlb_q;

assign fvrd_addr = { ov_row, ov_col };   // 8+6 = 14 bits, swept during fetch

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        HSov<=0; ov_busy<=0; ov_col<=0; ov_ph<=0; ovlb_we<=0; ov_row<=0;
    end else begin
        HSov    <= HS;
        ovlb_we <= 0;
        if( HS && !HSov ) begin           // new line: fetch overlay for vrender+10
            ov_row  <= vrender[7:0] + 8'd10;
            ov_col  <= 0;
            ov_ph   <= 0;
            ov_busy <= 1;
        end else if( ov_busy ) begin
            if( ov_ph==1'b0 ) ov_ph<=1'b1;   // 1-cycle BRAM read latency
            else begin
                ovlb_din <= fvram_data[7:0];   // low byte = 8 overlay pixels
                ovlb_wa  <= ov_col;
                ovlb_we  <= 1'b1;
                ov_ph    <= 1'b0;
                if( ov_col==6'd63 ) ov_busy<=1'b0;
                else ov_col <= ov_col + 6'd1;
            end
        end
    end
end

// jtframe_linebuf owns the buffer swap (on ~HS falling = HS rising).
jtframe_linebuf #(.DW(8),.AW(6)) u_ovlb(
    .clk     ( clk        ),
    .LHBL    ( ~HS        ),
    .wr_addr ( ovlb_wa    ),
    .wr_data ( ovlb_din   ),
    .we      ( ovlb_we    ),
    .rd_addr ( hovl[8:3]  ),
    .rd_data ( ovlb_q     ),
    .rd_gated(            )
);

// pixel pipeline: pen -> palette / buffered overlay -> RGB
assign palrd_addr = fb_pxl;                       // 9-bit pen index
reg       overlay_1;
// Sample the overlay bit with the same hovl used for the byte address, then
// register once to line up with fb_pxl.
always @(posedge clk) if( pxl_cen ) overlay_1 <= ovlb_q[7 - hovl[2:0]];

wire [11:0] color = overlay_1 ? frontcol : pal_data[11:0];  // xBGR-444
wire blank = ~(LHBL & LVBL);
always @(posedge clk) if( pxl_cen ) begin
    if( blank ) begin red<=0; green<=0; blue<=0; end
    else begin
        red   <= color[ 3:0];
        green <= color[ 7:4];
        blue  <= color[11:8];
    end
end

endmodule
