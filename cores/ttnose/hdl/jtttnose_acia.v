/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_acia(
    input rst,clk,cen,cs,we,rs,
    input [7:0] din,
    output [7:0] dout,
    output irq
);
reg [7:0] control;
reg [9:0] ticks;
wire empty=ticks==0;
assign irq=control[6:5]==2'b01 && empty;
assign dout=rs ? 8'd0 : {irq,5'd0,empty,1'b0};
always @(posedge clk) begin
    if(rst) begin control<=0;ticks<=0;end
    else begin
        if(cen && !empty) ticks<=ticks-10'd1;
        if(cs && we) begin
            if(!rs) begin
                control<=din;
                if(din[1:0]==2'b11) ticks<=0;
            end else ticks<=control[1:0]==2 ? 10'd640 : control[1:0]==1 ? 10'd160 : 10'd10;
        end
    end
end
endmodule
