// SPDX-License-Identifier: GPL-3.0-or-later
// The score panel overlay's colours (jtmonacogp_panel.v, not original
// circuitry). After each of a set of random LED states, the whole 360 x 240
// raster is swept with the panel shown, then once with it hidden:
// - inside the box only black, the game's full red 12'hf00 and the caption
//   colour 12'hccc appear;
// - outside the box (and everywhere while hidden) the picture passes through;
// - segment a of every digit of lines 1ST..SCORE is 12'hf00 when its
//   segment line was captured lit and black when not (no dim red ghost).
// The first 8 states run with pro = 0 and random lamp inputs, which must not
// change anything. Then 4 states with pro = 1 (the Pro lamp box below the
// box) and random lamps: the game's green 12'h0f0 is allowed there only,
// each lamp pixel is green (top bar, lamps 1..9), red (top bar 10..14 and
// the bottom bar) or black as its input says, and the rest of the lamp box
// is black or caption. A last sweep hides the panel with pro = 1.
`timescale 1ns/1ps
module tb_panel_colour;
    reg clk = 0, rst = 1, pxl_cen = 0, show = 1, pro = 0;
    always #5 clk = ~clk;
    reg [2:0] scan = 0;
    reg [7:0] row_on = 0;
    reg [27:0] seg = 0;
    reg [14:0] cars_lamps = 0, bonus_lamps = 0;
    reg [8:0] x = 0, y = 0;
    wire [11:0] rgb;
    wire [11:0] bg = 12'h5a5;
    jtmonacogp_panel uut(.clk(clk),.rst(rst),.pxl_cen(pxl_cen),.scan(scan),.row_on(row_on),.seg(seg),
        .x(x),.y(y),.show(show),.pro(pro),.cars_lamps(cars_lamps),.bonus_lamps(bonus_lamps),
        // sheet I/K's Pro additions held off; their colours are in tb_panel.v
        .tenk(1'b0),.srs(16'd0),.srs_flag(1'b0),
        .rgb_in(bg),.rgb_out(rgb));

    // the layout of jtmonacogp_panel.v, upright: u = 239 - y, w = x
    localparam integer U0 = 64, W0 = 88, BW = 112, BH = 178, LH = 19, DU = 56, DP = 12;
    // the Pro lamp box: just below, 50 lines; lamps 5 wide at a pitch of 6
    // from column 11, rows 16..21 (top bar) and 37..42 (bottom bar)
    // the lamp box sits below the box, which is one line taller with pro = 1
    localparam integer LW0 = W0 + BH + 19, LBH = 50, LU = 11, LP = 6, GREEN = 9, NL = 14;
    reg [27:0] model [0:7];             // segments captured per row
    integer seed = 32'h52454431, k, s, xi, yi, u, w, bu, bw, ln, lw, pos, su, checked = 0;
    integer n_black = 0, n_red = 0, n_cap = 0, segs_lit = 0, segs_dark = 0;
    integer n_green = 0, lamp_on = 0, lamp_off = 0, lbw, lrw, lk;
    reg in_box, in_lbox, lrow;
    reg [6:0] want;
    reg [11:0] want_rgb;
    task automatic sweep;
        for (xi = 0; xi < 360; xi = xi + 1)
            for (yi = 0; yi < 240; yi = yi + 1) begin
                x = xi; y = yi; #1;
                u = 239 - yi; w = xi; bu = u - U0; bw = w - W0;
                in_box = show && u >= U0 && u < U0 + BW && w >= W0 && w < W0 + (pro ? BH + 19 : BH);
                in_lbox = show && pro && u >= U0 && u < U0 + BW && w >= LW0 && w < LW0 + LBH;
                if (in_lbox) begin
                    lbw = w - LW0; lrow = lbw >= 27; lrw = lrow ? lbw - 21 : lbw;
                    if (lrw >= 16 && lrw < 22 && bu >= LU && bu < LU + NL*LP && (bu - LU) % LP != LP - 1) begin
                        lk = (bu - LU) / LP;
                        want_rgb = !(lrow ? bonus_lamps[lk] : cars_lamps[lk]) ? 12'h000 :
                                   (!lrow && lk < GREEN) ? 12'h0f0 : 12'hf00;
                        if (rgb !== want_rgb)
                            $fatal(1, "(%0d, %0d) %0s bar lamp %0d is %h, expected %h", xi, yi,
                                   lrow ? "bottom" : "top", lk + 1, rgb, want_rgb);
                        if (want_rgb == 12'h000) lamp_off = lamp_off + 1; else lamp_on = lamp_on + 1;
                    end else if (rgb !== 12'h000 && rgb !== 12'hccc)
                        $fatal(1, "(%0d, %0d) in the lamp box, off the lamps, is %h", xi, yi, rgb);
                    case (rgb)
                        12'h000: n_black = n_black + 1;
                        12'hf00: n_red = n_red + 1;
                        12'h0f0: n_green = n_green + 1;
                        12'hccc: n_cap = n_cap + 1;
                    endcase
                end else if (!in_box) begin
                    if (rgb !== bg) $fatal(1, "(%0d, %0d) outside the box is %h, not the picture", xi, yi, rgb);
                end else begin
                    case (rgb)
                        12'h000: n_black = n_black + 1;
                        12'hf00: n_red = n_red + 1;
                        12'hccc: n_cap = n_cap + 1;
                        default: $fatal(1, "(%0d, %0d) inside the box is %h: not black, f00 or ccc", xi, yi, rgb);
                    endcase
                    // segment a: row 0 of the digit (lw = 2), columns 1..6, lines 0..5
                    ln = (bw - 8) / LH; lw = bw - 8 - LH*ln;
                    if (bw >= 8 && ln <= 5 && lw == 2 && bu >= DU && bu < DU + 4*DP) begin
                        pos = (bu - DU) / DP; su = (bu - DU) % DP;
                        if (su >= 1 && su <= 6) begin
                            want = model[ln][7*(3-pos) +: 7];
                            if (rgb !== (want[0] ? 12'hf00 : 12'h000))
                                $fatal(1, "line %0d digit %0d segment a is %h, lit %b", ln, pos, rgb, want[0]);
                            if (want[0]) segs_lit = segs_lit + 1; else segs_dark = segs_dark + 1;
                        end
                    end
                end
                checked = checked + 1;
            end
    endtask
    integer n_red0, n_black0, n_cap0;
    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        for (k = 0; k < 12; k = k + 1) begin
            pro = k >= 8;
            // a random LED state: every row captured once
            for (s = 0; s < 8; s = s + 1) begin
                @(negedge clk);
                scan = s; row_on = $random(seed); seg = $random(seed);
                if (k == 0) begin row_on = 8'hff; seg = 28'hfffffff; end   // all segments lit
                if (k == 1) row_on = 8'h00;                                // all dark
                model[s] = row_on[s] ? seg : 28'd0;
                pxl_cen = 1;
                @(negedge clk); pxl_cen = 0;
            end
            // random lamps; all lit with pro = 0 (k = 0) and pro = 1 (k = 8), all dark at k = 9
            cars_lamps = $random(seed); bonus_lamps = $random(seed);
            if (k == 0 || k == 8) begin cars_lamps = 15'h7fff; bonus_lamps = 15'h7fff; end
            if (k == 9) begin cars_lamps = 0; bonus_lamps = 0; end
            sweep;
            if (k == 7) begin
                if (n_green != 0) $fatal(1, "green with pro = 0");
                n_red0 = n_red; n_black0 = n_black; n_cap0 = n_cap;
            end
        end
        show = 0;
        sweep;
        if (n_black == 0 || n_red == 0 || n_cap == 0 || segs_lit == 0 || segs_dark == 0 ||
            n_green == 0 || lamp_on == 0 || lamp_off == 0)
            $fatal(1, "coverage: black %0d, red %0d, green %0d, caption %0d, segment a lit %0d dark %0d, lamp px on %0d off %0d",
                   n_black, n_red, n_green, n_cap, segs_lit, segs_dark, lamp_on, lamp_off);
        $display("PASS panel_colour: %0d pixels.", checked);
        $display("  pro = 0, 8 states, random lamp inputs: inside the box black %0d, f00 %0d, ccc %0d, nothing else (no 0f0)",
                 n_black0, n_red0, n_cap0);
        $display("  pro = 1, 4 states: box and lamp box black %0d, f00 %0d, 0f0 %0d, ccc %0d; lamp pixels lit %0d, unlit %0d",
                 n_black - n_black0, n_red - n_red0, n_green, n_cap - n_cap0, lamp_on, lamp_off);
        $display("  segment-a pixels lit (f00) %0d, unlit (black) %0d", segs_lit, segs_dark);
        $finish;
    end
endmodule
