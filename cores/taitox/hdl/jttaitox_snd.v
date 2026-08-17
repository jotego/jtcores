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
    input                snd_cen,    // Z80, gated on the sound-ROM wait

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
wire [ 3:0] syt_dout;
wire        mreq_n, rd_n, wr_n, iorq_n, m1_n, rfsh_n, int_n, nmi_n, cpu_cen;
wire        snd_rst, rst_n;
reg  [ 1:0] bank;
reg  [ 7:0] din;
wire        ram_cs, ym_cs, syt_sel, bank_cs, mem;
wire [19:0] ym_adpcma_addr;
wire [23:0] ym_adpcmb_addr;
wire [ 4:0] ym_adpcma_bank;
wire        ym_adpcma_roe_n, ym_adpcmb_roe_n;

assign mem      = ~mreq_n & rfsh_n;
assign rom_cs   = mem & ~A[15];
assign ram_cs   = mem & A[15:13]==3'b110;
assign ym_cs    = mem & A[15:8]==8'hE0;
assign syt_sel  = mem & A[15:8]==8'hE2;
assign bank_cs  = mem & A[15:8]==8'hF2 & ~wr_n;
assign rom_addr = { A[14] ? bank : 2'd0, A[13:0] };
assign rst_n    = ~(rst | snd_rst);

assign adpcma_addr = ym_adpcma_addr[18:0];
assign adpcma_cs   = ~ym_adpcma_roe_n;
assign adpcmb_addr = ym_adpcmb_addr[18:0];
assign adpcmb_cs   = ~ym_adpcmb_roe_n;

always @(posedge clk) begin
    if( rst ) bank <= 0;
    else if( bank_cs ) bank <= z80_dout[1:0];
end

always @(posedge clk) begin
    din <= rom_cs  ? rom_data :
           ram_cs  ? ram_dout :
           ym_cs   ? ym_dout  :
           syt_sel ? { 4'd0, syt_dout } : 8'hff;
end

jtrastan_pc060 u_syt(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .main_cen   ( main_cen      ),
    .snd_cen    ( snd_cen       ),

    .main_dout  ( main_dout     ),
    .main_din   ( main_din      ),
    .main_addr  ( main_addr     ),
    .main_rnw   ( main_rnw      ),
    .main_cs    ( syt_cs        ),

    .snd_dout   ( z80_dout[3:0] ),
    .snd_din    ( syt_dout      ),
    .snd_addr   ( A[0]          ),
    .snd_rnw    ( wr_n          ),
    .snd_cs     ( syt_sel       ),
    .snd_nmin   ( nmi_n         ),
    .snd_rst    ( snd_rst       )
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
    .fm_snd         (                   ),
    .psg_snd        (                   ),
    .snd_right      ( fm_r              ),
    .snd_left       ( fm_l              ),
    .snd_sample     (                   ),
    .ch_enable      ( 6'b111111         )
);
`else
assign rom_addr=0, rom_cs=0, main_din=0,
       adpcma_addr=0, adpcma_cs=0, adpcmb_addr=0, adpcmb_cs=0,
       fm_l=0, fm_r=0;
`endif

endmodule
