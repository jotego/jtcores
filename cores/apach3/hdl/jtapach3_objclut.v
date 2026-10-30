/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_objclut(
    input             rst,
    input             clk,
    input      [11:0] index,
    output reg  [7:0] color,
    output reg        loaded,
    output reg [20:3] rom_addr,
    output reg        rom_cs,
    input      [63:0] rom_data,
    input             rom_ok
);

reg [8:0] load_index;
reg [63:0] clut [0:511];
reg [63:0] word_data;
reg [2:0] byte_index;

always @(posedge clk) begin
    word_data <= clut[index[11:3]];
    byte_index <= index[2:0] ^ 3'b001;
    color <= word_data[{byte_index,3'b000}+:8];
    if (rst) begin
        loaded <= 0;
        load_index <= 0;
        rom_addr <= 0;
        rom_cs <= 0;
    end else if (!loaded) begin
        if (rom_cs) begin
            if (rom_ok) begin
                clut[load_index] <= rom_data;
                rom_cs <= 0;
                if (&load_index) loaded <= 1;
                else load_index <= load_index + 1'b1;
            end
        end else begin
            rom_addr <= 18'h3fe00 + {9'd0,load_index};
            rom_cs <= 1;
        end
    end
end

endmodule
