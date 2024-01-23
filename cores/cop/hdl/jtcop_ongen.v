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
    Date: 26-9-2021 */

module jtcop_ongen(
    input                rst,
    input                clk,
    input                cen_opn,
    input                cen_opl,

    input                cpu_a0,
    input                cpu_rnw,
    input         [ 7:0] cpu_dout,

    input                opl_cs,
    output               opl_irqn,
    output        [ 7:0] opl_dout,

    input                oki_wrn,
    output        [ 7:0] oki_dout,

    input                enable_psg,
    input                enable_fm,
    input         [ 1:0] fxlevel,

    input                opn_cs,
    output               opn_irqn,
    output        [ 7:0] opn_dout,
    // ADPCM ROM
    output        [17:0] adpcm_addr,
    output               adpcm_cs,
    input         [ 7:0] adpcm_data,
    input                adpcm_ok,

    output signed [15:0] snd,
    output               sample,
    output               peak
);

parameter [7:0] OPL_GAIN = 8'h10,
                PCM_GAIN = 8'h20,
                PSG_GAIN = 8'h10;
parameter       KARNOV   = 0;

wire signed [15:0] opl_snd, opn_snd;
wire signed [15:0] adpcm_snd;
wire signed [13:0] oki_pre;
wire        [ 9:0] psg_snd, psgac_snd;
wire               oki_sample;

reg  [ 7:0] opn_gain;

always @(posedge clk) begin
    if( KARNOV )
        case( fxlevel )
            0: opn_gain = 8'h08;
            1: opn_gain = 8'h10;
            2: opn_gain = 8'h18;
            3: opn_gain = 8'h20;
        endcase
    else
        case( fxlevel )
            0: opn_gain = 8'h18;
            1: opn_gain = 8'h20;
            2: opn_gain = 8'h28;
            3: opn_gain = 8'h30;
        endcase
end

/* verilator tracing_on */
jtopl2 u_opl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_opl   ),
    .din    ( cpu_dout  ),
    .addr   ( cpu_a0    ),
    .cs_n   ( ~opl_cs   ),
    .wr_n   ( cpu_rnw   ),
    .dout   ( opl_dout  ),
    .irq_n  ( opl_irqn  ),
    .snd    ( opl_snd   ),
    .sample ( sample    )
);
/* verilator tracing_off */
jt03 u_2203(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_opn   ),
    .din    ( cpu_dout  ),
    .addr   ( cpu_a0    ),
    .cs_n   ( ~opn_cs   ),
    .wr_n   ( cpu_rnw   ),

    .dout   ( opn_dout  ),
    .irq_n  ( opn_irqn  ),
    // I/O pins used by YM2203 embedded YM2149 chip
    .IOA_in (           ),
    .IOB_in (           ),
    .IOA_out(           ),
    .IOB_out(           ),
    .debug_view(        ),
    .IOA_oe (           ),
    .IOB_oe (           ),
    // 10 kOhm resistors
    .psg_A  (           ),
    .psg_B  (           ),
    .psg_C  (           ),
    .fm_snd ( opn_snd    ),
    .psg_snd( psg_snd   ),
    .snd    (           ),
    .snd_sample()
);

`ifndef NOPCM
reg         cen_oki;
reg  [ 2:0] cen_sh=1;

assign adpcm_cs = 1;

always @(posedge clk) begin
    // 1 MHz clock enable
    if( cen_opl ) cen_sh <= cen_sh==0 ? 3'd1 : { cen_sh[1:0], cen_sh[2] };
    cen_oki <= cen_sh[0] & cen_opl & adpcm_ok;
end

jt6295 #(.INTERPOL(1)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_oki   ),  // 1MHz
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( oki_wrn   ),  // active low
    .din        ( cpu_dout  ),
    .dout       ( oki_dout  ),
    // ROM interface
    .rom_addr   ( adpcm_addr),
    .rom_data   ( adpcm_data),
    .rom_ok     ( adpcm_ok  ),
    // Sound output
    .sound      ( oki_pre   ),
    .sample     ( oki_sample)   // ~26kHz
);

jtframe_uprate2_fir u_fir1(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .sample     ( oki_sample     ),
    .upsample   (                ), // ~52kHz, close to JT51's 55kHz
    .l_in       ({oki_pre,2'd0}  ),
    .r_in       (     16'd0      ),
    .l_out      ( adpcm_snd      ),
    .r_out      (                )
);
`else
    assign adpcm_snd  = 0;
    assign adpcm_addr = 0;
    assign adpcm_cs   = 0;
    assign oki_dout   = 0;
`endif

jtframe_dcrm #(.SW(10)) u_dcrm(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( cen_opn   ),
    .din    ( psg_snd   ),
    .dout   ( psgac_snd )
);

jtframe_mixer_en #(.W3(10),.WOUT(16)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_opn   ),
    // input signals
    .ch0    ( opn_snd   ),
    .ch1    ( opl_snd   ),
    .ch2    ( adpcm_snd ),
    .ch3    ( psgac_snd ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( opn_gain  ),
    .gain1  ( OPL_GAIN  ),
    .gain2  ( PCM_GAIN  ),
    .gain3  ( PSG_GAIN  ),
    .ch_en  ( { 2'b11, enable_fm, enable_psg } ),
    .mixed  ( snd       ),
    .peak   ( peak      )
);

endmodule