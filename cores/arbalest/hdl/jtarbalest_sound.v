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

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 17-06-2026 */

// X1-010 PCM. In the metafox-class boards the X1-010 is mapped directly on the
// main 68000 bus (0x100000-0x103fff), so there is no sound CPU / command FIFO
// This module is just the chip wrapper.
module jtarbalest_sound(
    input              clk,
    input              rst,
    input              cen_pcm,

    // Main-bus CPU interface
    input              cs,
    input       [12:0] addr,       // main cpu_addr = A[13:1]
    input       [ 7:0] din,
    output      [ 7:0] dout,
    input              we,

    // PCM sample ROM (SDRAM pcm bank)
    output      [19:0] pcm_addr,
    input       [ 7:0] pcm_data,
    output             pcm_cs,

    // Sound output: left = music (8kHz AA), right = bass/sfx (4kHz AA)
    output signed [15:0] snd_left, snd_right
);
`ifndef NOSOUND
jtx1010 u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( dout      ),
    .we         ( we & cs   ),
    .cs         ( cs        ),

    .rom_addr   ( pcm_addr  ),
    .rom_data   ( pcm_data  ),
    .rom_cs     ( pcm_cs    ),

    .left       ( snd_left  ),
    .right      ( snd_right ),
    .sample     (           )
);
`else
    assign dout=0, pcm_addr=0, pcm_cs=0, snd_left=0, snd_right=0;
`endif
endmodule
