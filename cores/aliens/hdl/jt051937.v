/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-4-2023 */

// Based on Furrtek's RE work on die shots
// and MAME documentation

// 1 kB external RAM holding 128 sprites, 8 bytes each
// the RAM is copied in during the first 8 lines of VBLANK
// the process is only done if the sprite logic is enabled
// and it gets halted while the CPU tries to write to the memory
// only active sprites (bit 7 of byte 0 set) are copied

// horizontal and vertical down scaling


module jt051937(    // sprite drawing
    input             rst,
    input             clk,
    input             pxl_cen,

    input             start,
    output reg        busy,

    // Tile details
    input      [17:0] base_addr,

    // ROM
    output reg [17:0] rom_addr,
    output reg        rom_cs,
    input             rom_ok,
    input      [31:0] rom_data,
    // New pixel
    output     [11:0] buf_din,
    output     [ 8:0] buf_addr,
    output            buf_we,
    // Debug
    input      [ 7:0] debug_bus
);

endmodule