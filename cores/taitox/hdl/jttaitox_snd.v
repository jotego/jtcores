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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

module jttaitox_snd(
    input                rst,
    input                clk,
    input                cen8,       // YM2610
    input                fm_cen,     // YM2151, P0-051A
    input                fm_cenp1,
    input                snd_cen,    // Z80, gated on the sound-ROM wait
    input                p051a,      // PC060HA + YM2151 instead of SYT + YM2610

    // 68k side of the comm chip
    input                main_cen,
    input                syt_cs,
    input                main_addr,  // 68k A1
    input         [ 3:0] main_dout,
    output        [ 3:0] main_din,
    input                main_rnw,

    output        [15:0] rom_addr,
    output               rom_cs,
    input                rom_ok,
    input         [ 7:0] rom_data,

    output        [18:0] adpcma_addr,
    output               adpcma_cs,
    input         [ 7:0] adpcma_data,
    output        [18:0] adpcmb_addr,
    output               adpcmb_cs,
    input         [ 7:0] adpcmb_data,

    output signed [15:0] fm_l, fm_r
);

`ifndef NOSOUND
// One Z80, two sound boards. Each board owns its own decode, data mux and
// chips; only the CPU and the board select live here.
wire [15:0] A, sup_rom_addr, hawk_rom_addr;
wire [ 7:0] z80_dout, ram_dout, sup_din, hawk_din;
wire [ 3:0] sup_main_din, hawk_main_din;
wire        mreq_n, rd_n, wr_n, iorq_n, m1_n, rfsh_n, cpu_cen;
wire        sup_nmi_n, sup_int_n, sup_rst, sup_rom_cs, sup_ram_cs;
wire        hawk_nmi_n, hawk_int_n, hawk_rst, hawk_rom_cs, hawk_ram_cs;
wire signed [15:0] sup_l, sup_r, hawk_l, hawk_r;
wire        rst_n, snd_rst, nmi_n, int_n, ram_cs;
wire [ 7:0] din;

assign nmi_n    = p051a ? hawk_nmi_n    : sup_nmi_n;
assign int_n    = p051a ? hawk_int_n    : sup_int_n;
assign snd_rst  = p051a ? hawk_rst      : sup_rst;
assign main_din = p051a ? hawk_main_din : sup_main_din;
assign din      = p051a ? hawk_din      : sup_din;
assign rom_cs   = p051a ? hawk_rom_cs   : sup_rom_cs;
assign rom_addr = p051a ? hawk_rom_addr : sup_rom_addr;
assign ram_cs   = p051a ? hawk_ram_cs   : sup_ram_cs;
assign fm_l     = p051a ? hawk_l        : sup_l;
assign fm_r     = p051a ? hawk_r        : sup_r;
assign rst_n    = ~(rst | snd_rst);

jtframe_sysz80 #(.RECOVERY(0), .RAM_AW(13)) u_z80(
    .rst_n      ( rst_n         ),
    .clk        ( clk           ),
    .cen        ( snd_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .int_n      ( int_n         ),
    .nmi_n      ( nmi_n         ),
    .busrq_n    ( 1'b1          ),
    .m1_n       ( m1_n          ),
    .mreq_n     ( mreq_n        ),
    .iorq_n     ( iorq_n        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .rfsh_n     ( rfsh_n        ),
    .halt_n     (               ),
    .busak_n    (               ),
    .A          ( A             ),
    .cpu_din    ( din           ),
    .cpu_dout   ( z80_dout      ),
    .ram_dout   ( ram_dout      ),
    .ram_cs     ( ram_cs        ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        )
);

// P0-039A / P0-057A: TC0140SYT + YM2610
jttaitox_sup_snd u_sup(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen8       ( cen8          ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_cs    ( syt_cs & ~p051a ),
    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_din   ( sup_main_din  ),
    .main_rnw   ( main_rnw      ),

    .a          ( A             ),
    .din        ( z80_dout      ),
    .mreq_n     ( mreq_n        ),
    .rfsh_n     ( rfsh_n        ),
    .wr_n       ( wr_n          ),
    .ram_dout   ( ram_dout      ),
    .cpu_din    ( sup_din       ),
    .nmi_n      ( sup_nmi_n     ),
    .int_n      ( sup_int_n     ),
    .z80_rst    ( sup_rst       ),

    .rom_cs     ( sup_rom_cs    ),
    .rom_addr   ( sup_rom_addr  ),
    .ram_cs     ( sup_ram_cs    ),
    .rom_data   ( rom_data      ),

    .adpcma_addr( adpcma_addr   ),
    .adpcma_cs  ( adpcma_cs     ),
    .adpcma_data( adpcma_data   ),
    .adpcmb_addr( adpcmb_addr   ),
    .adpcmb_cs  ( adpcmb_cs     ),
    .adpcmb_data( adpcmb_data   ),

    .snd_left   ( sup_l         ),
    .snd_right  ( sup_r         )
);

// P0-051A: PC060HA + YM2151
jttaitox_hawk_snd u_hawk(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .fm_cen     ( fm_cen        ),
    .fm_cenp1   ( fm_cenp1      ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_cs    ( syt_cs &  p051a ),
    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_din   ( hawk_main_din ),
    .main_rnw   ( main_rnw      ),

    .a          ( A             ),
    .din        ( z80_dout      ),
    .mreq_n     ( mreq_n        ),
    .rfsh_n     ( rfsh_n        ),
    .wr_n       ( wr_n          ),
    .ram_dout   ( ram_dout      ),
    .cpu_din    ( hawk_din      ),
    .nmi_n      ( hawk_nmi_n    ),
    .int_n      ( hawk_int_n    ),
    .z80_rst    ( hawk_rst      ),

    .rom_cs     ( hawk_rom_cs   ),
    .rom_addr   ( hawk_rom_addr ),
    .ram_cs     ( hawk_ram_cs   ),
    .rom_data   ( rom_data      ),

    .snd_left   ( hawk_l        ),
    .snd_right  ( hawk_r        )
);

`else
assign rom_addr=0, rom_cs=0, main_din=0,
       adpcma_addr=0, adpcma_cs=0, adpcmb_addr=0, adpcmb_cs=0,
       fm_l=0, fm_r=0;
`endif

endmodule
