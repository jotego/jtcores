/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-01-2025 */

module jtframe_serializer#(parameter DW=8, PAR=1)( // Set PAR==0 for even parity
    input            rst,
    input            clk,
    input            cen,
    input   [DW-1:0] din,
    input            send,
    output reg       ready,
    output           sdout,
    output reg       sclk
);

localparam CK=$clog2(DW+2);
reg  [DW+1:0] pre_data;
reg  [CK-1:0] cnt;
wire          par, done;

assign done  = cnt==0;
assign sdout = pre_data[0];
assign par   = ^din ^(PAR==1);

always @(posedge clk) begin 
    if(rst) begin
        sclk     <= 0;
        pre_data <= {DW+2{1'b1}};
        cnt      <= 0;
        ready    <= 1;
    end else if(cen) begin
        sclk     <= ~sclk;
        ready    <= done;
        if(!sclk) begin
            if(!done) begin
                pre_data <= {1'b1,pre_data[DW+1:1]};
                cnt      <= cnt-1'b1;
            end
            if(send) begin
                pre_data <= {par,din, 1'b0};
                cnt      <= DW[0+:CK] + {{CK-2{1'b0}},2'd2};
            end
        end
    end
end

endmodule
