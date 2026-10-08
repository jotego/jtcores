/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2020 */

module jtcps1_cpucen(
    input       clk,
    input       cen12,
    input       cpu_speed,
    output reg  cpu_cen,
    output reg  cpu_cenb
);


wire nc0, cen10;

// Fractional cen cannot provide an uniformly spaced cenb
jtframe_frac_cen #(.W(2))u_cen10(
    .clk        ( clk           ),
    .n          ( 10'd5         ),
    .m          ( 10'd24        ),
    .cen        ( {nc0, cen10  }),
    .cenb       (               ) // 180 shifted
);

reg cenx;

always @(posedge clk) begin
    cpu_cen  <= cpu_speed ? cen12 : cen10;
    cenx     <= cpu_cen;
    cpu_cenb <= cenx;
end

endmodule