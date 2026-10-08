/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2025 */

module jtflstory_single_line_buffer(
    input         clk, pxl_cen,
                  we,
    input  [10:0] din,
    input  [ 7:0] addr,
    input  [ 8:0] hvdump,
    output [10:0] pxl
);

reg clear, opaque, opaque_we;

always @* begin
    clear  = pxl_cen & hvdump[8];
end

always @* begin
    opaque    = din[3:0] != 4'hf;
    opaque_we = we & opaque;
end    

jtframe_dual_ram #(.AW(8), .DW(11)) u_linebuf (
    .clk0       ( clk         ),
    .addr0      ( addr        ),
    .data0      ( din         ),
    .we0        ( opaque_we   ),
    .q0         (             ),
    .clk1       ( clk         ),
    .addr1      ( hvdump[7:0] ),
    .data1      ( 11'hf       ),
    .we1        ( clear       ),
    .q1         ( pxl         )
);

endmodule