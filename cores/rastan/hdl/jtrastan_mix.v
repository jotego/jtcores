/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-7-2026 */

// Rastan mono signal path: FM left + FM right + 1.1 * filtered PCM.
module jtrastan_mix(
    input                       rst,
    input                       clk,
    input                       sample,
    input signed       [15:0]   fm_l,
    input signed       [15:0]   fm_r,
    input signed       [11:0]   pcm,
    output signed      [15:0]   snd,
    output reg                  peak
);

wire signed [15:0] pcm16, pcm_filt, pcm_gain;
wire               pcm_peak, mix_peak;

assign pcm16 = {pcm,pcm[3:0]};

always @(posedge clk) begin
    peak <= mix_peak | pcm_peak;
end

jtframe_fir #(
    .COEFFS ( "fir_192k_4k.hex" )
) u_pcm_filter(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .sample ( sample      ),
    .l_in   ( pcm16       ),
    .r_in   ( 16'd0       ),
    .l_out  ( pcm_filt    ),
    .r_out  (             )
);

jtframe_limmul u_pcm_gain(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .cen    ( sample   ),
    .sin    ( pcm_filt ),
    .gain   ( 8'h8d    ), // 1.1 in unsigned 1.7 format
    .peaked ( 1'b0     ),
    .mul    ( pcm_gain ),
    .peak   ( pcm_peak )
);

jtframe_limsum #(
    .K ( 3 )
) u_mix(
    .rst    ( rst                    ),
    .clk    ( clk                    ),
    .cen    ( sample                 ),
    .parts  ( {pcm_gain,fm_l,fm_r}   ),
    .en     ( 3'b111                 ),
    .sum    ( snd                    ),
    .peak   ( mix_peak               )
);

endmodule
