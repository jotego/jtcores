// SPDX-License-Identifier: GPL-3.0-or-later
// 96577-P sheet G (manual 420-0358, PDF page 27): player-car pixel path.
// Pin-level transcription: docs/trace/SHEET_G_PLAYER.md.
//
// Settled-state model, in host clocks after the pxl_cen clock edge (edge 0):
//   edge 0       end of a pixel: the counters keep the settled values of their
//                edge-sensitive inputs as the "previous" values (*_l);
//   edge 1       counters IC52, IC54, IC38 step on the new pixel's inputs;
//   edge 2       the PROM data follow the new address (block-RAM latency);
//   edges 3..0'  settled. The monostables IC119 and IC19 compare their inputs
//                at every one of these edges with the values at the previous
//                one, so an edge caused by their own outputs within the pixel
//                (IC19 Q -> /ACC1.ST -> IC119 /CLR; IC119 Q -> PROM enables ->
//                body pixel -> B) is seen one host clock later. Their periods
//                count down once per pixel, at edge 3. Edges 1 and 2 are
//                skipped: the nets mix two pixels there.
// pxl_cen must therefore be at least five host clocks apart. When a clear is
// released on the same 7 MHz edge that clocks a counter, the clear wins.
// TTL propagation delays and RC pulse shaping are not reproduced.
//
// Pro Monaco GP (manual 420-0525, sheet G, PDF page 10), selected by pro = 1:
// pro/docs/trace/BONUS_INPUTS_TRACE.md, "PLAYER ST". The Pro board adds one
// gate for sheet N, IC31 (1, 2 -> 3) = AND(IC32 pin 6, IC38 pin 11). Pro's
// IC32 and IC38 are this sheet's IC57 and IC52 (same function, same inputs),
// so on this model's nets it is AND(HWIN, HC4): high for HC = 0x90..0x9F
// while /COIN IN is low, on every line the counter runs (no vertical term).
// With pro = 0 the output is low: the original board has no PLAYER ST.
module jtmonacogp_player #(
    // IC119 (R16 = 47k, C30 = 10 uF) and IC19 (R19 = 47k, C33 = 10 uF), values
    // as read from the scan; 74123 data sheet: tw = 0.28*R*C*(1+0.7/R)
    // = 0.13356 s = 955290 periods of 7.1525 MHz.
    parameter integer IC119_PIXELS = 955290,
    parameter integer IC19_PIXELS  = 955290
)(
    input            clk, rst,
    input            pxl_cen,
    // Sheet E
    input            hs,            // HS, active high; IC63 pin 5 sees /HS
    // Sheet F
    input            pl_h_st,       // PL-H-ST: IC52 pins 2, 12
    input            pl_v_st,       // PL-V-ST: IC54 pins 2, 12
    input            explo_st,      // EXPLO.ST: IC62 pin 10
    input            explo_st_n,    // /EXPLO.ST: PR128..130 pins 18, 19; IC68 pin 1
    input            acc1_n,        // /ACC1: IC66 pin 1, IC95 pins 5, 9
    input            home_pos_n,    // /HOME POS.: IC51 pin 5
    // Sheet A
    input            coin_in_n,     // /COIN IN: IC57 pin 1
    input            extend_n,      // /EXTEND: IC62 pin 5
    // Sheet D
    input            gravel_n,      // /GRAVEL: IC66 pin 12
    input            slide_n,       // /SLIDE: IC66 pin 13, IC19 pin 1
    // Sheet H frame counter
    input            vs4, vs8, vs16, vs32,
    // IC51 pin 3 (/S2 of the window latch) is not drawn
    input            ic51_3,
    // Pro board; 0 for the original board
    input            pro,           // 1: Pro Monaco GP board
    // PR127..PR130 = IC77, IC84, IC91, IC98 (7641). Address A8..A0.
    output     [8:0] pr127_addr, pr128_addr, pr129_addr, pr130_addr,
    input      [7:0] pr127_q, pr128_q, pr129_q, pr130_q,
    // Outputs
    output           player_body_n, // IC83 pin 2 -> (C) BV
    output           tire_n,        // IC83 pin 3 -> (C) B19 "/PLAYER TIAR"
    output           player_bl_n,   // IC83 pin 4 -> (C) BW
    output           player_n,      // IC61 pin 10 -> (C) B9
    output           player,        // IC44 pin 10 -> (F) PLAYER
    output           sp_down_n,     // IC72 pin 1 -> (F) /SP.DOWN
    output           sp_down,       // IC119 pin 5 -> (F) SP.DOWN
    output           acc1_pulse_n,  // IC80 pin 6 -> (F) /ACC1.PULSE
    output           acc1_st_n,     // IC51 pin 7 -> (F) /ACC1.ST
    output           score_st_n,    // IC19 pin 4 -> (F) /SCORE.ST
    output           ic66_3,        // also IC51 pin 11 (latch 3, not traced)
    output           player_st,     // Pro IC31 pin 3 -> (N) PLAYER ST; low with pro = 0
    // Internal nets, for tests and the development view
    output     [7:0] hc, vc,        // IC52, IC54 outputs QA..QD (lower, upper)
    output           vwin,          // IC51 pin 4
    output           hwin,          // IC57 pin 6
    output           strobe_n,      // IC62 pin 8
    output     [3:0] prom_en,       // {PR130, PR129, PR128, PR127} enabled
    output     [7:0] bus,           // PROM data D7..D0 at IC76
    output     [1:0] mux,           // {IC76 pin 9 (2Y), IC76 pin 7 (1Y)}
    output     [3:0] ic38_q,        // IC38 QD..QA (pins 8, 9, 10, 11)
    output           ic68_3,        // IC119 pin 10 and IC19 pin 2 (B inputs)
    output           ic19_q         // IC19 pin 13 -> IC51 pin 6
);
    reg  [2:0] cen_sr;
    reg  [7:0] hc_q, vc_q;
    reg  [3:0] ic38_cnt;
    reg [19:0] ic119_cnt, ic19_cnt;
    reg        vwin_q, ic51b_q;
    // Counter inputs at the end of the previous pixel period
    reg        hs_l, plh_l, plv_l, vs32_l, ic38_clr_l;
    // Monostable inputs at the previous evaluation edge
    reg        a119_l, b_l, clr119_l, slide_l;

    wire cen_d1 = cen_sr[0];
    wire cen_d3 = cen_sr[2];
    wire mono_eval = !cen_sr[0] && !cen_sr[1];

    // IC52 and IC54 (74393): asynchronous, active-high clears.
    assign hc = pl_h_st ? 8'd0 : hc_q;
    assign vc = pl_v_st ? 8'd0 : vc_q;

    // IC51 latch 1 (74279, set-dominant).
    // /R  pin 1 = IC48 NAND(VC6, VC4)
    // /S1 pin 2 = IC45 pin 12 = NAND(/VC6 [IC46 3->4], VC5, VC4)
    wire ic48 = ~(vc[6] & vc[4]);
    wire ic45_12 = ~(~vc[6] & vc[5] & vc[4]);
    assign vwin = ~(ic45_12 & ic51_3) | (ic48 & vwin_q);

    // IC57 (7425, strobe not drawn) = NOR(/COIN IN, HC5, HC6, /HC7 [IC46 5->6]).
    assign hwin = ~(coin_in_n | hc[5] | hc[6] | ~hc[7]);
    // Pro IC31 (1, 2 -> 3): pin 1 = IC32 pin 6 (HWIN), pin 2 = IC38 pin 11 (HC4).
    assign player_st = pro & hwin & hc[4];
    // IC56 (4, 5 -> 6) NAND, then IC62 (9, 10 -> 8) OR with EXPLO.ST.
    assign strobe_n = ~(vwin & hwin) | explo_st;

    // PROM pins 8..4 = A0..A4 = VC0..VC4; pins 3, 2, 1 = A5..A7 = HC2..HC4;
    // pin 23 = A8: Vs/4 on PR127, Vs/8 on PR128..PR130.
    wire [7:0] a = {hc[4:2], vc[4:0]};
    assign pr127_addr = {vs4, a};
    assign pr128_addr = {vs8, a};
    assign pr129_addr = {vs8, a};
    assign pr130_addr = {vs8, a};

    // IC19 (74123 half): A pin 1 = /SLIDE, B pin 2 = IC68 pin 3, /CLR pin 3 = Vcc.
    assign ic19_q = ic19_cnt != 0;
    assign score_st_n = ~ic19_q;
    // IC51 latch 2: /R pin 5 = /HOME POS., /S pin 6 = IC19 pin 13 (Q).
    assign acc1_st_n = ~ic19_q | (home_pos_n & ic51b_q);
    // IC62 (4, 5 -> 6) OR -> IC38 pin 12 (clear).
    wire ic38_clr = extend_n | acc1_st_n;
    assign ic38_q = ic38_clr ? 4'd0 : ic38_cnt;
    // IC80 (3, 4, 5 -> 6) = NAND(QB, QC, QD).
    assign acc1_pulse_n = ~(ic38_q[1] & ic38_q[2] & ic38_q[3]);

    // IC119 (74123 half): A pin 9 = IC66 pin 11 = AND(/GRAVEL, /SLIDE),
    // B pin 10 = IC68 pin 3, /CLR pin 11 = IC51 pin 7.
    wire a119 = gravel_n & slide_n;
    wire clr119 = acc1_st_n;
    assign sp_down = clr119 && ic119_cnt != 0;

    // Chip enables. PR127: /CE1, /CE2 grounded; CE3, CE4 = IC66 pin 3.
    assign ic66_3 = acc1_n & ~sp_down;         // AND(/ACC1, IC119 pin 12 /Q)
    assign sp_down_n = ~(ic38_q[3] | sp_down); // IC72 (3, 2 -> 1)
    // PR128 /CE1,/CE2 = IC72 pin 1; PR129 = IC95 pin 6 = OR(/ACC1, Vs/16);
    // PR130 = IC95 pin 8 = OR(/ACC1, IC73 pin 10 = /Vs/16).
    // PR128..PR130 CE3, CE4 = /EXPLO.ST.
    wire en127 = ic66_3;
    wire en128 = ~sp_down_n & explo_st_n;
    wire en129 = ~(acc1_n | vs16) & explo_st_n;
    wire en130 = ~(acc1_n | ~vs16) & explo_st_n;
    assign prom_en = {en130, en129, en128, en127};
    // Shared data bus. ASSUMPTION (three-state outputs): an undriven bus reads
    // high at the TTL inputs and simultaneous drivers resolve to the low level.
    assign bus = (en127 ? pr127_q : 8'hff) & (en128 ? pr128_q : 8'hff) &
                 (en129 ? pr129_q : 8'hff) & (en130 ? pr130_q : 8'hff);

    // IC76 (74153): A pin 14 = HC0, B pin 2 = HC1; 1C0..1C3 = D0..D3,
    // 2C0..2C3 = D4..D7; strobes pins 1, 15 = IC62 pin 8 (active low).
    wire [3:0] c1 = bus[3:0], c2 = bus[7:4];
    wire y1 = ~strobe_n & c1[hc[1:0]];
    wire y2 = ~strobe_n & c2[hc[1:0]];
    assign mux = {y2, y1};
    // IC83 (7442): A = 1Y, B = 2Y, C = D = strobe. Codes 12..15 select nothing.
    wire [3:0] bcd = {strobe_n, strobe_n, y2, y1};
    assign player_body_n = bcd != 4'd1;
    assign tire_n        = bcd != 4'd2;
    assign player_bl_n   = bcd != 4'd3;
    assign player_n      = ~(y1 | y2);        // IC61 (8, 9 -> 10)
    assign player        = ~player_body_n;    // IC44 (11 -> 10)
    // IC68 (1, 2 -> 3), drawn as OR with inverted inputs.
    assign ic68_3 = ~(explo_st_n & player_body_n);

    // 74123 triggers. When several inputs change between two evaluation edges
    // they are taken in the order they settle within a pixel: the A input
    // first (other sheets), then B (the decoded car pixel), then /CLR.
    wire trig119 = (a119_l && !a119 && b_l) || (!b_l && ic68_3 && !a119) ||
                   (!clr119_l && clr119 && !a119 && ic68_3);
    wire trig19  = (slide_l && !slide_n && b_l) || (!b_l && ic68_3 && !slide_n);

    always @(posedge clk) begin
        if (rst) begin
            cen_sr     <= 0;
            // Stopped states (IC34 and IC63 hold the clocks): the first frame
            // after reset is then the same as every later one.
            hc_q       <= 8'ha0;
            vc_q       <= 8'h80;
            ic38_cnt   <= 0;
            ic119_cnt  <= 0;
            ic19_cnt   <= 0;
            vwin_q     <= 0;
            ic51b_q    <= 1; // arbitrary power-on state
            hs_l       <= 0;
            plh_l      <= 0;
            plv_l      <= 0;
            vs32_l     <= 0;
            ic38_clr_l <= 1;
            a119_l     <= 1;
            b_l        <= 0;
            clr119_l   <= 1;
            slide_l    <= 1;
        end else begin
            cen_sr  <= {cen_sr[1:0], pxl_cen};
            // 74279 latches follow their inputs at all times.
            vwin_q  <= vwin;
            ic51b_q <= acc1_st_n;
            if (pxl_cen) begin
                hs_l       <= hs;
                plh_l      <= pl_h_st;
                plv_l      <= pl_v_st;
                vs32_l     <= vs32;
                ic38_clr_l <= ic38_clr;
            end
            if (cen_d1) begin
                // IC52: one count per 7 MHz period unless IC34 (HC5 & HC7)
                // holds IC63 pin 1 low: HC stops at 0xA0.
                if (pl_h_st || plh_l) hc_q <= 0;
                else if (!(hc_q[5] && hc_q[7])) hc_q <= hc_q + 8'd1;
                // IC54: IC63 pin 4 = NOR(/HS, VC7) counts the end of each HS
                // pulse and stops at 0x80.
                if (pl_v_st || plv_l) vc_q <= 0;
                else if (hs_l && !hs && !vc_q[7]) vc_q <= vc_q + 8'd1;
                // IC38: counts falling edges of Vs/32.
                if (ic38_clr || ic38_clr_l) ic38_cnt <= 0;
                else if (vs32_l && !vs32) ic38_cnt <= ic38_cnt + 4'd1;
            end
            if (mono_eval) begin
                a119_l   <= a119;
                b_l      <= ic68_3;
                clr119_l <= clr119;
                slide_l  <= slide_n;
                // Retriggerable: a trigger restarts the full period.
                if (!clr119) ic119_cnt <= 0;
                else if (trig119) ic119_cnt <= IC119_PIXELS[19:0];
                else if (cen_d3 && ic119_cnt != 0) ic119_cnt <= ic119_cnt - 20'd1;
                if (trig19) ic19_cnt <= IC19_PIXELS[19:0];
                else if (cen_d3 && ic19_cnt != 0) ic19_cnt <= ic19_cnt - 20'd1;
            end
        end
    end
endmodule
