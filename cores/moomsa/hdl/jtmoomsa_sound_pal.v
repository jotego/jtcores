/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_sound_pal(
    input  [15:0] addr,
    input         mreq_n,
    input         rfsh_n,
    input         rd_n,
    output        rom_cs,
    output        ram_cs,
    output        fm_cs,
    output        pcm_cs,
    output        bank_cs,
    output        latch_cs
);

wire mem_acc = !mreq_n && rfsh_n;
/* verilator lint_off UNUSEDSIGNAL */
wire [9:0] addr_lo_diag = addr[9:0];
/* verilator lint_on UNUSEDSIGNAL */

assign rom_cs = mem_acc && !rd_n && ((!addr[15] && addr[14]) || !addr[14]);
assign ram_cs = mem_acc && addr[15] && addr[14] && !addr[13];
assign fm_cs = mem_acc && addr[15] && addr[14] && addr[13] && !addr[12] && addr[11];
assign pcm_cs = mem_acc && addr[15] && addr[14] && addr[13] && !addr[12] && !addr[11];
assign bank_cs = mem_acc && addr[15] && addr[14] && addr[13] && addr[12] && addr[11] && !addr[10];
assign latch_cs = mem_acc && addr[15:12] == 4'hf && !addr[11];

endmodule
