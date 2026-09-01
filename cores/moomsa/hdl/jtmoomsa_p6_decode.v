/* SPDX-License-Identifier: GPL-3.0-or-later */

// GX151 P6 decode recovered from Konami_055373.jed.  The physical outputs are
// active low; resource selects below are normalized to active high.
module jtmoomsa_p6_decode(
    input       [23:1] addr,
    input              as_n,
    input              rw,
    input              uds_n,
    input              lds_n,
    output             pale_n,
    output             oram_we_n,
    output             pre_dtack_n,
    output             lyr_prio_n,
    output             vpa_n,
    output             main_rom_cs,
    output             palette_cs,
    output             work_cs,
    output             objram_cs,
    output      [1:0]  objram_we
);

wire active = !as_n;
wire oe1_hit     = active && addr[23:19] == 5'b00000;
wire oe2_hit     = active && addr[23:19] == 5'b00010;
wire pale_hit    = active && addr[23:17] == 7'b0000110;
wire work_hit    = active && addr[23:16] == 8'h18;
wire objram_hit  = active && addr[23:16] == 8'h19;
wire lyr_hit     = active && addr[23:14] == 10'h068;
wire scr_hit     = active && addr[23:14] == 10'h06c;
wire palette_hit = active && addr[23:14] == 10'h070;
wire vpa_hit     = active && addr[23];

// P6 pin 23/O0 is not named on the schematic and has no proven consumer.
/* verilator lint_off UNUSEDSIGNAL */
wire o0_hit = active && !addr[23] && !addr[22] && !addr[21] &&
              (!addr[20] || !addr[19] || (!addr[18] && !addr[17]));
wire [13:1] addr_low_alias_diag = addr[13:1];
/* verilator lint_on UNUSEDSIGNAL */

assign pale_n      = !pale_hit;
assign oram_we_n   = !objram_hit;
assign pre_dtack_n = !scr_hit;
assign lyr_prio_n  = !lyr_hit;
assign vpa_n       = !vpa_hit;

assign main_rom_cs = oe1_hit || oe2_hit;
assign palette_cs  = palette_hit;
assign work_cs     = work_hit;
assign objram_cs   = objram_hit;
assign objram_we = {
    objram_hit && !rw && !uds_n,
    objram_hit && !rw && !lds_n
};

endmodule
