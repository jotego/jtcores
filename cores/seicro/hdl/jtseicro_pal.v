/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtseicro_pal(
    input      [1:0]  mode,
    input      [19:1] pin,
    output     [16:15] q
);

// Dump equations and physical pin connections: ../doc/hardware_verification.md.
assign q[15] = pin[4];
assign q[16] = mode==2 ? pin[19] :
    (&pin[9:6]) | !pin[3] | (mode==1 ? (!pin[2] & pin[19]) : pin[19]);

endmodule
