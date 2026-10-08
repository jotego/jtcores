/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2017 */

module jtframe_sh #(parameter W=5, L=24 )(
    // do not change port order
    input          clk,
    input          clk_en,
    input  [W-1:0] din,
    output [W-1:0] drop
);

reg [L-1:0] bits[W-1:0];

// This makes the argument L=1 valid:
localparam WM = L>1 ? L-2 : 0;

// The tool Verilator is troubled when L==1
/* verilator lint_off WIDTH */
generate
    genvar i;
    for (i=0; i < W; i=i+1) begin: bit_shifter
        always @(posedge clk) if(clk_en) begin
                bits[i]    <= bits[i]<<1;
                bits[i][0] <= din[i];
            end
        assign drop[i] = bits[i][L-1];
    end
endgenerate
/* verilator lint_on WIDTH */

endmodule
