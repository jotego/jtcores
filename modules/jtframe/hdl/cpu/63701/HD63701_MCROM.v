/***************************************************************************
       This file is part of "HD63701V0 Compatible Processor Core".
****************************************************************************/
`include "HD63701_defs.i"

module HD63701_MCROM #(parameter MCWIDTH=24) (
    input       clk,
    (*direct_enable *) input cen_rise,
    (*direct_enable *) input cen_fall,
    input [5:0] PHASE,
    input [7:0] OPCODE,

    output reg [MCWIDTH-1:0] mcode
);

`include "HD63701_MCODE.i"

wire [MCWIDTH-1:0] mc0,mc1,mc2,mc3,mc4,mc5,mc6,mc7,mc8,mc9;
HD63701_MCROM_S0 r0(clk,OPCODE,mc0);
HD63701_MCROM_S1 r1(clk,OPCODE,mc1);
HD63701_MCROM_S2 r2(clk,OPCODE,mc2);
HD63701_MCROM_S3 r3(clk,OPCODE,mc3);
HD63701_MCROM_S4 r4(clk,OPCODE,mc4);
HD63701_MCROM_S5 r5(clk,OPCODE,mc5);
HD63701_MCROM_S6 r6(clk,OPCODE,mc6);
HD63701_MCROM_S7 r7(clk,OPCODE,mc7);
HD63701_MCROM_S8 r8(clk,OPCODE,mc8);
HD63701_MCROM_S9 r9(clk,OPCODE,mc9);

always @( posedge clk ) if (cen_rise) begin
    mcode <= 
        (PHASE==`phRST  ) ? {`mcLDV,  `vaRST,   `mcrn,`mcpN,`amE0,`pcN}:    //(Load Reset Vector)
        
        (PHASE==`phVECT ) ? {`mcLDN,`mcrM,`mcrn,`mcrU,`mcpN,`amE0,`pcN}:    //(Load VectorH)
        (PHASE==`phVEC1 ) ? {`mcLDN,`mcrM,`mcrn,`mcrV,`mcpN,`amE1,`pcN}:    //(Load VectorL)
        (PHASE==`phVEC2 ) ? {`mcLDN,`mcrT,`mcrn,`mcrP,`mcp0,`amPC,`pcN}:    //(Load to PC)

        (PHASE==`phEXEC ) ? mc0 :
        (PHASE==`phEXEC1) ? mc1 :
        (PHASE==`phEXEC2) ? mc2 :
        (PHASE==`phEXEC3) ? mc3 :
        (PHASE==`phEXEC4) ? mc4 :
        (PHASE==`phEXEC5) ? mc5 :
        (PHASE==`phEXEC6) ? mc6 :
        (PHASE==`phEXEC7) ? mc7 :
        (PHASE==`phEXEC8) ? mc8 :
        (PHASE==`phEXEC9) ? mc9 :

        (PHASE==`phINTR ) ? {`mcLDN,`mcrC,`mcrn,`mcrT,`mcpN,`amPC,`pcN}:    //(T=C)
        (PHASE==`phINTR1) ? {`mcPSH,`mcrP,`mcrn,`mcrM,`mcpN,`amSP,`pcN}:    //[PUSH PL]
        (PHASE==`phINTR2) ? {`mcPSH,`mcrP,`mcrn,`mcrN,`mcpN,`amSP,`pcN}:    //[PUSH PH]
        (PHASE==`phINTR3) ? {`mcPSH,`mcrX,`mcrn,`mcrM,`mcpN,`amSP,`pcN}:    //[PUSH XL]
        (PHASE==`phINTR4) ? {`mcPSH,`mcrX,`mcrn,`mcrN,`mcpN,`amSP,`pcN}:    //[PUSH XH]
        (PHASE==`phINTR5) ? {`mcPSH,`mcrA,`mcrn,`mcrM,`mcpN,`amSP,`pcN}:    //[PUSH A]
        (PHASE==`phINTR6) ? {`mcPSH,`mcrB,`mcrn,`mcrM,`mcpN,`amSP,`pcN}:    //[PUSH B]
        (PHASE==`phINTR7) ? {`mcPSH,`mcrT,`mcrn,`mcrM,`mcpN,`amSP,`pcN}:    //[PUSH T]
        (PHASE==`phINTR8) ? 0:
        (PHASE==`phINTR9) ? 0:
                            `MC_HALT;
end
endmodule

module HD63701_MCROM_S0 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S0(OPCODE);
endmodule

module HD63701_MCROM_S1 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S1(OPCODE);
endmodule

module HD63701_MCROM_S2 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S2(OPCODE);
endmodule

module HD63701_MCROM_S3 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S3(OPCODE);
endmodule

module HD63701_MCROM_S4 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S4(OPCODE);
endmodule

module HD63701_MCROM_S5 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S5(OPCODE);
endmodule

module HD63701_MCROM_S6 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S6(OPCODE);
endmodule

module HD63701_MCROM_S7 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S7(OPCODE);
endmodule

module HD63701_MCROM_S8 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S8(OPCODE);
endmodule

module HD63701_MCROM_S9 #(parameter MCWIDTH=24)
    ( input clk, input [7:0] OPCODE, output reg [MCWIDTH-1:0] mcode );
`include "HD63701_MCODE.i"
always @( posedge clk ) mcode <= MCODE_S9(OPCODE);
endmodule

