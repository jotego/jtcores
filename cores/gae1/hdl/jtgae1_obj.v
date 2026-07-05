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
    parameter VTOTAL = 348,
    parameter integer YOFFS = 16
)(
    input        clk,
    input        rst,
    input        pxl_cen,
    input        hs,
    input [8:0]  vpos,
    input [8:0]  hpos,
    input [5:0]  spr_force_high,

    output [10:0] spr_a,
    input [15:0]  spr_q,

    output        rom_cs,
    output [21:2] rom_addr,
    input [31:0]  rom_data,
    input         rom_ok,

    output [12:0] pxl
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

reg  [8:0] vpos_d;
always @(posedge clk) vpos_d <= vpos;
wire line_change = (vpos != vpos_d);

wire [8:0] next_vpos = (vpos == VTOTAL-1) ? 9'd0 : (vpos + 9'd1);
wire [8:0] line = next_vpos + YOFFS[8:0];

reg  [ 3:0] state;
reg  [10:0] spr_idx;
reg  [ 8:0] line_r;
reg  [15:0] w0_r, w2_r, w3_r;
reg  [ 8:0] dr_xpos;
reg  [ 5:0] dr_color;
reg  [ 2:0] dr_prio;
reg  [15:0] dr_code;
reg  [ 3:0] dr_ysub;
reg         dr_hflip, dr_vflip, dr_draw, dr_trunc;

wire        dr_busy;
wire [22:2] pre_addr;
wire [21:2] norm_addr;
wire [31:0] sorted_data;
wire [ 8:0] draw_pal  = { dr_prio, dr_color };
wire [ 1:0] cell_quad = {pre_addr[6], 1'b0} + {1'b0, pre_addr[5]};
wire [ 1:0] trunc_sel = { dr_trunc, 1'b0 };
wire [ 7:0] sy0       = 8'd240 - spr_q[7:0];
wire [ 8:0] py0       = (line_r - {1'b0, sy0}) & 9'h1ff;
wire [ 4:0] sprh0     = spr_q[11] ? 5'd8 : 5'd16;
wire        online0   = py0 < {4'b0, sprh0};
wire [ 7:0] sy_c      = 8'd240 - w0_r[7:0];
wire [ 8:0] py_c      = (line_r - {1'b0, sy_c}) & 9'h1ff;
wire        size8     = w0_r[11];
wire        sprite_on = py_c < (size8 ? 9'd8 : 9'd16);

assign spr_a = state == LOAD0 ? spr_idx :
               state == RDW0  ? spr_idx + 11'd2 :
               state == RDW2  ? spr_idx + 11'd3 : 11'd0;

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

assign norm_addr = dr_trunc ? { 1'b0, pre_addr[22:7], pre_addr[4:2] } :
                              { 1'b0, pre_addr[22:9], cell_quad, pre_addr[4:2] };
assign rom_addr  = norm_addr;

reg  start;
always @(posedge clk or posedge rst) begin
    if (rst) start <= 1'b0; else start <= line_change;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state   <= IDLE;
        spr_idx <= 11'd2043;
        dr_draw <= 1'b0;
    end else begin
        dr_draw <= 1'b0;
        if (start) begin
            line_r  <= line;
            spr_idx <= 11'd2043;
            state   <= LOAD0;
        end else begin
            case (state)
                IDLE: ;
                LOAD0: state <= RDW0;
                RDW0: begin
                    w0_r  <= spr_q;
                    state <= online0 ? RDW2 : NEXT;
                end
                RDW2: begin
                    w2_r  <= spr_q;
                    state <= RDW3;
                end
                RDW3: begin
                    w3_r  <= spr_q;
                    state <= TEST;
                end
                TEST: begin
                    dr_hflip <= w0_r[14];
                    dr_vflip <= w0_r[15];
                    dr_xpos  <= w2_r[8:0] - 9'd15;
                    dr_color <= w2_r[14:9];
                    dr_prio  <= w2_r[14:9] >= spr_force_high ? 3'd4 : {1'b0, w0_r[13:12]};
                    dr_code  <= size8 ? w3_r : {w3_r[15:2], 2'b00};
                    dr_ysub  <= { size8 ? 1'b0 : py_c[3], py_c[2:0] };
                    dr_trunc <= size8;
                    state    <= sprite_on ? DRAW : NEXT;
                end
                DRAW: begin
                    if (!dr_busy) begin
                        dr_draw <= 1'b1;
                        state   <= NEXT;
                    end
                end
                NEXT: if (spr_idx >= 11'd7) begin
                    spr_idx <= spr_idx - 11'd4;
                    state   <= LOAD0;
                end else begin
                    state <= DONE;
                end
                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
end

jtframe_objdraw_trunc #(
    .CW       (  16 ),
    .PW       (  13 ),
    .LATCH    (   1 ),
    .KEEP_OLD (   1 )
) u_draw (
    .rst      ( rst                    ),
    .clk      ( clk                    ),
    .pxl_cen  ( pxl_cen                ),
    .hs       ( hs                     ),
    .flip     ( 1'b0                   ),
    .hdump    ( hpos                   ),
    .trunc    ( trunc_sel              ),

    .draw     ( dr_draw                ),
    .busy     ( dr_busy                ),
    .code     ( dr_code                ),
    .xpos     ( dr_xpos                ),
    .ysub     ( dr_ysub                ),
    .hzoom    ( 6'd0                   ),
    .hz_keep  ( 1'b0                   ),

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
