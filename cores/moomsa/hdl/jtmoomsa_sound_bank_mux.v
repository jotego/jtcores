/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_sound_bank_mux(
    input       snd_a14,
    input       snd_a15,
    input [3:0] sbank,
    output [3:0] muxed
);

assign muxed = snd_a15 ? sbank : {3'b000,snd_a14};

endmodule
