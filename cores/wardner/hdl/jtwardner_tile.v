/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * One tilemap layer, 64 tiles wide and 2^MAP_VW pixels high. While the
 * current tile is shown from `cur`, the next one along the row is fetched
 * into `nxt`: the VRAM word first, then the ROM row it selects.
 */

module jtwardner_tile #(parameter
    VA=12, MAP_VW=9, CW=12, PALW=4, ROMAW=15, BPP=4,
    BANK_VRAM=0,   // bank bit is the VRAM address MSB (background)
    BANK_CODE=0    // bank bit extends the tile code (foreground)
)(
    input             rst, clk, pxl_cen, hact,
    input      [ 8:0] heff, vdump,
    input      [ 8:0] scrx,
    input [MAP_VW-1:0] scry,
    input             flip,
    input             bank,
    output reg [VA-1:0] vram_addr,
    input      [15:0] vram_q,
    output reg [ROMAW-1:0] rom_addr,
    input      [31:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,
    output [PALW+3:0] pxl
);

// Where the pixel at screen position (heff, vdump) sits in the unflipped
// pixmap. Flipping mirrors the map end to end and swaps in MAME's second
// scroll offsets; folding both into the coordinate leaves the map size out of
// the result (see render_ref.py for the derivation), so the only difference
// is that the scan now walks the map backwards.
wire [8:0] py9 = flip ? (9'd482 + {{(9-MAP_VW){1'b0}}, scry} - vdump)
                      : (vdump + 9'd30 + {{(9-MAP_VW){1'b0}}, scry});

wire [8:0]        px = flip ? (9'd453 + scrx - heff) : (heff + 9'd55 + scrx);
wire [MAP_VW-1:0] py = py9[MAP_VW-1:0];
wire [5:0]        col_nxt = flip ? px[8:3] - 6'd1 : px[8:3] + 6'd1;
// first and last pixel of a tile in scan order, which swap when flipped
wire [2:0]        px_first = flip ? 3'd7 : 3'd0;
wire [2:0]        px_last  = flip ? 3'd0 : 3'd7;

reg [31:0]     cur, nxt;
reg [PALW-1:0] cur_pal, nxt_pal;
reg [ 2:0]     st;
reg [15:0]     code;

// leftmost pixel is the MSB of each plane byte
wire [2:0] sh = ~px[2:0];
wire [7:0] cur3 = cur[31:24], cur2 = cur[23:16], cur1 = cur[15:8], cur0 = cur[7:0];
// MAME's gfx_layout lists planeoffset from the most significant pen bit down:
// charlayout's { RGN_FRAC(0,3), RGN_FRAC(1,3), RGN_FRAC(2,3) } makes the first
// slice of the region pen bit 2, not bit 0, and tilelayout and the SCU's
// spritelayout do the same with four planes. The ROM keeps the region order in
// the low byte, so the pen is assembled from cur0 downwards, not upwards.
wire [3:0] pen = BPP==3 ? { 1'b0, cur0[sh], cur1[sh], cur2[sh] }
                        : {       cur0[sh], cur1[sh], cur2[sh], cur3[sh] };
assign pxl = { cur_pal, pen };

wire [VA-1:0]    vaddr_nxt;
wire [ROMAW-1:0] raddr;
generate
    if( BANK_VRAM ) begin : gen_vram_bank
        assign vaddr_nxt = { bank, py[MAP_VW-1:3], col_nxt };
    end else begin : gen_vram_plain
        assign vaddr_nxt = {       py[MAP_VW-1:3], col_nxt };
    end
    if( BANK_CODE ) begin : gen_code_bank
        assign raddr = { bank, code[CW-1:0], py[2:0] };
    end else begin : gen_code_plain
        assign raddr = {       code[CW-1:0], py[2:0] };
    end
endgenerate

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st <= 0; rom_cs <= 0; cur <= 0; nxt <= 0; cur_pal <= 0; nxt_pal <= 0;
        code <= 0; vram_addr <= 0; rom_addr <= 0;
    end else begin
        if( pxl_cen && px[2:0] == px_last && hact ) begin
            cur     <= nxt;
            cur_pal <= nxt_pal;
        end
        case( st )
            0: if( pxl_cen && px[2:0] == px_first && hact ) begin
                vram_addr <= vaddr_nxt;
                st <= 1;
            end
            1: st <= 2;                         // VRAM read latency
            2: begin
                code <= vram_q;
                st   <= 3;
            end
            3: begin
                rom_addr <= raddr;
                rom_cs   <= 1;
                st       <= 4;
            end
            4: if( rom_ok ) begin
                nxt     <= rom_data;
                nxt_pal <= code[15:16-PALW];
                rom_cs  <= 0;
                st      <= 0;
            end
            default: st <= 0;
        endcase
    end
end

endmodule
