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
wire [15:0] A;
wire [ 7:0] z80_dout, ym_dout, ram_dout;
wire [ 3:0] syt_dout, hawk_dout;
wire [ 7:0] opm_dout;
wire        hawk_nmi_n, hawk_rst, opm_int_n;
wire signed [15:0] opm_l, opm_r, ym2610_l, ym2610_r;
wire [ 3:0] syt_main_din, hawk_main_din;
wire        mreq_n, rd_n, wr_n, iorq_n, m1_n, rfsh_n, cpu_cen;
wire        rst_n;
wire        snd_rst, nmi_n, int_n, syt_nmi_n, syt_rst, ym2610_int_n;
wire        syt_mbox, syt_z80, hawk_mbox, hawk_z80;
reg  [ 7:0] din;
wire        ram_cs, ym_cs, syt_sel, opx_n;
wire [19:0] ym_adpcma_addr;
wire [23:0] ym_adpcmb_addr;
wire [ 4:0] ym_adpcma_bank;
wire        ym_adpcma_roe_n, ym_adpcmb_roe_n;

assign ym_cs    = ~opx_n;
// One Z80, two chip sets: the board flag picks which answers.
assign nmi_n    = p051a ? hawk_nmi_n : syt_nmi_n;
assign snd_rst  = p051a ? hawk_rst   : syt_rst;
assign int_n    = p051a ? opm_int_n  : ym2610_int_n;
assign main_din = p051a ? hawk_main_din : syt_main_din;
assign fm_l     = p051a ? opm_l : ym2610_l;
assign fm_r     = p051a ? opm_r : ym2610_r;
// Only the board's own mailbox sees the bus, so the idle one never
// advances its pointer. The Z80 decode still comes from u_syt, which is
// combinational on the address and identical on all three boards.
assign syt_mbox = syt_cs  & ~p051a;
assign syt_z80  = syt_sel & ~p051a;
assign hawk_mbox= syt_cs  &  p051a;
assign hawk_z80 = syt_sel &  p051a;
assign rst_n    = ~(rst | snd_rst);

assign adpcma_addr = ym_adpcma_addr[18:0];
assign adpcma_cs   = ~ym_adpcma_roe_n;
assign adpcmb_addr = ym_adpcmb_addr[18:0];
assign adpcmb_cs   = ~ym_adpcmb_roe_n;

always @(posedge clk) begin
    din <= rom_cs  ? rom_data :
           ram_cs  ? ram_dout :
           ym_cs   ? (p051a ? opm_dout : ym_dout) :
           syt_sel ? { 4'd0, p051a ? hawk_dout : syt_dout } : 8'hff;
end

jttaitox_tc0140syc u_syt(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_cs    ( syt_mbox      ),
    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_din   ( syt_main_din  ),
    .main_rnw   ( main_rnw      ),

    .a          ( A             ),
    .din        ( z80_dout      ),
    .dout       ( syt_dout      ),
    .mreq_n     ( mreq_n        ),
    .rfsh_n     ( rfsh_n        ),
    .wr_n       ( wr_n          ),
    .nmi_n      ( syt_nmi_n     ),
    .z80_rst    ( syt_rst       ),

    .rom_cs     ( rom_cs        ),
    .rom_addr   ( rom_addr      ),
    .ram_cs     ( ram_cs        ),
    .opx_n      ( opx_n         ),
    .syt_cs     ( syt_sel       )
);

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

jt10 u_jt10(
    .rst            ( ~rst_n            ),
    .clk            ( clk               ),
    .cen            ( cen8              ),
    .din            ( z80_dout          ),
    .addr           ( A[1:0]            ),
    .cs_n           ( ~ym_cs            ),
    .wr_n           ( wr_n              ),

    .dout           ( ym_dout           ),
    .irq_n          ( ym2610_int_n      ),

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
    .fm_snd         (                   ),
    .psg_snd        (                   ),
    .snd_right      ( ym2610_r          ),
    .snd_left       ( ym2610_l          ),
    .snd_sample     (                   ),
    .ch_enable      ( 6'b111111         )
);

jttaitox_hawk_snd u_hawk(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .fm_cen     ( fm_cen        ),
    .fm_cenp1   ( fm_cenp1      ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_cs    ( hawk_mbox     ),
    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_din   ( hawk_main_din ),
    .main_rnw   ( main_rnw      ),

    .a          ( A             ),
    .din        ( z80_dout      ),
    .dout       ( hawk_dout     ),
    .wr_n       ( wr_n          ),
    .syt_cs     ( hawk_z80      ),
    .ym_cs      ( ym_cs & p051a ),
    .nmi_n      ( hawk_nmi_n    ),
    .z80_rst    ( hawk_rst      ),
    .ym_dout    ( opm_dout      ),
    .int_n      ( opm_int_n     ),

    .snd_left   ( opm_l         ),
    .snd_right  ( opm_r         )
);

`else
assign rom_addr=0, rom_cs=0, main_din=0,
       adpcma_addr=0, adpcma_cs=0, adpcmb_addr=0, adpcmb_cs=0,
       fm_l=0, fm_r=0;
`endif

endmodule
