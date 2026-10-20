/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtroundu_text(
    input             rst,
    input             clk,
    input             pxl_cen,
    input       [8:0] h,
    input       [8:0] v,
    input       [9:0] scroll_y,
    output     [13:1] map_addr,
    input      [15:0] map_data,
    output reg [16:0] gfx_addr,
    input       [7:0] gfx_data,
    output      [6:0] pxl
);

wire [8:0] hdump = h >= 360 ? h + 9'd112 : h;
wire [8:0] vdump = h >= 336 ? (v == 271 ? 9'd0 : v + 9'd1) : v;
wire [14:0] rom_addr;
wire [7:0] tile_pxl;
reg [14:0] fetch_addr;
reg [2:0] step;
reg [7:0] plane0, plane1;
reg [31:0] rom_data;
reg ready;
wire rom_ok = ready && fetch_addr == rom_addr;

assign pxl = {tile_pxl[7:4],tile_pxl[2:0]};

jtframe_scroll #(
    .SIZE      ( 8  ),
    .VA        ( 13 ),
    .CW        ( 12 ),
    .PW        ( 8  ),
    .MAP_HW    ( 10 ),
    .MAP_VW    ( 9  ),
    .ROM_HFLIP ( 0  ),
    .HLOOP     ( 359 ),
    .HJUMP     ( 0  )
) u_scroll (
    .rst       ( rst                         ),
    .clk       ( clk                         ),
    .pxl_cen   ( pxl_cen                     ),
    .hs        ( !(h >= 336 && h < 368)      ),
    .vdump     ( vdump                       ),
    .hdump     ( hdump                       ),
    .blankn    ( 1'b1                        ),
    .flip      ( 1'b0                        ),
    .scrx      ( 10'd32                      ),
    .scry      ( scroll_y[8:0]               ),
    .vram_addr ( map_addr                    ),
    .code      ( map_data[11:0]              ),
    .pal       ( map_data[15:12]             ),
    .hflip     ( 1'b0                        ),
    .vflip     ( 1'b0                        ),
    .rom_addr  ( rom_addr                    ),
    .rom_data  ( rom_data                    ),
    .rom_cs    (                             ),
    .rom_ok    ( rom_ok                      ),
    .pxl       ( tile_pxl                    )
);

always @(posedge clk) begin
    if (rst) begin
        fetch_addr <= 0;
        step <= 0;
        gfx_addr <= 0;
        plane0 <= 0;
        plane1 <= 0;
        rom_data <= 0;
        ready <= 0;
    end else begin
        case (step)
            0: if (!rom_ok) begin
                fetch_addr <= rom_addr;
                gfx_addr <= {2'b00,rom_addr};
                ready <= 0;
                step <= 1;
            end
            1: step <= 2;
            2: begin
                plane0 <= gfx_data;
                gfx_addr <= {2'b01,fetch_addr};
                step <= 3;
            end
            3: step <= 4;
            4: begin
                plane1 <= gfx_data;
                gfx_addr <= {2'b10,fetch_addr};
                step <= 5;
            end
            5: step <= 6;
            6: begin
                rom_data <= {8'd0,gfx_data,plane1,plane0};
                ready <= 1;
                step <= 0;
            end
            default: step <= 0;
        endcase
    end
end

endmodule
