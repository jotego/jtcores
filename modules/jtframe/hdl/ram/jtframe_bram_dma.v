/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-21-2022 */

// Copy one BRAM to another at the edge of a signal
// cen can be used to slow down the process
// cen cannot bet set to 1 or the copy will fail

module jtframe_bram_dma #( parameter
    AW  = 11
)(
    input               rst,
    input               clk,
    input               cen, // cannot be 1'b1 or the copy will fail
    output reg [AW-1:0] addr,
    input               start,
    output reg          we
);

reg sl;

always @(posedge clk) begin
    if( rst ) begin
        we   <= 0;
        addr <= 0;
    end else if(cen) begin
        sl <= start;
        if( start & ~sl ) begin
            addr <= 0;
            we   <= 1;
        end
        if( we ) begin
            addr <= addr + 1'd1;
            we   <= ~&addr;
        end
    end
end

endmodule
