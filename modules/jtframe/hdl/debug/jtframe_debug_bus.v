/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-1-2025 */

module jtframe_debug_bus(
    input            clk,
    input            rst,

    input            shift,         // count step 16, instead of 1
    input            ctrl,          // reset debug_bus
    input      [1:0] inc,
    input      [1:0] dec,
    input      [7:0] key_digit,

    output reg [7:0] debug_bus
);

reg        inc_l, dec_l, last_digit;
wire [7:0] step = |{shift,inc[1],dec[1]} ? 8'd16 : 8'd1;

function rise_edge(input [1:0] x, input xl); begin
    rise_edge = x!=0 && !xl;
end endfunction

always @(posedge clk) begin
    if( rst ) begin
        debug_bus  <= 0;
        last_digit <= 0;
        inc_l      <= 0;
        dec_l      <= 0;

    end else begin
        inc_l      <= |inc;
        dec_l      <= |dec;
        last_digit <= |key_digit;

        if( ctrl && (inc[0]||dec[0]) ) begin
            debug_bus <= 0;
        end else begin
            if( rise_edge(inc, inc_l) ) begin
                debug_bus <= debug_bus + step;
            end else if( rise_edge(dec, dec_l) ) begin
                debug_bus <= debug_bus - step;
            end
            if( shift && key_digit!=0 && !last_digit ) begin
                debug_bus <= debug_bus ^ { key_digit[0],
                    key_digit[1],
                    key_digit[2],
                    key_digit[3],
                    key_digit[4],
                    key_digit[5],
                    key_digit[6],
                    key_digit[7] };
            end
        end
    end
end

endmodule    