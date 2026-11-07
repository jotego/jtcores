/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-3-2025 */

module jtthundr_ioctl_mux(
    input            flip, bank,
    input      [7:0] backcolor, mmr0, mmr1, mmr2,
    input      [4:0] ioctl_addr,
    output reg [7:0] ioctl_din
);

always @* begin
    case(ioctl_addr[4:3])
        0: ioctl_din = mmr0;
        1: ioctl_din = mmr1;
        2: ioctl_din = mmr2;
        3: case(ioctl_addr[0])
            0: ioctl_din = backcolor;
            1: ioctl_din = {3'd0, flip, 3'd0, bank};
        endcase
    endcase
end

endmodule