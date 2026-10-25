/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_decode(
    input      [23:1] addr,
    input            access,
    input            rnw, rpunch,
    output           rom_cs, work_cs, vram0_cs, vram1_cs,
                     oram_cs, pal_cs, gga_cs, scroll_cs,
                     flags_cs, objctl_cs, sound_cs,
                     p1_cs, p2_cs, dip_cs, pending_cs
);

wire [19:0] a = {addr[19:1], 1'b0};

assign rom_cs     = access && rnw && a < 20'h40000;
assign work_cs    = access && (a >= 20'hfc000 ||
                             (rpunch && a >= 20'h40000 && a <= 20'h4fffe));
assign vram0_cs   = access && a >= 20'h80000 && a <= 20'h81ffe;
assign vram1_cs   = access && a >= 20'h82000 && a <= 20'h83ffe;
assign oram_cs    = access && a >= 20'h60000 && a <= 20'h60ffe;
assign pal_cs     = access && a >= 20'ha0000 && a <= 20'ha07fe;
assign gga_cs     = access && !rnw && (a & 20'hfffdf) == 20'hc0008;
assign scroll_cs  = access && !rnw && a >= 20'hc0000 && a <= 20'hc0006;
assign flags_cs   = access && !rnw && a == 20'hc000c;
assign objctl_cs  = access && !rnw && (a == 20'hc0010 || a == 20'hc0012);
assign sound_cs   = access && !rnw && a == 20'hc000e;
assign p1_cs      = access && rnw && a == 20'hc0018;
assign p2_cs      = access && rnw && a == 20'hc001a;
assign dip_cs     = access && rnw && a == 20'hc001c;
assign pending_cs = access && rnw && a == 20'hc001e;

endmodule
