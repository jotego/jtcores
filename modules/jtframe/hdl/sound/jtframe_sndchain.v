/* This file is part of JTFRAME.


    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 4-3-2024

*/

module jtframe_sndchain #(parameter
    W=12,
    DCRM=1,
    STEREO=1, 
    WC=8,           // width for each pole coefficient
    // do not set
    WS  = STEREO==1?2*W :W,
    WO  = 16,
    WOS = STEREO==1?2*WO:WO
)(
    input                       rst,
    input                       clk,
    input                       cen,     // sample frequency
    input            [WC*2-1:0] poles,   // 8-bit coefficients for two poles
    input                 [7:0] gain,    // 4.4 fixed point format
    input      signed [ WS-1:0] sin,     // for stereo input: { left, right }
    output reg signed [WOS-1:0] sout     // for stereo output: { left, right }
);

localparam WM  = WOS+9,
           WD  = 4;    // decimal part

reg  signed [WOS-1:0] sext;
wire signed [WOS-1:0] dc, p1, p2;
wire signed [ WM-1:0] mul_l, mul_r;
wire signed [    8:0] sgain;
wire        [ WC-1:0] c1, c2;

initial begin
    if( W>WO ) begin
        $display("Maximum allowed signal width is %d\n",WO);
        $finish;
    end
end

assign c1    = poles[WC-1:0],
       c2    = poles[WC+:WC];
assign sgain = {1'b0,gain};
assign mul_r = $signed(p2[    0+:WO])*sgain;
assign mul_l = $signed(p2[WOS-1-:WO])*sgain;

function over(input [WM-WO-WD:0]signs);
    over = |signs & ~&signs;
endfunction

always @* begin
    sext[    0+:WO]={sin[   0+:W], {WO-W{1'b0}}};
    sext[WOS-1-:WO]={sin[WS-1-:W], {WO-W{1'b0}}};
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        sout <= 0;
    end else begin
        sout[0+:WO] <= mul_r[WD+:WO];
        if(over(mul_r[WM-1:WO+WD-1])) sout[0+:WO] <= { mul_r[WM-1], {WO-1{~mul_r[WM-1]}}};
        if(STEREO==1) begin
            sout[WOS-1-:WO] <= mul_l[WD+:WO];
            if(over(mul_l[WM-1:WO+WD-1])) sout[WOS-1-:WO] <= { mul_l[WM-1], {WO-1{~mul_l[WM-1]}}};
        end
    end
end

generate
    if( DCRM==1 ) begin // Use the dc removal to convert from unsigned to signed
        jtframe_dcrm #(.SW(WO),.SIGNED_INPUT(0)) u_dcrm(
            .rst    ( rst           ),
            .clk    ( clk           ),
            .sample ( cen           ),
            .din    ( sext[WO-1:0]  ),
            .dout   ( dc[WO-1:0]    )
        );
        if( STEREO==1 ) begin
            jtframe_dcrm #(.SW(WO),.SIGNED_INPUT(0)) u_dcrm_l(
                .rst    ( rst           ),
                .clk    ( clk           ),
                .sample ( cen           ),
                .din    (sext[WOS-1-:WO]),
                .dout   ( dc[WOS-1-:WO] )
            );            
        end
    end else begin
        assign dc = sext;
    end
endgenerate    

generate
    // 1st pole
    jtframe_pole #(.WS(WO),.WA(WC)) u_pole1(
        .rst    ( rst           ),
        .clk    ( clk           ),
        .sample ( cen           ),
        .a      ( c1            ),
        .sin    ( dc[0+:WO]      ),
        .sout   ( p1[0+:WO]      )
    );    
    jtframe_pole #(.WS(WO),.WA(WC)) u_pole2(
        .rst    ( rst           ),
        .clk    ( clk           ),
        .sample ( cen           ),
        .a      ( c2            ),
        .sin    ( p1[0+:WO]      ),
        .sout   ( p2[0+:WO]      )
    );     
    if( STEREO==1 ) begin
        jtframe_pole #(.WS(WO),.WA(WC)) u_pole1_l(
            .rst    ( rst           ),
            .clk    ( clk           ),
            .sample ( cen           ),
            .a      ( c1            ),
            .sin    (dc[(WOS-1)-:WO]),
            .sout   (p1[(WOS-1)-:WO])
        );        
        jtframe_pole #(.WS(WO),.WA(WC)) u_pole2_l(
            .rst    ( rst           ),
            .clk    ( clk           ),
            .sample ( cen           ),
            .a      ( c2            ),
            .sin    (p1[(WOS-1)-:WO]),
            .sout   (p2[(WOS-1)-:WO])
        );             
    end
endgenerate

endmodule