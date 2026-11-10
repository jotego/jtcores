/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_timing(
    input            rst,
    input            clk,
    input            cen5,
    input            cen10,
    input            rv,

    output     [7:0] tprom_addr,
    input      [3:0] tprom_data,

    output reg [7:0] h_raw,
    output reg       hb,
    output     [7:0] h,
    output           h20,
    output     [7:0] v,
    output reg       vb,
    output reg       hbd_n,
    output           ai_n,
    output           bi_n,
    output           initeo,
    output reg       sy_n,
    output reg       vtick,
    output reg [7:0] vcnt,
    output reg [7:0] vlatch,
    output reg       vhalf,

    output reg       hs,
    output reg       vs,
    output reg       lhbl,
    output reg       lvbl
);

wire       serr, vclk, hsy, ld, d6, p6, vb_up;
reg        hq, hb_l, vclk_l, vend, v4_l, v2_l, vb_l, vsq, eo, hbdq;

assign tprom_addr = { hb, h_raw[7:1] };
assign serr       = tprom_data[0];
assign vclk       = tprom_data[1];
assign hsy        = tprom_data[2];
assign ld         = ~vend;
assign d6         = &vcnt[7:5];
assign p6         = ~(~vcnt[2] & vcnt[3] & vcnt[4] & vb);
assign vb_up      = vb & ~vb_l;
assign h          = { h_raw[7:3] ^ {5{rv}}, h_raw[2:0] };
assign h20        = h_raw[2] ^ rv;
assign v          = vlatch ^ {8{rv}};
assign ai_n       = ~h_raw[0];
assign bi_n       = ~h_raw[1];
assign initeo     = eo ^ rv;

always @(posedge clk) begin
    if( rst ) begin
        h_raw <= 0;
        hq    <= 0;
        hb    <= 0;
        hbdq  <= 0;
        lvbl  <= 0;
    end else if( cen5 ) begin
        h_raw <= &h_raw ? { hq, hq, 6'd0 } : h_raw + 8'd1;
        hb    <= hq;
        if( h_raw == 8'hfe ) hq <= ~hq;
        if( h_raw[3:0] == 4'h7 ) begin
            hbdq <= hb;
            if( hb ) lvbl <= ~vb;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        vclk_l <= 0;
        vhalf  <= 0;
        vcnt   <= 0;
        vend   <= 0;
        vtick  <= 0;
    end else begin
        vclk_l <= vclk;
        vtick  <= vclk & ~vclk_l;
        if( vclk && !vclk_l ) begin
            vhalf <= ld & ~vhalf;
            vend  <= vhalf & (&vcnt);
            if( !ld )
                vcnt <= 0;
            else if( vhalf )
                vcnt <= vcnt + 8'd1;
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        v4_l <= 0;
        v2_l <= 0;
        vb   <= 0;
        vsq  <= 0;
    end else begin
        v4_l <= vcnt[4];
        v2_l <= vcnt[2];
        if( vcnt[4] && !v4_l ) vb  <= d6;
        if( vcnt[2] && !v2_l ) vsq <= d6 & vb;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        vb_l   <= 0;
        hb_l   <= 0;
        eo     <= 0;
        vlatch <= 0;
    end else begin
        vb_l <= vb;
        hb_l <= hb;
        if( vb_up ) eo <= hb;
        if( hb && !hb_l ) vlatch <= vcnt;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        hbd_n <= 1;
        sy_n  <= 1;
        hs    <= 0;
        vs    <= 0;
        lhbl  <= 0;
    end else begin
        hbd_n <= ~(hb & hbdq);
        sy_n  <= ~((~p6 & serr) | (p6 & vsq & vclk) | (~vsq & hsy));
        hs    <= hsy;
        vs    <= ~p6;
        if( cen10 && !cen5 && h_raw[3:0] == 4'h7 ) lhbl <= ~hb;
    end
end

endmodule
