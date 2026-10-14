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

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_shifter — tile-row ring buffer with a fine-scroll read tap
// ============================================================================
//
// Architecture borrowed from the Taito F2 TC0100SCN MiSTer core
// (Arcade-TaitoF2_MiSTer/rtl/tc0100scn.sv :: tc0100scn_shifter).  The
// TC0180VCU is a *different* chip, so only the rendering *technique* is
// reused — register/VRAM semantics stay TC0180VCU-specific.
//
// A small ring of LEN tile-rows is filled tile-by-tile AHEAD of the beam by
// the caller's prefetch FSM.  Read-out is a single `tap`:
//   tap_index = tap[hi]  → which buffered tile
//   tap_pixel = tap[lo]  → pixel within that tile (fine-scroll granularity)
// Because the ring holds several consecutive tiles, the tap walks across
// tile boundaries seamlessly, so arbitrary (sub-tile) horizontal scroll and
// per-row scroll are handled for free — no per-screen-slice straddle.
//
// flipX is applied at LOAD (the caller passes load_flip); the tap always
// reads left→right.  Pixels are 4bpp; load_pix holds TW pixels with pixel 0
// in bits [3:0].  Each tile also carries a 12-bit palette base (color_base
// already folded in by the caller); the tapped pen is OR-combined with it
// downstream by the colour mux.
// ============================================================================

module jttaitob_shifter #(
    parameter TW  = 16,                       // tile width in pixels (16 BG/FG, 8 TX)
    parameter LEN = 4                         // ring depth in tiles
)(
    input                                   clk,
    input                                   ce,

    // Load port (prefetch FSM)
    input                                   load,
    input  [$clog2(LEN)-1:0]                load_index,
    input  [11:0]                           load_pal,
    input  [TW*4-1:0]                        load_pix,    // pixel 0 in [3:0]
    input                                   load_flip,   // 1 = reverse pixel order

    // Read tap (= screen_x - scroll), low bits select the sub-tile pixel
    input  [$clog2(LEN)+$clog2(TW)-1:0]     tap,
    output reg [11:0]                       pal_out,
    output reg [ 3:0]                       pen_out
);

localparam IB = $clog2(LEN);
localparam PB = $clog2(TW);

reg [11:0]      pal_buf [0:LEN-1];
reg [TW*4-1:0]  pix_buf [0:LEN-1];

wire [IB-1:0] tap_index = tap[IB+PB-1:PB];
wire [PB-1:0] tap_pixel = tap[PB-1:0];

integer i;
always @(posedge clk) begin
    if (load) begin
        pal_buf[load_index] <= load_pal;
        if (load_flip) begin
            for (i = 0; i < TW; i = i + 1)
                pix_buf[load_index][4*((TW-1)-i) +: 4] <= load_pix[4*i +: 4];
        end else begin
            pix_buf[load_index] <= load_pix;
        end
    end
    if (ce) begin
        pal_out <= pal_buf[tap_index];
        pen_out <= pix_buf[tap_index][4*tap_pixel +: 4];
    end
end

endmodule
