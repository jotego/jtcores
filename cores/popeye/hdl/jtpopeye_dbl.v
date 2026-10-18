/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_dbl(
    input            rst,
    input            clk,
    input            cen20,
    input            cen10,
    input            cen5,
    input            vtick,
    input            vs,
    input      [7:0] vcnt,
    input      [7:0] vlatch,
    input            vhalf,
    input            lhbl,

    input            txtv,
    input      [3:0] txtc,
    input      [4:0] bakc,
    input            hbd_n,
    input            vb,
    input      [2:0] obj_chi,
    input      [1:0] obj_va,
    input      [2:0] obj_ca,
    input      [1:0] obj_vb,
    input      [2:0] obj_cb,

    output reg       txtv_o,
    output reg [3:0] txtc_o,
    output reg [4:0] bakc_o,
    output reg       hbd_n_o,
    output reg       vb_o,
    output reg [1:0] obj_v_o,
    output reg [5:0] obj_c_o,
    output reg       lhbl_o,
    output reg       lvbl_o,
    output reg       hs_o,
    output reg       vs_o
);

wire [24:0] wdata, rdata;
wire [10:0] waddr, raddr;
wire [ 7:0] vr;
wire [ 3:0] rd_txtc;
wire [ 4:0] rd_bakc;
wire [ 2:0] rd_chi, rd_obj_ca, rd_obj_cb;
wire [ 1:0] rd_obj_va, rd_obj_vb;
wire        we, rd_txtv, rd_hbd_n, rd_vb, pxl_on, row_on;
reg  [ 9:0] oc, px;
reg  [ 8:0] x, rx;
reg  [ 1:0] wrow, rrow;
reg         sub;
reg         lhbl_l, vs_l, vs_seen, vt_l;

assign wdata  = { txtv, txtc, bakc, hbd_n, vb, obj_chi, obj_va, obj_ca, obj_vb, obj_cb };
assign { rd_txtv, rd_txtc, rd_bakc, rd_hbd_n, rd_vb, rd_chi, rd_obj_va, rd_obj_ca, rd_obj_vb, rd_obj_cb } = rdata;
assign we     = cen10 & lhbl;
assign waddr  = { lhbl_l ? wrow : vlatch[1:0], x };
assign raddr  = { rrow, rx };
assign vr     = vcnt - 8'd3;
assign pxl_on = px >= 10'd104 && px < 10'd616;
assign row_on = vr >= 8'd16 && vr < 8'd240;

always @(posedge clk) begin
    if( rst ) begin
        x      <= 0;
        wrow   <= 0;
        lhbl_l <= 0;
    end else if( cen10 ) begin
        lhbl_l <= lhbl;
        x      <= lhbl ? x + 9'd1 : 9'd0;
        if( lhbl && !lhbl_l ) wrow <= vlatch[1:0];
    end
end

always @(posedge clk) begin
    if( rst ) begin
        oc      <= 0;
        px      <= 0;
        vs_l    <= 0;
        vs_seen <= 0;
        vt_l    <= 0;
    end else begin
        if( cen20 && px==10'd320 ) begin
            vs_l    <= vs;
            vs_seen <= vs && !vs_l;
        end
        if( vtick ) begin
            oc      <= vs_seen ? 10'd0 : oc + 10'd1;
            vs_seen <= 0;
        end
        if( vtick ) vt_l <= 1;
        if( cen20 ) begin
            if( cen5 && (vtick || vt_l) ) begin
                px   <= 0;
                vt_l <= 0;
            end else begin
                px   <= px + 10'd1;
            end
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        rx   <= 0;
        rrow <= 0;
        sub  <= 0;
    end else if( cen20 ) begin
        rx   <= px[8:0] - 9'd103;
        rrow <= vr[1:0];
        sub  <= vhalf;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        lhbl_o  <= 0;
        lvbl_o  <= 0;
        hs_o    <= 0;
        vs_o    <= 0;
        txtv_o  <= 1;
        txtc_o  <= 0;
        bakc_o  <= 0;
        hbd_n_o <= 0;
        vb_o    <= 1;
        obj_v_o <= 0;
        obj_c_o <= 0;
    end else if( cen20 ) begin
        lhbl_o <= pxl_on;
        lvbl_o <= row_on;
        hs_o   <= px >= 10'd8 && px < 10'd72;
        vs_o   <= oc < 10'd6;
        if( pxl_on && row_on ) begin
            txtv_o  <= rd_txtv;
            txtc_o  <= rd_txtc;
            bakc_o  <= rd_bakc;
            hbd_n_o <= rd_hbd_n;
            vb_o    <= rd_vb;
            obj_v_o <= sub ? rd_obj_vb : rd_obj_va;
            obj_c_o <= { rd_chi, sub ? rd_obj_cb : rd_obj_ca };
        end else begin
            txtv_o  <= 1;
            txtc_o  <= 0;
            bakc_o  <= 0;
            hbd_n_o <= 0;
            vb_o    <= 1;
            obj_v_o <= 0;
            obj_c_o <= 0;
        end
    end
end

jtframe_dual_ram #(.DW(25),.AW(11)) u_ram(
    .clk0       ( clk       ),
    .data0      ( wdata     ),
    .addr0      ( waddr     ),
    .we0        ( we        ),
    .q0         (           ),
    .clk1       ( clk       ),
    .data1      ( 25'd0     ),
    .addr1      ( raddr     ),
    .we1        ( 1'b0      ),
    .q1         ( rdata     )
);

endmodule
