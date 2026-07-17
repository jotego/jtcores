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
    Date: 2-7-2026 */

module jtgae1_obj #(
    parameter         VTOTAL    = 348,
    parameter integer YOFFS     = 16,
    parameter         ROM_AW    = 21,
    parameter         CODE_EXT  = 0,
    parameter [8:0]   HDUMP_OFF = 9'd4,
    parameter [8:0]   OBJ_XOFFS = 9'd4
)(
    input               clk,
    input               rst,
    input               pxl_cen,
    input               hs,
    input        [ 8:0] vpos,
    input        [ 8:0] hpos,
    input        [ 5:0] spr_force_high,

    output       [10:0] spr_a,
    input        [15:0] spr_q,

    output              rom_cs,
    output [ROM_AW:2]  rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output       [12:0] pxl
);
localparam [ 3:0] IDLE  = 4'd0,
                  LOAD0 = 4'd1,
                  RDW0  = 4'd2,
                  RDW2  = 4'd3,
                  RDW3  = 4'd4,
                  TEST  = 4'd5,
                  DRAW  = 4'd6,
                  NEXT  = 4'd7,
                  DONE  = 4'd8;
localparam CODEW = CODE_EXT ? 18 : 16;

wire [CODEW+6:2] pre_addr;
wire [CODEW-1:0] obj_code;
wire [31:0]      sorted_data;
wire [15:0]      code_base;
wire [ 8:0]      draw_hpos, next_vpos, line, draw_pal;
wire [ 8:0]      py0, py_c;
wire [ 7:0]      sy0, sy_c;
wire [ 5:0]      hzoom;
wire [ 4:0]      sprh0, spr_h, spr_row;
wire [ 1:0]      trunc_sel;
wire             dr_busy, draw_flip, hz_keep, line_change, online0, size8, sprite_on;

reg  [CODEW-1:0] dr_code;
reg  [15:0]      w0_r, w2_r, w3_r;
reg  [10:0]      spr_idx;
reg  [ 8:0]      line_r, dr_xpos;
reg  [ 5:0]      dr_color;
reg  [ 3:0]      st, dr_ysub;
reg  [ 2:0]      dr_prio;
reg              hs_l, start, dr_hflip, dr_vflip, dr_draw, dr_trunc, rom_trunc;

assign draw_hpos   = hpos - HDUMP_OFF;
assign line_change = hs & ~hs_l;
assign next_vpos   = vpos == VTOTAL-1 ? 9'd0 : vpos + 9'd1;
assign line        = next_vpos + YOFFS[8:0];

