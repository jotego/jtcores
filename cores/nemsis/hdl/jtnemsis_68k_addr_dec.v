/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  68000 CPU Address Decoder
//================================================================================

`default_nettype none

module jtnemsis_68k_addr_dec(
    input        as_n,
    input        lds_n,
    input        uds_n,
    input [23:1] cpu_addr,

    output reg   prom_cs_n,
    output reg   chara,
    output reg   excs_n,
    output reg   ram_cs_n,
    output reg   vzure,
    output reg   vramcs1,
    output reg   vramcs2,
    output reg   objram,
    output reg   color_ram,
    output reg   u11k_g_n,
    output reg   u13j_g_n,
    output reg   data_n,
    output reg   afe_n,
    output reg   input_mux_g_n,
    output reg   dip1_g_n,
    output reg   dip2_g_n
);

always @(*) begin
    reg u14j_en, u6j_g2b_n, u6j_en, u13g_g2a_n, u11e_sel_n, u13g_en, dip_sel_n;

    // [LS27] @ 16G, [LS00] @ 17J + AS signal
    u14j_en = cpu_addr[23:19] == 5'b0 && ~as_n;

    // [LS138] @ 14J
    prom_cs_n = !(u14j_en && cpu_addr[18] == 1'b0); // Y0-Y3
    chara     = !(u14j_en && cpu_addr[18:16] == 3'b100); // Y4
    u6j_g2b_n = !(u14j_en && cpu_addr[18:16] == 3'b101); // Y5
    ram_cs_n  = !(u14j_en && cpu_addr[18:16] == 3'b110); // Y6
    excs_n    = !(u14j_en && cpu_addr[18:16] == 3'b111); // Y7

    // [LS32] @ 11E, [LS04] @ 12G; grouped with ram_cs_n
    u6j_en = &{~u6j_g2b_n, ~as_n};

    // [LS138] @ 6J
    vzure     = !(u6j_en && cpu_addr[15:13] == 3'b000); // Y0
    vramcs1   = !(u6j_en && cpu_addr[15:13] == 3'b001); // Y1
    vramcs2   = !(u6j_en && cpu_addr[15:13] == 3'b010); // Y2
    objram    = !(u6j_en && cpu_addr[15:13] == 3'b011); // Y3
    color_ram = !(u6j_en && cpu_addr[15:13] == 3'b101); // Y5
    u13g_g2a_n = !(u6j_en && cpu_addr[15:13] == 3'b110); // Y6
    u11e_sel_n = !(u6j_en && cpu_addr[15:13] == 3'b111); // Y7

    // [LS32] @ 11E
    u11k_g_n = ~&{~lds_n, ~u11e_sel_n};
    u13j_g_n = ~&{~uds_n, ~u11e_sel_n};

    u13g_en = &{~u13g_g2a_n, ~lds_n};

    // [LS138] @ 13G
    data_n        = !(u13g_en && cpu_addr[12:10] == 3'b000); // Y0
    dip_sel_n     = !(u13g_en && cpu_addr[12:10] == 3'b001); // Y1
    afe_n         = !(u13g_en && cpu_addr[12:10] == 3'b010); // Y2
    input_mux_g_n = !(u13g_en && cpu_addr[12:10] == 3'b011); // Y3

    // [LS32] @ 4J, [LS04] @ 12G
    dip1_g_n = ~&{~dip_sel_n, ~cpu_addr[1]};
    dip2_g_n = ~&{~dip_sel_n, cpu_addr[1]}; // labelled DIP3 on PCB; connected to DIP2
end

endmodule
