/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-1-2025 */

// captures one byte from the header at a given offset
module jtframe_headerbyte #(parameter
    OFFSET=0,
    AW    =6
)(
    input            clk,
    input            header,
    input   [AW-1:0] ioctl_addr,
    input            ioctl_wr,
    input      [7:0] ioctl_dout,
    output reg [7:0] dout=0
);

always @(posedge clk) begin
    if(header && ioctl_wr && ioctl_addr==OFFSET[AW-1:0])
        dout <= ioctl_dout;
end

endmodule