/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-10-2026 */

module jtnarc_cvsdflt(
    input                    rst,
    input                    clk,
    input                    cen192,
    input      signed [ 9:0] dac,
    output reg signed [15:0] snd
);

localparam signed [23:0]
    B10=24'sd4123, B11=24'sd8245, B12=24'sd4123, A11=-24'sd1871997, A12=24'sd839912,
    B20=24'sd4500, B21=24'sd9000, B22=24'sd4500, A21=-24'sd1975630, A22=24'sd945054;

reg  [ 3:0] st;
reg         done;
reg  signed [23:0] x0, s1x1, s1x2, s1y1, s1y2, s2x1, s2x2, s2y1, s2y2, opx, opc;
reg  signed [47:0] acc;
wire signed [47:0] prod, acc_nx;
wire signed [23:0] hp, y;

assign prod   = opx * opc;
assign acc_nx = (st==4'd0 || st==4'd5) ? prod : acc + prod;
assign y      = acc_nx[43:20];

always @(*) begin
    case( st )
        4'd0:    begin opx = x0;   opc =  B10; end
        4'd1:    begin opx = s1x1; opc =  B11; end
        4'd2:    begin opx = s1x2; opc =  B12; end
        4'd3:    begin opx = s1y1; opc = -A11; end
        4'd4:    begin opx = s1y2; opc = -A12; end
        4'd5:    begin opx = s1y1; opc =  B20; end
        4'd6:    begin opx = s2x1; opc =  B21; end
        4'd7:    begin opx = s2x2; opc =  B22; end
        4'd8:    begin opx = s2y1; opc = -A21; end
        default: begin opx = s2y2; opc = -A22; end
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        st   <= 4'd15;
        done <= 0;
        acc  <= 0;
        x0   <= 0;
        s1x1 <= 0;
        s1x2 <= 0;
        s1y1 <= 0;
        s1y2 <= 0;
        s2x1 <= 0;
        s2x2 <= 0;
        s2y1 <= 0;
        s2y2 <= 0;
    end else begin
        done <= st==4'd9;
        if( cen192 ) begin
            x0 <= dac * 24'sd9830;
            st <= 4'd0;
        end else if( st<4'd10 ) begin
            acc <= acc_nx;
            st  <= st + 4'd1;
            if( st==4'd4 ) begin
                s1x1 <= x0;
                s1x2 <= s1x1;
                s1y1 <= y;
                s1y2 <= s1y1;
            end
            if( st==4'd9 ) begin
                s2x1 <= s1y1;
                s2x2 <= s2x1;
                s2y1 <= y;
                s2y2 <= s2y1;
            end
        end
    end
end

jtframe_hipass #(.WS(24),.WA(16)) u_c43(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .sample ( done      ),
    .sin    ( s2y1      ),
    .a      ( 16'd65522 ),
    .b      ( 16'd65529 ),
    .sout   ( hp        )
);

always @(posedge clk) begin
    if( rst )
        snd <= 0;
    else if( hp[23:22]==2'b01 )
        snd <= 16'h7fff;
    else if( hp[23:22]==2'b10 )
        snd <= 16'h8000;
    else
        snd <= hp[22:7];
end

endmodule
