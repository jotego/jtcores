/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module jtmoomsa_inputs(
    input      [15:0] side_a,
    input      [15:0] side_b,
    input             sel,
    input             oe_n,
    output     [15:0] q
);

assign q = oe_n ? 16'hffff : (sel ? side_b : side_a);

endmodule
