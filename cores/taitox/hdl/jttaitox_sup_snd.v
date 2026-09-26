/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received A copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-8-2026 */

/*  P0-039A / P0-057A sound: TC0140SYT + YM2610.

    The TC0140SYT owns the Z80 memory decode as well as the 68000 mailbox,
    so the map comes out of jttaitox_tc0140syc. The Z80 itself is shared
    with the other board and lives in jttaitox_snd.                       */

module jttaitox_sup_snd(
    input             rst,
    input             clk,
    input             cen8,        // 16/2 = 8 MHz
    input             main_cen,
    input             snd_cen,

    // 68000 side of the mailbox
    input             main_cs,
    input             main_addr,   // A1
    input      [ 3:0] main_dout,
    output     [ 3:0] main_din,
    input             main_rnw,

    // Z80 bus
    input      [15:0] A,
    input      [ 7:0] din,
    input             mreq_n,
    input             rfsh_n,
    input             wr_n,
    input      [ 7:0] ram_dout,
    output reg [ 7:0] cpu_din,
    output            nmi_n,
    output            int_n,
    output            z80_rst,

    output            rom_cs,
    output     [15:0] rom_addr,
    output            ram_cs,
    input      [ 7:0] rom_data,

    output     [18:0] adpcma_addr,
    output            adpcma_cs,
    input      [ 7:0] adpcma_data,
    output     [18:0] adpcmb_addr,
    output            adpcmb_cs,
    input      [ 7:0] adpcmb_data,

    output signed [15:0] fm_left, fm_right,
    output        [ 9:0] psg
);

wire [ 7:0] ym_dout;
wire [ 3:0] syt_dout;
wire        opx_n, syt_cs, ym_cs;
wire [19:0] ym_adpcma_addr;
wire [23:0] ym_adpcmb_addr;
wire [ 4:0] ym_adpcma_bank;
wire        ym_adpcma_roe_n, ym_adpcmb_roe_n;

assign ym_cs       = ~opx_n;
assign adpcma_addr = ym_adpcma_addr[18:0];
assign adpcma_cs   = ~ym_adpcma_roe_n;
assign adpcmb_addr = ym_adpcmb_addr[18:0];
assign adpcmb_cs   = ~ym_adpcmb_roe_n;

always @(posedge clk) begin
    cpu_din <= rom_cs ? rom_data :
               ram_cs ? ram_dout :
               ym_cs  ? ym_dout  :
               syt_cs ? { 4'd0, syt_dout } : 8'hff;
end

jttaitox_tc0140syc u_syt(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_cs    ( main_cs       ),
    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_din   ( main_din      ),
    .main_rnw   ( main_rnw      ),

    .addr       ( A             ),
    .din        ( din           ),
    .dout       ( syt_dout      ),
    .mreq_n     ( mreq_n        ),
    .rfsh_n     ( rfsh_n        ),
    .wr_n       ( wr_n          ),
    .nmi_n      ( nmi_n         ),
    .z80_rst    ( z80_rst       ),

    .rom_cs     ( rom_cs        ),
    .rom_addr   ( rom_addr      ),
    .ram_cs     ( ram_cs        ),
    .opx_n      ( opx_n         ),
    .syt_cs     ( syt_cs        )
);

jt10b u_jt10b(
    .rst            ( z80_rst           ),
    .clk            ( clk               ),
    .cen            ( cen8              ),
    .din            ( din               ),
    .addr           ( A[1:0]            ),
    .cs_n           ( ~ym_cs            ),
    .wr_n           ( wr_n              ),

    .dout           ( ym_dout           ),
    .irq_n          ( int_n             ),

    .adpcma_addr    ( ym_adpcma_addr    ),
    .adpcma_bank    ( ym_adpcma_bank    ),
    .adpcma_roe_n   ( ym_adpcma_roe_n   ),
    .adpcma_data    ( adpcma_data       ),
    .adpcmb_addr    ( ym_adpcmb_addr    ),
    .adpcmb_roe_n   ( ym_adpcmb_roe_n   ),
    .adpcmb_data    ( adpcmb_data       ),

    .psg_A          (                   ),
    .psg_B          (                   ),
    .psg_C          (                   ),
    .fm_left        ( fm_left           ),
    .fm_right       ( fm_right          ),
    .psg_snd        ( psg               ),
    .snd_right      (                   ),
    .snd_left       (                   ),
    .snd_sample     (                   ),
    .ch_enable      ( 6'b111111         )
);

endmodule
