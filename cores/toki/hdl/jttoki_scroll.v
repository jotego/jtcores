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
    Date: 1-7-2025 */

module jttoki_scroll(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             cabal,

    input       [8:0] hdump,
    input       [8:0] vdump,
    input             hs,
    input       [7:0] line_number,

    input       [8:0] scroll_x,
    input       [8:0] scroll_y,
    input             edge_fix_en,

    output     [10:1] vram_addr,
    input      [15:0] vram_out,

    input      [31:0] gfx_data,
    input             gfx_ok,
    output     [18:2] gfx_addr,
    output            gfx_cs,

    output      [7:0] pxl
);

localparam [8:0] DEEP_IN_HB = 9'h120;
localparam [1:0] FILL_IDLE  = 2'd0,
                 FILL_VRAM  = 2'd1,
                 FILL_WAIT  = 2'd2,
                 FILL_ROM   = 2'd3;

wire [31:0] sorted, cabal_sorted, cabal_gfx_sort_data;
wire [ 7:0] pre_pxl, cabal_pxl;
wire [11:0] code = vram_out[11:0];
wire [ 3:0] pal  = vram_out[15:12];
wire [ 8:0] scrx = scroll_x + 9'd8;
wire        scroll_cen = pxl_cen && (!edge_fix_en || hdump < 9'h180);
wire        group_start = pxl_cen && hdump[2:0] == 3'd0;
wire        line_start  = group_start && hdump[7:0] == 8'd0;

wire [10:1] toki_vram_addr;
wire [18:2] toki_gfx_addr;
wire        toki_gfx_cs;
reg  [10:1] cabal_vram_addr;
reg  [18:2] cabal_gfx_addr;
reg         cabal_gfx_cs;

reg  [31:0] pxl_data = 32'd0;
reg  [31:0] group_data [0:1][0:31];
reg  [ 4:0] fill_slot, rom_slot;
reg  [ 3:0] group_pal  [0:1][0:31];
reg  [ 3:0] cur_pal = 4'd0;
reg  [ 3:0] fill_row, rom_pal;
reg  [ 8:0] fill_line;
reg         display_bank, fill_bank;
reg         vram_pending, rom_pending;
reg  [ 1:0] fill_state;
integer     i;

assign sorted = { gfx_data[12], gfx_data[13], gfx_data[14], gfx_data[15],
                  gfx_data[28], gfx_data[29], gfx_data[30], gfx_data[31],
                  gfx_data[ 8], gfx_data[ 9], gfx_data[10], gfx_data[11],
                  gfx_data[24], gfx_data[25], gfx_data[26], gfx_data[27],
                  gfx_data[ 4], gfx_data[ 5], gfx_data[ 6], gfx_data[ 7],
                  gfx_data[20], gfx_data[21], gfx_data[22], gfx_data[23],
                  gfx_data[ 0], gfx_data[ 1], gfx_data[ 2], gfx_data[ 3],
                  gfx_data[16], gfx_data[17], gfx_data[18], gfx_data[19] };

assign cabal_gfx_sort_data = { gfx_data[23:16], gfx_data[31:24], gfx_data[7:0], gfx_data[15:8] };

assign cabal_sorted = {
    cabal_gfx_sort_data[ 4], cabal_gfx_sort_data[ 5], cabal_gfx_sort_data[ 6], cabal_gfx_sort_data[ 7],
    cabal_gfx_sort_data[20], cabal_gfx_sort_data[21], cabal_gfx_sort_data[22], cabal_gfx_sort_data[23],
    cabal_gfx_sort_data[ 0], cabal_gfx_sort_data[ 1], cabal_gfx_sort_data[ 2], cabal_gfx_sort_data[ 3],
    cabal_gfx_sort_data[16], cabal_gfx_sort_data[17], cabal_gfx_sort_data[18], cabal_gfx_sort_data[19],
    cabal_gfx_sort_data[12], cabal_gfx_sort_data[13], cabal_gfx_sort_data[14], cabal_gfx_sort_data[15],
    cabal_gfx_sort_data[28], cabal_gfx_sort_data[29], cabal_gfx_sort_data[30], cabal_gfx_sort_data[31],
    cabal_gfx_sort_data[ 8], cabal_gfx_sort_data[ 9], cabal_gfx_sort_data[10], cabal_gfx_sort_data[11],
    cabal_gfx_sort_data[24], cabal_gfx_sort_data[25], cabal_gfx_sort_data[26], cabal_gfx_sort_data[27]
};

assign cabal_pxl[7:4] = cur_pal;
assign cabal_pxl[0]   = pxl_data[ 7];
assign cabal_pxl[1]   = pxl_data[15];
assign cabal_pxl[2]   = pxl_data[23];
assign cabal_pxl[3]   = pxl_data[31];

assign vram_addr = cabal ? cabal_vram_addr : toki_vram_addr;
assign gfx_addr  = cabal ? cabal_gfx_addr  : toki_gfx_addr;
assign gfx_cs    = cabal ? cabal_gfx_cs    : toki_gfx_cs;
assign pxl       = cabal ? cabal_pxl       : pre_pxl;

jtframe_scroll #(
    .SIZE   ( 16 ),
    .PW     ( 8  ),
    .CW     ( 12 ),
    .VA     ( 10 ),
    .HJUMP  ( 0  ),
    .HLOOP  ( DEEP_IN_HB )
) u_scroll(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( scroll_cen ),

    .hs         ( hs         ),
    .vdump      ( vdump      ),
    .hdump      ( hdump      ),
    .blankn     ( 1'b1       ),
    .flip       ( 1'b0       ),
    .scrx       ( scrx       ),
    .scry       ( scroll_y   ),

    .vram_addr  ( toki_vram_addr ),

    .code       ( code       ),
    .pal        ( pal        ),
    .hflip      ( 1'b0       ),
    .vflip      ( 1'b0       ),

    .rom_addr   ( toki_gfx_addr ),
    .rom_data   ( sorted     ),
    .rom_cs     ( toki_gfx_cs ),
    .rom_ok     ( gfx_ok     ),

    .pxl        ( pre_pxl    )
);

always @(posedge clk) begin
    if (rst) begin
        cabal_vram_addr <= 10'd0;
        cabal_gfx_addr  <= 17'd0;
        cabal_gfx_cs    <= 1'b0;
        pxl_data        <= 32'd0;
        cur_pal         <= 4'd0;
        fill_slot       <= 5'd0;
        rom_slot        <= 5'd0;
        fill_row        <= 4'd0;
        fill_line       <= 9'd0;
        rom_pal         <= 4'd0;
        display_bank    <= 1'b0;
        fill_bank       <= 1'b1;
        vram_pending    <= 1'b0;
        rom_pending     <= 1'b0;
        fill_state      <= FILL_IDLE;
        for (i = 0; i < 32; i = i + 1) begin
            group_data[0][i] <= 32'd0;
            group_data[1][i] <= 32'd0;
            group_pal[0][i]  <= 4'd0;
            group_pal[1][i]  <= 4'd0;
        end
    end else begin
        if (group_start) begin
            pxl_data <= group_data[display_bank][hdump[7:3]];
            cur_pal  <= group_pal[display_bank][hdump[7:3]];
        end else if (pxl_cen) begin
            pxl_data <= pxl_data << 1;
        end

        if (line_start) begin
            display_bank <= fill_bank;
            fill_bank    <= ~fill_bank;
            fill_line    <= vdump;
            fill_row     <= vdump[3:0];
            fill_slot    <= 5'd0;
            fill_state   <= FILL_VRAM;
            vram_pending <= 1'b0;
            rom_pending  <= 1'b0;
            cabal_gfx_cs <= 1'b0;
        end

        case (fill_state)
            FILL_VRAM: begin
                cabal_vram_addr <= {2'd0, fill_line[7:4], fill_slot[4:1]};
                fill_state      <= FILL_WAIT;
            end

            FILL_WAIT: begin
                vram_pending <= 1'b1;
                fill_state   <= FILL_ROM;
            end

            FILL_ROM: begin
                if (vram_pending) begin
                    cabal_gfx_addr <= {vram_out[11:0], fill_slot[0], fill_row};
                    cabal_gfx_cs   <= 1'b1;
                    rom_slot       <= fill_slot;
                    rom_pal        <= vram_out[15:12];
                    rom_pending    <= 1'b1;
                    vram_pending   <= 1'b0;
                end else if (rom_pending && gfx_ok) begin
                    group_data[fill_bank][rom_slot] <= cabal_sorted;
                    group_pal[fill_bank][rom_slot]  <= rom_pal;
                    cabal_gfx_cs                    <= 1'b0;
                    rom_pending                     <= 1'b0;
                    if (fill_slot == 5'd31) begin
                        fill_state <= FILL_IDLE;
                    end else begin
                        fill_slot  <= fill_slot + 5'd1;
                        fill_state <= FILL_VRAM;
                    end
                end
            end

            default: begin
                cabal_gfx_cs <= 1'b0;
            end
        endcase

        if (!rom_pending && fill_state != FILL_ROM)
            cabal_gfx_cs <= 1'b0;
    end
end

endmodule
