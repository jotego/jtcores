/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_colmix(
    input            rst,
    input            clk,
    input            pxl_cen,

    input            hbd_n,
    input            vb,
    input            lhbl,
    input            lvbl,

    input            txtv,
    input      [3:0] txtc,
    input      [1:0] obj_v,
    input      [5:0] obj_c,
    input      [4:0] bakc,
    input            boot,
    input            tnx1,

    output reg [4:0] txtpal_addr,
    input      [7:0] txtpal_data,
    output reg [4:0] bgpal_addr,
    input      [7:0] bgpal_data,
    output reg [7:0] objpall_addr,
    input      [3:0] objpall_data,
    output     [7:0] objpalh_addr,
    input      [3:0] objpalh_data,

    output     [7:0] red,
    output     [7:0] green,
    output     [7:0] blue,
    output           LHBL,
    output           LVBL,
    input      [3:0] gfx_en
);

localparam [1:0] NONE = 2'd0,
                 TXT  = 2'd1,
                 OBJ  = 2'd2,
                 BAK  = 2'd3;

wire        txt_on, obj_on, bak_on;
wire [ 7:0] pull, txt_d, bg_d, obj_d, inv;
wire [ 2:0] obj_bank;
wire [23:0] rgb_in, rgb_out;
reg  [ 1:0] sel;
reg  [ 7:0] pal;

assign inv          = {8{boot}};
assign txt_d        = txtpal_data ^ inv;
assign bg_d         = bgpal_data ^ inv;
assign obj_d        = { objpalh_data, objpall_data } ^ inv;
assign obj_bank     = tnx1 ? { 1'b0, {2{obj_c[3]}} } : obj_c[5:3];
assign txt_on       = ~txtv & gfx_en[0];
assign obj_on       = |obj_v & gfx_en[3];
assign bak_on       = hbd_n & ~vb & gfx_en[1];
assign objpalh_addr = objpall_addr;
assign pull         = ~pal;
assign { red, green, blue } = rgb_out;
assign rgb_in       = { {2{pull[2:0]}}, pull[2:1], {2{pull[5:3]}}, pull[5:4], {4{pull[7:6]}} };

always @(posedge clk) begin
    if( rst ) begin
        txtpal_addr  <= 0;
        bgpal_addr   <= 0;
        objpall_addr <= 0;
        sel          <= NONE;
    end else if( pxl_cen ) begin
        txtpal_addr  <= { txtc[3], txtc };
        bgpal_addr   <= bakc;
        objpall_addr <= { obj_bank, obj_c[2:0], obj_v };
        sel          <= txt_on ? TXT :
                        obj_on ? OBJ :
                        bak_on ? BAK : NONE;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        pal <= 8'hff;
    end else if( pxl_cen ) begin
        case( sel )
            TXT:     pal <= txt_d;
            OBJ:     pal <= obj_d;
            BAK:     pal <= bg_d;
            default: pal <= 8'hff;
        endcase
    end
end

jtframe_blank #(.DLY(3),.DW(24)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( lhbl      ),
    .preLVBL    ( lvbl      ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( rgb_in    ),
    .rgb_out    ( rgb_out   )
);

endmodule
