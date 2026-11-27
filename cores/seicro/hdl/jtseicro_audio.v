/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtseicro_audio(
    input             rst, clk,
    input             seicross,
    input       [9:0] psg,
    input       [7:0] porta,
    input       [3:0] dac,
    output reg [15:0] psg_snd, dac_snd
);

wire [2:0] dac_weight={2'd0,dac[0]}+{1'b0,dac[1],1'b0}+
                      {2'd0,dac[2]}+{1'b0,dac[3],1'b0};
wire [13:0] psg_product=psg*porta[3:0];
wire [6:0] dac_product=porta[7:4]*dac_weight;

// 32768 counts per 5 V; AY amplitude provisionally 0.6 VDD.
wire [22:0] psg_level=psg_product*9'd289;
wire [14:0] dac_level=dac_product*8'd226;

always @(posedge clk) begin
    if(rst) begin
        psg_snd<=0;
        dac_snd<=0;
    end else if(seicross) begin
        psg_snd<={1'b0,psg_level[22:8]};
        dac_snd<={1'b0,dac_level};
    end else begin
        psg_snd<={1'b0,psg,5'd0};
        dac_snd<={2'd0,dac,10'd0};
    end
end

endmodule
