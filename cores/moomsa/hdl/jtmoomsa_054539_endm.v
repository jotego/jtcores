/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_054539_endm(
    input  [15:0] step,
    input         dtype1,
    input         dtype2,
    output        ch_endm
);

wire z26  = ~(dtype2 & dtype1);
wire v39  = z26 & step[7];
wire v38b = ~(v39 | (|step[6:0]));
wire d2_n = ~dtype2;
wire v34  = d2_n & step[12];
wire v35  = d2_n & step[13];
wire v33d = d2_n & step[14];
wire v37  = d2_n & step[9];
wire v36  = d2_n & step[11];
wire v33c = d2_n & step[10];
wire v33b = d2_n & step[8];
wire v34b = ~(v34 | v35 | v33d | v37 | v36 | v33c | v33b | ~step[15]);

assign ch_endm = ~(v38b & v34b);

endmodule
