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
    Date: 7-11-2022 */

// This is tile map section of the SETA chip
// This one uses an independent line buffer
// from that of the sprites

module jtkiwi_tilemap(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               tm_cen,

    input               hs,
    input               flip,
    input               page,
    input      [15:0]   col_xmsb,
    input      [ 3:0]   col_cfg,
    input      [ 1:0]   col0,

    output     [11:0]   tm_addr,
    input      [15:0]   tm_data,

    // Column scroll
    output     [ 7:0]   col_addr,
    input      [ 7:0]   col_data,

    output     [20:2]   rom_addr,
    output              rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    input      [ 8:0]   vrender,
    input      [ 8:0]   hdump,
    output     [ 8:0]   pxl,

    input      [ 7:0]   debug_bus
);

reg         line, done, hsl, video_en;
reg  [ 4:0] col_cnt, dr_pal;
reg  [ 3:0] dr_ysub, col_end;
reg  [ 8:0] eff_h, eff_v, dr_xpos;
reg  [ 7:0] yscr;
reg  [ 8:0] xscr;
wire [ 8:0] vf, raw_pxl;
reg  [ 1:0] st;
reg         dr_draw, dr_hflip, dr_vflip, hflip, vflip;
reg  [13:0] dr_code, code;
wire        dr_busy;
wire [ 8:0] buf_din, buf_addr;
wire        buf_we;

assign tm_addr  = { page, 1'b1, st[0], eff_h[8:5], eff_v[7:4], eff_h[4] }; // 1 + 1 + 1 + 4 + 5 = 12
assign col_addr = { col_cnt[4:1], 1'd0, st[0], 2'd0 };
assign vf       = {9{~flip}} ^ vrender;
assign pxl      = video_en ? raw_pxl : 9'd0;

always @* begin
    eff_v = vf + { 1'b0, yscr };
    eff_h = { col_cnt + {col0,3'd0}, 4'b0 };
end

// Columns are 32-pixel wide
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        col_cnt  <= 0;
        line     <= 0;
        hsl      <= 0;
        dr_code  <= 0;
        dr_hflip <= 0;
        dr_vflip <= 0;
        dr_xpos  <= 0;
        dr_ysub  <= 0;
        video_en <= 0;
    end else begin
        hsl <= hs;
        dr_draw <= 0;
        if ( hs & ~hsl ) line <= ~line;
        if( hs || (vrender>9'hf0 && vrender<8) || col_cfg==0 ) begin
            col_cnt  <= 0;
            done     <= col_cfg==0; // don't do anything for col_cfg==0
            video_en <= col_cfg!=0;
            st       <= 0;
            dr_draw  <= 0;
            col_end  <= col_cfg==1 ? 4'hf : col_cfg-4'd1;
        end else if( !done && tm_cen ) begin
            st <= st + 1'd1;
            case( st )
                0: yscr <= col_data;
                1: begin
                    xscr <= { col_xmsb[col_cnt[4:1]], col_data };
                end
                2: begin
                    { hflip, vflip } <= tm_data[15:14];
                    code <= tm_data[13:0];
                end
                3: begin
                    if( !dr_busy )  begin
                        dr_draw  <= 1;
                        dr_code  <= code;
                        dr_hflip <= hflip^flip;
                        dr_vflip <= vflip;
                        dr_pal   <= tm_data[11+:5]; //{1'b1, tm_data[12:9] }; // some games seem to use the fifth bit too. This is probably some config setting unexplored by MAME
                        dr_xpos  <= { 4'd0, col_cnt[0], 4'd0 } + xscr;
                        dr_ysub  <= eff_v[3:0];
                        col_cnt  <=  col_cnt + 1'd1;
                        done     <= col_cnt[4:1]==col_end && col_cnt[0];
                    end else begin
                        st <= st;
                    end
                end
            endcase
        end
    end
end

jtkiwi_draw #(.SWAP_HALVES(1'b1)) u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .draw       ( dr_draw       ),
    .busy       ( dr_busy       ),
    .code       ( dr_code       ),
    .pal        ( dr_pal        ),
    .hflip      ( dr_hflip      ),
    .vflip      ( dr_vflip      ),
    .xpos       ( dr_xpos       ),
    .ysub       ( dr_ysub       ),
    .flip       ( flip          ),

    .rom_addr   ( rom_addr      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .rom_data   ( rom_data      ),

    .buf_addr   ( buf_addr      ),
    .buf_we     ( buf_we        ),
    .buf_din    ( buf_din       ),
    .debug_bus  ( 8'd0          )
    //.debug_bus  ( debug_bus     )
);

// The tilemap is made of transparent tiles
// that can be drawn on top of other ones. That's
// how the sky in TNZS intro scene is drawn

jtframe_obj_buffer #(
    .DW   ( 9 ),
    .ALPHA( 0 )
) u_linebuf(
    .clk    ( clk       ),
    .flip   ( 1'b0      ),
    .LHBL   ( ~hs       ),
    // New line writting
    .we     ( buf_we    ),
    .wr_data( buf_din   ),
    .wr_addr( buf_addr  ),
    // Previous line reading
    .rd     ( pxl_cen   ),
    .rd_addr( hdump     ),
    .rd_data( raw_pxl   )
);

endmodule
