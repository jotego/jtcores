/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-12-2022 */

// BCD counter

module jtframe_bcd_cnt #(parameter DIGITS=4, WRAP=1 ) (
    input               rst,
    input               clk,
    input               clr,
    input               up,
    output reg [DIGITS*4-1:0] cnt
);

integer i;
genvar k;
reg [DIGITS-1:0] nines;

always @* begin
    for( i=0; i<DIGITS; i=i+1 )
        nines[i] = cnt[(i*4)+:4]==4'h9;
end

always @(posedge clk) begin
    if( rst ) begin
        cnt[3:0] <= 0;
    end else begin
        if( clr ) begin
            cnt[3:0] <= 0;
        end else if( up && (WRAP==1 || ~&nines) ) begin
            cnt[3:0] <= cnt[3:0]==4'd9 ? 4'd0 : cnt[3:0] + 1'd1;
        end
    end
end

generate
    for( k=1; k<DIGITS; k=k+1 ) begin : upper_bcds
        always @(posedge clk) begin
            if( rst ) begin
                cnt[k*4+:4] <= 0;
            end else begin
                if( clr ) begin
                    cnt[k*4+:4] <= 0;
                end else if( up && (WRAP==1 || ~&nines) && &nines[0+:k] ) begin
                    cnt[k*4+:4] <= cnt[k*4+:4]==4'd9 ? 4'd0 : cnt[k*4+:4] + 1'd1;
                end
            end
        end
    end
endgenerate

endmodule