/* Copyright (C) 2020 Sean Gonsalves

Foobar is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

Foobar is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Foobar.  If not, see <http://www.gnu.org/licenses/>. */

// This draft is not tested !

module k053251(
    input CLK,

    input nCS,
    input [5:0] DIN,
    input [3:0] ADDR,

    input [5:0] PR0,
    input [5:0] PR1,
    input [5:0] PR2,

    input SEL,
    input [8:0] CI0,
    input [8:0] CI1,
    input [8:0] CI2,
    input [7:0] CI3,
    input [7:0] CI4,

    input [1:0] SDI,
    output reg [1:0] SDO,
    
    output reg [10:0] CO,
    output reg BRIT,
    output reg NCOL
);

reg [5:0] REG0;
reg [5:0] REG1;
reg [5:0] REG2;
reg [5:0] REG3;
reg [5:0] REG4;
reg [5:0] REG5;
reg [5:0] REG6;
reg [5:0] REG7;
reg [5:0] REG8;
reg [5:0] REG9;
reg [5:0] REG10;
reg [5:0] REG11;
reg [2:0] REG12;

always @(posedge nCS) begin
    // The real chip doesn't work this way.
    // If the address changes while nCS is kept low, multiple registers can be written to.
    case(ADDR)
        4'd0: REG0 <= DIN;
        4'd1: REG1 <= DIN;
        4'd2: REG2 <= DIN;
        4'd3: REG3 <= DIN;
        4'd4: REG4 <= DIN;
        4'd5: REG5 <= DIN;
        4'd6: REG6 <= DIN;
        4'd7: REG7 <= DIN;
        4'd8: REG8 <= DIN;
        4'd9: REG9 <= DIN;
        4'd10: REG10 <= DIN;
        4'd11: REG11 <= DIN;
        4'd12: REG12 <= DIN[2:0];
    endcase
end

reg [8:0] L0_Q;
reg [8:0] L0_W1;
reg [8:0] L1_Q;
reg [8:0] L1_W1;
reg [8:0] L2_Q;
reg [8:0] L2_W1;
reg [7:0] L3_Q;
reg [7:0] L3_W1;
reg [7:0] L3_W2;
reg [7:0] L4_Q;
reg [7:0] L4_W1;
reg [7:0] L4_W2;
reg [7:0] L4_W3;

reg [5:0] PR0_Q;
reg [5:0] PR1_Q;
reg [5:0] PR2_Q;
reg [5:0] PR2_W1; // E125, F129, G119
reg [5:0] PR4_W1;

reg [10:0] L0L1L2MIX_Q;
reg T0T1T2MIX_Q;
reg [10:0] L0L1L2L3MIX_Q;
reg T0T1T2T3MIX_Q;

reg SEL_W1, SEL_W2;

reg TRANSP0_W1, TRANSP1_W1, TRANSP2_W1, TRANSP4_W1;

reg [5:0] PR0MUX_Q;
reg [5:0] PR1MUX_Q;
reg [5:0] PR0PR1PR2MIX_Q;
reg [5:0] PR0PR1PR2PR3MIX_Q;

reg SEL_L1, SEL_L4;

reg [1:0] SDI_Q;
reg [1:0] SDI_W1;
reg [1:0] SDI_W2;
reg [1:0] SDI_W3;


