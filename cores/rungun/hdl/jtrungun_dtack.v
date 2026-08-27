/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-7-2025 */

module jtrungun_dtack(
    input       clk, pxl_cen,
    input       bus_dtackn,
    input       fix_cs,
    input [1:0] dsn,
    output      dtackn
);

wire fix_acc, fix_dt;

assign fix_acc = ~dsn[0] & fix_cs;
assign dtackn  =~(~fix_acc | fix_dt) | bus_dtackn;

jtframe_sh #(.W(1),.L(3)) u_fixsh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( fix_acc   ),
    .drop   ( fix_dt    )
);

endmodule 