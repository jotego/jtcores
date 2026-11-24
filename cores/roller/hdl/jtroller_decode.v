/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * F11 (053758) and F12 (053759), from the Roller Games PCB. */

module jtroller_decode(
    input             as_n,
    input      [19:0] addr,
    input             g18p7,
    output            cs1_n,
    output     [ 3:0] rom_ab,
    output            rom_oe_n,
    output            data_oe_n,
    output            pal12_n,
    output            ccu_n,
    output            pal14_n,
    output            objset_n,
    output            objoe_n,
    output            pal17_n,
    output            obj_cs_n,
    output            objse_n
);

wire f12_en;

// F11 pins 1-9 are /AS, A15-A12, A19-A16. Pin 12 feeds F12 pin 1.
assign f12_en   = !as_n && addr[15:13]==3'b000;
assign cs1_n    = !(!as_n && addr[15:13]==3'b001); // F11 pin 13
assign rom_ab[0]= addr[13];                         // F11 pin 14
assign rom_ab[1]= !((!addr[15] && !addr[16]) ||
                   ( addr[15] && !addr[14]));       // F11 pin 15
assign rom_ab[2]= addr[15] || addr[17];             // F11 pin 16
assign rom_ab[3]= addr[15] || addr[18];             // F11 pin 17
assign data_oe_n= addr[15] || addr[14];             // F11 pin 18
// F11 pin 19 is configured active high in the GAL, unlike pins 12-18.
assign rom_oe_n = !addr[15] && !addr[14];           // F11 pin 19

// F12 pins 3-9 are A12-A6; pin 2 is G18 pin 7. All outputs are
// configured active low. A10, A7-A5 are don't-cares in these terms.
assign pal12_n  = !(f12_en && !addr[12] && !addr[11] &&
                    !addr[9] && !addr[8]);          // F12 pin 12
assign ccu_n    = !(f12_en && !addr[12] && !addr[11] &&
                    !addr[9] &&  addr[8]);          // F12 pin 13
assign pal14_n  = !(f12_en && !addr[12] && !addr[11] &&
                     addr[9] && !addr[8]);          // F12 pin 14
assign objset_n = !(f12_en && !addr[12] && !addr[11] &&
                     addr[9] &&  addr[8]);          // F12 pin 15
assign objoe_n  = !(f12_en &&  g18p7 && !addr[12] && addr[11]);
assign pal17_n  = !(f12_en && !g18p7 && !addr[12] && addr[11]);
assign obj_cs_n = !(f12_en && addr[12] && !addr[11]);
assign objse_n  = !(f12_en && addr[12] &&  addr[11]);

endmodule
