/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtseicro_nsc8105_decode(
    input            enable,
    input      [7:0] raw,
    output     [7:0] opcode
);

assign opcode=enable ? {raw[6],raw[7],raw[5:2],raw[0],raw[1]} : raw;

endmodule
