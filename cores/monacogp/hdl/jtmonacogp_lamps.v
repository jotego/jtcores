// SPDX-License-Identifier: GPL-3.0-or-later
// Pro Monaco GP, sheet I (manual 420-0525, PDF page 18): the bonus lamp
// PROMs PR-01 (IC55) and PR-02 (IC54) and the lamp unit's two commons, as
// read in pro/reconstruction/LAMP_PROMS.md, section 1.
//
// - Address: A0..A3 = BONUS A..D (sheet N's IC133 through IC126, A = LSB),
//   A4 = V2 (pad HH). Sheet N's IC133 sends the car count (IC132) while V2
//   is low and the stored bonuses (IC140) while it is high, so the address
//   is 16 * V2 + count.
// - Open-collector outputs: a 0 sinks current through the element's 220 ohm
//   resistor, so the element is ON; a 1 leaves it off.
//   PR-01 O1..O8 -> unit pins 3..10, PR-02 O1..O7 -> unit pins 11..17: the
//   15 element lines. Here pin 3 is bit 0 of each output word (position 1),
//   pin 17 bit 14 (position 15).
// - PR-02 O8 selects the common: 0 -> TR16 -> G26, 1 -> inverter 37 -> TR13
//   -> Gd. One common conducts at a time.
// The elements of a common keep what they showed during its last phase, as
// the panel's persistence does for jtmonacogp_panel.v's digits: g26 and gd
// are the 15 elements on each common, captured at each cen while that
// common is selected.
//
module jtmonacogp_lamps(
    input             clk, rst,
    input             cen,              // one capture per pixel
    input             v2,               // V2 (E), pad HH: A4
    input       [3:0] bonus,            // BONUS {D, C, B, A}: A3..A0
    output      [4:0] prom_addr,
    input       [7:0] q01, q02,
    output reg [14:0] g26,              // elements lit on common G26 (TR16)
    output reg [14:0] gd                // elements lit on common Gd (TR13)
);
    assign prom_addr = {v2, bonus};
    wire [14:0] on   = ~{q02[6:0], q01};   // 0 at an output = element on
    wire        sel_gd = q02[7];           // O8 high: TR13 (Gd), low: TR16 (G26)

    always @(posedge clk) begin
        if (rst) begin
            g26 <= 15'd0;
            gd  <= 15'd0;
        end else if (cen) begin
            if (sel_gd) gd  <= on;
            else        g26 <= on;
        end
    end
endmodule
