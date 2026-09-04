/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-12-2019 */

module jtframe_ff #(parameter W=1 ) (
    input                clk,
    input                rst,
    (*direct_enable*) input cen,
    input       [W-1:0]  din,
    output reg  [W-1:0]  q,
    output reg  [W-1:0]  qn,
    input       [W-1:0]  set,    // active high
    input       [W-1:0]  clr,    // active high
    input       [W-1:0]  sigedge // signal whose edge will trigger the FF
);

reg  [W-1:0] last_edge;

generate
    genvar i;
    for (i=0; i < W; i=i+1) begin: flip_flop
        always @(posedge clk) begin
            if(rst) begin
                q[i]         <= 0;
                qn[i]        <= 1;
                last_edge[i] <= 0;
            end
            else begin
                last_edge[i] <= sigedge[i];
                if( cen && clr[i] ) begin
                    q[i]  <= 1'b0;
                    qn[i] <= 1'b1;
                end else
                if( cen && set[i] ) begin
                    q[i]  <= 1'b1;
                    qn[i] <= 1'b0;
                end else
                if( sigedge[i] && !last_edge[i] ) begin
                    q[i]  <=  din[i];
                    qn[i] <= ~din[i];
                end
            end
        end
    end
endgenerate

endmodule
