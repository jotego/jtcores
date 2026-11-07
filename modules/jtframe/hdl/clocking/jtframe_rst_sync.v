/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-9-2021 */

// Reference:
// https://www.intel.com/content/www/us/en/programmable/quartushelp/15.1/index.htm#verify/da/comp_file_rules_reset_synch.htm

module jtframe_rst_sync(
    input   rst,
    input   clk,
    output  rst_sync
);

reg [1:0] s;

assign rst_sync = s[1];

always @(posedge clk) begin
    s <= { s[0], rst };
end

endmodule