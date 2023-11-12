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
    Date: 27-10-2017 */

module jttora_sound(
    input           rst,
    input           clk,
    input           cen3,    //  3   MHz
    input           cenfm,   //  3.57   MHz
    input           cenp384, //  384 kHz
    input           jap,
    input           f1dream,
    // Interface with main CPU
    input   [7:0]   snd_latch,
    // Interface with MCU
    input   [7:0]   snd_din,
    output  [7:0]   snd_dout,
    output          snd_mcu_wr,
    // Sound control
    input           enable_psg,
    input           enable_fm,
    input   [ 1:0]  psg_level,
    // ROM
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // ADPCM ROM
    output  [15:0]  rom2_addr,
    output          rom2_cs,
    input   [ 7:0]  rom2_data,
    input           rom2_ok,

    // Sound output
    output signed [15:0] ym_snd,
    output               sample,
    output  reg          peak,
    output        [ 7:0] debug_view
);
`ifndef NOSOUND
wire signed [15:0] fm_snd;
wire signed [11:0] adpcm_snd, prepcm_snd;
wire        [ 7:0] snd2_latch;
wire               fm_peak, mix_peak;

// It looks like the sound CPU never interacts with the MCU
// So I do not bother to fully connect it
assign snd_mcu_wr = 1'b0;
assign snd_dout   = 8'd0;
assign adpcm_snd  = jap ? prepcm_snd : 12'd0;

always @(posedge clk) peak <= mix_peak | fm_peak;

jtgng_sound #(.LAYOUT(3),.PSG_ATT(2)) u_fmcpu (
    .rst        (  rst          ),
    .clk        (  clk          ),
    .cen3       (  cenfm        ),
    .cen1p5     (  cenfm        ), // unused
    .sres_b     (  1'b1         ),
    .snd_latch  (  f1dream ? snd_din : snd_latch ),
    .snd2_latch (  snd2_latch   ),
    .snd_int    (  1'b1         ), // unused
    .enable_psg (  enable_psg   ),
    .enable_fm  (  enable_fm    ),
    .psg_level  (  psg_level    ),
    .rom_addr   (  rom_addr     ),
    .rom_cs     (  rom_cs       ),
    .rom_data   (  rom_data     ),
    .rom_ok     (  rom_ok       ),
    .ym_snd     (  fm_snd       ),
    .sample     (  sample       ),
    .peak       (  fm_peak      ),
    .debug_bus  ( 8'd0          ),
    .debug_view ( debug_view    )
);

reg [7:0] pcm_gain, fm_gain;
reg       pcm_rst;

always @(posedge clk) pcm_rst <= f1dream | rst;

always @(posedge clk) begin
    if( !enable_psg )
        pcm_gain <= 8'h0;
    else begin
        case( psg_level )
            2'd0: pcm_gain <= 8'h03;
            2'd1: pcm_gain <= 8'h06;
            2'd2: pcm_gain <= 8'h0c;
            2'd3: pcm_gain <= 8'h18;
        endcase
    end
    fm_gain <= jap ? 8'h0c : 8'h10;
end

jttora_adpcm u_adpcmcpu(
    .rst        ( pcm_rst       ),
    .clk        ( clk           ),
    .cen3       ( cen3          ),
    .cenp384    ( cenp384       ),
    // Interface with second CPU
    .snd2_latch ( snd2_latch    ),
    // ADPCM ROM
    .rom2_addr  ( rom2_addr     ),
    .rom2_cs    ( rom2_cs       ),
    .rom2_data  ( rom2_data     ),
    .rom2_ok    ( rom2_ok       ),
    // Sound output
    .snd        ( prepcm_snd    )
);


jtframe_mixer #(.W0(16),.W1(12)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cenfm     ),
    // input signals
    .ch0    ( fm_snd    ),
    .ch1    ( adpcm_snd ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    // adpcm_snd doesn't seem to be used in its full dynamic range
    // so I can multiply by x2
    .gain0  ( fm_gain   ),
    .gain1  ( pcm_gain  ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( ym_snd    ),
    .peak   ( mix_peak  )
);

`else // NOSOUND
    assign snd_dout   = 0;
    assign snd_mcu_wr = 0;
    assign rom_addr   = 0;
    assign rom_cs     = 0;
    assign rom2_addr  = 0;
    assign rom2_cs    = 0;
    assign ym_snd     = 0;
    assign sample     = 0;
    assign debug_view = 0;
    initial peak = 0;
`endif
endmodule