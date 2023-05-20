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
    Date: 19-3-2023 */

// Compatible with TMP95C061

module jt95c061(
    input                 rst,
    input                 clk,
    output     [23:0]     addr,
    output reg [ 3:0]     map_cs, // cs[0] used as flash chip 0, cs[1] chip 1
                                  // cs[2/3] used for BIOS ROM
    input      [15:0]     din,
    output     [15:0]     dout,
    output     [ 1:0]     we
);

wire port_cs;
reg  [7:0] mmr[0:63];
reg  [3:0] pre_map_cs;
wire [2:0] intrq;

assign port_cs = addr[23:7]==0;
assign intrq = 0;

// memory mapper
// MSA registers set the starting address, counting in 64kB pages
// MAM registers set the size, from 256 bytes to 8MB
// the starting address is a multiple of the size, rounded down to the nearest
// 64kB page
localparam [6:0]
                 // 34~37 event capture, ignored
                 MSAR0 = 7'h3C, // set to 20 by NGPC firmware
                 MAMR0 = 7'h3D, // set to FF by NGPC firmware
                 MSAR1 = 7'h3E, // set to 80 by NGPC firmware
                 MAMR1 = 7'h3F, // set to 7F by NGPC firmware
                 // 44~47 event capture, ignored
                 // 4C~4E pattern generator, ignored
                 DREFCR= 7'h5A, // DRAM refresh rate, ignored
                 DMEMCR= 7'h5B, // DRAM mode, ignored
                 MSAR2 = 7'h5C, // set to FF by NGPC firmware
                 MAMR2 = 7'h5D, // set to FF by NGPC firmware
                 MSAR3 = 7'h5E, // set to FF by NGPC firmware
                 MAMR3 = 7'h5F, // set to FF by NGPC firmware
                 // 60~67 ADC, ignored
                 B0CS  = 7'h68, // set to 17 = 8 bits, 0 wait
                 B1CS  = 7'h69, // set to 17
                 B2CS  = 7'h6A, // set to 03 = 16 bits, 0 wait
                 B3CS  = 7'h6B; // set to 03

always @* begin
    pre_map_cs[0]=&{addr[23:21]^mmr[MSAR0][7:5],
                   (addr[20:16]^mmr[MSAR0][4:0])|mmr[MAMR0][7:3],
                    addr[15]   | mmr[MAMR0][2],
                    addr[14:9] | {6{mmr[MAMR0][1]}},
                    addr[8] | mmr[MAMR0][0]
                };
    pre_map_cs[1]=&{addr[23:20]^mmr[MSAR1][7:6],
                   (addr[21:16]^mmr[MSAR1][5:0])|mmr[MAMR1][7:2],
                    addr[15:9] | {7{mmr[MAMR1][1]}},
                    addr[8] | mmr[MAMR1][0], ~pre_map_cs[0]
                };
    pre_map_cs[2]=&{addr[23]   ^mmr[MSAR2][7],
                   (addr[22:16]^mmr[MSAR2][6:0])|mmr[MAMR2][7:1],
                    addr[15] | mmr[MAMR2][0], ~pre_map_cs[1:0]
                };
    pre_map_cs[3]=&{addr[23]   ^mmr[MSAR3][7],
                   (addr[22:16]^mmr[MSAR3][6:0])|mmr[MAMR3][7:1],
                    addr[15] | mmr[MAMR3][0], ~pre_map_cs[2:0]
                };
end

always @(posedge clk) begin
    map_cs <= pre_map_cs;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[MSAR0]
    end else begin
        if( port_cs && we ) begin
            mmr[ addr[6:0] ] <= dout;
        end
    end
end

jt900h #(.PC_RSTVAL(32'hFF1800)) u_cpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),

    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( dout      ),
    .we         ( we        ),

    .intrq      ( intrq     ),     // interrupt request
    // Register dump
    .dmp_addr   (           ),     // dump
    .dmp_dout   (           )
);


endmodule