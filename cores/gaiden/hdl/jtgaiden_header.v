/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-3-2025 */

module jtgaiden_header(
    input            clk,
                     header, prog_we,
    input      [2:0] prog_addr,
    input      [7:0] prog_data,
    output reg [1:0] frmbuf=0,
    output reg       objdly=0,
                     mcutype=0,
                     vsize_en=0
);

localparam [2:0] FRAMEBUFFER=0, MCUTYPE=1;

always @(posedge clk) begin
    if( header && prog_addr[2:0]==FRAMEBUFFER  && prog_we ) begin
        {objdly,frmbuf} <= prog_data[2:0];
        vsize_en        <= prog_data[4];
    end
    if( header && prog_addr[2:0]==MCUTYPE  && prog_we )
        mcutype <= prog_data[0];
end

endmodule