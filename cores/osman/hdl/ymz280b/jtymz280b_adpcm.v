/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */

module jtymz280b_adpcm(
    input         [ 3:0] nibble,
    input  signed [15:0] signal_in,
    input         [14:0] step_in,
    output reg signed [15:0] signal_out,
    output reg    [14:0] step_out
);

reg [ 9:0] scale;
reg [18:0] magnitude;
reg [24:0] scaled_step;
reg signed [19:0] next_signal;

always @* begin
    case(nibble[2:0])
        0,1,2,3: scale = 10'h0e6;
        4:       scale = 10'h133;
        5:       scale = 10'h199;
        6:       scale = 10'h200;
        7:       scale = 10'h266;
    endcase
    magnitude   = step_in * {nibble[2:0],1'b1};
    scaled_step = step_in * scale;
    next_signal = {{4{signal_in[15]}},signal_in};
    if(nibble[3]) next_signal = next_signal - $signed({4'd0,magnitude[18:3]});
    else          next_signal = next_signal + $signed({4'd0,magnitude[18:3]});
    signal_out = next_signal > 32767 ? 16'sh7fff :
                 next_signal < -32768 ? 16'sh8000 : next_signal[15:0];
    step_out = scaled_step[24:8] < 127 ? 15'd127 :
               scaled_step[24:8] > 24576 ? 15'd24576 : scaled_step[22:8];
end

endmodule
