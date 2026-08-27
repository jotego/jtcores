/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2026 */

module jtcps3_scr #(
    parameter CMDW=96
)(
    input               rst,
    input               clk,
    input               draw,
    input       [CMDW-1:0] cmd,
    input       [ 8:0]  draw_v,

    input       [15:0]  tmap0_scrx,
    input       [15:0]  tmap0_scry,
    input       [ 5:0]  tmap0_ctrl,
    input       [ 6:0]  tmap0_lscr_base,
    input       [ 6:0]  tmap0_tile_base,

    input       [15:0]  tmap1_scrx,
    input       [15:0]  tmap1_scry,
    input       [ 5:0]  tmap1_ctrl,
    input       [ 6:0]  tmap1_lscr_base,
    input       [ 6:0]  tmap1_tile_base,

    input       [15:0]  tmap2_scrx,
    input       [15:0]  tmap2_scry,
    input       [ 5:0]  tmap2_ctrl,
    input       [ 6:0]  tmap2_lscr_base,
    input       [ 6:0]  tmap2_tile_base,

    input       [15:0]  tmap3_scrx,
    input       [15:0]  tmap3_scry,
    input       [ 5:0]  tmap3_ctrl,
    input       [ 6:0]  tmap3_lscr_base,
    input       [ 6:0]  tmap3_tile_base,

    output reg          busy,
    output reg          done,

    output              tiles_rd,
    output      [22:4]  tiles_addr,
    input       [127:0] tiles_data,
    input               tiles_ok,

    output              scrmap_rd,
    output      [18:2]  scrmap_addr,
    input       [31:0]  scrmap_data,
    input               scrmap_ok,

    input       [16:0]  buf_dout,
    output              wr_en,
    output      [ 9:0]  wr_addr,
    output      [16:0]  wr_pxl
);

wire        fetch_done, seg_valid, seg_take, draw_active;
wire [ 9:0] seg_screen_x;
wire [ 4:0] seg_left;
wire [ 3:0] seg_xoff;
wire [ 8:0] seg_pal;
wire        seg_tile_hflip, seg_alpha, seg_bpp;
wire [31:0] seg_row_data0, seg_row_data1, seg_row_data2, seg_row_data3;

always @(posedge clk) begin
    if( rst ) begin
        busy <= 1'b0;
        done <= 1'b0;
    end else begin
        done <= 1'b0;
        if( draw ) begin
            busy <= 1'b1;
        end
        if( busy && fetch_done && !seg_valid && !draw_active ) begin
            busy <= 1'b0;
            done <= 1'b1;
        end
    end
end

jtcps3_scr_fetch #(
    .CMDW( CMDW )
) u_fetch(
    .rst            ( rst             ),
    .clk            ( clk             ),
    .draw           ( draw            ),
    .cmd            ( cmd             ),
    .draw_v         ( draw_v          ),
    .tmap0_scrx     ( tmap0_scrx      ),
    .tmap0_scry     ( tmap0_scry      ),
    .tmap0_ctrl     ( tmap0_ctrl      ),
    .tmap0_lscr_base( tmap0_lscr_base ),
    .tmap0_tile_base( tmap0_tile_base ),
    .tmap1_scrx     ( tmap1_scrx      ),
    .tmap1_scry     ( tmap1_scry      ),
    .tmap1_ctrl     ( tmap1_ctrl      ),
    .tmap1_lscr_base( tmap1_lscr_base ),
    .tmap1_tile_base( tmap1_tile_base ),
    .tmap2_scrx     ( tmap2_scrx      ),
    .tmap2_scry     ( tmap2_scry      ),
    .tmap2_ctrl     ( tmap2_ctrl      ),
    .tmap2_lscr_base( tmap2_lscr_base ),
    .tmap2_tile_base( tmap2_tile_base ),
    .tmap3_scrx     ( tmap3_scrx      ),
    .tmap3_scry     ( tmap3_scry      ),
    .tmap3_ctrl     ( tmap3_ctrl      ),
    .tmap3_lscr_base( tmap3_lscr_base ),
    .tmap3_tile_base( tmap3_tile_base ),
    .fetch_done     ( fetch_done      ),
    .seg_valid      ( seg_valid       ),
    .seg_screen_x   ( seg_screen_x    ),
    .seg_left       ( seg_left        ),
    .seg_xoff       ( seg_xoff        ),
    .seg_pal        ( seg_pal         ),
    .seg_tile_hflip ( seg_tile_hflip  ),
    .seg_alpha      ( seg_alpha       ),
    .seg_bpp        ( seg_bpp         ),
    .seg_row_data0  ( seg_row_data0   ),
    .seg_row_data1  ( seg_row_data1   ),
    .seg_row_data2  ( seg_row_data2   ),
    .seg_row_data3  ( seg_row_data3   ),
    .seg_take       ( seg_take        ),
    .tiles_rd       ( tiles_rd        ),
    .tiles_addr     ( tiles_addr      ),
    .tiles_data     ( tiles_data      ),
    .tiles_ok       ( tiles_ok        ),
    .scrmap_rd      ( scrmap_rd       ),
    .scrmap_addr    ( scrmap_addr     ),
    .scrmap_data    ( scrmap_data     ),
    .scrmap_ok      ( scrmap_ok       )
);

jtcps3_scr_draw u_draw(
    .rst            ( rst             ),
    .clk            ( clk             ),
    .seg_valid      ( seg_valid       ),
    .seg_screen_x   ( seg_screen_x    ),
    .seg_left       ( seg_left        ),
    .seg_xoff       ( seg_xoff        ),
    .seg_pal        ( seg_pal         ),
    .seg_tile_hflip ( seg_tile_hflip  ),
    .seg_alpha      ( seg_alpha       ),
    .seg_bpp        ( seg_bpp         ),
    .seg_row_data0  ( seg_row_data0   ),
    .seg_row_data1  ( seg_row_data1   ),
    .seg_row_data2  ( seg_row_data2   ),
    .seg_row_data3  ( seg_row_data3   ),
    .seg_take       ( seg_take        ),
    .active         ( draw_active     ),
    .buf_dout       ( buf_dout        ),
    .wr_en          ( wr_en           ),
    .wr_addr        ( wr_addr         ),
    .wr_pxl         ( wr_pxl          )
);

endmodule
