// SPDX-License-Identifier: GPL-3.0-or-later
// 96577-P sheet G (manual 420-0358, PDF page 27): the headlight (PR-125),
// explosion (PR-126) and splash (PR-131) paths. Pin-level transcription:
// docs/trace/SHEET_G_TRACE.md. Behaviour: docs/SHEET_G_LOGIC.md.
//
// The paths share the player-car counters HC and VC and the windows of
// jtmonacogp_player, and follow its settled-state model (host clocks after
// the pxl_cen edge, edge 0):
//   edge 1       the counters step (in jtmonacogp_player);
//   edge 2       the PROM data follow the new address (block-RAM latency);
//   edges 3..0'  settled. The two 74279 latches take their inputs at these
//                edges only: the comparators' match is filtered by 470 pF on
//                the board, and at edges 1 and 2 the nets mix two pixels.
// The outputs are combinational on the settled nets and the latches, valid at
// the next pxl_cen edge, where the game module holds them for the pixel.
// pxl_cen must be at least five host clocks apart.
module jtmonacogp_effects(
    input            clk, rst,
    input            pxl_cen,
    // Sheet G player path (jtmonacogp_player)
    input      [7:0] hc, vc,        // IC52, IC54
    input            hwin,          // IC57a pin 6
    input            vwin,          // IC51 pin 4
    input            ic66_3,        // AND(/ACC1, IC119 /Q): IC51 pin 11
    // Sheet F
    input            acc1_n,        // /ACC1: PR-125 pins 18, 19
    input            tunnel_n,      // /TUNNEL: IC57b pin 13
    input            explo_st,      // EXPLO.ST: PR-126 pins 18, 19
    input            explo_st_n,    // /EXPLO.ST: IC74 pin 3
    input      [3:0] explo_sel,     // EXPLO.SEL D..A
    input            splay_a_n,     // /SPLAY A: PR-131 pin 1
    input            splay_b,       // SPLAY B (IC49 Q on sheet F): IC45 pin 11
    // PROMs: PR-125 = IC59, PR-126 = IC65, PR-131 = IC71 (7641), A8..A0
    output     [8:0] pr125_addr, pr126_addr, pr131_addr,
    input      [7:0] pr125_q, pr126_q, pr131_q,
    // To sheet C
    output           light_n,       // IC51 pin 9, pad BC
    output           explo_r_n,     // IC62 pin 11, pad BK
    output           explo_y_n,     // IC56 pin 3, pad B4
    output           explo_area_n,  // IC64 pin 6, pad C15
    output           splay_n,       // IC70 pin 6, pad B10
    // Internal nets, for tests
    output           eq,            // IC58 pin 6
    output           w,             // IC57b output
    output           splash_win     // IC51 pin 13
);
    reg  [1:0] cen_sr;
    reg        q51c, q51d;          // latches 3 and 4
    wire       settled = !cen_sr[0] && !cen_sr[1];

    // ------------------------------------------------------------ headlight
    // IC57b (7425, strobe not drawn) = NOR(HC5, HC6, HC7, /TUNNEL); IC46 9 -> 8.
    assign w = ~(hc[5] | hc[6] | hc[7] | tunnel_n);
    // PR-125: A0..A6 = VC0..VC6, A7 = IC46 pin 8, A8 grounded; enabled by
    // /ACC1 (CE3, CE4). A disabled PROM's outputs read high.
    assign pr125_addr = {1'b0, ~w, vc[6:0]};
    wire [7:0] d125 = acc1_n ? pr125_q : 8'hff;
    // IC53, IC58 (7485): A = HC, B = PR-125 data, A=B cascade in = /VC7
    // (IC46 11 -> 10), the other cascade inputs high.
    assign eq = hc == d125 && !vc[7];
    // IC56 13, 12 -> 11 (/S2) and 10, 9 -> 8 (/R); /S1 = IC66 pin 3.
    wire s1_c = ic66_3;
    wire s2_c = ~(~w & eq);
    wire r_c  = ~(eq & w);
    // 74279: either /S low drives Q high, else /R low drives it low.
    assign light_n = (!s1_c || !s2_c) ? 1'b1 : !r_c ? 1'b0 : q51c;

    // ------------------------------------------------------------ explosion
    // PR-126: A0..A4 = VC0..VC4, A5 = HC3, A6 = HC4, A7 = SEL A, A8 = SEL B;
    // enabled by EXPLO.ST.
    assign pr126_addr = {explo_sel[1], explo_sel[0], hc[4], hc[3], vc[4:0]};
    wire [7:0] d126 = explo_st ? pr126_q : 8'hff;
    // IC74 (7427) = NOR(IC56 pin 6, SEL D, /EXPLO.ST); IC44 3 -> 4 -> IC64 /G.
    wire ic56_6 = ~(vwin & hwin);
    wire g64_n  = ic56_6 | explo_sel[3] | explo_st_n;
    // IC64 (74151): A, B, C = HC0, HC1, HC2.
    wire y64 = !g64_n && d126[hc[2:0]];
    assign explo_area_n = ~y64;                         // /W
    wire ic63_10 = ~(explo_sel[0] | explo_sel[2]);      // NOR(SEL A, SEL C)
    assign explo_y_n = ~(ic63_10 & y64);                // IC56 1, 2 -> 3
    assign explo_r_n = explo_area_n | ic63_10;          // IC62 12, 13 -> 11

    // ------------------------------------------------------------ splash
    // IC51 latch 4: /R = IC48 NAND(VC4, VC5), /S = IC48 NAND(/VC5 [IC44
    // 13 -> 12], VC4).
    wire s4 = ~(~vc[5] & vc[4]);
    wire r4 = ~(vc[4] & vc[5]);
    assign splash_win = !s4 ? 1'b1 : !r4 ? 1'b0 : q51d;
    // PR-131: A0..A4 = VC0..VC4, A5 = HC3, A6 = HC4, A7 = /SPLAY A, A8 = VC6;
    // always enabled.
    assign pr131_addr = {vc[6], splay_a_n, hc[4], hc[3], vc[4:0]};
    // IC45 (7410) = NAND(IC51 pin 13, HWIN, SPLAY B) -> IC70 /G.
    wire g70_n = ~(splash_win & hwin & splay_b);
    assign splay_n = ~(!g70_n && pr131_q[hc[2:0]]);    // IC70 /W

    always @(posedge clk) begin
        if (rst) begin
            cen_sr <= 0;
            q51c   <= 1;            // arbitrary power-on state: light off
            q51d   <= 0;
        end else begin
            cen_sr <= {cen_sr[0], pxl_cen};
            if (settled) begin
                q51c <= light_n;
                q51d <= splash_win;
            end
        end
    end
endmodule
