/* SPDX-FileCopyrightText: 2026 meathax
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: meathax
 * Date: 6-9-2026 */

module jtmoo_dump(
    input             clk,
    input      [15:0] ioctl_addr,
    input      [ 7:0] dump_scr, dump_pal, dump_obj,
    input      [ 7:0] scr_mmr, pal_mmr, obj_mmr, ccu_mmr,
    input      [ 7:0] debug_bus, st_scr,
    output reg [ 7:0] ioctl_din, st_dout
);

// Version 1 scene format, offsets exclude the 128-byte EEPROM prefix.
// RAM words and register words are low byte first; palette is x/R/G/B.
localparam [127:0] SIGNATURE = 128'h4d4f4f5343454e450100000000000000;

always @(posedge clk) begin
    st_dout <= debug_bus[5] ? (debug_bus[4] ? pal_mmr : obj_mmr) : st_scr;
    if      (ioctl_addr < 16'h6000) ioctl_din <= dump_scr;
    else if (ioctl_addr < 16'h8000) ioctl_din <= dump_pal;
    else if (ioctl_addr < 16'hc000) ioctl_din <= dump_obj;
    else if (ioctl_addr < 16'hc048) ioctl_din <= scr_mmr;
    else if (ioctl_addr >= 16'hc080 && ioctl_addr < 16'hc08d)
        ioctl_din <= pal_mmr;
    else if (ioctl_addr >= 16'hc0a0 && ioctl_addr < 16'hc0c0)
        ioctl_din <= pal_mmr;
    else if (ioctl_addr >= 16'hc0c0 && ioctl_addr < 16'hc0c8)
        ioctl_din <= obj_mmr;
    else if (ioctl_addr >= 16'hc0d0 && ioctl_addr < 16'hc0e0)
        ioctl_din <= ccu_mmr;
    else if (ioctl_addr >= 16'hc0e0 && ioctl_addr < 16'hc0f0)
        ioctl_din <= SIGNATURE[{~ioctl_addr[3:0],3'b000} +: 8];
    else ioctl_din <= 8'd0;
end

endmodule
