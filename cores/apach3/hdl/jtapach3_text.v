/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_text(
    input             rst,
    input             clk,
    input             pxl_cen,
    input       [8:0] h,
    input       [8:0] v,
    output     [12:1] map_addr,
    input      [15:0] map_data,
    output reg [16:2] gfx_addr,
    input      [31:0] gfx_data,
    output reg        gfx_cs,
    input             gfx_ok,
    output      [6:0] pxl
);

wire [8:0] hdump = h >= 360 ? h + 9'd112 : h;
wire [8:0] vdump = h >= 336 ? (v == 279 ? 9'd0 : v + 9'd1) : v;
wire [14:0] rom_addr;
wire [7:0] tile_pxl;
reg [14:0] fetch_addr;
reg [31:0] rom_data;
reg ready;
wire rom_ok = ready && fetch_addr == rom_addr;

assign pxl = {tile_pxl[7:4],tile_pxl[2:0]};

jtframe_scroll #(
    .SIZE      ( 8   ),
    .VA        ( 12  ),
    .CW        ( 12  ),
    .PW        ( 8   ),
    .MAP_HW    ( 9   ),
    .MAP_VW    ( 9   ),
    .ROM_HFLIP ( 0   ),
    .HLOOP     ( 359 ),
    .HJUMP     ( 0   )
) u_scroll (
    .rst       ( rst                    ),
    .clk       ( clk                    ),
    .pxl_cen   ( pxl_cen                ),
    .hs        ( !(h >= 336 && h < 368) ),
    .vdump     ( vdump                  ),
    .hdump     ( hdump                  ),
    .blankn    ( 1'b1                   ),
    .flip      ( 1'b0                   ),
    .scrx      ( 9'd34                  ),
    .scry      ( 9'd0                   ),
    .vram_addr ( map_addr               ),
    .code      ( map_data[11:0]         ),
    .pal       ( map_data[15:12]        ),
    .hflip     ( 1'b0                   ),
    .vflip     ( 1'b0                   ),
    .rom_addr  ( rom_addr               ),
    .rom_data  ( rom_data               ),
    .rom_cs    (                        ),
    .rom_ok    ( rom_ok                 ),
    .pxl       ( tile_pxl               )
);

always @(posedge clk) begin
    if (rst) begin
        fetch_addr <= 0;
        gfx_addr <= 0;
        gfx_cs <= 0;
        rom_data <= 0;
        ready <= 0;
    end else if (gfx_cs) begin
        if (gfx_ok) begin
            rom_data <= {8'd0,gfx_data[23:0]};
            gfx_cs <= 0;
            ready <= 1;
        end
    end else if (!rom_ok) begin
        fetch_addr <= rom_addr;
        gfx_addr <= rom_addr;
        gfx_cs <= 1;
        ready <= 0;
    end
end

endmodule
