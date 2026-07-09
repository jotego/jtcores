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

    Block Out video (clk 48 MHz). vtimer -> framebuffer scanout (jtblockout_fb,
    two-plane composite) -> 1bpp overlay (pen 512) -> palette (xBGR-444) -> RGB.
    Timing 7 MHz pxl, htotal 448 / hvis 320, vtotal 272 / vvis 240. DRAFT V
    offset + H/pixel-pipeline offsets (tune vs MAME screen.png).
*/

module jtblockout_video(
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
wire       lhbl_v, lvbl_v;

assign LHBL = lhbl_v;
assign LVBL = lvbl_v;

// 8 MHz pxl (24 MHz video xtal / 3; PXLCLK=8 = 48/6). Real board timing:
// H-total 512 (15.625 kHz H-rate), V-total 269 -> 8M/(512*269) = 58.1 Hz,
// matching the board's measured 58 Hz VSync. Visible 320x240.
// The 10px-up / 3px-left image offset is applied in jtblockout_fb (fy+10, hdump+3).
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
    .LHBL     ( lhbl_v   ),
    .LVBL     ( lvbl_v   ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

jtblockout_fb u_fb(
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

// ── overlay line buffer ─────────────────────────────────────────────────────
// The CPU rewrites the 1bpp overlay VRAM continuously (fill/erase loop). Reading
// it live during scanout collided with the in-flight fills (read 0xffff -> the
// pen-512 white flood). So fetch the line's 64 overlay words into a buffer a
// line ahead (during HBLANK) and scan out from that, exactly like the bitmap.
reg        ov_disp, HSov, ov_busy, ov_ph;
reg [ 5:0] ov_col;
reg [ 7:0] ov_row;
reg [ 7:0] ovlb_din;
reg [ 6:0] ovlb_wa;
reg        ovlb_we;
wire [7:0] ovlb_q;

assign fvrd_addr = { ov_row, ov_col };   // 8+6 = 14 bits, swept during fetch

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ov_disp<=0; HSov<=0; ov_busy<=0; ov_col<=0; ov_ph<=0; ovlb_we<=0; ov_row<=0;
    end else begin
        HSov    <= HS;
        ovlb_we <= 0;
        if( HS && !HSov ) begin           // new line: fetch overlay for vrender+10
            ov_disp <= ~ov_disp;
            ov_row  <= vrender[7:0] + 8'd10;
            ov_col  <= 0;
            ov_ph   <= 0;
            ov_busy <= 1;
        end else if( ov_busy ) begin
            if( ov_ph==1'b0 ) ov_ph<=1'b1;   // 1-cycle BRAM read latency
            else begin
                ovlb_din <= fvram_data[7:0];   // low byte = 8 overlay pixels
                ovlb_wa  <= { ~ov_disp, ov_col };
                ovlb_we  <= 1'b1;
                ov_ph    <= 1'b0;
                if( ov_col==6'd63 ) ov_busy<=1'b0;
                else ov_col <= ov_col + 6'd1;
            end
        end
    end
end

jtframe_dual_ram #(.DW(8),.AW(7)) u_ovlb(
    .clk0 ( clk       ), .data0( ovlb_din ), .addr0( ovlb_wa            ), .we0( ovlb_we ), .q0(       ),
    .clk1 ( clk       ), .data1( 8'd0     ), .addr1( {ov_disp,hovl[8:3]}), .we1( 1'b0    ), .q1( ovlb_q )
);

// ── pixel pipeline: pen -> palette / buffered overlay -> RGB ─────────────────
assign palrd_addr = fb_pxl;                       // 9-bit pen index
reg       overlay_1;
// Sample the overlay bit with the SAME hovl used for the byte address (ovlb_q),
// registered once to line up with fb_pxl. (Delaying only the bit index shifts
// it 1px inside each 8px byte -> dropped/dotted wireframe pixels.)
always @(posedge clk) if( pxl_cen ) overlay_1 <= ovlb_q[7 - hovl[2:0]];

wire [11:0] color = overlay_1 ? frontcol : pal_data[11:0];  // xBGR-444
// Blank keys off the CURRENT lhbl/lvbl (only the final rgb register delays it),
// not a doubly-delayed copy — else it eats the first ~2 visible columns while
// the +2 read-ahead already has valid data there.
wire blank = ~(lhbl_v & lvbl_v);
always @(posedge clk) if( pxl_cen ) begin
    if( blank ) begin red<=0; green<=0; blue<=0; end
    else begin
        red   <= color[ 3:0];
        green <= color[ 7:4];
        blue  <= color[11:8];
    end
end

endmodule
