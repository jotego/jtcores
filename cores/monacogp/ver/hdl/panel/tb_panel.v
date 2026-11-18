// SPDX-License-Identifier: GPL-3.0-or-later
// The score panel overlay (jtmonacogp_panel.v, not original circuitry) with
// pro = 0 and pro = 1 side by side, on the same LED lines. After each of a
// set of random LED states (and lamp and SUPER RACER SCORE values), the
// whole 360 x 240 raster is swept:
// - the two agree on every pixel outside what Pro adds: the line below the
//   original box, the bonus lamp box below it (tb_panel_lamps and
//   tb_panel_colour check its contents) and the two lamp places (the
//   caption's sixth place of SCORE and SUPER);
// - with pro = 1, the YOUR SCORE 10000POINT and TODAY'S HIGH SCORE 10000PT.
//   lamps are lit (12'hf00) or black as their inputs, and the SUPER RACER
//   SCORE digits show S4..S1 while FLAG is set and are dark while it is
//   clear, lit segments 12'hf00 and unlit ones black (#107's rule);
// - with pro = 1, inside the grown box only black, 12'hf00 and the caption
//   colour 12'hccc appear;
// - with pro = 0, nothing is drawn below the original box.
`timescale 1ns/1ps
module tb_panel;
    reg clk = 0, rst = 1, pxl_cen = 0;
    always #5 clk = ~clk;
    reg [2:0] scan = 0;
    reg [7:0] row_on = 0;
    reg [27:0] seg = 0;
    reg [8:0] x = 0, y = 0;
    reg tenk = 0, flag = 0;
    reg [15:0] srs = 0;
    wire [11:0] rgb0, rgb1;
    wire [11:0] bg = 12'h5a5;
    jtmonacogp_panel u0(.clk(clk),.rst(rst),.pxl_cen(pxl_cen),.scan(scan),.row_on(row_on),.seg(seg),
        .x(x),.y(y),.show(1'b1),.pro(1'b0),.tenk(tenk),.srs(srs),.srs_flag(flag),
        .cars_lamps(15'd0),.bonus_lamps(15'd0),.rgb_in(bg),.rgb_out(rgb0));
    jtmonacogp_panel u1(.clk(clk),.rst(rst),.pxl_cen(pxl_cen),.scan(scan),.row_on(row_on),.seg(seg),
        .x(x),.y(y),.show(1'b1),.pro(1'b1),.tenk(tenk),.srs(srs),.srs_flag(flag),
        .cars_lamps(15'd0),.bonus_lamps(15'd0),.rgb_in(bg),.rgb_out(rgb1));

    // the layout of jtmonacogp_panel.v, upright: u = 239 - y, w = x
    localparam integer U0 = 64, W0 = 88, BW = 112, LH = 19, DU = 56, DP = 12;
    function integer line_of(input integer w);   // 0..9, -1 outside
        integer j;
        begin
            line_of = -1;
            for (j = 0; j < 10; j = j + 1)
                if (w - W0 >= 8 + LH*j && w - W0 < 8 + LH*j + LH) line_of = j;
        end
    endfunction
    function [6:0] seg7(input [3:0] v);
        case (v)
        4'd0: seg7 = 7'b0111111;  4'd1: seg7 = 7'b0000110;  4'd2: seg7 = 7'b1011011;
        4'd3: seg7 = 7'b1001111;  4'd4: seg7 = 7'b1100110;  4'd5: seg7 = 7'b1101101;
        4'd6: seg7 = 7'b1111100;  4'd7: seg7 = 7'b0000111;  4'd8: seg7 = 7'b1111111;
        4'd9: seg7 = 7'b1100111;  default: seg7 = 7'b0000000;
        endcase
    endfunction

    integer seed = 32'h50414e4c, k, s, xi, yi, u, w, bu, bw, ln, lw, pos, su, sw, checked = 0;
    integer lamps_lit = 0, lamps_dim = 0, segs_lit = 0, segs_dark = 0;
    reg [6:0] want;
    reg lamp, in_new, sega;
    task automatic sweep;
        for (xi = 0; xi < 360; xi = xi + 1)
            for (yi = 0; yi < 240; yi = yi + 1) begin
                x = xi; y = yi; #1;
                u = 239 - yi; w = xi; bu = u - U0; bw = w - W0;
                ln = line_of(w); lw = bw - 8 - LH*ln;
                lamp = (ln == 5 || ln == 9) && bu >= 49 && bu < 55 && lw >= 6 && lw < 13 && u >= U0 && u < U0 + BW;
                in_new = u >= U0 && u < U0 + BW && bw >= 178 && bw < 178 + LH + 50;   // the line and the lamp box
                if (!lamp && !in_new && rgb0 !== rgb1)
                    $fatal(1, "pro changed (%0d, %0d) outside its additions: %h -> %h", xi, yi, rgb0, rgb1);
                if (in_new && rgb0 !== bg)
                    $fatal(1, "pro = 0 draws below the box at (%0d, %0d)", xi, yi);
                if (u >= U0 && u < U0 + BW && bw >= 0 && bw < 178 + LH &&
                    rgb1 !== 12'h000 && rgb1 !== 12'hf00 && rgb1 !== 12'hccc)
                    $fatal(1, "pro = 1: (%0d, %0d) inside the box is %h: not black, f00 or ccc", xi, yi, rgb1);
                if (lamp) begin
                    if (rgb1 !== ((ln == 5 ? tenk : flag) ? 12'hf00 : 12'h000))
                        $fatal(1, "lamp of line %0d at (%0d, %0d) is %h", ln, xi, yi, rgb1);
                    if (ln == 5 ? tenk : flag) lamps_lit = lamps_lit + 1; else lamps_dim = lamps_dim + 1;
                end
                // SUPER RACER SCORE digits, segment a of each: row 0 of the digit, columns 1..6
                if (ln == 9 && bu >= DU && bu < DU + 4*DP && lw == 2 && u >= U0 && u < U0 + BW) begin
                    pos = (bu - DU) / DP; su = (bu - DU) % DP;
                    if (su >= 1 && su <= 6) begin
                        want = flag ? seg7(srs[4*(3-pos) +: 4]) : 7'd0;
                        if (rgb1 !== (want[0] ? 12'hf00 : 12'h000))
                            $fatal(1, "SUPER RACER SCORE digit %0d (%h, FLAG %b): segment a is %h", pos, srs, flag, rgb1);
                        if (want[0]) segs_lit = segs_lit + 1; else segs_dark = segs_dark + 1;
                    end
                end
                checked = checked + 1;
            end
    endtask
    function integer rnd(input integer m); rnd = ($random(seed) & 32'h7fffffff) % m; endfunction
    initial begin
        repeat (3) @(negedge clk);
        rst = 0;
        for (k = 0; k < 12; k = k + 1) begin
            // a random LED state: every row captured once
            for (s = 0; s < 8; s = s + 1) begin
                @(negedge clk);
                scan = s; row_on = $random(seed); seg = $random(seed); pxl_cen = 1;
                @(negedge clk); pxl_cen = 0;
            end
            tenk = k[0]; flag = k[1];
            srs[15:12] = rnd(10); srs[11:8] = rnd(10); srs[7:4] = rnd(10); srs[3:0] = rnd(10);
            if (k == 2) srs = 16'h2345;
            sweep;
        end
        if (lamps_lit == 0 || lamps_dim == 0 || segs_lit == 0 || segs_dark == 0)
            $fatal(1, "coverage: lamps lit %0d dim %0d, segments lit %0d dark %0d", lamps_lit, lamps_dim, segs_lit, segs_dark);
        $display("PASS panel: %0d pixels, pro = 0 and pro = 1 agree outside the Pro lamps and line;", checked);
        $display("  lamp pixels lit (f00) %0d, unlit (black) %0d; SUPER RACER SCORE segment-a pixels lit (f00) %0d, unlit (black) %0d",
                 lamps_lit, lamps_dim, segs_lit, segs_dark);
        $finish;
    end
endmodule
