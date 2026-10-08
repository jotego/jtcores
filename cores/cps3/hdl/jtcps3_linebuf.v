/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2026 */

module jtcps3_linebuf(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               ln_hs,
    input               ln_vs,
    input               ln_lvbl,
    input       [ 8:0]  ln_v,

    input               transfer,
    output reg          busy,

    input               obj_busy,
    input               obj_wr_en,
    input       [ 9:0]  obj_addr,
    input       [16:0]  obj_pxl,
    input               scr_busy,
    input               scr_wr_en,
    input       [ 9:0]  scr_addr,
    input       [16:0]  scr_pxl,
    input       [14:0]  scene_rgb,
    output      [16:0]  scene_pxl,
    output      [16:0]  buf_dout,

    output reg  [ 9:0]  ln_addr=0,
    output      [15:0]  ln_data,
    output reg          ln_we,
    output reg          ln_done
);

wire        wr_en, rd_en, pxl_pre;
wire [ 9:0] wr_addr;
wire [16:0] wr_data;
reg         line, ln_trig, clr_we, clring, pal_rding, wait_ln, pal_start;
reg  [ 2:0] rd_vld;
reg  [ 3:0] pxl_cnt;
reg  [ 9:0] rd_addr=0, rd_addr0, rd_addr1, rd_addr2;

assign wr_en    = obj_wr_en | scr_wr_en;
assign wr_addr  = obj_busy ? obj_addr : scr_addr;
assign wr_data  = obj_busy ? obj_pxl  : scr_pxl;
assign pxl_pre  = pxl_cnt == 4'd12;
assign rd_en    = pal_rding & ~pxl_pre;

assign ln_data = { 1'b0, scene_rgb };

always @(posedge clk) begin
    if( rst ) begin
        line      <= 0;
        pal_rding <= 0;
        clring    <= 0;
        busy      <= 0;
        clr_we    <= 0;
        ln_we     <= 0;
        ln_done   <= 0;
        wait_ln   <= 0;
        pal_start <= 0;
        rd_vld    <= 0;
        pxl_cnt   <= 0;
    end else begin
        pxl_cnt  <= pxl_cen ? 4'd0 : pxl_cnt + 4'd1;
        ln_trig  <= 0;
        ln_done  <= ln_trig;
        ln_we    <= rd_vld[2];
        ln_addr  <= rd_addr2;
        rd_vld   <= { rd_vld[1:0], rd_en };
        rd_addr0 <= rd_addr;
        rd_addr1 <= rd_addr0;
        rd_addr2 <= rd_addr1;
        if( ln_trig ) wait_ln <= 1;

        if( ln_hs ) wait_ln <= 0;
        if( !pal_start && !pal_rding && !clring && !wait_ln && rd_vld==0 ) busy <= 0;

        if( pxl_cen ) begin
            if( pal_start ) pal_rding <= 1;
            pal_start <= 0;
        end

        if( transfer ) begin
            pal_start <= 1;
            clring    <= 0;
            wait_ln   <= 0;
            busy      <= 1;
            line      <= ~line;
            rd_addr   <= 10'd0;
            ln_addr   <= 10'd0;
            clr_we    <= 0;
            ln_we     <= 0;
            rd_vld    <= 0;
        end

        if( pal_rding ) begin
            if( rd_en ) begin
                rd_addr <= rd_addr + 1'd1;
                if( rd_addr == 10'h3ff ) begin
                    pal_rding <= 0;
                    rd_addr   <= 10'd0;
                end
            end
        end

        if( !pal_rding && rd_vld==3'b100 ) begin
            ln_trig <= 1;
            clr_we  <= 1;
            clring  <= 1;
        end

        if(clring) begin
            ln_we   <= 0;
            rd_addr <= rd_addr + 1'd1;
            if( rd_addr == 10'h3ff ) begin
                clr_we <= 0;
                clring <= 0;
            end
        end
    end
end

jtframe_dual_ram #(
    .DW( 17 ),
    .AW( 11 )
) u_linebuf(
    // takes writes from object and scroll modules
    .clk0   ( clk                   ),
    .data0  ( wr_data               ),
    .addr0  ( { ~line, wr_addr }    ),
    .we0    ( wr_en                 ),
    .q0     ( buf_dout              ),
    // Read out and clear old data
    .clk1   ( clk                   ),
    .data1  ( 17'd0                 ),
    .addr1  ( { line, rd_addr }     ),
    .we1    ( clr_we                ),
    .q1     ( scene_pxl             )
);

endmodule
