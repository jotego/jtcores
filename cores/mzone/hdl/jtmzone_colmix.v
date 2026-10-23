// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,

    input         [3:0] scr_pxl,
    input         [3:0] fix_pxl,
    input         [3:0] obj_pxl,
    input         [3:0] gfx_en,
    input               fix_src,
    input               fix_prio,
    input               preLHBL,
    input               preLVBL,

    input         [7:0] prog_data,
    input        [21:0] prog_addr,
    input               prom_we,

    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue,
    output              LHBL,
    output              LVBL,
    output              preLBL
);

localparam [21:0] PAL_OFFSET = `ifdef JTFRAME_PROM_START `JTFRAME_PROM_START + 22'h000 `else 22'h000 `endif;
localparam        BLANK_DLY  = 9;

wire [ 7:0] pal_prom_dout;
wire [ 7:0] pal_addr;
wire [ 3:0] red_raw, green_raw, blue_raw;
wire [11:0] raw, rgb;
wire        pal_we;
wire [ 3:0] red_blank, green_blank, blue_blank;
wire [ 3:0] scr_mux_pxl = gfx_en[0] ? scr_pxl : 4'd0;
wire        fix_sel = fix_src && gfx_en[1];
wire        fix_opaque = fix_prio && gfx_en[1];
wire [ 3:0] char_pxl = fix_sel ? fix_pxl : scr_mux_pxl;
wire        obj_opaque = gfx_en[3] && obj_pxl != 4'd0 && !fix_opaque;
wire        pal_a4 = !obj_opaque;
wire [ 4:0] pal_mux = { pal_a4, obj_opaque ? obj_pxl : char_pxl };
reg  [ 4:0] pal_mux_r;

assign pal_addr = { 3'd0, pal_mux_r };
assign red_raw   = rg_dac( pal_prom_dout[2:0] );
assign green_raw = rg_dac( pal_prom_dout[5:3] );
assign blue_raw  = b_dac ( pal_prom_dout[7:6] );

assign pal_we = prom_we && prog_addr >= PAL_OFFSET && prog_addr < PAL_OFFSET+22'h20;

assign raw = { red_raw, green_raw, blue_raw };
assign { red_blank, green_blank, blue_blank } = rgb;

jtframe_prom #(
    .DW ( 8 ),
    .AW ( 5 )
) u_pal_prom(
    .clk    ( clk              ),
    .cen    ( pxl_cen          ),
    .data   ( prog_data        ),
    .wr_addr( prog_addr[4:0]   ),
    .we     ( pal_we           ),
    .rd_addr( pal_addr[4:0]   ),
    .q      ( pal_prom_dout    )
);

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_blank(
    .clk        ( clk      ),
    .pxl_cen    ( pxl_cen  ),
    .preLHBL    ( preLHBL  ),
    .preLVBL    ( preLVBL  ),
    .LHBL       ( LHBL     ),
    .LVBL       ( LVBL     ),
    .preLBL     ( preLBL   ),
    .rgb_in     ( raw      ),
    .rgb_out    ( rgb      )
);

assign red   = red_blank;
assign green = green_blank;
assign blue  = blue_blank;

always @(posedge clk) begin
    if( rst )
        pal_mux_r <= 5'd0;
    else if( pxl_cen )
        pal_mux_r <= pal_mux;
end

function [3:0] rg_dac;
    input [2:0] bits;
begin
    case( bits )
        3'b000: rg_dac = 4'h0;
        3'b001: rg_dac = 4'h2;
        3'b010: rg_dac = 4'h4;
        3'b011: rg_dac = 4'h6;
        3'b100: rg_dac = 4'h9;
        3'b101: rg_dac = 4'hb;
        3'b110: rg_dac = 4'hd;
        default: rg_dac = 4'hf;
    endcase
end
endfunction

function [3:0] b_dac;
    input [1:0] bits;
begin
    case( bits )
        2'b00: b_dac = 4'h0;
        2'b01: b_dac = 4'h5;
        2'b10: b_dac = 4'ha;
        default: b_dac = 4'hf;
    endcase
end
endfunction

endmodule
