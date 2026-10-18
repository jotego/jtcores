/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-10-2026 */

module jtpopeye_ana(
    input             rst,
    input             clk,
    input             cen10,
    input             cen20,
    input             lhbl,
    input             vs,
    input             vtick,
    input      [ 7:0] vlatch,
    input             fsel,

    input      [ 7:0] red,
    input      [ 7:0] green,
    input      [ 7:0] blue,
    input             LHBL,
    input             LVBL,

    input      [ 1:0] deflicker,
    input             narrow,
    input      [ 5:0] hpos,
    input      [ 4:0] vpos,

    output reg [ 7:0] ana_r,
    output reg [ 7:0] ana_g,
    output reg [ 7:0] ana_b,
    output reg        ana_hs,
    output reg        ana_vs,
    output reg        ana_de,
    output reg        ana_ce,
    output reg        ana_field
);

localparam [ 7:0] DLY   = 8'd6,
                  VTOP  = 8'd16,
                  VBOT  = 8'd239;
localparam [ 9:0] HREF  = 10'd638,
                  HLINE = 10'd640,
                  SLEAD = 10'd15,
                  NRWC  = 10'd5,
                  VHL   = 10'd513,
                  HSON  = 10'd539,
                  HSOFF = 10'd575;
localparam [ 3:0] VSW   = 4'd8;
localparam [ 4:0] VDN   = 5'd6;
localparam [ 5:0] HRT   = 6'd26;

wire [23:0] wdata, q;
wire [12:0] waddr;
wire [10:0] hsum;
wire [ 9:0] vsum;
wire [ 7:0] crow;
wire [ 4:0] vmov;
wire [ 5:0] hmov;
wire        we, pce;
reg  [12:0] raddr;
reg  [23:0] cc, ca, blend0, blend1;
reg  [ 9:0] hc, hst, op, lead, vn, vst;
reg  [ 8:0] wl, wx, rx;
reg  [ 2:0] rrow;
reg  [ 3:0] asl, bsl, vw;
reg  [ 2:0] st, sdiv;
reg  [ 1:0] mode;
reg         whbl_l, lhbl_c, v_on, rd_on, on_l, f, sodd, vs_l, vs_seen, bp, wp, nrw, hsr;

