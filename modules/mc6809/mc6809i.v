`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Greg Miller
// Copyright (c) 2016, Greg Miller
// 
// Create Date:    14:26:59 08/13/2016 
// Design Name: 
// Module Name:    mc6809 
// Project Name:   Cycle-Accurate 6809 Core 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: Intended to be standalone Vanilla Verilog.
//
// Revision: 
// Revision 1.0 - Initial Release
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////


//
// The 6809 has incomplete instruction decoding.  A collection of instructions, if met, end up actually behaving like
// a binary-adjacent neighbor.  
//
// The soft core permits three different behaviors for this situation, controlled by the instantiation parameter
// ILLEGAL_INSTRUCTIONS
//
// "GHOST" - Mimic the 6809's incomplete decoding.  This is as similar to a hard 6809 as is practical.  [DEFAULT]
//
// "STOP"  - Cause the soft core to cease execution, placing $DEAD on the address bus and R/W to 'read'.  Interrupts,
//           bus control (/HALT, /DMABREQ), etc. are ignored.  The core intentionally seizes in this instance.  
//           (Frankly, this is useful when making changes to the core and you have a logic analyzer connected.)
//
// "IGNORE"- Cause the soft core to merely ignore illegal instructions.  It will consider them 1-byte instructions and
//           attempt to fetch and run an exception 1 byte later.
//

module mc6809i
#(
    parameter ILLEGAL_INSTRUCTIONS="GHOST"
) 
(

    input   [7:0]  D,
    output  [7:0]  DOut,
    output  [15:0] ADDR,
    output  RnW,
    input   E,
    input   Q,
    output  BS,
    output  BA,
    input   nIRQ,
    input   nFIRQ,
    input   nNMI,
    output  AVMA,
    output  BUSY,
    output  LIC,
    input   nHALT,
    input   nRESET,
    input   nDMABREQ,
    output  [111:0] RegData
);

reg     [7:0]  DOutput;

assign DOut = DOutput;

reg     RnWOut;         // Combinatorial     

reg     rLIC;
assign LIC = rLIC;

reg     rAVMA;
assign AVMA = rAVMA;

reg     rBUSY;
assign BUSY = rBUSY;

// Bus control
// BS    BA
//  0     0   normal (CPU running, CPU is master)
//  0     1   Interrupt Ack
//  1     0   Sync Ack
//  1     1   CPU has gone high-Z on A, D, R/W
//

assign RnW = RnWOut;


/////////////////////////////////////////////////
// Vectors
`define RESET_VECTOR        16'HFFFE
`define NMI_VECTOR          16'HFFFC
`define SWI_VECTOR          16'HFFFA
`define IRQ_VECTOR          16'HFFF8
`define FIRQ_VECTOR         16'HFFF6
`define SWI2_VECTOR         16'HFFF4
`define SWI3_VECTOR         16'HFFF2
`define Reserved_VECTOR     16'HFFF0

//////////////////////////////////////////////////////
// Latched registers
//

// The last-latched copy.
reg     [7:0]           a;
reg     [7:0]           b;
reg     [15:0]          x;
reg     [15:0]          y;
reg     [15:0]          u;
reg     [15:0]          s;
reg     [15:0]          pc;
reg     [7:0]           dp;
reg     [7:0]           cc;
reg     [15:0]          tmp;
reg     [15:0]          addr;
reg     [15:0]          ea;


// Debug ability to export register contents
assign  RegData[7:0] = a;
assign  RegData[15:8] = b;
assign  RegData[31:16] = x;
assign  RegData[47:32] = y;
assign  RegData[63:48] = s;
assign  RegData[79:64] = u;
assign  RegData[87:80] = cc;
assign  RegData[95:88] = dp;
assign  RegData[111:96] = pc;



// The values as being calculated
reg     [7:0]           a_nxt;
reg     [7:0]           b_nxt;
reg     [15:0]          x_nxt;
reg     [15:0]          y_nxt;
reg     [15:0]          u_nxt;
reg     [15:0]          s_nxt;
reg     [15:0]          pc_nxt;
reg     [7:0]           dp_nxt;
reg     [7:0]           cc_nxt;
reg     [15:0]          addr_nxt;
reg     [15:0]          ea_nxt;
reg     [15:0]          tmp_nxt;

reg                     BS_nxt;
reg                     BA_nxt;

// for ADDR, BS/BA, assign them to the flops
assign BS = BS_nxt;
assign BA = BA_nxt;
assign ADDR=addr_nxt;

localparam CC_E=  8'H80;
localparam CC_F=  8'H40;
localparam CC_H=  8'H20;
localparam CC_I=  8'H10;
localparam CC_N=  8'H08;
localparam CC_Z=  8'H04;
localparam CC_V=  8'H02;
localparam CC_C=  8'H01;

localparam CC_E_BIT=  3'd7;
localparam CC_F_BIT=  3'd6;
localparam CC_H_BIT=  3'd5;
localparam CC_I_BIT=  3'd4;
localparam CC_N_BIT=  3'd3;
localparam CC_Z_BIT=  3'd2;
localparam CC_V_BIT=  3'd1;
localparam CC_C_BIT=  3'd0;

// Convenience calculations
reg     [15:0] pc_p1;
reg     [15:0] pc_p2;
reg     [15:0] pc_p3;
reg     [15:0] s_p1;
reg     [15:0] s_m1;
reg     [15:0] u_p1;
reg     [15:0] u_m1;
reg     [15:0] addr_p1;
reg     [15:0] ea_p1;

//////////////////////////////////////////////////////
// NMI Mask
//
// NMI is supposed to be masked - despite the name - until the 6809 loads a value into S.
// Frankly, I'm cheating slightly.  If someone does a LDS #$0, it won't disable the mask.  Pretty much anything else 
// that changes the value of S from the default (which is currently $0) will clear the mask.  A reset will set the mask again.
reg     NMIMask;

reg     NMILatched;
reg     NMISample;
reg     NMISample2;
reg     NMIClear;
reg     NMIClear_nxt;
wire    wNMIClear = NMIClear;

reg     IRQLatched;

reg     IRQSample;
reg     IRQSample2;
reg     FIRQLatched;
reg     FIRQSample;
reg     FIRQSample2;
reg     HALTLatched;
reg     HALTSample;
reg     HALTSample2;
reg     DMABREQLatched;
reg     DMABREQSample;
reg     DMABREQSample2;

// Interrupt types
localparam INTTYPE_NMI      = 3'H0 ;
localparam INTTYPE_IRQ      = 3'H1 ;
localparam INTTYPE_FIRQ     = 3'H2 ;
localparam INTTYPE_SWI      = 3'H3 ;
localparam INTTYPE_SWI2     = 3'H4 ;
localparam INTTYPE_SWI3     = 3'H5 ;

reg [2:0] IntType;
reg [2:0] IntType_nxt;

//////////////////////////////////////////////////////
// Instruction Fetch Details
//
reg     InstPage2;
reg     InstPage3;
reg     InstPage2_nxt;
reg     InstPage3_nxt;

reg     [7:0]        Inst1;
reg     [7:0]        Inst2;
reg     [7:0]        Inst3;
reg     [7:0]        Inst1_nxt;
reg     [7:0]        Inst2_nxt;
reg     [7:0]        Inst3_nxt;


localparam CPUSTATE_RESET      =  7'd0;
localparam CPUSTATE_RESET0     =  7'd1;

localparam CPUSTATE_RESET2     =  7'd3;
localparam CPUSTATE_FETCH_I1   =  7'd4;
localparam CPUSTATE_FETCH_I1V2 =  7'd5;     
localparam CPUSTATE_FETCH_I2   =  7'd8;

localparam CPUSTATE_LBRA_OFFSETLOW =  7'd17;
localparam CPUSTATE_LBRA_DONTCARE  =  7'd18;
localparam CPUSTATE_LBRA_DONTCARE2 =  7'd19;



localparam CPUSTATE_BRA_DONTCARE   =  7'd20;

localparam CPUSTATE_BSR_DONTCARE1  =  7'd21;
localparam CPUSTATE_BSR_DONTCARE2  =  7'd22;
localparam CPUSTATE_BSR_RETURNLOW  =  7'd23;
localparam CPUSTATE_BSR_RETURNHIGH =  7'd24;

localparam CPUSTATE_TFR_DONTCARE1  =  7'd26;
localparam CPUSTATE_TFR_DONTCARE2  =  7'd27;
localparam CPUSTATE_TFR_DONTCARE3  =  7'd28;
localparam CPUSTATE_TFR_DONTCARE4  =  7'd29;

localparam CPUSTATE_EXG_DONTCARE1      =    7'd30;
localparam CPUSTATE_EXG_DONTCARE2      =    7'd31;
localparam CPUSTATE_EXG_DONTCARE3      =    7'd32;
localparam CPUSTATE_EXG_DONTCARE4      =    7'd33;
localparam CPUSTATE_EXG_DONTCARE5      =    7'd34;
localparam CPUSTATE_EXG_DONTCARE6      =    7'd35;

localparam CPUSTATE_ABX_DONTCARE       =    7'd36;

localparam  CPUSTATE_RTS_HI            =    7'd38;
localparam  CPUSTATE_RTS_LO            =    7'd39;     
localparam  CPUSTATE_RTS_DONTCARE2     =    7'd40;          

localparam  CPUSTATE_16IMM_LO          =    7'd41;
localparam CPUSTATE_ALU16_DONTCARE     =    7'd42;
localparam CPUSTATE_DIRECT_DONTCARE    =    7'd43;

localparam CPUSTATE_ALU_EA             =    7'd44;

localparam CPUSTATE_ALU_DONTCARE       =    7'd46;
localparam CPUSTATE_ALU_WRITEBACK      =    7'd47;

localparam CPUSTATE_LD16_LO            =    7'd48;

localparam CPUSTATE_ST16_LO            =    7'd49;
localparam CPUSTATE_ALU16_LO           =    7'd50;




localparam CPUSTATE_JSR_DONTCARE       =    7'd53;
localparam CPUSTATE_JSR_RETLO          =    7'd54;
localparam CPUSTATE_JSR_RETHI          =    7'd55;      
localparam CPUSTATE_EXTENDED_ADDRLO    =    7'd56;
localparam CPUSTATE_EXTENDED_DONTCARE  =    7'd57;      
localparam CPUSTATE_INDEXED_BASE       =    7'd58;                


localparam CPUSTATE_IDX_DONTCARE3      =    7'd60;

localparam CPUSTATE_IDX_OFFSET_LO      =    7'd61;
localparam CPUSTATE_IDX_16OFFSET_LO    =    7'd62;

localparam CPUSTATE_IDX_16OFF_DONTCARE0=    7'd63;
localparam CPUSTATE_IDX_16OFF_DONTCARE1=    7'd64;
localparam CPUSTATE_IDX_16OFF_DONTCARE2=    7'd65;
localparam CPUSTATE_IDX_16OFF_DONTCARE3=    7'd66;

localparam CPUSTATE_IDX_DOFF_DONTCARE1 =    7'd68;
localparam CPUSTATE_IDX_DOFF_DONTCARE2 =    7'd69;
localparam CPUSTATE_IDX_DOFF_DONTCARE3 =    7'd70;
localparam CPUSTATE_IDX_PC16OFF_DONTCARE =  7'd71;

localparam CPUSTATE_IDX_EXTIND_LO =         7'd72;
localparam CPUSTATE_IDX_EXTIND_DONTCARE =   7'd73;

localparam CPUSTATE_INDIRECT_HI         =   7'd74;
localparam CPUSTATE_INDIRECT_LO         =   7'd75;
localparam CPUSTATE_INDIRECT_DONTCARE   =   7'd76;
localparam CPUSTATE_MUL_ACTION          =   7'd77;

localparam CPUSTATE_PSH_DONTCARE1       =   7'd80;
localparam CPUSTATE_PSH_DONTCARE2       =   7'd81;
localparam CPUSTATE_PSH_DONTCARE3       =   7'd82;
localparam CPUSTATE_PSH_ACTION          =   7'd83;

localparam CPUSTATE_PUL_DONTCARE1       =   7'd84;
localparam CPUSTATE_PUL_DONTCARE2       =   7'd85;
localparam CPUSTATE_PUL_ACTION          =   7'd86;

localparam CPUSTATE_NMI_START           =   7'd87;
localparam CPUSTATE_IRQ_DONTCARE        =   7'd88;
localparam CPUSTATE_IRQ_START           =   7'd89;
localparam CPUSTATE_IRQ_DONTCARE2       =   7'd90;
localparam CPUSTATE_IRQ_VECTOR_HI       =   7'd91;
localparam CPUSTATE_IRQ_VECTOR_LO       =   7'd92;
localparam CPUSTATE_FIRQ_START          =   7'd93;
localparam CPUSTATE_CC_DONTCARE         =   7'd94;
localparam CPUSTATE_SWI_START           =   7'd95;

localparam CPUSTATE_TST_DONTCARE1       =   7'd96;
localparam CPUSTATE_TST_DONTCARE2       =   7'd97;

localparam CPUSTATE_DEBUG               =   7'd98;

localparam CPUSTATE_16IMM_DONTCARE      =   7'd99;

localparam CPUSTATE_HALTED              =  7'd100;

localparam CPUSTATE_HALT_EXIT2          =  7'd102;
localparam CPUSTATE_STOP                =  7'd105;
localparam CPUSTATE_STOP2               =  7'd106;
localparam CPUSTATE_STOP3               =  7'd107;


localparam CPUSTATE_CWAI                =  7'd108;
localparam CPUSTATE_CWAI_DONTCARE1      =  7'd109;
localparam CPUSTATE_CWAI_POST           =  7'd110;

localparam CPUSTATE_DMABREQ             =  7'd111;
localparam CPUSTATE_DMABREQ_EXIT        =  7'd112;
localparam CPUSTATE_SYNC                =  7'd113;
localparam CPUSTATE_SYNC_EXIT           =  7'd114;

localparam CPUSTATE_INT_DONTCARE        =  7'd115;


reg     [6:0]    CpuState = CPUSTATE_RESET;
reg     [6:0]    CpuState_nxt = CPUSTATE_RESET;

reg     [6:0]    NextState = CPUSTATE_RESET;
reg     [6:0]    NextState_nxt = CPUSTATE_RESET;

wire    [6:0]    PostIllegalState;

// If we encounter something like an illegal addressing mode (an index mode that's illegal for instance)
// What state should we go to?
generate
if (ILLEGAL_INSTRUCTIONS=="STOP")
begin : postillegal
    assign PostIllegalState = CPUSTATE_STOP; 
end
else
begin
    assign PostIllegalState = CPUSTATE_FETCH_I1;
end
endgenerate



///////////////////////////////////////////////////////////////////////

//
// MapInstruction - Considering how the core was instantiated, this 
// will either directly return D[7:0] *or* remap values from D[7:0] 
// that relate to undefined instructions in the 6809 to the instructions
// that the 6809 actually executed when these were encountered, due to
// incomplete decoding.
//
// NEG, COM, LSR, DEC - these four instructions, in Direct, Inherent (A or B)
// Indexed, or Extended addressing do not actually decode bit 0 on the instruction.
// Thus, for instance, a $51 encountered will be executed as a $50, which is a NEGB.
//

// Specifically, the input is an instruction; if it matches an unknown instruction that the 
// 6809 is known to ghost to another instruction, the output of the function 
// is the the instruction that actually gets executed.  Otherwise, the output is the 
// input.

function [7:0] MapInstruction(input [7:0] i);
reg [3:0] topnyb;
reg [3:0] btmnyb;
reg [7:0] newinst;
begin
    newinst = i;
    
    topnyb = i[7:4];
    btmnyb = i[3:0];
    
    if ( (topnyb == 4'H0) || 
         (topnyb == 4'H4) || 
         (topnyb == 4'H5) || 
         (topnyb == 4'H6) ||
         (topnyb == 4'H7) 
        )
    begin
        if (btmnyb == 4'H1)
            newinst = {topnyb, 4'H0};
        if (btmnyb == 4'H2)
            newinst = {topnyb, 4'H3};
        if (btmnyb == 4'H5)
            newinst = {topnyb, 4'H4};
        if (btmnyb == 4'HB)
            newinst = {topnyb, 4'HA};
    end
    MapInstruction = newinst;
end
endfunction


wire [7:0] MappedInstruction;
generate
if (ILLEGAL_INSTRUCTIONS=="GHOST")
begin : ghost
    assign MappedInstruction = MapInstruction(D);  
end
else
begin
    assign MappedInstruction = D;
end
endgenerate



///////////////////////////////////////////////////////////////////////

function IllegalInstruction(input [7:0] i);
reg [3:0] hi;
reg [3:0] lo;
reg       illegal;
begin
    illegal = 1'b0;
    hi = i[7:4];
    lo = i[3:0];
    if ( (hi == 4'H0) || (hi == 4'H4) || (hi == 4'H5) || (hi == 4'H6) || (hi == 4'H7) )
    begin
        if ( (lo == 4'H1) || (lo == 4'H2) || (lo == 4'H5) || (lo == 4'HB) )
            illegal = 1'b1;
        if (lo == 4'HE)
            if ( (hi == 4'H4) || (hi == 4'H5) )
                illegal = 1'b1;
    end
    if (hi == 4'H3)
    begin
        if ( (lo == 4'H8) || (lo == 4'HE) )
            illegal = 1'b1;
    end
    if (hi == 4'H1)
    begin
        if ( (lo == 4'H4) || (lo == 4'H5) || (lo == 4'H8) || (lo == 4'HB) )
            illegal = 1'b1;
    end
    if ( (hi == 4'H8) || (hi == 4'HC) )
    begin
        if ( (lo == 4'H7) || (lo == 4'HF) )
            illegal = 1'b1;
        if ( lo == 4'HD )
            if (hi == 4'HC)
                illegal = 1'b1;
    end
    IllegalInstruction = illegal;
end
endfunction

wire IsIllegalInstruction;

generate
if (ILLEGAL_INSTRUCTIONS=="GHOST")
begin : never_illegal
    assign IsIllegalInstruction = 1'b0; 
end
else
begin
    assign IsIllegalInstruction = IllegalInstruction(Inst1);
end
endgenerate

wire [6:0] IllegalInstructionState;
generate
if (ILLEGAL_INSTRUCTIONS=="IGNORE")
begin : illegal_state
    assign IllegalInstructionState = CPUSTATE_FETCH_I1;
end
else if (ILLEGAL_INSTRUCTIONS=="STOP")
begin
    assign IllegalInstructionState = CPUSTATE_STOP;
end
else
begin
    assign IllegalInstructionState = 7'd0;
end
endgenerate


///////////////////////////////////////////////////////////////////////


always @(negedge NMISample2 or posedge wNMIClear)
begin
    if (wNMIClear == 1)
        NMILatched <= 1;
    else if (NMIMask == 0)
        NMILatched <= 0;
    else
        NMILatched <= 1;
end

//
// The 6809 specs say that the CPU control signals are sampled on the falling edge of Q.
// It also says that the interrupts require 1 cycle of synchronization time.  
// That's vague, as it doesn't say where "1 cycle" starts or ends.  Starting from the
// falling edge of Q, the next cycle notices an assertion.  From checking a hard 6809 on
// an analyzer, what they really mean is that it's sampled on the falling edge of Q, 
// but there's a one cycle delay from the falling edge of E (0.25 clocks from the falling edge of Q
// where the signals were sampled) before it can be noticed.  
// So, SIGNALSample is the latched value at the falling edge of Q
//     SIGNALSample2 is the latched value at the falling edge of E (0.25 clocks after the line above)
//     SIGNALLatched is the latched value at the falling edge of E (1 cycle after the line above)
//
// /HALT and /DMABREQ are delayed one cycle less than interrupts.  The 6809 specs infer these details,
// but don't list the point-of-reference they're written from (for instance, they say that an interrupt requires
// a cycle for synchronization; however, it isn't clear whether that's from the falling Q to the next falling Q,
// a complete intermediate cycle, the falling E to the next falling E, etc.) - which, in the end, required an
// analyzer on the 6809 to determine how many cycles before a new instruction an interrupt (or /HALT & /DMABREQ)
// had to be asserted to be noted instead of the next instruction running start to finish.  
// 
always @(negedge Q)
begin
    NMISample <= nNMI;
    
    IRQSample <= nIRQ;

    FIRQSample <= nFIRQ;

    HALTSample <= nHALT;
    
    DMABREQSample <= nDMABREQ;

        
end


reg rnRESET=0; // The latched version of /RESET, useful 1 clock after it's latched
always @(negedge E)
begin
    rnRESET <= nRESET;
    
    NMISample2 <= NMISample;
    
    IRQSample2 <= IRQSample;
    IRQLatched <= IRQSample2;

    FIRQSample2 <= FIRQSample;
    FIRQLatched <= FIRQSample2;

    HALTSample2 <= HALTSample;
    HALTLatched <= HALTSample2;

    DMABREQSample2 <= DMABREQSample;
    DMABREQLatched <= DMABREQSample2;


    if (rnRESET == 1)
    begin
        CpuState <= CpuState_nxt;
        
        // Don't interpret this next item as "The Next State"; it's a special case 'after this 
        // generic state, go to this programmable state', so that a single state 
        // can be shared for many tasks. [Specifically, the stack push/pull code, which is used
        // for PSH, PUL, Interrupts, RTI, etc.
        NextState <= NextState_nxt;
         
        // CPU registers latch from the combinatorial circuit
        a <= a_nxt;
        b <= b_nxt;
        x <= x_nxt;
        y <= y_nxt;
        s <= s_nxt;
        u <= u_nxt;
        cc <= cc_nxt;
        dp <= dp_nxt;
        pc <= pc_nxt;
        tmp <= tmp_nxt;
        addr <= addr_nxt;
        ea <= ea_nxt;
        
        InstPage2 <= InstPage2_nxt;
        InstPage3 <= InstPage3_nxt;
        Inst1 <= Inst1_nxt;
        Inst2 <= Inst2_nxt;
        Inst3 <= Inst3_nxt;
        NMIClear <= NMIClear_nxt;
        
        IntType <= IntType_nxt;
        
        if (s != s_nxt)                 // Once S changes at all (default is '0'), release the NMI Mask.
            NMIMask <= 1'b0;
    end
    else
    begin
        CpuState <= CPUSTATE_RESET; 
        NMIMask <= 1'b1; // Mask NMI until S is loaded.
        NMIClear <= 1'b0; // Mark us as not having serviced NMI
    end
end


/////////////////////////////////////////////////////////////////
// Decode the Index byte

localparam IDX_REG_X   =  3'd0;
localparam IDX_REG_Y   =  3'd1;
localparam IDX_REG_U   =  3'd2;
localparam IDX_REG_S   =  3'd3;
localparam IDX_REG_PC  =  3'd4;

localparam IDX_MODE_POSTINC1   =  4'd0;
localparam IDX_MODE_POSTINC2   =  4'd1;
localparam IDX_MODE_PREDEC1    =  4'd2;
localparam IDX_MODE_PREDEC2    =  4'd3;
localparam IDX_MODE_NOOFFSET   =  4'd4;
localparam IDX_MODE_B_OFFSET   =  4'd5;
localparam IDX_MODE_A_OFFSET   =  4'd6;
localparam IDX_MODE_5BIT_OFFSET=  4'd7;    // Special case, not bit pattern 7; the offset sits in the bit pattern
localparam IDX_MODE_8BIT_OFFSET=  4'd8;
localparam IDX_MODE_16BIT_OFFSET   =  4'd9;
localparam IDX_MODE_D_OFFSET       =  4'd11;
localparam IDX_MODE_8BIT_OFFSET_PC =  4'd12;
localparam IDX_MODE_16BIT_OFFSET_PC=  4'd13;
localparam IDX_MODE_EXTENDED_INDIRECT  =  4'd15;

// Return:
//     Register base [3 bits]
//     Indirect      [1 bit]
//     Mode          [4 bits]

function [7:0] IndexDecode(input   [7:0] postbyte);
reg     [2:0]  regnum;
reg     indirect;
reg     [3:0]  mode;
begin
    indirect   =  0;
    mode       =  0;
    
    if (postbyte[7] == 0)           // 5-bit
    begin
        mode   =  IDX_MODE_5BIT_OFFSET;
    end
    else
    begin
        mode   =  postbyte[3:0];
        indirect   =  postbyte[4];
    end            
    if ((mode != IDX_MODE_8BIT_OFFSET_PC) && (mode != IDX_MODE_16BIT_OFFSET_PC))
        regnum[2:0]    =  postbyte[6:5];
    else
        regnum[2:0]    =  IDX_REG_PC;
    
    IndexDecode    =  {indirect, mode, regnum};
end
endfunction

wire    [3:0]  IndexedMode;
wire    IndexedIndirect;
wire    [2:0]  IndexedRegister;

assign  {IndexedIndirect, IndexedMode, IndexedRegister}    =  IndexDecode(Inst2);

/////////////////////////////////////////////////////////////////
// Is this a JMP instruction?  (irrespective of addressing mode)
function IsJMP(input   [7:0] inst);
reg     [3:0] hi;
reg     [3:0] lo;
begin
    hi =  inst[7:4];
    lo =  inst[3:0];
    
    IsJMP  =  0;
    if ((hi == 4'H0) || (hi == 4'H6) || (hi == 4'H7))
        if (lo == 4'HE)
            IsJMP  =  1;
end
endfunction

///////////////////////////////////////////////////////////////////
// Is this an 8-bit Store?

localparam ST8_REG_A   =  1'b0;
localparam ST8_REG_B   =  1'b1;

function [1:0] IsST8(input   [7:0] inst);
reg     regnum;
reg     IsStore;
begin
    
    IsStore        =  1'b0;
    regnum =  1'b1;
    
    if ( (Inst1 == 8'H97) || (Inst1 == 8'HA7) || (Inst1 == 8'HB7) )
    begin
        IsStore    =  1'b1;
        regnum     =  1'b0;
    end
    else if ( (Inst1 == 8'HD7) || (Inst1 == 8'HE7) || (Inst1 == 8'HF7) )
    begin
        IsStore    =  1'b1;
        regnum     =  1'b1;
    end
    IsST8  =  {IsStore, regnum};
end
endfunction

wire    IsStore8;
wire    Store8RegisterNum;

assign  {IsStore8, Store8RegisterNum}  =  IsST8(Inst1);        


/////////////////////////////////////////////////////////////////
// Is this a 16-bit Store?

localparam ST16_REG_X  =  3'd0;
localparam ST16_REG_Y  =  3'd1;
localparam ST16_REG_U  =  3'd2;
localparam ST16_REG_S  =  3'd3;
localparam ST16_REG_D  =  3'd4;


function [3:0] IsST16(input   [7:0] inst);
reg     [3:0] hi;
reg     [3:0] lo;
reg     [2:0] regnum;
reg     IsStore;
begin
    hi =  inst[7:4];
    lo =  inst[3:0];
    IsStore    =  1'b0;
    regnum     =  3'b111;
    
    if ((inst == 8'H9F) || (inst == 8'HAF) || (inst == 8'HBF))
    begin
        IsStore    =  1;
        if (~InstPage2)
            regnum =  ST16_REG_X;
        else
            regnum =  ST16_REG_Y;
    end
    else if ((inst == 8'HDF) || (inst == 8'HEF) || (inst == 8'HFF))
    begin
        IsStore        =  1;
        if (~InstPage2)
            regnum =  ST16_REG_U;
        else
            regnum =  ST16_REG_S;
    end
    else if ((inst == 8'HDD) || (inst == 8'HED) || (inst == 8'HFD))
    begin
        IsStore        =  1;
        regnum =  ST16_REG_D;
    end
    
    IsST16 =  {IsStore, regnum};
end
endfunction

wire    IsStore16;
wire    [2:0] StoreRegisterNum;

assign  {IsStore16, StoreRegisterNum}  =  IsST16(Inst1);

/////////////////////////////////////////////////////////////////
// Is this a special Immediate mode instruction, ala
// PSH, PUL, EXG, TFR, ANDCC, ORCC
function IsSpecialImm(input   [7:0] inst);
reg     is;
reg     [3:0] hi;
reg     [3:0] lo;
begin
    hi =  inst[7:4];
    lo =  inst[3:0];
    is =  0;
    
    if (hi == 4'H1)
    begin
        if ( (lo == 4'HA) || (lo == 4'HC) || (lo == 4'HE) || (lo == 4'HF) )     // ORCC, ANDCC, EXG, TFR
            is =  1;
    end
    else if (hi == 4'H3)
    begin
        if ( (lo >= 4'H3) && (lo <= 4'H7) )     // PSHS, PULS, PSHU, PULU
            is =  1;
    end
    else
        is =  0;
    
    IsSpecialImm   =  is;
end
endfunction
wire    IsSpecialImmediate =  IsSpecialImm(Inst1);

/////////////////////////////////////////////////////////////////
// Is this a one-byte instruction?  [The 6809 reads 2 bytes for every instruction, minimum (it can read more).  On a one-byte, we have to ensure that we haven't skipped the PC ahead.
function IsOneByteInstruction(input   [7:0] inst);
reg     is;
reg     [3:0] hi;
reg     [3:0] lo;
begin
    hi =  inst[7:4];
    lo =  inst[3:0];
    is = 1'b0;
    
    if ( (hi == 4'H4) || (hi == 4'H5) )
        is =  1'b1;
    else if ( hi == 4'H1)
    begin
        if ( (lo == 4'H2) || (lo == 4'H3) || (lo == 4'H9) || (lo == 4'HD) )
            is =  1'b1;
    end
    else if (hi == 4'H3)
    begin
        if ( (lo >= 4'H9) && (lo != 4'HC) )
            is =  1'b1;
    end
    else
        is =  1'b0;
    
    IsOneByteInstruction   =  is;           
end
endfunction 

/////////////////////////////////////////////////////////////////
// ALU16 - Simpler than the 8 bit ALU

localparam ALU16_REG_X =  3'd0;
localparam ALU16_REG_Y =  3'd1;
localparam ALU16_REG_U =  3'd2;
localparam ALU16_REG_S =  3'd3;
localparam ALU16_REG_D =  3'd4;

function [2:0] ALU16RegFromInst(input   Page2, input   Page3, input   [7:0] inst);
reg     [2:0] srcreg;
begin
    srcreg =  3'b111;       // default
    casex ({Page2, Page3, inst}) // Note pattern for the matching below
        10'b1010xx0011:         // 1083, 1093, 10A3, 10B3 CMPD 
            srcreg =  ALU16_REG_D;
        10'b1010xx1100:         // 108C, 109C, 10AC, 10BC CMPY
            srcreg =  ALU16_REG_Y;
        10'b0110xx0011:         // 1183, 1193, 11A3, 11B3 CMPU
            srcreg =  ALU16_REG_U;
        10'b0110xx1100:         // 118C, 119C, 11AC, 11BC CMPS
            srcreg =  ALU16_REG_S;
        10'b0010xx1100:         // 8C,9C,AC,BC CMPX
            srcreg =  ALU16_REG_X;
        
        10'b0011xx0011:         // C3, D3, E3, F3 ADDD
            srcreg =  ALU16_REG_D;
        
        10'b0011xx1100:         // CC, DC, EC, FC LDD
            srcreg =  ALU16_REG_D;            
        10'b0010xx1110:         // 8E LDX, 9E LDX, AE LDX, BE LDX
            srcreg =  ALU16_REG_X;
        10'b0011xx1110:         // CE LDU, DE LDU, EE LDU, FE LDU
            srcreg =  ALU16_REG_U;        
        10'b1010xx1110:         // 108E LDY, 109E LDY, 10AE LDY, 10BE LDY
            srcreg =  ALU16_REG_Y;
        10'b1011xx1110:         // 10CE LDS, 10DE LDS, 10EE LDS, 10FE LDS
            srcreg =  ALU16_REG_S;               
        10'b0010xx0011:         // 83, 93, A3, B3 SUBD
            srcreg =  ALU16_REG_D;
        
        10'H03A:                // 3A ABX
            srcreg =  ALU16_REG_X;
        10'H030:                // 30 LEAX
            srcreg =  ALU16_REG_X;
        10'H031:                // 31 LEAY
            srcreg =  ALU16_REG_Y;
        10'H032:                // 32 LEAS
            srcreg =  ALU16_REG_S;
        10'H033:                // 32 LEAU
            srcreg =  ALU16_REG_U;
        default:
            srcreg =  3'b111;
    endcase
    ALU16RegFromInst   =  srcreg;
end
endfunction

wire    [2:0] ALU16Reg     =  ALU16RegFromInst(InstPage2, InstPage3, Inst1);

localparam  ALUOP16_SUB        =  3'H0;
localparam  ALUOP16_ADD        =  3'H1;
localparam  ALUOP16_LD         =  3'H2;
localparam  ALUOP16_CMP        =  3'H3;
localparam  ALUOP16_LEA        =  3'H4;
localparam  ALUOP16_INVALID    =  3'H7;

function [3:0] ALU16OpFromInst(input   Page2, input   Page3, input   [7:0] inst);
reg     [2:0] aluop;
reg     writeback;
begin
    aluop  =  3'b111;
    writeback  =  1'b1;
    casex ({Page2, Page3, inst})
        10'b1010xx0011:         // 1083, 1093, 10A3, 10B3 CMPD
        begin 
            aluop  =  ALUOP16_CMP;
            writeback  =  1'b0;
        end                
        10'b1010xx1100:         // 108C, 109C, 10AC, 10BC CMPY
        begin 
            aluop      =  ALUOP16_CMP;
            writeback  =  1'b0;
        end                
        10'b0110xx0011:         // 1183, 1193, 11A3, 11B3 CMPU
        begin 
            aluop      =  ALUOP16_CMP;
            writeback  =  1'b0;
        end                
        10'b0110xx1100:         // 118C, 119C, 11AC, 11BC CMPS
        begin 
            aluop      =  ALUOP16_CMP;
            writeback  =  1'b0;
        end                
        10'b0010xx1100:         // 8C,9C,AC,BC CMPX
        begin 
            aluop      =  ALUOP16_CMP;
            writeback  =  1'b0;
        end                
        
        10'b0011xx0011:         // C3, D3, E3, F3 ADDD
            aluop  =  ALUOP16_ADD;
        
        10'b0011xx1100:         // CC, DC, EC, FC LDD
            aluop  =  ALUOP16_LD;                
        10'b001xxx1110:         // 8E LDX, 9E LDX, AE LDX, BE LDX, CE LDU, DE LDU, EE LDU, FE LDU
            aluop  =  ALUOP16_LD;
        10'b101xxx1110:         // 108E LDY, 109E LDY, 10AE LDY, 10BE LDY, 10CE LDS, 10DE LDS, 10EE LDS, 10FE LDS
            aluop  =  ALUOP16_LD;
        
        10'b0010xx0011:         // 83, 93, A3, B3 SUBD
            aluop  =  ALUOP16_SUB;
        
        10'H03A:                // 3A ABX
            aluop  =  ALUOP16_ADD;
        
        10'b00001100xx:         // $30-$33, LEAX, LEAY, LEAS, LEAU
            aluop  =  ALUOP16_LEA;

        default:
            aluop  =  ALUOP16_INVALID;
    endcase
    ALU16OpFromInst    =  {writeback, aluop};
end
endfunction

wire    ALU16OpWriteback;
wire    [2:0]  ALU16Opcode;

assign  {ALU16OpWriteback, ALU16Opcode}    =  ALU16OpFromInst(InstPage2, InstPage3, Inst1);  

wire    IsALU16Opcode  =  (ALU16Opcode != 3'b111);          

function [23:0] ALU16Inst(input   [2:0] operation16, input   [15:0] a_arg, input   [15:0] b_arg, input   [7:0] cc_arg);
reg     [7:0]    cc_out;
reg     [15:0]   ALUFn;
reg     carry;
reg     borrow;
begin
    cc_out =  cc_arg;
    case (operation16)
        ALUOP16_ADD:
        begin
            {cc_out[CC_C_BIT], ALUFn} =  {1'b0, a_arg} + b_arg;
            cc_out[CC_V_BIT]   =  (a_arg[15] & b_arg[15] & ~ALUFn[15]) | (~a_arg[15] & ~b_arg[15] & ALUFn[15]);
        end
        
        ALUOP16_SUB:
        begin
            {cc_out[CC_C_BIT], ALUFn} =  {1'b0, a_arg} - {1'b0, b_arg};
            cc_out[CC_V_BIT]   =  (a_arg[15] & ~b_arg[15] & ~ALUFn[15]) | (~a_arg[15] & b_arg[15] & ALUFn[15]);
        end
        
        ALUOP16_LD:
        begin
            ALUFn  =  b_arg;
            cc_out[CC_V_BIT]   =  1'b0;
        end
        
        ALUOP16_CMP:
        begin
            {cc_out[CC_C_BIT], ALUFn} =  {1'b0, a_arg} - {1'b0, b_arg};
            cc_out[CC_V_BIT]   =  (a_arg[15] & ~b_arg[15] & ~ALUFn[15]) | (~a_arg[15] & b_arg[15] & ALUFn[15]);
        end
        
        ALUOP16_LEA:
        begin
            ALUFn  =  a_arg;
        end
        
        default:
            ALUFn = 16'H0000;
        
    endcase
    cc_out[CC_Z_BIT]   =  (ALUFn[15:0] == 16'H0000);
    if (operation16 != ALUOP16_LEA)
        cc_out[CC_N_BIT]   =  ALUFn[15];
    ALU16Inst  =  {cc_out, ALUFn};
end
endfunction

reg     [2:0]   ALU16_OP;
reg     [15:0]  ALU16_A;
reg     [15:0]  ALU16_B;
reg     [7:0]   ALU16_CC;     

// Top 8 bits == CC, bottom 8 bits = output value
wire    [23:0] ALU16   =  ALU16Inst(ALU16_OP, ALU16_A, ALU16_B, ALU16_CC);


/////////////////////////////////////////////////////////////////
// ALU

// The ops are organized from the 4 low-order bits of the instructions for the first set of ops, then 16-31 are the second set - even though bit 4 isn't representative.
localparam        ALUOP_NEG  =  5'd0;
localparam        ALUOP_COM  =  5'd3;
localparam        ALUOP_LSR  =  5'd4;
localparam        ALUOP_ROR  =  5'd6;
localparam        ALUOP_ASR  =  5'd7;
localparam        ALUOP_ASL  =  5'd8;
localparam        ALUOP_LSL  =  5'd8;
localparam        ALUOP_ROL  =  5'd9;
localparam        ALUOP_DEC  =  5'd10;
localparam        ALUOP_INC  =  5'd12;
localparam        ALUOP_TST  =  5'd13;
localparam        ALUOP_CLR  =  5'd15;

localparam        ALUOP_SUB  =  5'd16;
localparam        ALUOP_CMP  =  5'd17;
localparam        ALUOP_SBC  =  5'd18;
localparam        ALUOP_AND  =  5'd20;
localparam        ALUOP_BIT  =  5'd21;
localparam        ALUOP_LD   =  5'd22;
localparam        ALUOP_EOR  =  5'd24;
localparam        ALUOP_ADC  =  5'd25;
localparam        ALUOP_OR   =  5'd26;
localparam        ALUOP_ADD  =  5'd27;

function [5:0] ALUOpFromInst(input   [7:0] inst);
reg     [4:0] op;
reg     writeback;
begin
    // Okay, this turned out to be simpler than I expected ...
    op =  {inst[7], inst[3:0]};
    case (op)
        ALUOP_CMP:
            writeback  =  0;
        ALUOP_TST:
            writeback  =  0;
        ALUOP_BIT:
            writeback  =  0;
        default:
            writeback  =  1;
    endcase
    ALUOpFromInst  =  {writeback, op};                        
end
endfunction

wire    [4:0] ALU8Op;
wire    ALU8Writeback;

assign  {ALU8Writeback, ALU8Op}    =  ALUOpFromInst(Inst1);

reg     [7:0] ALU_A;
reg     [7:0] ALU_B;
reg     [7:0] ALU_CC;
reg     [4:0] ALU_OP;


function [15:0] ALUInst(input   [4:0] operation, input   [7:0] a_arg, input   [7:0] b_arg, input   [7:0] cc_arg);
reg     [7:0]    cc_out;
reg     [7:0]    ALUFn;
reg     carry;
reg     borrow;
begin
    cc_out =  cc_arg;
    case (operation)
        ALUOP_NEG:
        begin
            ALUFn[7:0]             =  ~a_arg + 1'b1;
            cc_out[CC_C_BIT]       =  (ALUFn[7:0] != 8'H00);
            cc_out[CC_V_BIT]       =  (a_arg == 8'H80);
        end
        
        ALUOP_LSL:
        begin
            {cc_out[CC_C_BIT], ALUFn}  =  {a_arg, 1'b0};
            cc_out[CC_V_BIT]   =  a_arg[7] ^ a_arg[6];
        end
        
        ALUOP_LSR:
        begin
            {ALUFn, cc_out[CC_C_BIT]}  =  {1'b0, a_arg}; 
        end
        
        ALUOP_ASR:
        begin
            {ALUFn, cc_out[CC_C_BIT]}  =  {a_arg[7], a_arg}; 
        end    
        
        ALUOP_ROL:
        begin
            {cc_out[CC_C_BIT], ALUFn}  =  {a_arg, cc_arg[CC_C_BIT]};
            cc_out[CC_V_BIT]   =  a_arg[7] ^ a_arg[6];
        end
        
        ALUOP_ROR:
        begin
            {ALUFn, cc_out[CC_C_BIT]}  =  {cc_arg[CC_C_BIT], a_arg}; 
        end
        
        ALUOP_OR:
        begin
            ALUFn[7:0] =  (a_arg | b_arg);
            cc_out[CC_V_BIT]   =  1'b0;
        end
        
        ALUOP_ADD:
        begin
            {cc_out[CC_C_BIT], ALUFn[7:0]} =  {1'b0, a_arg} + {1'b0, b_arg};
            cc_out[CC_V_BIT]   =  (a_arg[7] & b_arg[7] & ~ALUFn[7]) | (~a_arg[7] & ~b_arg[7] & ALUFn[7]);
            cc_out[CC_H_BIT]   =  a_arg[4] ^ b_arg[4] ^ ALUFn[4];
        end
        
        ALUOP_SUB:
        begin
            {cc_out[CC_C_BIT], ALUFn[7:0]} = {1'b0, a_arg} - {1'b0, b_arg};
            cc_out[CC_V_BIT]   =   (a_arg[7] & ~b_arg[7] & ~ALUFn[7]) | (~a_arg[7] & b_arg[7] & ALUFn[7]);
        end
        
        ALUOP_AND:
        begin
            ALUFn[7:0] =  (a_arg & b_arg);
            cc_out[CC_V_BIT]   =  1'b0;
        end
        
        ALUOP_BIT:
        begin
            ALUFn[7:0] =  (a_arg & b_arg);
            cc_out[CC_V_BIT]   =  1'b0;
        end
        
        ALUOP_EOR:
        begin
            ALUFn[7:0] =  (a_arg ^ b_arg);
            cc_out[CC_V_BIT]   =  1'b0;                
        end
        
        ALUOP_CMP:
        begin
            {cc_out[CC_C_BIT], ALUFn[7:0]} = {1'b0, a_arg} - {1'b0, b_arg};
            cc_out[CC_V_BIT]   =   (a_arg[7] & ~b_arg[7] & ~ALUFn[7]) | (~a_arg[7] & b_arg[7] & ALUFn[7]);
        end
        
        ALUOP_COM:
        begin
            ALUFn[7:0] =  ~a_arg;
            cc_out[CC_V_BIT]   =  1'b0;
            cc_out[CC_C_BIT]   =  1'b1;
        end
        
        ALUOP_ADC:
        begin
            {cc_out[CC_C_BIT], ALUFn[7:0]} =  {1'b0, a_arg} + {1'b0, b_arg} + cc_arg[CC_C_BIT];
            cc_out[CC_V_BIT]   =  (a_arg[7] & b_arg[7] & ~ALUFn[7]) | (~a_arg[7] & ~b_arg[7] & ALUFn[7]);
            cc_out[CC_H_BIT]   =  a_arg[4] ^ b_arg[4] ^ ALUFn[4];
        end
        
        ALUOP_LD:
        begin
            ALUFn[7:0] =  b_arg;
            cc_out[CC_V_BIT] = 1'b0;
        end
        
        ALUOP_INC:
        begin
            {carry, ALUFn} =  {1'b0, a_arg} + 1'b1;
            cc_out[CC_V_BIT]   =  (~a_arg[7] & ALUFn[7]);             
        end
        
        ALUOP_DEC:
        begin
            {carry, ALUFn[7:0]}    =  {1'b0, a_arg} - 1'b1;
            cc_out[CC_V_BIT]       =   (a_arg[7] & ~ALUFn[7]);
        end
        
        ALUOP_CLR:
        begin
            ALUFn[7:0] =  8'H00;
            cc_out[CC_V_BIT]   =  1'b0;
            cc_out[CC_C_BIT]   =  1'b0;
        end
        
        ALUOP_TST:
        begin
            ALUFn[7:0] =  a_arg;
            cc_out[CC_V_BIT]   =  1'b0;
        end
        
        ALUOP_SBC:
        begin
            {cc_out[CC_C_BIT], ALUFn[7:0]} = {1'b0, a_arg} - {1'b0, b_arg} - cc_arg[CC_C_BIT];
            cc_out[CC_V_BIT]   =   (a_arg[7] & ~b_arg[7] & ~ALUFn[7]) | (~a_arg[7] & b_arg[7] & ALUFn[7]);
        end
        
        default:
            ALUFn = 8'H00;
    
    endcase
    
    cc_out[CC_N_BIT]   =  ALUFn[7];
    cc_out[CC_Z_BIT]   =  (ALUFn == 8'H00);
    ALUInst    =  {cc_out[7:0], ALUFn[7:0]};
end
endfunction


// Top 8 bits == CC, bottom 8 bits = output value
wire    [15:0] ALU =  ALUInst(ALU_OP, ALU_A, ALU_B, ALU_CC);

////////////////////////////////////////////////////////////

localparam TYPE_INHERENT   =  3'd0;
localparam TYPE_IMMEDIATE  =  3'd1;
localparam TYPE_DIRECT     =  3'd2;
localparam TYPE_RELATIVE   =  3'd3;
localparam TYPE_INDEXED    =  3'd4;
localparam TYPE_EXTENDED   =  3'd5;

localparam TYPE_INVALID    =  3'd7;

// Function to decode the addressing mode the instruction uses
function [2:0] addressing_mode_type(input   [7:0] inst);
begin
    casex (inst)
    8'b0000???? :                 addressing_mode_type   =  TYPE_DIRECT;
    8'b0001???? :
    begin
        casex (inst[3:0])
        4'b0010:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b0011:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b1001:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b1101:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b0110:
            addressing_mode_type   =  TYPE_RELATIVE;
        
        4'b0111:
            addressing_mode_type   =  TYPE_RELATIVE;
        
        4'b1010:
            addressing_mode_type   =  TYPE_IMMEDIATE;
        
        4'b1100:
            addressing_mode_type   =  TYPE_IMMEDIATE;
        
        4'b1110:
            addressing_mode_type   =  TYPE_IMMEDIATE;
        
        4'b1111:
            addressing_mode_type   =  TYPE_IMMEDIATE;
        
        default:
            addressing_mode_type   =  TYPE_INVALID;
        endcase
    end
    
    8'b0010????:                     addressing_mode_type   =  TYPE_RELATIVE;
    8'b0011????:
    begin
        casex(inst[3:0])
        4'b00??:
            addressing_mode_type   =  TYPE_INDEXED;
        
        4'b01??:
            addressing_mode_type   =  TYPE_IMMEDIATE;
        
        4'b1001:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b101?:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b1100:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b1101:
            addressing_mode_type   =  TYPE_INHERENT;
        
        4'b1111:
            addressing_mode_type   =  TYPE_INHERENT;
        
        default:
            addressing_mode_type   =  TYPE_INVALID;
        endcase
    end
    
    8'b010?????:                addressing_mode_type   =  TYPE_INHERENT;
    
    8'b0110????:                addressing_mode_type   =  TYPE_INDEXED;
    
    8'b0111????:                addressing_mode_type   =  TYPE_EXTENDED;
    
    8'b1000????:
    begin
        casex (inst[3:0])
        4'b0111:                addressing_mode_type   =  TYPE_INVALID;
        4'b1111:                addressing_mode_type   =  TYPE_INVALID;
        4'b1101:                addressing_mode_type   =  TYPE_RELATIVE;
        default:                addressing_mode_type   =  TYPE_IMMEDIATE;
        endcase
    end
    
    8'b1001????:                addressing_mode_type   =  TYPE_DIRECT;
    8'b1010????:                addressing_mode_type   =  TYPE_INDEXED;
    8'b1011????:                addressing_mode_type   =  TYPE_EXTENDED;
    8'b1100????:                addressing_mode_type   =  TYPE_IMMEDIATE;
    8'b1101????:                addressing_mode_type   =  TYPE_DIRECT;
    8'b1110????:                addressing_mode_type   =  TYPE_INDEXED;
    8'b1111????:                addressing_mode_type   =  TYPE_EXTENDED;
    
    endcase
end
endfunction

wire    [2:0]    AddrModeType   =  addressing_mode_type(Inst1);

//////////////////////////////////////////////////

// Individual opcodes that are the top of a column of states.

localparam OPCODE_INH_ABX           =  8'H3A;
localparam OPCODE_INH_RTS           =  8'H39;
localparam OPCODE_INH_RTI           =  8'H3B;
localparam OPCODE_INH_CWAI          =  8'H3C;
localparam OPCODE_INH_MUL           =  8'H3D;
localparam OPCODE_INH_SWI           =  8'H3F;
localparam OPCODE_INH_SEX           =  8'H1D;
localparam OPCODE_INH_NOP           =  8'H12;
localparam OPCODE_INH_SYNC          =  8'H13;
localparam OPCODE_INH_DAA           =  8'H19;

localparam OPCODE_IMM_ORCC          =  8'H1A;
localparam OPCODE_IMM_ANDCC         =  8'H1C;
localparam OPCODE_IMM_EXG           =  8'H1E;
localparam OPCODE_IMM_TFR           =  8'H1F;
localparam OPCODE_IMM_PSHS          =  8'H34;
localparam OPCODE_IMM_PULS          =  8'H35;
localparam OPCODE_IMM_PSHU          =  8'H36;
localparam OPCODE_IMM_PULU          =  8'H37;

localparam OPCODE_IMM_SUBD          =  8'H83;
localparam OPCODE_IMM_CMPX          =  8'H8C;
localparam OPCODE_IMM_LDX           =  8'H8E;
localparam OPCODE_IMM_ADDD          =  8'HC3;
localparam OPCODE_IMM_LDD           =  8'HCC;
localparam OPCODE_IMM_LDU           =  8'HCE;
localparam OPCODE_IMM_CMPD          =  8'H83;    // Page2
localparam OPCODE_IMM_CMPY          =  8'H8C;    // Page2
localparam OPCODE_IMM_LDY           =  8'H8E;    // Page2
localparam OPCODE_IMM_LDS           =  8'HCE;    // Page2
localparam OPCODE_IMM_CMPU          =  8'H83;    // Page3
localparam OPCODE_IMM_CMPS          =  8'H8C;    // Page3

localparam EXGTFR_REG_D             =  4'H0;
localparam EXGTFR_REG_X             =  4'H1;
localparam EXGTFR_REG_Y             =  4'H2;
localparam EXGTFR_REG_U             =  4'H3;
localparam EXGTFR_REG_S             =  4'H4;
localparam EXGTFR_REG_PC            =  4'H5;
localparam EXGTFR_REG_A             =  4'H8;
localparam EXGTFR_REG_B             =  4'H9;
localparam EXGTFR_REG_CC            =  4'HA;
localparam EXGTFR_REG_DP            =  4'HB;

function IsALU8Set0(input   [7:0] instr);
reg     result;
reg     [3:0] hi;
reg     [3:0] lo;
begin
    hi =  instr[7:4];
    lo =  instr[3:0];
    if ( (hi == 4'H0) || (hi == 4'H4) || (hi == 4'H5) || (hi == 4'H6) || (hi == 4'H7) )
    begin
        if ( (lo != 4'H1) && (lo != 4'H2) && (lo != 4'H5) && (lo != 4'HB) && (lo != 4'HE) )     // permit NEG, COM, LSR, ROR, ASR, ASL/LSL, ROL, DEC, INC, TST, CLR 
            result =  1;
        else
            result =  0;
    end
    else
        result =  0;
    IsALU8Set0     =  result;            
end
endfunction    

function IsALU8Set1(input   [7:0] instr);
reg     result;
reg     [3:0] hi;
reg     [3:0] lo;
begin
    hi =  instr[7:4];
    lo =  instr[3:0];
    if ( (hi >= 4'H8) )
    begin
        if ( (lo <= 4'HB) && (lo != 4'H3) && (lo != 4'H7) )     // 8-bit SUB, CMP, SBC, AND, BIT, LD, EOR, ADC, OR, ADD
            result =  1;
        else
            result =  0;
    end
    else
        result =  0;
    IsALU8Set1     =  result;                
end
endfunction

// Determine if the instruction is performing an 8-bit op (ALU only)    
function ALU8BitOp(input   [7:0] instr);
begin
    ALU8BitOp      =  IsALU8Set0(instr) | IsALU8Set1(instr);
end
endfunction

wire    Is8BitInst     =  ALU8BitOp(Inst1);

function IsRegA(input   [7:0] instr);
reg     result;
reg     [3:0]    hi;
begin
    hi =  instr[7:4];
    if ((hi == 4'H4) || (hi == 4'H8) || (hi == 4'H9) || (hi == 4'HA) || (hi == 4'HB) )
        result =  1;
    else
        result =  0;
    IsRegA =  result;
end
endfunction

wire    IsTargetRegA   =  IsRegA(Inst1);

//
//
// Decode 
// 00-0F = DIRECT
// 10-1F = INHERENT, RELATIVE, IMMEDIATE
// 20-2F = RELATIVE
// 30-3F = INDEXED, IMMEDIATE (pus, pul), INHERENT
// 40-4F = INHERENT
// 50-5F = INHERENT
// 60-6F = INDEXED
// 70-7F = EXTENDED
// 80-8F = IMMEDIATE, RELATIVE (BSR)
// 90-9F = DIRECT
// A0-AF = INDEXED
// B0-BF = EXTENDED
// C0-CF = IMMEDIATE
// D0-DF = DIRECT
// E0-EF = INDEXED
// F0-FF = EXTENDED

// DIRECT; 00-0F, 90-9F, D0-DF
// INHERENT; 10-1F (12, 13, 19, 1D), 30-3F (39-3F), 40-4F, 50-5F, 
// RELATIVE: 10-1F (16, 17), 20-2F, 80-8F (8D)
// IMMEDIATE: 10-1F (1A, 1C, 1E, 1F), 30-3F (34-37), 80-8F (80-8C, 8E), C0-CF
// INDEXED: 60-6F, A0-AF, E0-EF
// EXTENDED: 70-7F, B0-Bf, F0-FF

localparam INST_LBRA   =  8'H16;                // always -- shitty numbering, damnit
localparam INST_LBSR   =  8'H17;                // 

localparam INST_BRA    =  8'H20;           // always
localparam INST_BRN    =  8'H21;           // never
localparam INST_BHI    =  8'H22;           // CC.Z = 0 && CC.C = 0
localparam INST_BLS    =  8'H23;           // CC.Z != 0 && CC.C != 0
localparam INST_BCC    =  8'H24;           // CC.C = 0
localparam INST_BHS    =  8'H24;           // same as BCC
localparam INST_BCS    =  8'H25;           // CC.C = 1
localparam INST_BLO    =  8'H25;           // same as BCS
localparam INST_BNE    =  8'H26;           // CC.Z = 0
localparam INST_BEQ    =  8'H27;           // CC.Z = 1
localparam INST_BVC    =  8'H28;           // V = 1
localparam INST_BVS    =  8'H29;           // V = 0
localparam INST_BPL    =  8'H2A;           // CC.N = 0
localparam INST_BMI    =  8'H2B;           // CC.N = 1
localparam INST_BGE    =  8'H2C;           // CC.N = CC.V
localparam INST_BLT    =  8'H2D;           // CC.N != CC.V
localparam INST_BGT    =  8'H2E;           // CC.N = CC.V && CC.Z = 0
localparam INST_BLE    =  8'H2F;           // CC.N != CC.V && CC.Z = 1
localparam INST_BSR    =  8'H8D;           // always

localparam NYB_BRA     =  4'H0;            // always
localparam NYB_BRN     =  4'H1;            // never
localparam NYB_BHI     =  4'H2;            // CC.Z = 0 && CC.C = 0
localparam NYB_BLS     =  4'H3;            // CC.Z != 0 && CC.C != 0
localparam NYB_BCC     =  4'H4;            // CC.C = 0
localparam NYB_BHS     =  4'H4;            // same as BCC
localparam NYB_BCS     =  4'H5;            // CC.C = 1
localparam NYB_BLO     =  4'H5;            // same as BCS
localparam NYB_BNE     =  4'H6;            // CC.Z = 0
localparam NYB_BEQ     =  4'H7;            // CC.Z = 1
localparam NYB_BVC     =  4'H8;            // V = 0
localparam NYB_BVS     =  4'H9;            // V = 1
localparam NYB_BPL     =  4'HA;            // CC.N = 0
localparam NYB_BMI     =  4'HB;            // CC.N = 1
localparam NYB_BGE     =  4'HC;            // CC.N = CC.V
localparam NYB_BLT     =  4'HD;            // CC.N != CC.V
localparam NYB_BGT     =  4'HE;            // CC.N = CC.V && CC.Z = 0
localparam NYB_BLE     =  4'HF;            // CC.N != CC.V && CC.Z = 1



function take_branch(input   [7:0] Inst1, input   [7:0] cc);
begin
    take_branch    =  0;    //default
    if ( (Inst1 == INST_BSR) || (Inst1 == INST_LBSR) || (Inst1 == INST_LBRA) )
        take_branch    =  1;
    else
        case (Inst1[3:0])
            NYB_BRA:
                take_branch    =  1;
            NYB_BRN:
                take_branch    =  0;
            NYB_BHI:
                if ( ( cc[CC_Z_BIT] | cc[CC_C_BIT] ) == 0)
                    take_branch    =  1;
            NYB_BLS:
                if ( cc[CC_Z_BIT] | cc[CC_C_BIT] )
                    take_branch    =  1;
            NYB_BCC:
                if ( cc[CC_C_BIT] == 0 )
                    take_branch    =  1;
            NYB_BCS:
                if ( cc[CC_C_BIT] == 1 )
                    take_branch    =  1;
            NYB_BNE:
                if ( cc[CC_Z_BIT] == 0 )
                    take_branch    =  1;
            NYB_BEQ:
                if ( cc[CC_Z_BIT] == 1 )
                    take_branch    =  1;
            NYB_BVC:
                if ( cc[CC_V_BIT] == 0)
                    take_branch    =  1;
            NYB_BVS:
                if ( cc[CC_V_BIT] == 1)
                    take_branch    =  1;
            NYB_BPL:
                if ( cc[CC_N_BIT] == 0 )
                    take_branch    =  1;
            NYB_BMI:
                if (cc[CC_N_BIT] == 1)
                    take_branch    =  1;
            NYB_BGE:
                if ((cc[CC_N_BIT] ^ cc[CC_V_BIT]) == 0)
                    take_branch    =  1;
            NYB_BLT:
                if ((cc[CC_N_BIT] ^ cc[CC_V_BIT]) == 1)
                    take_branch    =  1;
            NYB_BGT:
                if ( ((cc[CC_N_BIT] ^ cc[CC_V_BIT]) == 0) & (cc[CC_Z_BIT] == 0) )
                    take_branch    =  1;
            NYB_BLE:
                if ( ((cc[CC_N_BIT] ^ cc[CC_V_BIT]) == 1) | (cc[CC_Z_BIT] == 1) )
                    take_branch    =  1;
    endcase
end
endfunction

wire    TakeBranch =  take_branch(Inst1, cc);

/////////////////////////////////////////////////////////////////////
// Convenience function for knowing the contents for TFR, EXG
function [15:0] EXGTFRRegister(input [3:0] regid);
begin
        case (regid)
            EXGTFR_REG_D:
                EXGTFRRegister   =  {a, b};
            EXGTFR_REG_X:
                EXGTFRRegister   =  x;
            EXGTFR_REG_Y:
                EXGTFRRegister   =  y;
            EXGTFR_REG_U:
                EXGTFRRegister   =  u;
            EXGTFR_REG_S:
                EXGTFRRegister   =  s;
            EXGTFR_REG_PC:
                EXGTFRRegister   =  pc_p1; // For both EXG and TFR, this is used on the 2nd byte in the instruction's cycle.  The PC intended to transfer is actually the next byte.
            EXGTFR_REG_DP:
                EXGTFRRegister   =  {8'HFF, dp};
            EXGTFR_REG_A:
                EXGTFRRegister   =  {8'HFF, a};
            EXGTFR_REG_B:
                EXGTFRRegister   =  {8'HFF, b};
            EXGTFR_REG_CC:
                EXGTFRRegister   =  {8'HFF, cc};
            default:
                EXGTFRRegister   =  16'H0;                                       
        endcase
end
endfunction
wire [15:0] EXGTFRRegA = EXGTFRRegister(D[7:4]);
wire [15:0] EXGTFRRegB = EXGTFRRegister(D[3:0]);

// CPU state machine
always @(*)
begin
    rLIC       =  1'b0;
    rAVMA      =  1'b1;
    rBUSY      =  1'b0;
    
    addr_nxt   =  16'HFFFF;
    pc_p1      =  (pc+16'H1);
    pc_p2      =  (pc+16'H2);
    pc_p3      =  (pc+16'H3);
    s_p1       =  (s+16'H1);
    s_m1       =  (s-16'H1);
    u_p1       =  (u+16'H1);
    u_m1       =  (u-16'H1);
    addr_p1    =  (addr+16'H1);
    ea_p1      =  (ea+16'H1);
    BS_nxt     =  1'b0;
    BA_nxt     =  1'b0;
    
    // These may be overridden below, but the "next" version by default should be
    // the last latched version.
    IntType_nxt = IntType;
    NMIClear_nxt = NMIClear;
    NextState_nxt = NextState;
    a_nxt      =  a;
    b_nxt      =  b;
    x_nxt      =  x;
    y_nxt      =  y;
    s_nxt      =  s;
    u_nxt      =  u;
    cc_nxt     =  cc;
    dp_nxt     =  dp;
    pc_nxt     =  pc;
    tmp_nxt    =  tmp;
    ea_nxt     =  ea;
    
    ALU_A      =  8'H00;
    ALU_B      =  8'H00;
    ALU_CC     =  8'H00;
    ALU_OP     =  5'H00;
    
    ALU16_OP   =  3'H0;
    ALU16_A    =  16'H0000;
    ALU16_B    =  16'H0000;
    ALU16_CC   =  8'H00;
    
    DOutput       =  8'H00;
    RnWOut     =  1'b1;     // read
    
    Inst1_nxt  =  Inst1;
    Inst2_nxt  =  Inst2;
    Inst3_nxt  =  Inst3;
    InstPage2_nxt  =  InstPage2;
    InstPage3_nxt  =  InstPage3;
    
    CpuState_nxt   =  CpuState;
    
    case (CpuState)
    CPUSTATE_RESET:
    begin
        addr_nxt   =  16'HFFFF;
        a_nxt      =  0;
        b_nxt      =  0;
        x_nxt      =  0;
        y_nxt      =  0;
        s_nxt      =  16'HFFFD;    // Take care about removing the reset of S.  There's logic depending on the delta between s and s_nxt to clear NMIMask.
        u_nxt      =  0;
        cc_nxt     =  CC_F | CC_I; // reset disables interrupts
        dp_nxt     =  0;
        ea_nxt     =  16'HFFFF;
        
        RnWOut     =  1;        // read
        rLIC       =  1'b0;     // Instruction incomplete
        NMIClear_nxt= 1'b0;
        IntType_nxt = 3'b111;
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_RESET0;
    end
    
    CPUSTATE_RESET0:
    begin
        addr_nxt       =  `RESET_VECTOR;
        rBUSY          =  1'b1;
        pc_nxt[15:8]   =  D[7:0];
        BS_nxt         =  1'b1; // ACK RESET
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt   =  CPUSTATE_RESET2;
    end
    
    CPUSTATE_RESET2:
    begin
        addr_nxt       =  addr_p1;
        BS_nxt         =  1'b1; // ACK RESET        
        pc_nxt[7:0]    =  D[7:0];
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_FETCH_I1:
    begin
        if (~DMABREQLatched)
        begin
            addr_nxt      = pc;
            RnWOut        = 1'b1;
            rAVMA         = 1'b0;
            tmp_nxt       = {tmp[15:4], 4'b1111};
            BS_nxt         = 1'b1;
            BA_nxt         = 1'b1;
            rLIC           = 1'b1;
            CpuState_nxt  = CPUSTATE_DMABREQ;
        end
        else if (~HALTLatched)
        begin
            addr_nxt       = pc;
            RnWOut         = 1'b1;
            rAVMA          = 1'b0;
            BS_nxt         = 1'b1;
            BA_nxt         = 1'b1;
            rLIC           = 1'b1;            
            CpuState_nxt = CPUSTATE_HALTED;
        end
        else // not halting, run the inst byte fetch
        begin
            addr_nxt       =  pc;   // Set the address bus for the next instruction, first byte
            pc_nxt =  pc_p1;
            RnWOut =  1;            // Set for a READ
            Inst1_nxt  =  MappedInstruction;
            InstPage2_nxt  =  0;
            InstPage3_nxt  =  0;
            
            // New instruction fetch; service interrupts pending
            if (NMILatched == 0)
            begin
                pc_nxt = pc;        
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_NMI_START;
            end
            else if ((FIRQLatched == 0) && (cc[CC_F_BIT] == 0))
            begin
                pc_nxt = pc;
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_FIRQ_START;
            end
            else if ((IRQLatched == 0) && (cc[CC_I_BIT] == 0))
            begin
                pc_nxt = pc; 
                rAVMA = 1'b1;                
                CpuState_nxt = CPUSTATE_IRQ_START;
            end
            
            // The actual 1st byte checks
            else if (Inst1_nxt == 8'H10) // Page 2  Note, like the 6809, $10 $10 $10 $10 has the same effect as a single $10.
            begin
                InstPage2_nxt  =  1;
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_FETCH_I1V2;
            end
            else if (Inst1_nxt == 8'H11)    // Page 3
            begin
                InstPage3_nxt  =  1;
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_FETCH_I1V2;
            end
            else
            begin
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_FETCH_I2;
            end
        end // if not halting
    end
    
    CPUSTATE_FETCH_I1V2:
    begin
        addr_nxt   =  pc;            // Set the address bus for the next instruction, first byte
        pc_nxt     =  pc_p1;
        RnWOut     =  1;            // Set for a READ
        Inst1_nxt  =  MappedInstruction;

        if (Inst1_nxt == 8'H10)         // Page 2  Note, like the 6809, $10 $10 $10 $10 has the same effect as a single $10.
        begin
            if (InstPage3 == 0)             // $11 $11 $11 $11 ... $11 $10 still = Page 3
                InstPage2_nxt  =  1;
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1V2;
        end
        else if (Inst1_nxt == 8'H11)    // Page 3
        begin
            if (InstPage2 == 0)             // $10 $10 ... $10 $11 still = Page 2
                InstPage3_nxt  =  1;
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1V2;
        end
        else
        begin
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I2;
        end
    end
    
    
    CPUSTATE_FETCH_I2:      // We've fetched the first byte.  If a $10 or $11 (page select), mark those flags and fetch the next byte as instruction byte 1.
    begin
        addr_nxt   =  addr_p1;    // Address bus++
        pc_nxt     =  pc_p1;
        Inst2_nxt  =  D[7:0];
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;

        if (IsIllegalInstruction)           // Skip illegal instructions
        begin
            
            rAVMA = 1'b1;
            CpuState_nxt = IllegalInstructionState;
            rLIC = 1'b1;
        end
        else
        begin
            // First byte Decode for this stage
            case (AddrModeType)
                TYPE_INDEXED:
                begin
                    rAVMA = 1'b1;
                    CpuState_nxt   =  CPUSTATE_INDEXED_BASE;
                end
                
                
                TYPE_EXTENDED:
                begin
                    ea_nxt[15:8]   =  Inst2_nxt;
                    rAVMA = 1'b1;
                    CpuState_nxt   =  CPUSTATE_EXTENDED_ADDRLO;
                end
                TYPE_DIRECT:
                begin
                    ea_nxt =  {dp, Inst2_nxt};
                    rAVMA = 1'b0;
                    CpuState_nxt   =  CPUSTATE_DIRECT_DONTCARE;
                end
                
                TYPE_INHERENT:
                begin
                    if (Inst1 == OPCODE_INH_NOP)
                    begin
                        rLIC = 1'b1; // Instruction done!
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;    
                    end
                    else if (Inst1 == OPCODE_INH_DAA)       // Bcd lunacy
                    begin
                        if ( ((cc[CC_C_BIT]) || (a[7:4] > 4'H9)) ||
                             ((a[7:4] > 4'H8) && (a[3:0] > 4'H9)) )
                            tmp_nxt[7:4] = 4'H6;
                        else
                            tmp_nxt[7:4] = 4'H0;
                            
                        if ((cc[CC_H_BIT]) || (a[3:0] > 4'H9))
                            tmp_nxt[3:0] = 4'H6;
                        else
                            tmp_nxt[3:0] = 4'H0;
                            
                        // DAA handles carry in the weirdest way.  
                        // If it's already set, it remains set, even if carry-out is 0.
                        // If it wasn't set, but the output of the operation is set, carry-out gets set.
                        {tmp_nxt[8], a_nxt} = {1'b0, a} + tmp_nxt[7:0];
                        
                        cc_nxt[CC_C_BIT] = cc_nxt[CC_C_BIT] | tmp_nxt[8];

                        cc_nxt[CC_N_BIT] = a_nxt[7];
                        cc_nxt[CC_Z_BIT] = (a_nxt == 8'H00);
                        rLIC = 1'b1; // Instruction done!
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;    
                    end
                    else if (Inst1 == OPCODE_INH_SYNC)
                    begin
                        CpuState_nxt = CPUSTATE_SYNC;
                        rLIC = 1'b1;
                        rAVMA = 1'b0;
                    end
                    else if (Inst1 == OPCODE_INH_MUL)
                    begin
                        tmp_nxt = 16'H0000;
                        ea_nxt[15:8] = 8'H00;
                        ea_nxt[7:0] = a;
                        a_nxt = 8;
                        rAVMA = 1'b0;
                        CpuState_nxt = CPUSTATE_MUL_ACTION;
                    end
                    else if (Inst1 == OPCODE_INH_RTS)
                    begin
                        rAVMA = 1'b1;
                        CpuState_nxt   =  CPUSTATE_RTS_HI;
                    end
                    else if (Inst1 == OPCODE_INH_RTI)
                    begin
                        rAVMA = 1'b1;
                        tmp_nxt = 16'H1001; // Set tmp[12] to indicate an RTI being processed, and at least pull CC.
                        CpuState_nxt = CPUSTATE_PUL_ACTION;
                        NextState_nxt = CPUSTATE_FETCH_I1;
                    end
                    else if (Inst1 == OPCODE_INH_SWI)
                    begin
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_SWI_START;
                    end
                    else if (Inst1 == OPCODE_INH_CWAI)
                    begin
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_CWAI;
                    end
                    else if (Inst1 == OPCODE_INH_SEX)
                    begin
                        a_nxt = {8{b[7]}};
                        rLIC = 1'b1; // Instruction done!
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                        end
                    else if (Inst1 == OPCODE_INH_ABX)
                    begin
                        x_nxt  =  x + b;
                        rAVMA = 1'b0;
                        CpuState_nxt   =  CPUSTATE_ABX_DONTCARE;
                    end                                                                        
                    else
                    begin
                        ALU_OP =  ALU8Op; 
                        if (IsTargetRegA)
                            ALU_A  =  a;
                        else
                            ALU_A  =  b;
                        
                        ALU_B  =  0;
                        ALU_CC =  cc;
                        cc_nxt =  ALU[15:8];
                        
                        if (ALU8Writeback)
                        begin
                            if (IsTargetRegA)
                                a_nxt  =  ALU[7:0];
                            else
                                b_nxt  =  ALU[7:0];
                        end
                        rLIC = 1'b1; // Instruction done!
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;  
                    end
                    if (IsOneByteInstruction(Inst1))        // This check is probably superfluous.  Every inherent instruction is 1 byte on the 6809.
                        pc_nxt =  pc;                       // The 6809 auto-reads 2 bytes for every instruction.  :(  Adjust by not incrementing PC on the 2nd byte read.
                 end
                
                TYPE_IMMEDIATE:
                begin
                    if (IsSpecialImmediate)
                    begin
                        if (Inst1 == OPCODE_IMM_ANDCC)
                        begin
                            pc_nxt = pc_p1;
                            cc_nxt = cc & D; //cc_nxt & Inst2_nxt;
                            rAVMA = 1'b1;
                            CpuState_nxt = CPUSTATE_CC_DONTCARE;
                        end
                        else if (Inst1 == OPCODE_IMM_ORCC)
                        begin
                            pc_nxt = pc_p1;
                            cc_nxt = cc | D; //cc_nxt | Inst2_nxt;
                            rAVMA = 1'b1;
                            CpuState_nxt = CPUSTATE_CC_DONTCARE;
                        end
                        else if ( (Inst1 == OPCODE_IMM_PSHS) | (Inst1 == OPCODE_IMM_PSHU) )
                        begin
                            pc_nxt = pc_p1;
                            tmp_nxt[15] = 1'b0;
                            tmp_nxt[14] = Inst1[1]; // Mark whether to save to U or S.
                            tmp_nxt[13] = 1'b0; // Not pushing due to an interrupt.
                            tmp_nxt[13:8] = 6'H00;
                            tmp_nxt[7:0] = Inst2_nxt;
                            rAVMA = 1'b0;
                            CpuState_nxt = CPUSTATE_PSH_DONTCARE1;
                            NextState_nxt = CPUSTATE_FETCH_I1;
                        end
                        else if ( (Inst1 == OPCODE_IMM_PULS) | (Inst1 == OPCODE_IMM_PULU) )
                        begin
                            pc_nxt = pc_p1;
                            tmp_nxt[15] = 1'b0;
                            tmp_nxt[14] = Inst1[1]; // S (0) or U (1) stack in use.
                            tmp_nxt[13:8] = 6'H00;
                            tmp_nxt[7:0] = Inst2_nxt;
                            rAVMA = 1'b0;
                            CpuState_nxt = CPUSTATE_PUL_DONTCARE1;
                            NextState_nxt = CPUSTATE_FETCH_I1;
                        end
                        else if (Inst1 == OPCODE_IMM_TFR)
                        begin
                            // The second byte lists the registers; Top nybble is reg #1, bottom is reg #2.

                            case (Inst2_nxt[3:0])
                                EXGTFR_REG_D:
                                    {a_nxt,b_nxt}  =  EXGTFRRegA;
                                EXGTFR_REG_X:
                                    x_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_Y:
                                    y_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_U:
                                    u_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_S:
                                    s_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_PC:
                                    pc_nxt =  EXGTFRRegA;
                                EXGTFR_REG_DP:
                                    dp_nxt =  EXGTFRRegA[7:0];
                                EXGTFR_REG_A:
                                    a_nxt  =  EXGTFRRegA[7:0];
                                EXGTFR_REG_B:
                                    b_nxt  =  EXGTFRRegA[7:0];
                                EXGTFR_REG_CC:
                                    cc_nxt =  EXGTFRRegA[7:0];
                                default:
                                begin
                                end
                            endcase                          
                            rAVMA = 1'b0;
                            CpuState_nxt   =  CPUSTATE_TFR_DONTCARE1;
                            
                        end
                        else if (Inst1 == OPCODE_IMM_EXG)
                        begin
                            // The second byte lists the registers; Top nybble is reg #1, bottom is reg #2.
                              
                            case (Inst2_nxt[7:4])
                                EXGTFR_REG_D:
                                    {a_nxt,b_nxt}  =  EXGTFRRegB;
                                EXGTFR_REG_X:
                                    x_nxt  =  EXGTFRRegB;
                                EXGTFR_REG_Y:
                                    y_nxt  =  EXGTFRRegB;
                                EXGTFR_REG_U:
                                    u_nxt  =  EXGTFRRegB;
                                EXGTFR_REG_S:
                                    s_nxt  =  EXGTFRRegB;
                                EXGTFR_REG_PC:
                                    pc_nxt =  EXGTFRRegB;
                                EXGTFR_REG_DP:
                                    dp_nxt =  EXGTFRRegB[7:0];
                                EXGTFR_REG_A:
                                    a_nxt  =  EXGTFRRegB[7:0];
                                EXGTFR_REG_B:
                                    b_nxt  =  EXGTFRRegB[7:0];
                                EXGTFR_REG_CC:
                                    cc_nxt =  EXGTFRRegB[7:0];
                                default:
                                begin
                                end
                            endcase
                            case (Inst2_nxt[3:0])
                                EXGTFR_REG_D:
                                    {a_nxt,b_nxt}  =  EXGTFRRegA;
                                EXGTFR_REG_X:
                                    x_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_Y:
                                    y_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_U:
                                    u_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_S:
                                    s_nxt  =  EXGTFRRegA;
                                EXGTFR_REG_PC:
                                    pc_nxt =  EXGTFRRegA;
                                EXGTFR_REG_DP:
                                    dp_nxt =  EXGTFRRegA[7:0];
                                EXGTFR_REG_A:
                                    a_nxt  =  EXGTFRRegA[7:0];
                                EXGTFR_REG_B:
                                    b_nxt  =  EXGTFRRegA[7:0];
                                EXGTFR_REG_CC:
                                    cc_nxt =  EXGTFRRegA[7:0];
                                default:
                                begin
                                end
                            endcase                               
                            rAVMA = 1'b0;
                            CpuState_nxt   =  CPUSTATE_EXG_DONTCARE1;  
                        end
                    end
                    // Determine if this is an 8-bit ALU operation.
                    else if (Is8BitInst)
                    begin
                        ALU_OP =  ALU8Op;     
                        if (IsTargetRegA)
                            ALU_A  =  a;
                        else
                            ALU_A  =  b;
                        
                        ALU_B  =  Inst2_nxt;
                        ALU_CC =  cc;
                        cc_nxt =  ALU[15:8];
                        
                        if (ALU8Writeback)
                        begin
                            if (IsTargetRegA)
                                a_nxt  =  ALU[7:0];
                            else
                                b_nxt  =  ALU[7:0];
                        end
                        rLIC = 1'b1; // Instruction done!               
                        rAVMA = 1'b1;
                        CpuState_nxt   =  CPUSTATE_FETCH_I1;
                    end
                    else            // Then it must be a 16 bit instruction
                    begin
                                // 83 SUBD
                                // 8C CMPX
                                // 8E LDX
                                // C3 ADDD
                                // CC LDD
                                // CE LDU
                                // 108E CMPD
                                // 108C CMPY
                                // 108E LDY
                                // 10CE LDS
                                // 1183 CMPU
                                // 118C CMPS
                                // Wow, they were just stuffing them in willy-nilly ...
                        
                                // LD* 16 bit immediate
                        if (IsALU16Opcode)
                        begin
                            rAVMA = 1'b1;
                            CpuState_nxt   =  CPUSTATE_16IMM_LO;
                        end
                        // there's a dead zone here; I need an else to take us back to CPUSTATE_FETCHI1 if we want to ignore illegal instructions, to CPUSTATE_DEAD if we want to catch them.
                        
                    end
                    
                end
                
                TYPE_RELATIVE:
                begin
                    // Is this a LB** or a B**?
                    // If InstPage2 is set, it's a long branch; if clear, a normal branch.
                    if ( (InstPage2) || (Inst1 == INST_LBRA) || (Inst1 == INST_LBSR) )
                    begin
                        rAVMA = 1'b1;
                        CpuState_nxt   =  CPUSTATE_LBRA_OFFSETLOW;
                    end
                    else
                    begin
                        rAVMA = 1'b0;
                        CpuState_nxt   =  CPUSTATE_BRA_DONTCARE;
                    end
                    
                end
                default:
                begin
                    CpuState_nxt = CPUSTATE_FETCH_I1;
                end
            endcase
        end
    end
    
    
    CPUSTATE_LBRA_OFFSETLOW:
    begin
        addr_nxt   =  pc;
        pc_nxt     =  pc_p1;
        Inst3_nxt  =  D[7:0];
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_LBRA_DONTCARE;
    end
    
    CPUSTATE_LBRA_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        if ( TakeBranch )
        begin
            rAVMA = 1'b0;
            CpuState_nxt   =  CPUSTATE_LBRA_DONTCARE2;
        end
        else
        begin
            rLIC = 1'b1; // Instruction done!  
            rAVMA = 1'b1;            
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end            
    end
    
    CPUSTATE_BRA_DONTCARE:
    begin
        addr_nxt   =  16'HFFFF;
        tmp_nxt    =  pc;
        if (TakeBranch)
        begin
            pc_nxt =  pc + { {8{Inst2[7]}}, Inst2[7:0]}; // Sign-extend the 8 bit offset to 16.
            
            if (Inst1 == INST_BSR)
            begin
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_BSR_DONTCARE1;
            end
            else
            begin
                rLIC = 1'b1; // Instruction done!  
                rAVMA = 1'b1;                
                CpuState_nxt   =  CPUSTATE_FETCH_I1;
            end
        end
        else
        begin
            rLIC = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        
    end
    
    CPUSTATE_LBRA_DONTCARE2:
    begin
        tmp_nxt=  pc;
        addr_nxt   =  16'HFFFF;
        
        // Take branch
        pc_nxt     =  pc + {Inst2[7:0], Inst3[7:0]};
        if (Inst1 == INST_LBSR)
        begin
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_BSR_DONTCARE1;
        end
        else
        begin
            rLIC = 1'b1; // Instruction done!        
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
    end
    
    CPUSTATE_BSR_DONTCARE1:
    begin
        addr_nxt   =  pc;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_BSR_DONTCARE2;
    end
    
    CPUSTATE_BSR_DONTCARE2:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_BSR_RETURNLOW;
    end
    
    CPUSTATE_BSR_RETURNLOW:
    begin
        addr_nxt       =  s_m1;
        s_nxt  =  s_m1;
        DOutput[7:0]  =  tmp[7:0];
        RnWOut     =  0;
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_BSR_RETURNHIGH;
    end
    
    CPUSTATE_BSR_RETURNHIGH:
    begin
        addr_nxt       =  s_m1;
        s_nxt  =  s_m1;
        DOutput[7:0]  =  tmp[15:8];
        RnWOut     =  0;
        rLIC = 1'b1; // Instruction done!
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;    // after this, RnWOut must go to 1, and the bus needs the PC placed on it.
    end
    
    CPUSTATE_TFR_DONTCARE1:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_TFR_DONTCARE2;
    end            
    
    CPUSTATE_TFR_DONTCARE2:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_TFR_DONTCARE3;
    end            
    
    CPUSTATE_TFR_DONTCARE3:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_TFR_DONTCARE4;
    end            
    
    CPUSTATE_TFR_DONTCARE4:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b1;
        rLIC = 1'b1; // Instruction done!        
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end            
    
    CPUSTATE_EXG_DONTCARE1:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_EXG_DONTCARE2;
    end            
    
    CPUSTATE_EXG_DONTCARE2:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_EXG_DONTCARE3;
    end            
    
    CPUSTATE_EXG_DONTCARE3:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_EXG_DONTCARE4;
    end            
    
    CPUSTATE_EXG_DONTCARE4:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_EXG_DONTCARE5;
    end    
    
    CPUSTATE_EXG_DONTCARE5:
    begin
        rAVMA = 1'b0;
        addr_nxt       =  16'HFFFF;
        CpuState_nxt   =  CPUSTATE_EXG_DONTCARE6;
    end    
    
    CPUSTATE_EXG_DONTCARE6:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b1;
        rLIC = 1'b1; // Instruction done!        
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end            
    
    CPUSTATE_ABX_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b1;
        rLIC = 1'b1; // Instruction done!        
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end            
    
    CPUSTATE_RTS_HI:
    begin
        addr_nxt       =  s;
        s_nxt  =  s_p1;
        pc_nxt[15:8]   =  D[7:0];
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_RTS_LO;
    end
    
    CPUSTATE_RTS_LO:
    begin
        addr_nxt       =  s;
        s_nxt  =  s_p1;
        pc_nxt[7:0]    =  D[7:0];
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_RTS_DONTCARE2;
    end
    
    CPUSTATE_RTS_DONTCARE2:
    begin
        addr_nxt       =  16'HFFFF;
        rLIC = 1'b1; // Instruction done!        
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_16IMM_LO:
    begin
        addr_nxt       =  pc;
        pc_nxt =  pc_p1;
        
        ALU16_OP   =  ALU16Opcode;
        ALU16_CC   =  cc;
        ALU16_B    =  {Inst2, D[7:0]};
        
        case (ALU16Reg)
            ALU16_REG_X:
                ALU16_A    =  x;
            ALU16_REG_D:
                ALU16_A    =  {a, b};
            ALU16_REG_Y:
                ALU16_A    =  y;
            ALU16_REG_U:
                ALU16_A    =  u;
            ALU16_REG_S:
                ALU16_A    =  s;
            default:
                ALU16_A    =  16'H0;
        endcase
        
        if (ALU16OpWriteback)
        begin
            case (ALU16Reg)
                ALU16_REG_X:
                    {cc_nxt, x_nxt}        =  ALU16; 
                ALU16_REG_D:
                    {cc_nxt, a_nxt, b_nxt} =  ALU16;
                ALU16_REG_Y:
                    {cc_nxt, y_nxt}        =  ALU16;
                ALU16_REG_U:
                    {cc_nxt, u_nxt}        =  ALU16;
                ALU16_REG_S:
                    {cc_nxt, s_nxt}        =  ALU16;
                default:
                begin
                end
            endcase
        end
        else
            cc_nxt = ALU16[23:16];

        if (ALU16_OP == ALUOP16_LD)
        begin
            rLIC = 1'b1; // Instruction done!        
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        else
        begin
            rAVMA = 1'b0;
            CpuState_nxt   =  CPUSTATE_16IMM_DONTCARE;
        end
    end   
    
    CPUSTATE_DIRECT_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        
        if (IsJMP(Inst1))
        begin
            pc_nxt =  ea;
            rLIC = 1'b1; // Instruction done!            
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        else
        begin
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_ALU_EA;
        end
    end
    
    CPUSTATE_ALU_EA:
    begin
        
        // Is Figure 18/5 Column 2?  JMP (not Immediate Mode)
        // This actually isn't done here.  All checks passing in to ALU_EA should check for a JMP; FIXME EVERYWHERE

        // Is Figure 18/5 Column 8?  TST (not immediate mode)
        // THIS IS BURIED IN THE COLUMN 3 section with comparisons to ALUOP_TST.
        
        // Is Figure 18/5 Column 3?
        if (IsALU8Set1(Inst1))
        begin
            addr_nxt   =  ea;
            
            ALU_OP     =  ALU8Op;
            ALU_B      =  D[7:0];
            ALU_CC     =  cc;
            
            if (IsTargetRegA)
                ALU_A  =  a;
            else
                ALU_A  =  b;
            
            cc_nxt =  ALU[15:8];
            
            if ( (ALU8Writeback) )
            begin
                if (IsTargetRegA)
                    a_nxt  =  ALU[7:0];
                else
                    b_nxt  =  ALU[7:0];
            end

            rLIC = 1'b1; // Instruction done!             
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        
        // Is Figure 18/5 Column 4? (Store, 8 bits)
        else if (IsStore8)
        begin
            addr_nxt       =  ea;
            RnWOut =  0;    // write

            ALU_OP     =  ALUOP_LD;  // load has the same CC characteristics as store
            ALU_A      =  8'H00;
            ALU_CC     =  cc;
            
            case (Store8RegisterNum)
                ST8_REG_A:
                begin
                    DOutput   =  a;
                    ALU_B  =  a;
                end
                ST8_REG_B:
                begin
                    DOutput   =  b;                                                
                    ALU_B  =  b;
                end


            endcase
            
            cc_nxt =  ALU[15:8];

            rLIC = 1'b1; // Instruction done!            
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        
        // Is Figure 18/5 Column 5?  (Load, 16 bits)
        else if (IsALU16Opcode & (ALU16Opcode == ALUOP16_LD))
        begin
            addr_nxt   =  ea;
            ea_nxt     =  ea_p1;
            
            case (ALU16Reg)
                ALU16_REG_X:
                    x_nxt[15:8]    =  D[7:0];
                ALU16_REG_D:
                    a_nxt          =  D[7:0];
                ALU16_REG_Y:
                    y_nxt[15:8]    =  D[7:0];
                ALU16_REG_S:
                    s_nxt[15:8]    =  D[7:0];                                
                ALU16_REG_U:
                    u_nxt[15:8]    =  D[7:0];
                default:
                begin
                end
            endcase
            rAVMA = 1'b1;
            rBUSY = 1'b1;
            CpuState_nxt   =  CPUSTATE_LD16_LO;
            
        end
        
        // Is Figure 18/5 Column 6?  (Store, 16 bits)
        else if (IsStore16)
        begin
            addr_nxt       =  ea;
            ea_nxt         =  ea_p1;
            
            ALU16_OP       =  ALUOP16_LD;   // LD and ST have the same CC characteristics
            ALU16_CC       =  cc;
            ALU16_A        =  8'H00;
            
            case (StoreRegisterNum)
                ST16_REG_X:
                begin
                    DOutput[7:0]  =  x[15:8];
                    ALU16_B    =  x;
                end
                ST16_REG_Y:
                begin
                    DOutput[7:0]  =  y[15:8];
                    ALU16_B    =  y;
                end
                ST16_REG_U:
                begin
                    DOutput[7:0]  =  u[15:8];
                    ALU16_B    =  u;                    
                end
                ST16_REG_S:
                begin
                    DOutput[7:0]  =  s[15:8];
                    ALU16_B    =  s;                    
                end
                ST16_REG_D:
                begin
                    DOutput[7:0]  =  a[7:0];
                    ALU16_B    =  {a,b};
                end
                default:
                begin
                end
            endcase
            
            cc_nxt = ALU16[23:16];
            
            RnWOut         =  0;        // Write
            rAVMA          =  1'b1;
            rBUSY          =  1'b1;
            CpuState_nxt   =  CPUSTATE_ST16_LO;
        end
        
        // Is Figure 18/5 Column 7?
        else if (IsALU8Set0(Inst1))
        begin
            // These are registerless instructions, ala
            // ASL, ASR, CLR, COM, DEC, INC, (LSL), LSR, NEG, ROL, ROR
            // and TST (special!)
            // They require READ, Modify (the operation above), WRITE.  Between the Read and the Write cycles, there's actually a /VMA
            // cycle where the 6809 likely did the operation.  We'll include a /VMA cycle for accuracy, but we'll do the work primarily in the first cycle.              
            addr_nxt       =  ea;
            
            ALU_OP =  ALU8Op;       
            ALU_A  =  D[7:0];
            ALU_CC =  cc;
            tmp_nxt[15:8] = cc;  // for debug only
            tmp_nxt[7:0]   =  ALU[7:0];
            cc_nxt =  ALU[15:8];
            if (ALU8Op == ALUOP_TST)
            begin
                rAVMA = 1'b0;
                CpuState_nxt = CPUSTATE_TST_DONTCARE1;
            end
            else
            begin
                rAVMA = 1'b0;
                rBUSY = 1'b1;
                CpuState_nxt   =  CPUSTATE_ALU_DONTCARE;
            end
            
        end
        
        // Is Figure 18/5 Column 8?  TST
        // NOTE:
        // THIS IS BURIED IN THE COLUMN 3 section with comparisons to ALUOP_TST.  [Directly above.]
        
        
        // Is Figure 18/5 Column 9?  (16-bit ALU ops, non-load)
        else if (IsALU16Opcode && (ALU16Opcode != ALUOP16_LD) && ((Inst1 < 8'H30) || (Inst1 > 8'H33)) ) // 30-33 = LEAX, LEAY, LEAS, LEAU; don't include them here.
        begin
            addr_nxt       =  ea;
            ea_nxt =  ea_p1;
            
            tmp_nxt[15:8]  =  D[7:0];
            rAVMA = 1'b1;
            rBUSY = 1'b1;
            CpuState_nxt   =  CPUSTATE_ALU16_LO;
            
        end
        
        // Is Figure 18/5 Column 10?  JSR (not Immediate Mode)
        else if ((Inst1 == 8'H9D) || (Inst1 == 8'HAD) || (Inst1 == 8'HBD))      // JSR
        begin
            pc_nxt =  ea;
            addr_nxt   =  ea;
            tmp_nxt    =  pc;
            rAVMA = 1'b0;
            CpuState_nxt   =  CPUSTATE_JSR_DONTCARE;
        end
        // Is Figure 18/5 Column 11?  LEA(X,Y,S,U)
        else if ((Inst1 >= 8'H30) && (Inst1<= 8'H33))
        begin
            addr_nxt = 16'HFFFF; // Ack, actually a valid cycle, this isn't a dontcare (/VMA) cycle!
            
            ALU16_OP       =  ALU16Opcode;
            ALU16_CC       =  cc;
            ALU16_A        =  ea;
            
            case (ALU16Reg)
                ALU16_REG_X:
                    {cc_nxt, x_nxt}    =  ALU16; 
                ALU16_REG_Y:
                    {cc_nxt, y_nxt}    =  ALU16;
                ALU16_REG_U:
                    u_nxt = ALU16[15:0];
                ALU16_REG_S:
                    s_nxt = ALU16[15:0];
                default:
                begin
                end
            endcase
            
            rLIC = 1'b1; // Instruction done!        
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
            
        end
        
    end         
    
    
    CPUSTATE_ALU_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b1;
        rBUSY = 1'b1; // We do nothing here, but on the real 6809, they did the modify phase here.  :|
        CpuState_nxt   =  CPUSTATE_ALU_WRITEBACK;
    end
    
    CPUSTATE_ALU_WRITEBACK:
    begin
        addr_nxt       =  ea;
        RnWOut =  0;    // Write
        DOutput   =  tmp[7:0];
        rLIC = 1'b1; // Instruction done!      
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_LD16_LO:
    begin
        addr_nxt       =  ea;
        
        case (ALU16Reg)
            ALU16_REG_X:
            begin
                x_nxt[7:0] =  D[7:0];
                ALU16_B[15:8] = x[15:8];
            end
            ALU16_REG_D:
            begin
                b_nxt      =  D[7:0];
                ALU16_B[15:8] = a;
            end
            ALU16_REG_Y:
            begin
                y_nxt[7:0] =  D[7:0];
                ALU16_B[15:8] = y[15:8];                
            end
            ALU16_REG_S:
            begin
                s_nxt[7:0] =  D[7:0];                                
                ALU16_B[15:8] = s[15:8];                
            end
            ALU16_REG_U:
            begin
                u_nxt[7:0] =  D[7:0];                                
                ALU16_B[15:8] = u[15:8];                
            end
            default:
            begin
            end
            
        endcase

        ALU16_OP       =    ALU16Opcode;
        ALU16_CC       =    cc;
        ALU16_A        =    8'H00;        
        ALU16_B[7:0]   =    D[7:0];
        cc_nxt         =    ALU16[23:16];
        
        rLIC = 1'b1; // Instruction done!        
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_ST16_LO:
    begin
        addr_nxt       =  ea;
        ea_nxt =  ea_p1;
        case (StoreRegisterNum)
            ST16_REG_X:
                DOutput[7:0]  =  x[7:0];
            ST16_REG_Y:
                DOutput[7:0]  =  y[7:0];
            ST16_REG_U:
                DOutput[7:0]  =  u[7:0];
            ST16_REG_S:
                DOutput[7:0]  =  s[7:0];
            ST16_REG_D:
                DOutput[7:0]  =  b[7:0];
            default:
            begin
            end
        endcase
        RnWOut     =  0;        // write
        
        rLIC = 1'b1; // Instruction done!        
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;                
    end
    
    CPUSTATE_ALU16_LO:
    begin
        addr_nxt       =  ea;
        
        ALU16_OP       =  ALU16Opcode;
        ALU16_CC       =  cc;
        
        ALU16_B        =  {tmp[15:8], D[7:0]};
        
        case (ALU16Reg)
            ALU16_REG_X:
                ALU16_A        =  x;
            ALU16_REG_D:
                ALU16_A        =  {a, b};
            ALU16_REG_Y:
                ALU16_A        =  y;
            ALU16_REG_S:
                ALU16_A        =  s;                                
            ALU16_REG_U:
                ALU16_A        =  u;      
            default:
                ALU16_A        =  16'H0;
                
        endcase
        
        if (ALU16OpWriteback)
        begin
            case (ALU16Reg)
                ALU16_REG_X:
                    {cc_nxt, x_nxt}        =  ALU16; 
                ALU16_REG_D:
                    {cc_nxt, a_nxt, b_nxt} =  ALU16;
                ALU16_REG_Y:
                    {cc_nxt, y_nxt}        =  ALU16;
                ALU16_REG_U:
                    {cc_nxt, u_nxt}        =  ALU16;
                ALU16_REG_S:
                    {cc_nxt, s_nxt}        =  ALU16;
                default:
                begin
                end
            endcase
        end
        else
            cc_nxt = ALU16[23:16];
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_ALU16_DONTCARE;
    end
    
    CPUSTATE_ALU16_DONTCARE:
    begin
        addr_nxt = 16'HFFFF;
        rLIC = 1'b1; // Instruction done!        
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end

    
    CPUSTATE_JSR_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_JSR_RETLO;
    end
    
    CPUSTATE_JSR_RETLO:
    begin
        addr_nxt       =  s_m1;
        s_nxt  =  s_m1;
        RnWOut =  0;
        DOutput   =  tmp[7:0];
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_JSR_RETHI;
    end
    
    CPUSTATE_JSR_RETHI:
    begin
        addr_nxt       =  s_m1;
        s_nxt  =  s_m1;
        RnWOut =  0;
        DOutput   =  tmp[15:8];
        rLIC = 1'b1; // Instruction done!        
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_EXTENDED_ADDRLO:
    begin
        addr_nxt       =  pc;
        pc_nxt =  pc_p1;
        ea_nxt[7:0]    =  D[7:0];
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_EXTENDED_DONTCARE;
    end
    
    CPUSTATE_EXTENDED_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        if (IsJMP(Inst1))
        begin
            pc_nxt =  ea;
            rLIC = 1'b1; // Instruction done!            
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        else
        begin
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_ALU_EA;
        end
    end
    
    CPUSTATE_INDEXED_BASE:
    begin
        addr_nxt       =  pc;

        Inst3_nxt      =  D[7:0];
        
        case (IndexedRegister)
            IDX_REG_X:
                ALU16_A        =  x;
            IDX_REG_Y:
                ALU16_A        =  y;
            IDX_REG_U:
                ALU16_A        =  u;
            IDX_REG_S:
                ALU16_A        =  s;
            IDX_REG_PC:
                ALU16_A        =  pc_p1;
            default:
                ALU16_A        =  16'H0;
        endcase
        ALU16_OP       =  ALUOP16_ADD;                    
        
        case (IndexedMode)
            IDX_MODE_NOOFFSET:
            begin
                case (IndexedRegister)
                    IDX_REG_X:
                        ea_nxt =  x;
                    IDX_REG_Y:
                        ea_nxt =  y;
                    IDX_REG_U:
                        ea_nxt =  u;
                    IDX_REG_S:
                        ea_nxt =  s;
                    default:
                        ea_nxt =  16'H0;
                endcase
                
                if (IndexedIndirect)
                begin
                    rAVMA = 1'b1;
                    CpuState_nxt   =  CPUSTATE_INDIRECT_HI;
                end
                else
                begin
                    if (IsJMP(Inst1))
                    begin
                        pc_nxt =  ea_nxt;
                        rLIC = 1'b1; // Instruction done!                        
                        rAVMA = 1'b1;
                        CpuState_nxt   =  CPUSTATE_FETCH_I1;
                    end
                    else
                    begin
                        rAVMA = 1'b1;
                        CpuState_nxt   =  CPUSTATE_ALU_EA;
                    end
                end
            end
            
            IDX_MODE_5BIT_OFFSET:
            begin
                // The offset is the bottom 5 bits of the Index Postbyte, which is Inst2 here.
                // We'll sign-extend it to 16 bits.
                ALU16_B    =  { {11{Inst2[4]}}, Inst2[4:0] };
                ea_nxt     =  ALU16[15:0]; 
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_DONTCARE3;
            end


            IDX_MODE_8BIT_OFFSET_PC:
            begin
                ALU16_B        =  { {8{D[7]}}, D[7:0] };
                pc_nxt =  pc_p1;
                ea_nxt =  ALU16[15:0];
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_DONTCARE3;
            end
            
            IDX_MODE_8BIT_OFFSET:
            begin
                ALU16_B        =  { {8{D[7]}}, D[7:0] };
                pc_nxt =  pc_p1;
                ea_nxt =  ALU16[15:0];
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_DONTCARE3;
            end
            
            IDX_MODE_A_OFFSET:
            begin
                ALU16_B        =  { {8{a[7]}}, a[7:0] };
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_DONTCARE3;
                ea_nxt =  ALU16[15:0];
            end
            
            IDX_MODE_B_OFFSET:
            begin
                ALU16_B    =  { {8{b[7]}}, b[7:0] };
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_DONTCARE3;
                ea_nxt =  ALU16[15:0];
            end
            
            IDX_MODE_D_OFFSET:
            begin
                ALU16_B    =  {a, b};
                
                ea_nxt     =  ALU16[15:0];
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_IDX_DOFF_DONTCARE1;
            end
            
            IDX_MODE_POSTINC1:
            begin
                ALU16_B    =  16'H1;
                ea_nxt     =  ALU16_A;
                case (IndexedRegister)
                IDX_REG_X:
                    x_nxt      =  ALU16[15:0];
                IDX_REG_Y:
                    y_nxt      =  ALU16[15:0];
                IDX_REG_U:
                    u_nxt      =  ALU16[15:0];
                IDX_REG_S:
                    s_nxt      =  ALU16[15:0];
                default:
                begin
                end
                endcase
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE2;  
            end
            
            IDX_MODE_POSTINC2:
            begin
                ALU16_B        =  16'H2;
                ea_nxt =  ALU16_A;
                case (IndexedRegister)
                    IDX_REG_X:
                        x_nxt  =  ALU16[15:0];
                    IDX_REG_Y:
                        y_nxt  =  ALU16[15:0];
                    IDX_REG_U:
                        u_nxt  =  ALU16[15:0];
                    IDX_REG_S:
                        s_nxt  =  ALU16[15:0];
                    default:
                    begin
                    end
                endcase
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE0;
            end
            
            IDX_MODE_PREDEC1:
            begin
                ALU16_B        =  16'HFFFF;     // -1
                case (IndexedRegister)
                    IDX_REG_X:
                        x_nxt  =  ALU16[15:0];
                    IDX_REG_Y:
                        y_nxt  =  ALU16[15:0];
                    IDX_REG_U:
                        u_nxt  =  ALU16[15:0];
                    IDX_REG_S:
                        s_nxt  =  ALU16[15:0];
                    default:
                    begin
                    end
                endcase
                ea_nxt =  ALU16[15:0];
                rAVMA = 1'b0;
                CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE2;                              
            end
            
            IDX_MODE_PREDEC2:
            begin
                ALU16_B        =  16'HFFFE;     // -2
                case (IndexedRegister)
                    IDX_REG_X:
                        x_nxt  =  ALU16[15:0];
                    IDX_REG_Y:
                        y_nxt  =  ALU16[15:0];
                    IDX_REG_U:
                        u_nxt  =  ALU16[15:0];
                    IDX_REG_S:
                        s_nxt  =  ALU16[15:0];
                    default:
                    begin
                    end
                endcase
                ea_nxt =  ALU16[15:0];
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE0;                            
            end
            
            IDX_MODE_16BIT_OFFSET_PC:            
            begin
                tmp_nxt[15:8]  =  D[7:0];
                pc_nxt =  pc_p1;
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_IDX_16OFFSET_LO;
            end

            IDX_MODE_16BIT_OFFSET:
            begin
                tmp_nxt[15:8]  =  D[7:0];
                pc_nxt =  pc_p1;
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_IDX_16OFFSET_LO;
            end

            IDX_MODE_EXTENDED_INDIRECT:
            begin
                ea_nxt[15:8] = D[7:0];
                pc_nxt =  pc_p1;
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_IDX_EXTIND_LO;
            end
            
            default:
            begin
                rLIC = 1'b1;
                CpuState_nxt = PostIllegalState;
            end
            
        endcase
    end
    
    CPUSTATE_IDX_OFFSET_LO:
    begin
        tmp_nxt[7:0]   =  D[7:0];
        addr_nxt       =  pc;
        pc_nxt =  pc_p1;
        ALU16_B    =  tmp_nxt;
        
        case (IndexedRegister)
            IDX_REG_X:
                ALU16_A    =  x;
            IDX_REG_Y:
                ALU16_A    =  y;
            IDX_REG_U:
                ALU16_A    =  u;
            IDX_REG_S:
                ALU16_A    =  s;
            IDX_REG_PC:
                ALU16_A    =  pc;
            default:
                ALU16_A    =  16'H0;
        endcase
        ALU16_OP   =  ALUOP16_ADD;                    
        
        ea_nxt     =  ALU16[15:0];
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE1;
    end
    
    
    CPUSTATE_IDX_DONTCARE3:
    begin
        addr_nxt   =  16'HFFFF;
        if (IndexedIndirect)
        begin
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_INDIRECT_HI;
        end
        else
        begin
            if (IsJMP(Inst1))
            begin
                pc_nxt =  ea;
                rLIC = 1'b1; // Instruction done!                
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_FETCH_I1;
            end
            else
            begin
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_ALU_EA;
            end
        end

    end                
    
    CPUSTATE_IDX_16OFFSET_LO:
    begin
        addr_nxt       =  pc;
        pc_nxt =  pc_p1;

        case (IndexedRegister)
            IDX_REG_X:
                ALU16_A    =  x;
            IDX_REG_Y:
                ALU16_A    =  y;
            IDX_REG_U:
                ALU16_A    =  u;
            IDX_REG_S:
                ALU16_A    =  s;
            IDX_REG_PC:
                ALU16_A    =  pc_nxt;  // Whups; tricky; not part of the actual pattern
            default:
                ALU16_A    =  x; // Default to something
        endcase

        ALU16_OP   =  ALUOP16_ADD;                    
        
        ALU16_B    =  {tmp[15:8], D[7:0]};
        
        ea_nxt     =  ALU16[15:0];
        rAVMA = 1'b1;
        CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE1;
    end
    
    CPUSTATE_IDX_16OFF_DONTCARE1:
    begin
        addr_nxt       =  pc;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE2;
    end

    CPUSTATE_IDX_16OFF_DONTCARE0:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE2;
    end

    CPUSTATE_IDX_16OFF_DONTCARE2:
    begin
        addr_nxt       =  16'HFFFF;
        if (IndexedRegister == IDX_REG_PC)
        begin
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_IDX_PC16OFF_DONTCARE;
        end
        else        
        begin
            rAVMA = 1'b0;
            CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE3;
        end
    end
    
    CPUSTATE_IDX_PC16OFF_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt   =  CPUSTATE_IDX_16OFF_DONTCARE3;
    end
    
    
    CPUSTATE_IDX_16OFF_DONTCARE3:
    begin
        addr_nxt       =  16'HFFFF;
        if (IndexedIndirect)
        begin
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_INDIRECT_HI;
        end
        else
        begin
            if (IsJMP(Inst1))
            begin
                pc_nxt =  ea;
                rLIC = 1'b1; // Instruction done!                
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_FETCH_I1;
            end
            else
            begin
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_ALU_EA;        
            end
        end
    end

    CPUSTATE_IDX_DOFF_DONTCARE1:
    begin
        addr_nxt = pc_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IDX_DOFF_DONTCARE2;
    end

    CPUSTATE_IDX_DOFF_DONTCARE2:
    begin
        addr_nxt = pc_p2;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_IDX_16OFF_DONTCARE2;
    end

    CPUSTATE_IDX_DOFF_DONTCARE3:
    begin
        addr_nxt = pc_p3;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IDX_DOFF_DONTCARE2;
    end

    CPUSTATE_IDX_EXTIND_LO:
    begin
        ea_nxt[7:0]   =  D[7:0];
        addr_nxt       =  pc;
        pc_nxt =  pc_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IDX_EXTIND_DONTCARE;        
    end
    
    CPUSTATE_IDX_EXTIND_DONTCARE:
    begin
        addr_nxt = pc;
        if (IndexedIndirect)
        begin
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_INDIRECT_HI;
        end
        else
        begin
            if (IsJMP(Inst1))
            begin
                pc_nxt =  ea;
                rLIC = 1'b1; // Instruction done!                
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_FETCH_I1;
            end
            else
            begin
                rAVMA = 1'b1;
                CpuState_nxt   =  CPUSTATE_ALU_EA;        
            end
        end
    end
    
    CPUSTATE_INDIRECT_HI:
    begin
        addr_nxt = ea;
        tmp_nxt[15:8] = D[7:0];
        rAVMA = 1'b1;
        rBUSY = 1'b1;
        CpuState_nxt = CPUSTATE_INDIRECT_LO;
    end                        

    CPUSTATE_INDIRECT_LO:
    begin
        addr_nxt = ea_p1;
        ea_nxt[15:8] = tmp_nxt[15:8];
        ea_nxt[7:0] = D[7:0];
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_INDIRECT_DONTCARE;
    end
 
    CPUSTATE_INDIRECT_DONTCARE:
    begin
        addr_nxt = 16'HFFFF;
        if (IsJMP(Inst1))
        begin
            pc_nxt =  ea;
            rLIC = 1'b1; // Instruction done!            
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end
        else
        begin
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_ALU_EA;
        end
    end
    
    CPUSTATE_MUL_ACTION:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        // tmp = result
        // ea = additor (the shifted multiplicand)
        // a = counter
        // b is the multiplier (which gets shifted right)
        if (a != 8'H00)
        begin
            if (b[0])
            begin
                tmp_nxt = tmp + ea;
            end
            ea_nxt = {ea[14:0], 1'b0};
            b_nxt = {1'b0, b[7:1]};
            a_nxt = a - 8'H1;
        end
        else
        begin
            {a_nxt, b_nxt} = tmp;
            
            cc_nxt[CC_Z_BIT] = (tmp == 0);
            cc_nxt[CC_C_BIT] = tmp[7];
            rLIC = 1'b1; // Instruction done!            
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end
    end
    
    CPUSTATE_PSH_DONTCARE1:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_PSH_DONTCARE2;
    end

    CPUSTATE_PSH_DONTCARE2:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_DONTCARE3;
    end
    
    CPUSTATE_PSH_DONTCARE3:
    begin
        addr_nxt = (Inst1[1]) ? u : s;
        
        CpuState_nxt = CPUSTATE_PSH_ACTION;
    end    

    CPUSTATE_PSH_ACTION:
    begin
        rAVMA = 1'b1;
        if (tmp[7] & ~(tmp[15]))                    // PC_LO
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = pc[7:0];
            RnWOut = 1'b0; // write
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[7] & (tmp[15]))                    // PC_HI
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = pc[15:8];
            RnWOut = 1'b0; // write
            tmp_nxt[7] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else if (tmp[6] & ~(tmp[15]))                    // U/S_LO
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = (tmp[14]) ? s[7:0] : u[7:0]; 
            RnWOut = 1'b0; // write
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[6] & (tmp[15]))                    // U/S_HI
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = (tmp[14]) ? s[15:8] : u[15:8]; 
            RnWOut = 1'b0; // write
            tmp_nxt[6] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else if (tmp[5] & ~(tmp[15]))                    // Y_LO
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = y[7:0];
            RnWOut = 1'b0; // write
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[5] & (tmp[15]))                    // Y_HI
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = y[15:8];
            RnWOut = 1'b0; // write
            tmp_nxt[5] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end        
        else if (tmp[4] & ~(tmp[15]))                    // X_LO
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = x[7:0];
            RnWOut = 1'b0; // write
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[4] & (tmp[15]))                    // X_HI
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = x[15:8];
            RnWOut = 1'b0; // write
            tmp_nxt[4] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else if (tmp[3])                    // DP
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = dp;
            RnWOut = 1'b0; // write
            tmp_nxt[3] = 1'b0;        
        end
        else if (tmp[2])                    // B
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = b;
            RnWOut = 1'b0; // write
            tmp_nxt[2] = 1'b0;        
        end
        else if (tmp[1])                    // A
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = a;
            RnWOut = 1'b0; // write
            tmp_nxt[1] = 1'b0;        
        end
        else if (tmp[0])                    // CC
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14])
                u_nxt = u_m1;
            else
                s_nxt = s_m1;
            DOutput = cc;
            RnWOut = 1'b0; // write
            tmp_nxt[0] = 1'b0;        
        end
        if (tmp[13]) // Then we're pushing for an IRQ, and LIC is supposed to be set.
            rLIC = 1'b1;
        if (tmp_nxt[7:0] == 8'H00)
        begin
            if (NextState == CPUSTATE_FETCH_I1)
            begin
                rAVMA = 1'b1;
                rLIC = 1'b1;
            end
            else
                rAVMA = 1'b0;
            CpuState_nxt  = NextState;
        end                                           
    end
    
    CPUSTATE_PUL_DONTCARE1:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_PUL_DONTCARE2;
    end

    CPUSTATE_PUL_DONTCARE2:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PUL_ACTION;
    end    

    CPUSTATE_PUL_ACTION:
    begin
        rAVMA = 1'b1;
        if (tmp[0])                    // CC
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            cc_nxt = D[7:0];
            if (tmp[12] == 1'b1) // This pull is from an RTI, the E flag comes from the retrieved CC, and set the tmp_nxt accordingly, indicating what other registers to retrieve
            begin
                if (D[CC_E_BIT])
                    tmp_nxt[7:0] = 8'HFE;     // Retrieve all registers (ENTIRE) [CC is already retrieved]
                else
                    tmp_nxt[7:0] = 8'H80;     // Retrieve PC and CC [CC is already retrieved]
            end
            else
                tmp_nxt[0] = 1'b0;
        end 
        else if (tmp[1])                    // A
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            a_nxt = D[7:0];
            tmp_nxt[1] = 1'b0;
        end         
        else if (tmp[2])                    // B
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            b_nxt = D[7:0];
            tmp_nxt[2] = 1'b0;
        end 
        else if (tmp[3])                    // DP
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            dp_nxt = D[7:0];
            tmp_nxt[3] = 1'b0;
        end        
        else if (tmp[4] & (~tmp[15]))                    // X_HI
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            x_nxt[15:8] = D[7:0];
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[4] & tmp[15])                    // X_LO
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            x_nxt[7:0] = D[7:0];
            tmp_nxt[4] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else if (tmp[5] & (~tmp[15]))                    // Y_HI
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            y_nxt[15:8] = D[7:0];
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[5] & tmp[15])                    // Y_LO
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            y_nxt[7:0] = D[7:0];
            tmp_nxt[5] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else if (tmp[6] & (~tmp[15]))                    // U/S_HI
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            if (tmp[14])
                s_nxt[15:8] = D[7:0];
            else
                u_nxt[15:8] = D[7:0];
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[6] & tmp[15])                    // U/S_LO
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            if (tmp[14])
                s_nxt[7:0] = D[7:0];
            else
                u_nxt[7:0] = D[7:0];
            tmp_nxt[6] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else if (tmp[7] & (~tmp[15]))                    // PC_HI
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            pc_nxt[15:8] = D[7:0];
            tmp_nxt[15] = 1'b1;            
        end
        else if (tmp[7] & tmp[15])                    // PC_LO
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14])
                u_nxt = u_p1;
            else
                s_nxt = s_p1;
            pc_nxt[7:0] = D[7:0];
            tmp_nxt[7] = 1'b0;
            tmp_nxt[15] = 1'b0;            
        end
        else
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (NextState == CPUSTATE_FETCH_I1)
            begin
                rAVMA = 1'b1;
                rLIC = 1'b1;
            end
            else
                rAVMA = 1'b0;
            CpuState_nxt  = NextState;
        end  
    end
                                      
    CPUSTATE_NMI_START:
    begin
        NMIClear_nxt = 1'b1;
        addr_nxt = pc;
        // tmp stands as the bits to push to the stack
        tmp_nxt = 16'H20FF; // Save to the S stack, PC, U, Y, X, DP, B, A, CC; set LIC on every push 
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        IntType_nxt = INTTYPE_NMI;
        cc_nxt[CC_E_BIT] = 1'b1;
    end
    
    CPUSTATE_IRQ_START:
    begin
        addr_nxt = pc;
        tmp_nxt = 16'H20FF; // Save to the S stack, PC, U, Y, X, DP, B, A, CC; set LIC on every push 
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        IntType_nxt = INTTYPE_IRQ;        
        cc_nxt[CC_E_BIT] = 1'b1;
    end

    CPUSTATE_FIRQ_START:
    begin
        addr_nxt = pc;
        tmp_nxt = 16'H2081; // Save to the S stack, PC, CC; set LIC on every push 
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        IntType_nxt = INTTYPE_FIRQ;        
        cc_nxt[CC_E_BIT] = 1'b0;
    end
    
    CPUSTATE_SWI_START:
    begin
        addr_nxt = pc;
        tmp_nxt = 16'H00FF; // Save to the S stack, PC, U, Y, X, DP, B, A, CC

        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        if (InstPage3)
            IntType_nxt = INTTYPE_SWI3;
        if (InstPage2)
            IntType_nxt = INTTYPE_SWI2;
        else
            IntType_nxt = INTTYPE_SWI;        
            
        cc_nxt[CC_E_BIT] = 1'b1;
    end
    
    CPUSTATE_IRQ_DONTCARE:
    begin
        NMIClear_nxt = 1'b0;    
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_ACTION;
    end
    
    
    CPUSTATE_IRQ_DONTCARE2:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_VECTOR_HI;
        rLIC = 1'b1;
    end
    
    CPUSTATE_IRQ_VECTOR_HI:
    begin
        case (IntType)
            INTTYPE_NMI:
            begin
                addr_nxt = `NMI_VECTOR;
                BS_nxt         =  1'b1; // ACK Interrupt
            end
            INTTYPE_IRQ:
            begin
                addr_nxt = `IRQ_VECTOR;
                BS_nxt         =  1'b1; // ACK Interrupt
            end
            INTTYPE_SWI:
            begin
                addr_nxt = `SWI_VECTOR;
            end
            INTTYPE_FIRQ:
            begin
                addr_nxt = `FIRQ_VECTOR;
                BS_nxt         =  1'b1; // ACK Interrupt
            end
            INTTYPE_SWI2:
            begin
                addr_nxt = `SWI2_VECTOR;
            end
            INTTYPE_SWI3:
            begin
                addr_nxt = `SWI3_VECTOR;
            end
            default: // make the default an IRQ, even though it really should never happen 
            begin
                addr_nxt = `IRQ_VECTOR;
                BS_nxt         =  1'b1; // ACK Interrupt
            end
        endcase
        
        pc_nxt[15:8] = D[7:0];
        rAVMA = 1'b1;
        rBUSY = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_VECTOR_LO;
        
        
    end
    
    CPUSTATE_IRQ_VECTOR_LO:
    begin
        case (IntType)
            INTTYPE_NMI:
            begin
                addr_nxt = `NMI_VECTOR+16'H1;
                cc_nxt[CC_I_BIT] = 1'b1;
                cc_nxt[CC_F_BIT] = 1'b1;
                BS_nxt         =  1'b1; // ACK Interrupt
            end                
            INTTYPE_IRQ:
            begin
                addr_nxt = `IRQ_VECTOR+16'H1;
                cc_nxt[CC_I_BIT] = 1'b1;                
                BS_nxt         =  1'b1; // ACK Interrupt
            end  
            INTTYPE_SWI:
            begin
                addr_nxt = `SWI_VECTOR+16'H1;
                cc_nxt[CC_F_BIT] = 1'b1;
                cc_nxt[CC_I_BIT] = 1'b1;
                rLIC = 1'b1;
            end                  
            INTTYPE_FIRQ:
            begin
                addr_nxt = `FIRQ_VECTOR+16'H1;
                cc_nxt[CC_F_BIT] = 1'b1;                                
                cc_nxt[CC_I_BIT] = 1'b1;
                BS_nxt         =  1'b1; // ACK Interrupt
            end                  
            INTTYPE_SWI2:
            begin
                addr_nxt = `SWI2_VECTOR+16'H1;
                rLIC = 1'b1;                
            end                  
            INTTYPE_SWI3:
            begin
                addr_nxt = `SWI3_VECTOR+16'H1;
                rLIC = 1'b1;
            end                
            default:
            begin
            end
        endcase
    
        pc_nxt[7:0] = D[7:0];
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_INT_DONTCARE;
    end
    
    CPUSTATE_INT_DONTCARE:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_CC_DONTCARE:
    begin
        addr_nxt = pc;
        rLIC = 1'b1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_TST_DONTCARE1:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_TST_DONTCARE2;
    end

    CPUSTATE_TST_DONTCARE2:
    begin
        addr_nxt = 16'HFFFF;
        rLIC = 1'b1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_DEBUG:
    begin
        addr_nxt = tmp;
        rLIC = 1'b1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_16IMM_DONTCARE:
    begin
        addr_nxt = 16'HFFFF;
        rLIC = 1'b1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_SYNC:
    begin
        addr_nxt = 16'HFFFF;
        BA_nxt = 1'b1;
        rLIC   = 1'b1;
        rAVMA  = 1'b0;

        if (~(NMILatched & FIRQLatched & IRQLatched))
        begin
            CpuState_nxt = CPUSTATE_SYNC_EXIT;
        end
    end

    CPUSTATE_SYNC_EXIT:
    begin
        addr_nxt = 16'HFFFF;
        BA_nxt = 1'b1;
        rLIC   = 1'b1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end


    CPUSTATE_DMABREQ:
    begin
        rAVMA = 1'b0;
        addr_nxt = 16'HFFFF;
        BS_nxt = 1'b1;
        BA_nxt = 1'b1;
        rLIC   = 1'b1;
        tmp_nxt[3:0] = tmp[3:0] - 1'b1;
        if ( (tmp[3:0] == 4'H0) | (DMABREQSample2) )
        begin
            CpuState_nxt = CPUSTATE_DMABREQ_EXIT;
        end
    end
    
    CPUSTATE_DMABREQ_EXIT:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end
    
    CPUSTATE_HALTED:
    begin
        rAVMA = 1'b0;
        addr_nxt = 16'HFFFF;
        BS_nxt = 1'b1;
        BA_nxt = 1'b1;
        rLIC   = 1'b1;
        if (HALTSample2)
        begin
            CpuState_nxt = CPUSTATE_HALT_EXIT2;
        end
    end


    CPUSTATE_HALT_EXIT2:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_STOP:
    begin
        addr_nxt = 16'HDEAD;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_STOP2;
    end

    CPUSTATE_STOP2:
    begin
        addr_nxt = pc;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_STOP3;
    end

    CPUSTATE_STOP3:
    begin
        addr_nxt = 16'H0000; //{Inst1, Inst2};
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_STOP;
    end

    // The otherwise critically useful Figure 18 in the 6809 datasheet contains an error;
    // it lists that CWAI has a tri-stated bus while it waits for an interrupt.
    // That is not true.  SYNC tristates the bus, as do things like /HALT and /DMABREQ.
    // CWAI does not.  It waits with /VMA cycles on the bus until an interrupt occurs.
    // The implementation here fits with the 6809 Programming Manual and other Motorola
    // sources, not with that typo in Figure 18.
    CPUSTATE_CWAI:
    begin
        addr_nxt = pc;
        cc_nxt = {1'b1, (cc[6:0] & Inst2[6:0])}; // Set E flag, AND CC with CWAI argument
        tmp_nxt = 16'H00FF; // Save to the S stack, PC, U, Y, X, DP, B, A, CC

        NextState_nxt = CPUSTATE_CWAI_POST;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_CWAI_DONTCARE1;
    end
    
    CPUSTATE_CWAI_DONTCARE1:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_ACTION;
    end
    
    CPUSTATE_CWAI_POST:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;

        CpuState_nxt = CPUSTATE_CWAI_POST;

        // Wait for an interrupt
        if (NMILatched == 0)
        begin
            rAVMA = 1'b1;
            IntType_nxt = INTTYPE_NMI;
            cc_nxt[CC_F_BIT] = 1'b1;
            cc_nxt[CC_I_BIT] = 1'b1;
            CpuState_nxt = CPUSTATE_IRQ_VECTOR_HI;
        end
        else if ((FIRQLatched == 0) && (cc[CC_F_BIT] == 0))
        begin
            rAVMA = 1'b1;
            cc_nxt[CC_F_BIT] = 1'b1;
            cc_nxt[CC_I_BIT] = 1'b1;
            IntType_nxt = INTTYPE_FIRQ;
            CpuState_nxt = CPUSTATE_IRQ_VECTOR_HI;
        end
        else if ((IRQLatched == 0) && (cc[CC_I_BIT] == 0))
        begin
            rAVMA = 1'b1;
            cc_nxt[CC_I_BIT] = 1'b1;
            IntType_nxt = INTTYPE_IRQ;
            CpuState_nxt = CPUSTATE_IRQ_VECTOR_HI;
        end
    end

    default: // Picky darned Verilog.
    begin
        CpuState_nxt = PostIllegalState;
    end
    
    endcase
end

endmodule

