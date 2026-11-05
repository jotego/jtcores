/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-10-2026 */

module jtnarc_cvsd(
    input                    rst,
    input                    clk,
    input                    cvsd_clk,
    input                    cvsd_din,
    output reg signed [ 9:0] dac
);

reg        clk_l;
reg  [2:0] sr;
reg [11:0] syl;
reg signed [16:0] x;
wire       coinc, frozen;
wire [11:0] syl_nx;
wire [ 6:0] step;
wire signed [16:0] leak, x_up, x_dn, x_nx;

localparam signed [16:0] XMAX = 17'sd384<<6;

assign frozen = (x>=XMAX && cvsd_din) || (x<=-XMAX && !cvsd_din);
assign coinc  = (sr[1:0]==2'b11 && cvsd_din) || (sr[1:0]==2'b00 && !cvsd_din);
assign syl_nx = coinc ? syl + ((12'hfc0 - syl)>>6) : syl - (syl>>6);
assign step   = syl_nx[11:7]==5'd0 ? 7'd2 : {1'b0, syl_nx[11:6]};
assign leak   = x - (x>>>4);
assign x_up   = leak + {4'd0, step, 6'd0};
assign x_dn   = leak - {4'd0, step, 6'd0};
assign x_nx   = cvsd_din ? (x_up > XMAX ? XMAX : x_up) : (x_dn < -XMAX ? -XMAX : x_dn);

always @(posedge clk) begin
    if( rst ) begin
        clk_l <= 0;
        sr    <= 0;
        syl   <= 0;
        x     <= 0;
        dac   <= 0;
    end else begin
        clk_l <= cvsd_clk;
        if( cvsd_clk && !clk_l ) begin
            sr  <= { sr[1:0], cvsd_din };
            if( !frozen ) begin
                syl <= syl_nx;
                x   <= x_nx;
                dac <= x_nx[15:6];
            end
        end
    end
end

endmodule