assign wdata = { red, green, blue };
assign we    = cen20 & LHBL & LVBL;
assign waddr = { wl[3:0], wx };
assign hmov  = !narrow && !hpos[5] && hpos > HRT ? HRT : hpos;
assign hsum  = { 1'b0, HREF } + { {5{hmov[5]}}, hmov } + ( narrow ? { 1'b0, NRWC } : 11'd0 );
assign vmov  = !vpos[4] && vpos > VDN ? VDN : vpos;
assign vsum  = { 1'b0, DLY, 1'b0 } - { {4{vmov[4]}}, vmov, 1'b0 } - 10'd1;
assign crow  = vlatch - DLY;
assign pce   = nrw ? sdiv == 3'd0 : cen10;

function [7:0] mix( input [7:0] a, c, b, input [1:0] m );
    reg [13:0] s, t, u;
    begin
        s = { 6'd0, a } + { 6'd0, b };
        u = { 6'd0, c };
        case( m )
            2'd0:    t = u;
            2'd1:    t = ( s + 14'd6*u ) >> 3;
            2'd2:    t = ( 14'd3*s + 14'd10*u ) >> 4;
            default: t = ( s + 14'd2*u ) >> 2;
        endcase
        mix = t[7:0];
    end
endfunction

always @(posedge clk) begin
    if( rst ) begin
        hst   <= 0;
        vst   <= 0;
        lead  <= 0;
        mode  <= 0;
        nrw   <= 0;
    end else begin
        hst   <= hsum >= { 1'b0, HLINE } ? hsum[9:0] - HLINE : hsum[9:0];
        vst   <= vsum[9] ? vsum + VHL : vsum;
        lead  <= narrow ? SLEAD : 10'd0;
        mode  <= deflicker;
        nrw   <= narrow;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        wl     <= 0;
        wx     <= 0;
        whbl_l <= 0;
    end else if( cen20 ) begin
        whbl_l <= LHBL;
        wx     <= LHBL ? wx + 9'd1 : 9'd0;
        if( !LVBL )
            wl <= 0;
        else if( whbl_l && !LHBL )
            wl <= wl + 9'd1;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        hc     <= 0;
        lhbl_c <= 0;
        hsr    <= 0;
    end else if( cen10 ) begin
        lhbl_c <= lhbl;
        hc     <= lhbl && !lhbl_c ? 10'd0 : hc + 10'd1;
        if( hc == HSON  ) hsr <= 1;
        if( hc == HSOFF ) hsr <= 0;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        sdiv <= 0;
        sodd <= 0;
        op   <= 0;
        rrow <= 0;
        v_on <= 0;
        f    <= 0;
        asl  <= 0;
        bsl  <= 0;
    end else begin
        if( sdiv == ( sodd ? 3'd4 : 3'd3 ) ) begin
            sdiv <= 0;
            sodd <= ~sodd;
        end else begin
            sdiv <= sdiv + 3'd1;
        end
        if( pce && op != 10'h3ff ) op <= op + 10'd1;
        if( cen10 && hc == hst ) begin
            sdiv <= 3'd1;
            sodd <= 0;
            op   <= 0;
            rrow <= crow[2:0];
            v_on <= crow >= VTOP && crow <= VBOT;
            if( crow == VTOP ) f <= fsel;
            if( crow == VTOP ? !fsel : !f ) begin
                asl <= crow == VTOP ? { crow[2:0], 1'b0 } : { crow[2:0] - 3'd1, 1'b1 };
                bsl <= { crow[2:0], 1'b1 };
            end else begin
                asl <= { crow[2:0], 1'b0 };
                bsl <= crow == VBOT ? { crow[2:0], 1'b1 } : { crow[2:0] + 3'd1, 1'b0 };
            end
        end
    end
end

always @* begin
    case( st )
        3'd2:    raddr = { asl, rx };
        3'd3:    raddr = { bsl, rx };
        default: raddr = { rrow, f, rx };
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        st     <= 0;
        rx     <= 0;
        rd_on  <= 0;
        on_l   <= 0;
        cc     <= 0;
        ca     <= 0;
        blend0 <= 0;
        blend1 <= 0;
        bp     <= 0;
        wp     <= 0;
    end else begin
        if( st != 3'd0 ) st <= st == 3'd4 ? 3'd0 : st + 3'd1;
        if( st == 3'd2 ) cc <= q;
        if( st == 3'd3 ) ca <= q;
        if( st == 3'd4 ) begin
            if( wp )
                blend1 <= { mix( ca[23:16], cc[23:16], q[23:16], mode ),
                            mix( ca[15: 8], cc[15: 8], q[15: 8], mode ),
                            mix( ca[ 7: 0], cc[ 7: 0], q[ 7: 0], mode ) };
            else
                blend0 <= { mix( ca[23:16], cc[23:16], q[23:16], mode ),
                            mix( ca[15: 8], cc[15: 8], q[15: 8], mode ),
                            mix( ca[ 7: 0], cc[ 7: 0], q[ 7: 0], mode ) };
        end
        if( pce ) begin
            bp    <= ~bp;
            wp    <= ~bp;
            st    <= 3'd1;
            rx    <= op[8:0] - lead[8:0];
            rd_on <= v_on && op >= lead && op < lead + 10'd512;
            on_l  <= rd_on;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        vs_l    <= 0;
        vs_seen <= 0;
        vn      <= 0;
        vw      <= 0;
    end else begin
        vs_l <= vs;
        if( vs && !vs_l ) vs_seen <= 1;
        if( vtick ) begin
            vn      <= vs_seen ? 10'd0 : vn + 10'd1;
            vs_seen <= 0;
            if( ( vs_seen ? 10'd0 : vn + 10'd1 ) == vst )
                vw <= VSW;
            else if( vw != 4'd0 )
                vw <= vw - 4'd1;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        ana_r     <= 0;
        ana_g     <= 0;
        ana_b     <= 0;
        ana_hs    <= 0;
        ana_vs    <= 0;
        ana_de    <= 0;
        ana_ce    <= 0;
        ana_field <= 0;
    end else begin
        ana_hs    <= hsr;
        ana_vs    <= vw != 4'd0;
        ana_ce    <= pce;
        ana_field <= f;
        if( pce ) begin
            ana_de <= on_l;
            { ana_r, ana_g, ana_b } <= !on_l ? 24'd0 : bp ? blend0 : blend1;
        end
    end
end

jtframe_dual_ram #(.DW(24),.AW(13)) u_ram(
    .clk0       ( clk       ),
    .data0      ( wdata     ),
    .addr0      ( waddr     ),
    .we0        ( we        ),
    .q0         (           ),
    .clk1       ( clk       ),
    .data1      ( 24'd0     ),
    .addr1      ( raddr     ),
    .we1        ( 1'b0      ),
    .q1         ( q         )
);

endmodule