assign sy0       = 8'd240 - spr_q[7:0];
assign py0       = (line_r - {1'b0, sy0}) & 9'h1ff;
assign sprh0     = spr_q[11] ? 5'd8 : 5'd16;
assign online0   = py0 < {4'b0, sprh0};
assign sy_c      = 8'd240 - w0_r[7:0];
assign py_c      = (line_r - {1'b0, sy_c}) & 9'h1ff;
assign size8     = w0_r[11];
assign sprite_on = py_c < (size8 ? 9'd8 : 9'd16);
assign spr_h     = size8 ? 5'd8 : 5'd16;
assign spr_row   = w0_r[15] ? spr_h - 5'd1 - py_c[4:0] : py_c[4:0];

assign draw_pal  = { dr_prio, dr_color };
assign trunc_sel = { dr_trunc, 1'b0 };
assign hzoom     = 6'd0;
assign draw_flip = 1'b0;
assign hz_keep   = 1'b0;

assign spr_a = st == LOAD0 ? spr_idx :
               st == RDW0  ? spr_idx + 11'd2 :
               st == RDW2  ? spr_idx + 11'd3 : 11'd0;

assign code_base = size8 ? w3_r : {w3_r[15:2], 2'b00};

assign sorted_data = {
    rom_data[ 0], rom_data[ 1], rom_data[ 2], rom_data[ 3],
    rom_data[ 4], rom_data[ 5], rom_data[ 6], rom_data[ 7],
    rom_data[ 8], rom_data[ 9], rom_data[10], rom_data[11],
    rom_data[12], rom_data[13], rom_data[14], rom_data[15],
    rom_data[16], rom_data[17], rom_data[18], rom_data[19],
    rom_data[20], rom_data[21], rom_data[22], rom_data[23],
    rom_data[24], rom_data[25], rom_data[26], rom_data[27],
    rom_data[28], rom_data[29], rom_data[30], rom_data[31]
};

generate
    if (CODE_EXT) begin : gen_ext_addr
        assign obj_code = { w3_r[1:0], code_base };
        assign rom_addr = rom_trunc ? { pre_addr[24:7], pre_addr[4:2] } :
                                      { pre_addr[24:9], pre_addr[6:2] };
    end else begin : gen_addr
        assign obj_code = code_base;
        assign rom_addr = rom_trunc ? { 1'b0, pre_addr[22:7], pre_addr[4:2] } :
                                      { 1'b0, pre_addr[22:9], pre_addr[6:2] };
    end
endgenerate

always @(posedge clk) begin
    if (rst) begin
        hs_l <= 1'b0;
    end else begin
        hs_l <= hs;
    end
end

always @(posedge clk) begin
    if (rst) begin
        start <= 1'b0;
    end else begin
        start <= line_change;
    end
end

always @(posedge clk) begin
    if (rst) begin
        st      <= IDLE;
        spr_idx <= 11'd2043;
        dr_draw <= 1'b0;
        rom_trunc <= 1'b0;
    end else begin
        dr_draw <= 1'b0;
        if (start) begin
            line_r  <= line;
            spr_idx <= 11'd2043;
            st      <= LOAD0;
        end else begin
            case (st)
                IDLE: ;
                LOAD0: st <= RDW0;
                RDW0: begin
                    w0_r  <= spr_q;
                    st    <= online0 ? RDW2 : NEXT;
                end
                RDW2: begin
                    w2_r  <= spr_q;
                    st    <= RDW3;
                end
                RDW3: begin
                    w3_r  <= spr_q;
                    st    <= TEST;
                end
                TEST: begin
                    dr_hflip <= w0_r[14];
                    dr_vflip <= 1'b0;
                    dr_xpos  <= w2_r[8:0] - OBJ_XOFFS;
                    dr_color <= w2_r[14:9];
                    dr_prio  <= w2_r[14:9] >= spr_force_high ? 3'd4 : {1'b0, w0_r[13:12]};
                    dr_code  <= obj_code;
                    dr_ysub  <= { size8 ? 1'b0 : spr_row[3], spr_row[2:0] };
                    dr_trunc <= size8;
                    st       <= sprite_on ? DRAW : NEXT;
                end
                DRAW: begin
                    if (!dr_busy) begin
                        dr_draw   <= 1'b1;
                        rom_trunc <= dr_trunc;
                        st        <= NEXT;
                    end
                end
                NEXT: if (spr_idx >= 11'd7) begin
                    spr_idx <= spr_idx - 11'd4;
                    st      <= LOAD0;
                end else begin
                    st <= DONE;
                end
                DONE: st <= IDLE;
                default: st <= IDLE;
            endcase
        end
    end
end

jtframe_objdraw_trunc #(
    .CW       ( CODEW ),
    .PW       (  13 ),
    .LATCH    (   1 ),
    .KEEP_OLD (   1 ),
    .KEEP_MAP (   1 )
) u_draw (
    .rst      ( rst                    ),
    .clk      ( clk                    ),
    .pxl_cen  ( pxl_cen                ),
    .hs       ( hs                     ),
    .flip     ( draw_flip              ),
    .hdump    ( draw_hpos              ),
    .trunc    ( trunc_sel              ),

    .draw     ( dr_draw                ),
    .busy     ( dr_busy                ),
    .code     ( dr_code                ),
    .xpos     ( dr_xpos                ),
    .ysub     ( dr_ysub                ),
    .hzoom    ( hzoom                  ),
    .hz_keep  ( hz_keep                ),

    .hflip    ( dr_hflip               ),
    .vflip    ( dr_vflip               ),
    .pal      ( draw_pal               ),

    .rom_addr ( pre_addr               ),
    .rom_cs   ( rom_cs                 ),
    .rom_ok   ( rom_ok                 ),
    .rom_data ( sorted_data            ),

    .pxl      ( pxl                    )
);
endmodule
