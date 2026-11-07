/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-7-2026 */

// Operation Wolf signal path. The first TC0060DCA controls the two MSM5205
// paths. VA is attenuated 5 dB and mixed with the YM2151. Filtered VB is then
// added at 0.55 gain. A second TC0060DCA controls the two speaker outputs.
module jtopwolf_mix(
    input                       rst,
    input                       clk,
    input                       sample,
    input                       va_vol_we,
    input                       vb_vol_we,
    input                       spk1_vol_we,
    input                       spk2_vol_we,
    input              [ 7:0]   din,
    input signed       [15:0]   fm_l,
    input signed       [15:0]   fm_r,
    input signed       [11:0]   va,
    input signed       [11:0]   vb,
    output signed      [15:0]   snd_l,
    output signed      [15:0]   snd_r,
    output reg                  peak
);

wire signed [15:0] va16, vb16, vb_filt;
wire signed [15:0] va_amp, vb_amp, va_mix, vb_mix;
wire signed [15:0] pre_l, pre_r;
wire               va_peak, vb_peak, pre_l_peak, pre_r_peak;

assign va16 = {va[11],va,va[11-:3]}; // compensate for -6 dB attenuation in vb
assign vb16 = {vb,vb[11-:4]};

always @(posedge clk) begin
    peak <= |{va_peak, vb_peak, pre_l_peak, pre_r_peak};
end

jtframe_fir #(
    .COEFFS ( "fir_192k_4k.hex" )
) u_vb_filter(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .sample ( sample      ),
    .l_in   ( vb16        ),
    .r_in   ( 16'd0       ),
    .l_out  ( vb_filt     ),
    .r_out  (             )
);

jt060dca u_pcm_volume(
    .rst     ( rst       ),
    .clk     ( clk       ),
    .vol1_we ( va_vol_we ),
    .vol2_we ( vb_vol_we ),
    .din     ( din       ),
    .sin1    ( va16      ),
    .sin2    ( vb_filt   ),
    .sout1   ( va_amp    ),
    .sout2   ( vb_amp    )
);

jtframe_limmul u_va_gain(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .cen    ( sample   ),
    .sin    ( va_amp   ),
    .gain   ( 8'h48    ), // -5 dB
    .peaked ( 1'b0     ),
    .mul    ( va_mix   ),
    .peak   ( va_peak  )
);

jtframe_limmul u_vb_gain(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .cen    ( sample   ),
    .sin    ( vb_amp   ),
    .gain   ( 8'h46    ), // 0.55 in unsigned 1.7 format
    .peaked ( 1'b0     ),
    .mul    ( vb_mix   ),
    .peak   ( vb_peak  )
);

jtframe_limsum #(
    .K ( 3 )
) u_left(
    .rst    ( rst                  ),
    .clk    ( clk                  ),
    .cen    ( sample               ),
    .parts  ( {vb_mix,va_mix,fm_l} ),
    .en     ( 3'b111               ),
    .sum    ( pre_l                ),
    .peak   ( pre_l_peak           )
);

jtframe_limsum #(
    .K ( 3 )
) u_right(
    .rst    ( rst                  ),
    .clk    ( clk                  ),
    .cen    ( sample               ),
    .parts  ( {vb_mix,va_mix,fm_r} ),
    .en     ( 3'b111               ),
    .sum    ( pre_r                ),
    .peak   ( pre_r_peak           )
);

jt060dca u_master_volume(
    .rst     ( rst         ),
    .clk     ( clk         ),
    .vol1_we ( spk1_vol_we ),
    .vol2_we ( spk2_vol_we ),
    .din     ( din         ),
    .sin1    ( pre_l       ),
    .sin2    ( pre_r       ),
    .sout1   ( snd_l       ),
    .sout2   ( snd_r       )
);

endmodule
