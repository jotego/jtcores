/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_snd(
    input                    clk,
    input                    rst,
    input                    cen,
    input                    wr,
    input             [7:0]  din,
    input             [7:0]  v,
    output reg signed [15:0] snd,
    output reg               sample
);

reg [3:0] latch;
reg [14:0] level;
reg [15:0] noise;
reg [7:0] old_v;
wire [7:0] sources;
wire tone;

assign sources[0] = v[2];
assign sources[1] = v[3];
assign sources[2] = v[4];
assign sources[3] = v[5];
assign sources[4] = ~(v[0] | v[4]);
assign sources[5] = ~(v[1] | v[5]);
assign sources[6] = ~(v[2] | v[6]);
assign sources[7] = noise[15];
assign tone = sources[latch[2:0]];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        latch  <= 0;
        level  <= 0;
        noise  <= 16'h0000;
        old_v  <= 0;
        sample <= 0;
        snd    <= 0;
    end else begin
        sample <= 0;
        if (wr) begin
            latch <= din[3:0];
            level <= 15'h7fff;
            noise <= 16'h0000;
        end
        if (cen) begin
            old_v <= v;
            if (!wr && v[1:0] == 2'b10 && old_v[1:0] != 2'b10)
                noise <= {noise[14:0], noise[0] ^ ~noise[14]};
            if (v[0] != old_v[0]) begin
                sample <= 1;
                if (level != 0)
                    level <= level - (latch[3] ? ((level >> 8) | 15'd1) : ((level >> 10) | 15'd1));
                snd <= tone ? $signed({1'b0, level}) : 16'sd0;
            end
        end
    end
end

endmodule