wire [5:0] PRSHA = (SDI_W3 == 2'd0) ? 6'h3F :
                    (SDI_W3 == 2'd1) ? REG6 :
                    (SDI_W3 == 2'd2) ? REG7 : REG8;

wire A49 = (PR1MUX < PR0MUX);
wire SEL_L2 = (PR2_W1 < PR0PR1MIX);
wire SEL_L3 = (PR3 < PR0PR1PR2MIX_Q);
wire G93 = (PR4 < PR0PR1PR2PR3MIX);
wire J122A = (PR0PR1PR2PR3PR4MIX < ~REG5);
wire SELSHA = (PR0PR1PR2PR3PR4MIX < PRSHA);

// No need for L0 signal
wire L1 = ~(SEL_W2 & REG11[5]) & ~(~SEL_L1 & REG11[5]);

wire [5:0] PR0MUX = TRANSP0 ? (REG12[0] ? REG0 : PR0_Q) : 6'h3F;  // To check: gating
wire [5:0] PR1MUX = TRANSP1 ? (REG12[1] ? REG1 : PR1_Q) : 6'h3F;  // To check: gating
wire [5:0] PR2MUX = TRANSP2 ? (REG12[2] ? REG2 : PR2_Q) : 6'h3F;  // To check: gating
wire [5:0] PR3 = TRANSP3 ? REG3 : 6'h3F;  // To check: gating
wire [5:0] PR4 = TRANSP4 ? REG4 : 6'h3F;  // To check: gating

wire [5:0] PR0PR1MIX = ~(SEL_L1 | REG11[5]) ? PR1MUX_Q : PR0MUX_Q;
wire [5:0] PR0PR1PR2MIX = SEL_L2 ? PR2_W1 : PR0PR1MIX;
wire [5:0] PR0PR1PR2PR3MIX = SEL_L3 ? PR3 : PR0PR1PR2MIX_Q;
wire [5:0] PR0PR1PR2PR3PR4MIX = SEL_L4 ? PR4_W1 : PR0PR1PR2PR3MIX_Q;

wire TRANSP0 = REG11[0] ? ~|{L0_Q[7:0]} : ~|{L0_Q[3:0]};
wire TRANSP1 = REG11[1] ? ~|{L1_Q[7:0]} : ~|{L1_Q[3:0]};
wire TRANSP2 = REG11[2] ? ~|{L2_Q[7:0]} : ~|{L2_Q[3:0]};
wire TRANSP3 = REG11[3] ? ~|{L3_W2[7:0]} : ~|{L3_W2[3:0]};
wire TRANSP4 = REG11[4] ? ~|{L4_W2[7:0]} : ~|{L4_W2[3:0]};

wire [10:0] L0L1MIX = L1 ? {REG9[3:2], L1_W1} : {REG9[1:0], L0_W1};
wire [10:0] L0L1L2MIX = SEL_L2 ? {REG9[5:4], L2_W1} : L0L1MIX;
wire [10:0] L0L1L2L3MIX = SEL_L3 ? {REG10[2:0], L3_W2} : L0L1L2MIX_Q;
wire [10:0] L0L1L2L3L4MIX = SEL_L4 ? {REG10[5:3], L4_W3} : L0L1L2L3MIX_Q;

wire T0T1MIX = L1 ? TRANSP1_W1 : TRANSP0_W1;
wire T0T1T2MIX = SEL_L2 ? TRANSP2_W1 : T0T1MIX;
wire T0T1T2T3MIX = SEL_L3 ? TRANSP3 : T0T1T2MIX_Q;
wire T0T1T2T3T4MIX = SEL_L4 ? TRANSP4_W1 : T0T1T2T3MIX_Q;

always @(posedge CLK) begin
    L0_Q <= CI0;
    L0_W1 <= L0_Q;

    L1_Q <= CI1;
    L1_W1 <= L1_Q;

    L2_Q <= CI2;
    L2_W1 <= L2_Q;

    L3_Q <= CI3;
    L3_W1 <= L3_Q;
    L3_W2 <= L3_W1;

    L4_Q <= CI4;
    L4_W1 <= L4_Q;
    L4_W2 <= L4_W1;
    L4_W3 <= L4_W2;

    PR0_Q <= PR0;
    PR1_Q <= PR1;
    PR2_Q <= PR2;
    
    TRANSP0_W1 <= TRANSP0;
    TRANSP1_W1 <= TRANSP1;
    TRANSP2_W1 <= TRANSP2;
    TRANSP4_W1 <= TRANSP4;
    
    L0L1L2MIX_Q <= L0L1L2MIX;
    T0T1T2MIX_Q <= T0T1T2MIX;
    
    L0L1L2L3MIX_Q <= L0L1L2L3MIX;
    T0T1T2T3MIX_Q <= T0T1T2T3MIX;
    
    CO <= L0L1L2L3L4MIX;
    NCOL <= T0T1T2T3T4MIX;
    
    PR2_W1 <= PR2MUX;
    PR4_W1 <= PR4;
    
    SEL_W1 <= SEL;
    SEL_W2 <= SEL_W1;
    
    PR0MUX_Q <= PR0MUX;
    PR1MUX_Q <= PR1MUX;
    
    PR0PR1PR2MIX_Q <= PR0PR1PR2MIX;
    PR0PR1PR2PR3MIX_Q <= PR0PR1PR2PR3MIX;
    
    SEL_L1 <= A49;
    SEL_L4 <= G93;
    BRIT <= J122A;
    
    SDI_Q <= SDI;
    SDI_W1 <= SDI_Q;
    SDI_W2 <= SDI_W1;
    SDI_W3 <= SDI_W2;

    SDO <= SELSHA ? SDI_W3 : 2'b00;
end

endmodule
