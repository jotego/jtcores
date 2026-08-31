/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_k056832_tile_decode(
    input  [2:0] x,
    input  [31:0] raw,
    output [3:0] pen
);

function [3:0] decode(input [2:0] px, input [31:0] d);
    begin
        case(px)
            3'd0: decode = d[11:8];
            3'd1: decode = d[15:12];
            3'd2: decode = d[3:0];
            3'd3: decode = d[7:4];
            3'd4: decode = d[27:24];
            3'd5: decode = d[31:28];
            3'd6: decode = d[19:16];
            default: decode = d[23:20];
        endcase
    end
endfunction

assign pen = decode(x,raw);

endmodule
