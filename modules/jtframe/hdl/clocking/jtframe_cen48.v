/*  This file is part of JTFRAME.
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
    Date: 6-12-2019 */

// Input clock must be 48 MHz
// Generates various clock enable signals

module jtframe_cen48(
    input   clk,    // 48 MHz
    output  reg cen12,
    output  reg cen16,
    output  reg cen8,
    output  reg cen6,
    output  reg cen4,
    output  reg cen4_12, // cen4 based on cen12
    output  reg cen3,
    output  reg cen3q, // 1/4 advanced with respect to cen3
    output  reg cen1p5,
    // 180 shifted signals
    output  reg cen16b,
    output  reg cen12b,
    output  reg cen6b,
    output  reg cen3b,
    output  reg cen3qb,
    output  reg cen1p5b
);

reg [4:0] cencnt=5'd0;
reg [2:0] cencnt6=3'd0;
reg       cencnt12=1'd0;
reg [2:0] cencnt4_12=3'd1;

always @(posedge clk) begin
    cencnt  <= cencnt+5'd1;
    cencnt6 <= cencnt6==3'd5 ? 3'd0 : (cencnt6+3'd1);
    cencnt12<= cencnt12 ^^ (cencnt6==3'd5);
end

always @(posedge clk) begin
    cen12  <= cencnt[1:0] == 2'd0;
    cen12b <= cencnt[1:0] == 2'd2;
    if(cencnt[1:0]==2'b0) cencnt4_12 <= { cencnt4_12[1:0], cencnt4_12[2]};
    cen4_12 <= cencnt[1:0]==2'd0 && cencnt4_12[2];
    cen16  <= cencnt6 == 3'd0 || cencnt6 == 3'd3;
    cen16b <= cencnt6 == 3'd2 || cencnt6 == 3'd5;
    cen8   <= cencnt6     == 3'd0;
    cen4   <= cencnt6     == 3'd0 && cencnt12;
    cen6   <= cencnt[2:0] == 3'd0;
    cen6b  <= cencnt[2:0] == 3'd4;
    cen3   <= cencnt[3:0] == 4'd0;
    cen3b  <= cencnt[3:0] == 4'h8;
    cen3q  <= cencnt[3:0] == 4'b1100;
    cen3qb <= cencnt[3:0] == 4'b0100;
    cen1p5 <= cencnt[4:0] == 5'd0;
    cen1p5b<= cencnt[4:0] == 5'h10;
end
endmodule

////////////////////////////////////////////////////////////////////
// Generates a 3.57 MHz clock enable signal for a 48MHz/24MHz clock

module jtframe_cen3p57(
    input  clk,       // 48 MHz
    output cen_3p57,
    output cen_1p78
);
    parameter CLK24=0;

    localparam [15:0] STEP =
`ifdef JTFRAME_PLL6144
        16'd1048;
`elsif JTFRAME_PLL6293
        16'd35;
`elsif JTFRAME_PLL6671
        16'd105;
`else
        16'd3758; // 6MHz PLL
`endif

    localparam [15:0] LIM  =
`ifdef JTFRAME_PLL6144
        16'd14391;
`elsif JTFRAME_PLL6293
        16'd492;
`elsif JTFRAME_PLL6671
        16'd1566;
`else
        16'd50393;
`endif

    jtframe_frac_cen #(.W(2),.WC(16)) u_frac(
        .clk    ( clk   ),
        .n      ( STEP<<CLK24 ),
        .m      ( LIM   ),
        .cen    ( { cen_1p78, cen_3p57 } ),
        .cenb   (       )
    );
endmodule

////////////////////////////////////////////////////////////////////
// 384kHz clock enable
module jtframe_cenp384(
    input      clk,       // 48 MHz
    output reg cen_p384
);

parameter CLK24=0;
localparam [6:0] STEP=7'd1<<CLK24;

reg  [6:0] cencnt=7'd0;

always @(posedge clk) begin
    cen_p384 <= 1'b0;
    cencnt <= cencnt+STEP;
    if( cencnt >= 7'd124 ) begin
        cencnt   <= 7'd0;
        cen_p384 <= 1'b1;
    end
end
endmodule

////////////////////////////////////////////////////////////////////
// 10MHz clock enable
module jtframe_cen10(
    input   clk,    // 48MHz only
    output  reg cen10,
    // 180 shifted signals
    output  reg cen10b
);

reg [2:0] cencnt=3'd0;
reg [2:0] muxcnt=3'd0;
reg [2:0] next=3'd4, nextb=3'd2;

always @(*) begin
    next = muxcnt[2] ? 3'd3 : 3'd4;
    nextb= muxcnt[2] ? 3'd1 : 3'd2;
end

always @(posedge clk) begin
    cencnt <= cencnt+3'd1;
    cen10  <= cencnt == next;
    cen10b <= cencnt == nextb;
    if( cencnt==next ) begin
        cencnt <= 3'd0;
        muxcnt <= muxcnt[2] ? 3'd1 : muxcnt + 3'b1;
    end
end
endmodule

