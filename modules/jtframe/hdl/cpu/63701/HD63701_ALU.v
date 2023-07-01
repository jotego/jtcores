/***************************************************************************
       This file is part of "HD63701V0 Compatible Processor Core".
****************************************************************************/
`timescale 1ps / 1ps
`include "HD63701_defs.i"

module HD63701_ALU (
    input       [4:0] op,   // operation code
    input       [7:0] cf,   // Flag register
    input             bw,   // bit width

    input      [15:0] R0,   // operands
    input      [15:0] R1,
    input             C,    // input carry

    output reg [15:0] RR,   // result
    output      [5:0] RC
);

`ifdef SIMULATION
always @(op) begin
    if( op==`mcDAA ) begin
        $display("ERROR: HD63701_ALU.v DAA is not implemented.");
        $finish;
    end
end
`endif

wire [15:0] carry = {15'b0,C};
wire [16:0] r0ext = {1'b0,R0};
wire [16:0] r1ext = {1'b0,R1};

reg         identity;
reg         cnew;

reg chCarryL, chCarryR;
reg fC, fZ, fN, fV, fH;

assign RC = {fH,1'b0,fN,fZ,fV,fC};

always @(*) begin
    identity = 
           (op==`mcTST)
        || (op==`mcLDR)
        || (op==`mcLDN)
        || (op==`mcPSH)
        || (op==`mcPUL)
        || (op==`mcINT);

    { cnew, RR } = identity     ? r0ext :
        (op==`mcDAA) ? r0ext :            // todo: DAA
        (op==`mcINC) ? (R0+16'h1):
        (op==`mcADD) ? (R0+R1):
        (op==`mcADC) ? (R0+R1+carry):
        (op==`mcDEC) ? (R0-16'h1):
        (op==`mcSUB) ? (R0-R1):
        (op==`mcSBC) ? (R0-R1-carry):
        (op==`mcMUL) ? (R0*R1):
        (op==`mcNEG) ? ((~r0ext)+16'h1):
        (op==`mcNOT) ? ~r0ext:
        (op==`mcAND) ? (r0ext&r1ext):
        (op==`mcLOR) ? (r0ext|r1ext):
        (op==`mcEOR) ? (r0ext^r1ext):
        (op==`mcASL) ? {R0[15:0],1'b0}:
        (op==`mcASR) ? (bw ? {1'b0,R0[15],R0[15:1]}:{9'b0,R0[7],R0[7:1]}):
        (op==`mcLSR) ? {2'b0,R0[15:1]}: // shift right logical
        (op==`mcROL) ? {R0,C}:
        (op==`mcROR) ? (bw ? {1'b0,C,R0[15:1]} : {9'b0,C,R0[7:1]}):
        (op==`mcCCB) ? {11'h3,(R0[5:0]&cf[5:0])}:
        (op==`mcSCB) ? {11'h3,(R0[5:0]|cf[5:0])}:
                            17'h0;
    // Carry
    chCarryL = (op==`mcASL)|(op==`mcROL)|
                  (op==`mcADD)|(op==`mcADC)|
                  (op==`mcSUB)|(op==`mcSBC)|
                  (op==`mcMUL);

    chCarryR = (op==`mcASR)|(op==`mcLSR)|(op==`mcROR);
    // Flags
    fC =   (op==`mcNOT) ? 1'b1 : 
                    chCarryL ? ( bw ? cnew : RR[8] ) :
                    chCarryR ? R0[0] :
                    C ;

    fZ = bw ?(RR[15:0]==0) : (RR[7:0]==0);
    fN = bw ? RR[15] : RR[7];

    fV = (op==`mcLDR) ? 1'b0 : (bw ?(R0[15]^R1[15]^RR[15]^RR[14]) : (R0[7]^R1[7]^RR[7]^RR[6]));
    fH = (op==`mcLDR) ? 1'b0 : R0[4]^R1[4]^RR[4];
end

endmodule

