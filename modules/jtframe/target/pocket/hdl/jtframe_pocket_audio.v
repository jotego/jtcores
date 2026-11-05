/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 26-8-2022 */

// Based on Mazamar's code

module jtframe_pocket_audio(
    input           rst,
    input           clk_74a,
    // Base video
    input    [15:0] snd_left,
    input    [15:0] snd_right,
    input           snd_sample,

    output          mclk=0,  // 12.288 MHz
    output          dac,
    output          lrck
);

parameter [15:0] STEP = 4096,
                 OVER = 12375;

reg     [31:0]  audgen_sampshift;
reg     [ 4:0]  audgen_lrck_cnt;
reg             audgen_lrck;
reg             audgen_dac;

// generate MCLK = 12.288mhz with fractional accumulator
pll_audio u_pll(
    .rst        ( rst       ),
    .refclk     ( clk_74a   ),
    .outclk_0   ( mclk      )
);

assign dac  = audgen_dac;
assign lrck = audgen_lrck;

// generate SCLK = 3.072mhz by dividing MCLK by 4
    reg [1:0]   aud_mclk_divider;
    wire        audgen_sclk = aud_mclk_divider[1] /* synthesis keep*/;
    // reg         audgen_lrck_1;
always @(posedge mclk) begin
    aud_mclk_divider <= aud_mclk_divider + 1'b1;
    // rising edge
    // if(audgen_lrck & ~audgen_lrck_1) begin
        //aud_mclk_divider <= 1;
    // end
end

// shift out audio data as I2S
// 32 total bits per channel, but only 16 active bits at the start and then 16 dummy bits
//
// synchronize audio samples coming from the ram readout
    wire    [31:0]  audgen_sampdata_s;
synch_3 #(.WIDTH(32)) s5({snd_left, snd_right}, audgen_sampdata_s, audgen_sclk);
    //reg       [31:0]  audgen_sampdata = 32'hF0008000;

always @(negedge audgen_sclk) begin
    // output the next bit
    audgen_dac <= audgen_sampshift[31];

    // 48khz * 64
    audgen_lrck_cnt <= audgen_lrck_cnt + 1'b1;
    if(audgen_lrck_cnt == 31) begin
        // switch channels
        audgen_lrck <= ~audgen_lrck;

        if(audgen_lrck) begin
            // load new sample
            // RIFF wave data is stored as 16bit little endian signed, so byteswap 16-bit
            audgen_sampshift <= {audgen_sampdata_s};
        end
    end else begin
        // only shift for 16 clocks per channel
        if(audgen_lrck_cnt < 16) begin
            audgen_sampshift <= {audgen_sampshift[30:0], 1'b0};
        end

    end
end

endmodule
