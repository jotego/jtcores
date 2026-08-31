/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_main_rom_map(
    input             bank,
    input      [18:1] offset,
    output     [19:1] rom_addr
);

assign rom_addr = {bank,offset};

endmodule
