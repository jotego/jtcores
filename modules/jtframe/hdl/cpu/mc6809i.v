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

/* verilator lint_off CASEX */
/* verilator lint_off UNOPTFLAT */
/* verilator lint_off SIDEEFFECT */
/* verilator tracing_off */

module mc6809i
#(
    parameter ILLEGAL_INSTRUCTIONS="GHOST",
    parameter HD6309=0
)
(

    input   [7:0]  D,
    output  [7:0]  DOut,
    output  [15:0] ADDR,
    output  RnW,
    input   clk,
    (*direct_enable*) input   cen_E,
    (*direct_enable*) input   cen_Q,
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
    output reg OP,  // high when accessing an OP code
    output  [111:0] RegData,
    output  [55:0]  RegData6309
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
`ifdef VERILATOR_KEEP_CPU
/* verilator tracing_on */
`endif
reg     [7:0]           a;
reg     [7:0]           b;
reg     [15:0]          x;
reg     [15:0]          y;
reg     [15:0]          u;
reg     [15:0]          s;
reg     [15:0]          pc;
reg     [7:0]           dp;
reg     [7:0]           cc;
reg     [7:0]           e;
reg     [7:0]           f;
reg     [15:0]          v;
reg     [7:0]           md;
wire    [15:0]          w;
/* verilator tracing_off */
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
assign  RegData6309 = HD6309 ? {md,v,w,f,e} : 56'd0;
assign  w = {e,f};



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
reg     [7:0]           e_nxt;
reg     [7:0]           f_nxt;
reg     [15:0]          v_nxt;
reg     [7:0]           md_nxt;
reg     [15:0]          addr_nxt;
reg     [15:0]          ea_nxt;
reg     [15:0]          tmp_nxt;
reg                     s_wr;       // signal a write to S register (JT addition)

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
`ifdef VERILATOR_KEEP_CPU
/* verilator tracing_on */ `endif
reg     NMIMask;
/* verilator tracing_off */
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
localparam INTTYPE_HD_ILLEGAL = 3'H6;
localparam INTTYPE_HD_DIVZERO = 3'H7;

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


localparam CPUSTATE_RESET      =  8'd0;
localparam CPUSTATE_RESET0     =  8'd1;

localparam CPUSTATE_RESET2     =  8'd3;
localparam CPUSTATE_FETCH_I1   =  8'd4;
localparam CPUSTATE_FETCH_I1V2 =  8'd5;
localparam CPUSTATE_FETCH_I2   =  8'd8;

localparam CPUSTATE_LBRA_OFFSETLOW =  8'd17;
localparam CPUSTATE_LBRA_DONTCARE  =  8'd18;
localparam CPUSTATE_LBRA_DONTCARE2 =  8'd19;



localparam CPUSTATE_BRA_DONTCARE   =  8'd20;

localparam CPUSTATE_BSR_DONTCARE1  =  8'd21;
localparam CPUSTATE_BSR_DONTCARE2  =  8'd22;
localparam CPUSTATE_BSR_RETURNLOW  =  8'd23;
localparam CPUSTATE_BSR_RETURNHIGH =  8'd24;

localparam CPUSTATE_TFR_DONTCARE1  =  8'd26;
localparam CPUSTATE_TFR_DONTCARE2  =  8'd27;
localparam CPUSTATE_TFR_DONTCARE3  =  8'd28;
localparam CPUSTATE_TFR_DONTCARE4  =  8'd29;

localparam CPUSTATE_EXG_DONTCARE1      =    8'd30;
localparam CPUSTATE_EXG_DONTCARE2      =    8'd31;
localparam CPUSTATE_EXG_DONTCARE3      =    8'd32;
localparam CPUSTATE_EXG_DONTCARE4      =    8'd33;
localparam CPUSTATE_EXG_DONTCARE5      =    8'd34;
localparam CPUSTATE_EXG_DONTCARE6      =    8'd35;

localparam CPUSTATE_ABX_DONTCARE       =    8'd36;

localparam  CPUSTATE_RTS_HI            =    8'd38;
localparam  CPUSTATE_RTS_LO            =    8'd39;
localparam  CPUSTATE_RTS_DONTCARE2     =    8'd40;

localparam  CPUSTATE_16IMM_LO          =    8'd41;
localparam CPUSTATE_ALU16_DONTCARE     =    8'd42;
localparam CPUSTATE_DIRECT_DONTCARE    =    8'd43;

localparam CPUSTATE_ALU_EA             =    8'd44;

localparam CPUSTATE_ALU_DONTCARE       =    8'd46;
localparam CPUSTATE_ALU_WRITEBACK      =    8'd47;

localparam CPUSTATE_LD16_LO            =    8'd48;

localparam CPUSTATE_ST16_LO            =    8'd49;
localparam CPUSTATE_ALU16_LO           =    8'd50;




localparam CPUSTATE_JSR_DONTCARE       =    8'd53;
localparam CPUSTATE_JSR_RETLO          =    8'd54;
localparam CPUSTATE_JSR_RETHI          =    8'd55;
localparam CPUSTATE_EXTENDED_ADDRLO    =    8'd56;
localparam CPUSTATE_EXTENDED_DONTCARE  =    8'd57;
localparam CPUSTATE_INDEXED_BASE       =    8'd58;


localparam CPUSTATE_IDX_DONTCARE3      =    8'd60;

localparam CPUSTATE_IDX_OFFSET_LO      =    8'd61;
localparam CPUSTATE_IDX_16OFFSET_LO    =    8'd62;

localparam CPUSTATE_IDX_16OFF_DONTCARE0=    8'd63;
localparam CPUSTATE_IDX_16OFF_DONTCARE1=    8'd64;
localparam CPUSTATE_IDX_16OFF_DONTCARE2=    8'd65;
localparam CPUSTATE_IDX_16OFF_DONTCARE3=    8'd66;

localparam CPUSTATE_IDX_DOFF_DONTCARE1 =    8'd68;
localparam CPUSTATE_IDX_DOFF_DONTCARE2 =    8'd69;
localparam CPUSTATE_IDX_DOFF_DONTCARE3 =    8'd70;
localparam CPUSTATE_IDX_PC16OFF_DONTCARE =  8'd71;

localparam CPUSTATE_IDX_EXTIND_LO =         8'd72;
localparam CPUSTATE_IDX_EXTIND_DONTCARE =   8'd73;

localparam CPUSTATE_INDIRECT_HI         =   8'd74;
localparam CPUSTATE_INDIRECT_LO         =   8'd75;
localparam CPUSTATE_INDIRECT_DONTCARE   =   8'd76;
localparam CPUSTATE_MUL_ACTION          =   8'd77;

localparam CPUSTATE_PSH_DONTCARE1       =   8'd80;
localparam CPUSTATE_PSH_DONTCARE2       =   8'd81;
localparam CPUSTATE_PSH_DONTCARE3       =   8'd82;
localparam CPUSTATE_PSH_ACTION          =   8'd83;

localparam CPUSTATE_PUL_DONTCARE1       =   8'd84;
localparam CPUSTATE_PUL_DONTCARE2       =   8'd85;
localparam CPUSTATE_PUL_ACTION          =   8'd86;

localparam CPUSTATE_NMI_START           =   8'd87;
localparam CPUSTATE_IRQ_DONTCARE        =   8'd88;
localparam CPUSTATE_IRQ_START           =   8'd89;
localparam CPUSTATE_IRQ_DONTCARE2       =   8'd90;
localparam CPUSTATE_IRQ_VECTOR_HI       =   8'd91;
localparam CPUSTATE_IRQ_VECTOR_LO       =   8'd92;
localparam CPUSTATE_FIRQ_START          =   8'd93;
localparam CPUSTATE_CC_DONTCARE         =   8'd94;
localparam CPUSTATE_SWI_START           =   8'd95;

localparam CPUSTATE_TST_DONTCARE1       =   8'd96;
localparam CPUSTATE_TST_DONTCARE2       =   8'd97;

localparam CPUSTATE_DEBUG               =   8'd98;

localparam CPUSTATE_16IMM_DONTCARE      =   8'd99;
localparam CPUSTATE_MD_DONTCARE1        =   8'd122;
localparam CPUSTATE_MD_DONTCARE2        =   8'd123;
localparam CPUSTATE_6309_RR_WAIT        =   8'd124;
localparam CPUSTATE_Q_IMM2              =   8'd128;
localparam CPUSTATE_Q_IMM3              =   8'd129;
localparam CPUSTATE_Q_IMM4              =   8'd130;
localparam CPUSTATE_6309_WPUL_FINISH    =   8'd131;
localparam CPUSTATE_6309_QLOAD2         =   8'd132;
localparam CPUSTATE_6309_QLOAD3         =   8'd133;
localparam CPUSTATE_6309_QLOAD4         =   8'd134;
localparam CPUSTATE_6309_QSTORE2        =   8'd135;
localparam CPUSTATE_6309_QSTORE3        =   8'd136;
localparam CPUSTATE_6309_QSTORE4        =   8'd137;
localparam CPUSTATE_6309_SEXW_WAIT1     =   8'd138;
localparam CPUSTATE_6309_SEXW_WAIT2     =   8'd139;
localparam CPUSTATE_6309_BIT_ADDR       =   8'd141;
localparam CPUSTATE_6309_BIT_READ       =   8'd142;
localparam CPUSTATE_6309_BIT_WRITE      =   8'd143;
localparam CPUSTATE_6309_BIT_WAIT1      =   8'd144;
localparam CPUSTATE_6309_BIT_WAIT2      =   8'd145;
localparam CPUSTATE_6309_TFM_READ       =   8'd146;
localparam CPUSTATE_6309_TFM_WRITE      =   8'd147;
localparam CPUSTATE_6309_TFM_UPDATE     =   8'd148;
localparam CPUSTATE_6309_TFM_FINAL1     =   8'd149;
localparam CPUSTATE_6309_TFM_FINAL2     =   8'd150;
localparam CPUSTATE_6309_TFM_FINAL3     =   8'd151;
localparam CPUSTATE_6309_ARITH_IMM_LO   =   8'd152;
localparam CPUSTATE_6309_ARITH_MEM_LO   =   8'd153;
localparam CPUSTATE_6309_ARITH_EXEC     =   8'd154;
localparam CPUSTATE_6309_ARITH_WAIT     =   8'd155;
localparam CPUSTATE_6309_TRAP_START     =   8'd156;
localparam CPUSTATE_6309_IMM_DIRECT_ADDR=   8'd157;
localparam CPUSTATE_6309_IMM_INDEX_POST =   8'd158;
localparam CPUSTATE_6309_IMM_EXT_HI     =   8'd159;
localparam CPUSTATE_6309_IMM_EXT_LO     =   8'd160;
localparam CPUSTATE_6309_IMM_EXEC       =   8'd161;
localparam CPUSTATE_6309_IMM_WRITE      =   8'd162;
localparam CPUSTATE_6309_WOFF_LO        =   8'd163;
localparam CPUSTATE_6309_CWAI_PAD5      =   8'd164;
localparam CPUSTATE_6309_CWAI_PAD6      =   8'd165;
localparam CPUSTATE_6309_DIVZERO_PAD1   =   8'd166;
localparam CPUSTATE_6309_DIVZERO_PAD2   =   8'd167;
localparam CPUSTATE_6309_DIVZERO_START  =   8'd168;

localparam CPUSTATE_HALTED              =  8'd100;

localparam CPUSTATE_HALT_EXIT2          =  8'd102;
localparam CPUSTATE_STOP                =  8'd105;
localparam CPUSTATE_STOP2               =  8'd106;
localparam CPUSTATE_STOP3               =  8'd107;


localparam CPUSTATE_CWAI                =  8'd108;
localparam CPUSTATE_CWAI_DONTCARE1      =  8'd109;
localparam CPUSTATE_CWAI_POST           =  8'd110;

localparam CPUSTATE_DMABREQ             =  8'd111;
localparam CPUSTATE_DMABREQ_EXIT        =  8'd112;
localparam CPUSTATE_SYNC                =  8'd113;
localparam CPUSTATE_SYNC_EXIT           =  8'd114;

localparam CPUSTATE_INT_DONTCARE        =  8'd115;
localparam CPUSTATE_CWAI_PAD1           =  8'd116;
localparam CPUSTATE_CWAI_PAD2           =  8'd117;
localparam CPUSTATE_CWAI_PAD3           =  8'd118;
localparam CPUSTATE_CWAI_PAD4           =  8'd119;
localparam CPUSTATE_SYNC_PAD1           =  8'd120;
localparam CPUSTATE_SYNC_PAD2           =  8'd121;


reg     [7:0]    CpuState = CPUSTATE_RESET;
reg     [7:0]    CpuState_nxt = CPUSTATE_RESET;
reg              HDArithStarted;
reg              HDArithComplete;
wire             HDArithDone;

reg     [7:0]    NextState = CPUSTATE_RESET;
reg     [7:0]    NextState_nxt = CPUSTATE_RESET;

`ifdef SIMULATION
wire alu_busy = CpuState==CPUSTATE_MUL_ACTION;
wire stack_busy = CpuState==CPUSTATE_PUL_ACTION || CpuState==CPUSTATE_PSH_ACTION;
`endif

wire    [7:0]    PostIllegalState;

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

always @(posedge clk, negedge nRESET) begin
    if( !nRESET ) begin
        OP <= 0;
    end else if(cen_E) begin
        OP <= CpuState_nxt==CPUSTATE_FETCH_I1 ||
              CpuState_nxt==CPUSTATE_FETCH_I1V2;
    end
end

// The 6309 arithmetic helper iterates at the system clock, independently of
// the E-cycle sequencer. Latch its sticky completion so the CPU can consume
// the result at the next enabled E edge.
always @(posedge clk, negedge nRESET) begin
    if (!nRESET) begin
        HDArithStarted  <= 1'b0;
        HDArithComplete <= 1'b0;
    end else begin
        if (CpuState == CPUSTATE_6309_ARITH_EXEC && !HDArithStarted)
            HDArithStarted <= 1'b1;
        if (HDArithDone && HDArithStarted)
            HDArithComplete <= 1'b1;
        if (cen_E && CpuState == CPUSTATE_6309_ARITH_WAIT &&
            CpuState_nxt != CPUSTATE_6309_ARITH_WAIT) begin
            HDArithStarted  <= 1'b0;
            HDArithComplete <= 1'b0;
        end
    end
end

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

function IsHD6309MemImmediate(input [7:0] i);
reg low_valid;
begin
    low_valid = (i[3:0] == 4'h1) || (i[3:0] == 4'h2) ||
                (i[3:0] == 4'h5) || (i[3:0] == 4'hb);
    IsHD6309MemImmediate = HD6309 && !InstPage2 && !InstPage3 && low_valid &&
                           ((i[7:4] == 4'h0) || (i[7:4] == 4'h6) ||
                            (i[7:4] == 4'h7));
end
endfunction

function IsHD6309MemImmediateOpcode(input [7:0] i);
begin
    IsHD6309MemImmediateOpcode = HD6309 &&
                                 ((i[3:0] == 4'h1) || (i[3:0] == 4'h2) ||
                                  (i[3:0] == 4'h5) || (i[3:0] == 4'hb)) &&
                                 ((i[7:4] == 4'h0) || (i[7:4] == 4'h6) ||
                                  (i[7:4] == 4'h7));
end
endfunction


wire [7:0] MappedInstruction;
generate
if (ILLEGAL_INSTRUCTIONS=="GHOST")
begin : ghost
    // HD6309 reserved encodings must reach the HD illegal-instruction trap;
    // the legacy 6809 ghost map aliases some of them to legal opcodes.
    assign MappedInstruction = HD6309 ? D : MapInstruction(D);
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

function IsHD6309Page2Known(input [7:0] i);
reg good;
begin
    good = 1'b0;
    if ((i >= 8'h21) && (i <= 8'h2f)) good = 1'b1;
    else if (((i >= 8'h30) && (i <= 8'h3b)) || (i == 8'h3f)) good = 1'b1;
    else if ((i == 8'h40) || (i == 8'h43) || (i == 8'h44) ||
             ((i >= 8'h46) && (i <= 8'h4a)) ||
             (i == 8'h4c) || (i == 8'h4d) || (i == 8'h4f) ||
             (i == 8'h50) || (i == 8'h53) || (i == 8'h54) ||
             ((i >= 8'h56) && (i <= 8'h5a)) ||
             (i == 8'h5c) || (i == 8'h5d) || (i == 8'h5f)) good = 1'b1;
    else if ((i >= 8'h80) && (i <= 8'hbf)) begin
        case (i[7:4])
            4'h8: good = (i[3:0] == 4'h0) || (i[3:0] == 4'h1) ||
                         (i[3:0] == 4'h2) || (i[3:0] == 4'h3) ||
                         (i[3:0] == 4'h4) || (i[3:0] == 4'h5) ||
                         (i[3:0] == 4'h6) || (i[3:0] == 4'h8) ||
                         (i[3:0] == 4'h9) || (i[3:0] == 4'ha) ||
                         (i[3:0] == 4'hb) || (i[3:0] == 4'hc) ||
                         (i[3:0] == 4'he);
            4'h9,4'ha,4'hb:
                good = (i[3:0] <= 4'hc) || (i[3:0] == 4'he) || (i[3:0] == 4'hf);
            default: good = 1'b0;
        endcase
    end else begin
        case (i)
            8'hce, 8'hdc, 8'hdd, 8'hde, 8'hdf,
            8'hec, 8'hed, 8'hee, 8'hef,
            8'hfc, 8'hfd, 8'hfe, 8'hff: good = 1'b1;
            default: good = 1'b0;
        endcase
    end
    IsHD6309Page2Known = good;
end
endfunction

wire IsIllegalInstruction;
wire IsHD6309TrapOpcode;
/* verilator lint_off WIDTH */
generate
if (ILLEGAL_INSTRUCTIONS=="GHOST")
begin : never_illegal
    assign IsIllegalInstruction = HD6309 &&
                                  (IsHD6309TrapOpcode ||
                                   (!InstPage3 && !InstPage2 && (Inst1 != 8'hcd) && (Inst1 != 8'h14) &&
                                    !IsHD6309MemImmediate(Inst1) &&
                                    IllegalInstruction(Inst1)));
end
else
begin
    assign IsIllegalInstruction = IsHD6309TrapOpcode ? 1'b1 : ((HD6309 &&
                                   ((!InstPage2 && !InstPage3 &&
                                     ((Inst1 == 8'h14) || (Inst1 == 8'hcd) ||
                                      IsHD6309MemImmediate(Inst1))) ||
                                    (InstPage2 && IsHD6309Page2Known(Inst1)) ||
                                    (InstPage3 && !IsHD6309TrapOpcode))) ? 1'b0 :
                                  IllegalInstruction(Inst1));
end
endgenerate

wire [7:0] IllegalInstructionState;
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
    assign IllegalInstructionState = 8'd0;
end
endgenerate
/* verilator lint_on WIDTH */

///////////////////////////////////////////////////////////////////////


// NMI edges after reset are retained until S is initialized (Motorola programming manual).
// NMIMask blocks recognition, not edge capture.
reg last_NMISample2, last_wNMIClear, NMIPend;

always @(posedge clk, negedge nRESET) begin
    if( !nRESET ) begin
        last_NMISample2 <= 1;
        last_wNMIClear  <= 1;
        NMILatched      <= 1;
        NMIPend         <= 0;
    end else if(cen_Q) begin : NMIlatch
        last_NMISample2 <= NMISample2;
        last_wNMIClear  <= wNMIClear;
        if( (!NMISample2 && last_NMISample2) ||
            (wNMIClear && !last_wNMIClear) ) begin
            if (wNMIClear == 1)
                NMILatched <= 1;
            else if (NMIMask == 0)
                NMILatched <= 0;
            else begin
                NMILatched <= 1;
                NMIPend    <= 1;
            end
        end else if (NMIPend && !NMIMask) begin
            NMILatched <= 0;
            NMIPend    <= 0;
        end
    end
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
always @(posedge clk, negedge nRESET) begin
    if(!nRESET) begin
        NMISample     <= 1;
        IRQSample     <= 1;
        FIRQSample    <= 1;
        HALTSample    <= 1;
        DMABREQSample <= 1;
    end else if(cen_Q) begin
        NMISample     <= nNMI;
        IRQSample     <= nIRQ;
        FIRQSample    <= nFIRQ;
        HALTSample    <= nHALT;
        DMABREQSample <= nDMABREQ;
    end
end


always @(posedge clk, negedge nRESET) begin
    if (!nRESET) begin
        CpuState <= CPUSTATE_RESET;
        NMIMask <= 1'b1; // Mask NMI until S is loaded.
        NMIClear <= 1'b0; // Mark us as not having serviced NMI

        NMISample2  <= 1;
        IRQSample2  <= 1;
        IRQLatched  <= 1;
        FIRQSample2 <= 1;
        FIRQLatched <= 1;
        HALTSample2 <= 1;
        HALTLatched <= 1;
    end else if(cen_E) begin
        CpuState <= CpuState_nxt;

        NMISample2 <= NMISample;

        IRQSample2 <= IRQSample;
        IRQLatched <= IRQSample2;

        FIRQSample2 <= FIRQSample;
        FIRQLatched <= FIRQSample2;

        HALTSample2 <= HALTSample;
        HALTLatched <= HALTSample2;

        DMABREQSample2 <= DMABREQSample;
        DMABREQLatched <= DMABREQSample2;
        // Don't interpret this next item as "The Next State"; it's a special case 'after this
        // generic state, go to this programmable state', so that a single state
        // can be shared for many tasks. [Specifically, the stack push/pull code, which is used
        // for PSH, PUL, Interrupts, RTI, etc.
        NextState <= NextState_nxt;

        // CPU registers latch from the combinatorial circuit
        a <= a_nxt;
        b <= b_nxt;
        e <= e_nxt;
        f <= f_nxt;
        v <= v_nxt;
        md <= md_nxt;
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

        if( s_wr) NMIMask <= 0;
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
localparam IDX_MODE_F_OFFSET       =  4'd10;
localparam IDX_MODE_W_OFFSET       =  4'd14;
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
        regnum[2:0]    =  {1'b0,postbyte[6:5]};
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

localparam ST8_REG_A   =  2'd0;
localparam ST8_REG_B   =  2'd1;
localparam ST8_REG_E   =  2'd2;
localparam ST8_REG_F   =  2'd3;

function [2:0] IsST8(input   [7:0] inst);
reg     [1:0] regnum;
reg     IsStore;
begin

    IsStore        =  1'b0;
    regnum =  2'b01;

    if ( (Inst1 == 8'H97) || (Inst1 == 8'HA7) || (Inst1 == 8'HB7) )
    begin
        IsStore    =  1'b1;
        regnum     =  2'b00;
    end
    else if ( (Inst1 == 8'HD7) || (Inst1 == 8'HE7) || (Inst1 == 8'HF7) )
    begin
        IsStore    =  1'b1;
        regnum     =  2'b01;
    end
    if (HD6309 && InstPage3) begin
        if ((inst == 8'h97) || (inst == 8'ha7) || (inst == 8'hb7)) begin
            IsStore = 1'b1;
            regnum = ST8_REG_E;
        end else if ((inst == 8'hd7) || (inst == 8'he7) || (inst == 8'hf7)) begin
            IsStore = 1'b1;
            regnum = ST8_REG_F;
        end
    end
    IsST8  =  {IsStore, regnum};
end
endfunction

wire    IsStore8;
wire    [1:0] Store8RegisterNum;

assign  {IsStore8, Store8RegisterNum}  =  IsST8(Inst1);


/////////////////////////////////////////////////////////////////
// Is this a 16-bit Store?

localparam ST16_REG_X  =  3'd0;
localparam ST16_REG_Y  =  3'd1;
localparam ST16_REG_U  =  3'd2;
localparam ST16_REG_S  =  3'd3;
localparam ST16_REG_D  =  3'd4;
localparam ST16_REG_W  =  3'd5;


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

    if (HD6309 && InstPage2 && !InstPage3 &&
        ((inst == 8'h97) || (inst == 8'ha7) || (inst == 8'hb7))) begin
        IsStore = 1'b1;
        regnum = ST16_REG_W;
    end

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
wire    IsSpecialImmediate =  IsSpecialImm(Inst1) ||
                             (HD6309 && InstPage3 && ((Inst1 == 8'h3C) || (Inst1 == 8'h3D))) ||
                             (HD6309 && InstPage2 && (Inst1[7:3] == 5'b00110));

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

    if (HD6309 && InstPage2 && (inst[7:2] == 6'b001110))
        is = 1'b1;
    else if (HD6309 && !InstPage2 && !InstPage3 && (inst == 8'h14))
        is = 1'b1;

    else if ( (hi == 4'H4) || (hi == 4'H5) )
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
localparam ALU16_REG_W =  3'd5;

function [2:0] ALU16RegFromInst(input   Page2, input   Page3, input   [7:0] inst);
reg     [2:0] srcreg;
begin
    srcreg =  3'b111;       // default
    if (Page2 && !Page3 && (inst[7:4] >= 4'h8) && (inst[7:4] <= 4'hb)) begin
        case (inst[3:0])
            4'h0,4'h1,4'h6,4'h7,4'hb: srcreg = ALU16_REG_W;
            4'h2,4'h3,4'h4,4'h5,4'h8,4'h9,4'ha: srcreg = ALU16_REG_D;
            4'hc,4'he,4'hf: srcreg = ALU16_REG_Y;
            default: srcreg = 3'b111;
        endcase
    end else casex ({Page2, Page3, inst}) // Note pattern for the matching below
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

localparam  ALUOP16_SUB        =  4'H0;
localparam  ALUOP16_ADD        =  4'H1;
localparam  ALUOP16_LD         =  4'H2;
localparam  ALUOP16_CMP        =  4'H3;
localparam  ALUOP16_LEA        =  4'H4;
localparam  ALUOP16_SBC        =  4'H5;
localparam  ALUOP16_AND        =  4'H6;
localparam  ALUOP16_BIT        =  4'H7;
localparam  ALUOP16_EOR        =  4'H8;
localparam  ALUOP16_ADC        =  4'H9;
localparam  ALUOP16_OR         =  4'HA;
localparam  ALUOP16_INVALID    =  4'hf;

function [4:0] ALU16OpFromInst(input   Page2, input   Page3, input   [7:0] inst);
reg     [3:0] aluop;
reg     writeback;
begin
    aluop  =  ALUOP16_INVALID;
    writeback  =  1'b1;
    if (Page2 && !Page3 && (inst[7:4] >= 4'h8) && (inst[7:4] <= 4'hb)) begin
        case (inst[3:0])
            4'h0: aluop = ALUOP16_SUB;
            4'h1: begin aluop = ALUOP16_CMP; writeback = 1'b0; end
            4'h2: aluop = ALUOP16_SBC;
            4'h3: begin aluop = ALUOP16_CMP; writeback = 1'b0; end
            4'h4: aluop = ALUOP16_AND;
            4'h5: begin aluop = ALUOP16_BIT; writeback = 1'b0; end
            4'h6,4'he: aluop = ALUOP16_LD;
            4'h8: aluop = ALUOP16_EOR;
            4'h9: aluop = ALUOP16_ADC;
            4'ha: aluop = ALUOP16_OR;
            4'hb: aluop = ALUOP16_ADD;
            4'hc: begin aluop = ALUOP16_CMP; writeback = 1'b0; end
            default: aluop = ALUOP16_INVALID;
        endcase
    end else casex ({Page2, Page3, inst})
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
wire    [3:0]  ALU16Opcode;

assign  {ALU16OpWriteback, ALU16Opcode}    =  ALU16OpFromInst(InstPage2, InstPage3, Inst1);

wire    IsALU16Opcode  =  (ALU16Opcode != ALUOP16_INVALID);

function [23:0] ALU16Inst(input   [3:0] operation16, input   [15:0] a_arg, input   [15:0] b_arg, input   [7:0] cc_arg);
reg     [7:0]    cc_out;
reg     [15:0]   ALUFn;
reg     carry1, carry2;
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

        ALUOP16_ADC:
        begin
            {cc_out[CC_C_BIT], ALUFn} = {1'b0,a_arg} + {1'b0,b_arg} + cc_arg[CC_C_BIT];
            cc_out[CC_V_BIT] = (~(a_arg[15] ^ b_arg[15])) & (ALUFn[15] ^ a_arg[15]);
        end

        ALUOP16_SBC:
        begin
            {cc_out[CC_C_BIT], ALUFn} = {1'b0,a_arg} - {1'b0,b_arg} - cc_arg[CC_C_BIT];
            cc_out[CC_V_BIT] = (a_arg[15] ^ b_arg[15]) & (ALUFn[15] ^ a_arg[15]);
        end

        ALUOP16_AND:
        begin
            ALUFn = a_arg & b_arg;
            cc_out[CC_V_BIT] = 1'b0;
        end

        ALUOP16_BIT:
        begin
            ALUFn = a_arg & b_arg;
            cc_out[CC_V_BIT] = 1'b0;
        end

        ALUOP16_EOR:
        begin
            ALUFn = a_arg ^ b_arg;
            cc_out[CC_V_BIT] = 1'b0;
        end

        ALUOP16_OR:
        begin
            ALUFn = a_arg | b_arg;
            cc_out[CC_V_BIT] = 1'b0;
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

function [15:0] HD6309RegValue(input [3:0] regid, input wide);
begin
    if (wide) begin
        case (regid)
            4'h0: HD6309RegValue = {a,b};
            4'h1: HD6309RegValue = x;
            4'h2: HD6309RegValue = y;
            4'h3: HD6309RegValue = u;
            4'h4: HD6309RegValue = s;
            4'h5: HD6309RegValue = pc;
            4'h6: HD6309RegValue = w;
            4'h7: HD6309RegValue = v;
            4'h8,4'h9: HD6309RegValue = {a,b};
            4'hA: HD6309RegValue = {8'h00,cc};
            4'hB: HD6309RegValue = {dp,8'h00};
            4'hE,4'hF: HD6309RegValue = w;
            default: HD6309RegValue = 16'h0000;
        endcase
    end else begin
        case (regid)
            4'h0: HD6309RegValue = {8'h00,b};
            4'h1: HD6309RegValue = {8'h00,x[7:0]};
            4'h2: HD6309RegValue = {8'h00,y[7:0]};
            4'h3: HD6309RegValue = {8'h00,u[7:0]};
            4'h4: HD6309RegValue = {8'h00,s[7:0]};
            4'h5: HD6309RegValue = {8'h00,pc[7:0]};
            4'h6: HD6309RegValue = {8'h00,f};
            4'h7: HD6309RegValue = {8'h00,v[7:0]};
            4'h8: HD6309RegValue = {8'h00,a};
            4'h9: HD6309RegValue = {8'h00,b};
            4'hA: HD6309RegValue = {8'h00,cc};
            4'hB: HD6309RegValue = {8'h00,dp};
            4'hE: HD6309RegValue = {8'h00,e};
            4'hF: HD6309RegValue = {8'h00,f};
            default: HD6309RegValue = 16'h0000;
        endcase
    end
end
endfunction

function [23:0] HD6309RegALU(input [2:0] operation, input [15:0] dst,
                             input [15:0] src, input wide, input [7:0] cc_arg);
reg [16:0] result17;
reg [15:0] result;
reg [7:0] flags;
reg carry;
reg overflow;
reg [15:0] mask;
begin
    result17 = 17'h00000;
    result = 16'h0000;
    flags = cc_arg;
    carry = cc_arg[CC_C_BIT];
    overflow = 1'b0;
    mask = wide ? 16'hFFFF : 16'h00FF;
    case (operation)
        3'd0,3'd1: begin
            result17 = {1'b0,(dst & mask)} + {1'b0,(src & mask)} +
                       ((operation == 3'd1 && cc_arg[CC_C_BIT]) ? 17'd1 : 17'd0);
            result = result17[15:0] & mask;
            carry = result17[wide ? 16 : 8];
            overflow = wide ? ((dst[15] == src[15]) && (result[15] != dst[15])) :
                               ((dst[7] == src[7]) && (result[7] != dst[7]));
            flags[CC_C_BIT] = carry;
            flags[CC_V_BIT] = overflow;
        end
        3'd2,3'd3,3'd7: begin
            result17 = {1'b0,(dst & mask)} - {1'b0,(src & mask)} - ((operation == 3'd3 && cc_arg[CC_C_BIT]) ? 17'd1 : 17'd0);
            result = result17[15:0] & mask;
            carry = result17[16];
            overflow = wide ? ((dst[15] != src[15]) && (result[15] != dst[15])) :
                               ((dst[7] != src[7]) && (result[7] != dst[7]));
            flags[CC_C_BIT] = carry;
            flags[CC_V_BIT] = overflow;
        end
        3'd4: begin result = (dst & src) & mask; flags[CC_V_BIT] = 1'b0; end
        3'd5: begin result = (dst | src) & mask; flags[CC_V_BIT] = 1'b0; end
        3'd6: begin result = (dst ^ src) & mask; flags[CC_V_BIT] = 1'b0; end
        default: result = 16'h0000;
    endcase
    flags[CC_N_BIT] = wide ? result[15] : result[7];
    flags[CC_Z_BIT] = (result == 16'h0000);
    HD6309RegALU = {flags,result};
end
endfunction

function [23:0] HD6309Unary16(input [3:0] operation, input [15:0] value,
                              input [7:0] cc_arg);
reg [15:0] result;
reg [7:0] flags;
reg carry;
begin
    result = value;
    flags = cc_arg;
    carry = cc_arg[CC_C_BIT];
    case (operation)
        4'h0: begin result = -value; carry = (value != 16'h0000); flags[CC_V_BIT] = (value == 16'h8000); end
        4'h3: begin result = ~value; carry = 1'b1; flags[CC_V_BIT] = 1'b0; end
        4'h4: begin result = {1'b0,value[15:1]}; carry = value[0]; end
        4'h6: begin result = {cc_arg[CC_C_BIT],value[15:1]}; carry = value[0]; end
        4'h7: begin result = {value[15],value[15:1]}; carry = value[0]; end
        4'h8: begin result = {value[14:0],1'b0}; carry = value[15]; flags[CC_V_BIT] = value[15] ^ result[15]; end
        4'h9: begin result = {value[14:0],cc_arg[CC_C_BIT]}; carry = value[15]; flags[CC_V_BIT] = result[15] ^ carry; end
        4'hA: begin result = value - 16'd1; flags[CC_V_BIT] = (value == 16'h8000); end
        4'hC: begin result = value + 16'd1; flags[CC_V_BIT] = (value == 16'h7FFF); end
        4'hD: begin result = value; flags[CC_V_BIT] = 1'b0; end
        4'hF: begin result = 16'h0000; carry = 1'b0; flags[CC_V_BIT] = 1'b0; end
        default: begin result = 16'h0000; end
    endcase
    flags[CC_N_BIT] = result[15];
    flags[CC_Z_BIT] = (result == 16'h0000);
    flags[CC_C_BIT] = carry;
    HD6309Unary16 = {flags,result};
end
endfunction

function IsHD6309WideUnary(input [7:0] inst);
begin
    case (inst)
        8'h40,8'h43,8'h44,8'h46,8'h47,8'h48,8'h49,8'h4A,8'h4C,8'h4D,8'h4F,
        8'h50,8'h53,8'h54,8'h56,8'h57,8'h58,8'h59,8'h5A,8'h5C,8'h5D,8'h5F:
            IsHD6309WideUnary = 1'b1;
        default: IsHD6309WideUnary = 1'b0;
    endcase
end
endfunction

wire [3:0] HDRegSrc = D[7:4];
wire [3:0] HDRegDst = D[3:0];
wire HDRegDst8 = HDRegDst[3];
// HD6309 register arithmetic takes its width from the destination. A wide
// source is demoted to its low byte when the destination is eight bits.
wire HDRegWide = !HDRegDst8;
wire [15:0] HDRegSrcValue = HD6309RegValue(HDRegSrc,HDRegWide);
wire [15:0] HDRegDstValue = HD6309RegValue(HDRegDst,HDRegWide);
wire [23:0] HDRegResult = HD6309RegALU(Inst1[2:0],HDRegDstValue,HDRegSrcValue,HDRegWide,cc);
wire [23:0] HDWideUnaryResult = HD6309Unary16(Inst1[3:0],Inst1[7:4] == 4'h4 ? {a,b} : w,cc);
wire [23:0] FastHDWideUnaryResult = HD6309Unary16(MappedInstruction[3:0],MappedInstruction[7:4] == 4'h4 ? {a,b} : w,cc);

reg     [3:0]   ALU16_OP;
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
wire    [5:0] FastALU8Decode;

assign  {ALU8Writeback, ALU8Op}    =  ALUOpFromInst(Inst1);
assign  FastALU8Decode = ALUOpFromInst(MappedInstruction);

reg     [7:0] ALU_A;
reg     [7:0] ALU_B;
reg     [7:0] ALU_CC;
reg     [4:0] ALU_OP;


function [15:0] ALUInst(input   [4:0] operation, input   [7:0] a_arg, input   [7:0] b_arg, input   [7:0] cc_arg);
reg     [7:0]    cc_out;
reg     [7:0]    ALUFn;
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
            {cc_out[CC_C_BIT], ALUFn[7:0]} =  {1'b0, a_arg} + {1'b0, b_arg} + {8'd0,cc_arg[CC_C_BIT]};
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
            ALUFn            =  a_arg + 1'b1;
            cc_out[CC_V_BIT] =  (~a_arg[7] & ALUFn[7]);
        end

        ALUOP_DEC:
        begin
            ALUFn            = a_arg - 1'b1;
            cc_out[CC_V_BIT] = (a_arg[7] & ~ALUFn[7]);
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
            {cc_out[CC_C_BIT], ALUFn[7:0]} = {1'b0, a_arg} - {1'b0, b_arg} - {8'd0,cc_arg[CC_C_BIT]};
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

wire    [2:0]    AddrModeType   = (HD6309 && InstPage3 && (Inst1[7:4] == 4'h8) &&
                                                          ((Inst1[3:0] == 4'hd) || (Inst1[3:0] == 4'he) || (Inst1[3:0] == 4'hf))) ||
                                  (HD6309 && InstPage3 && ((Inst1[7:3] == 5'b00110) ||
                                                          (Inst1[7:2] == 6'b001110) ||
                                                          (Inst1 == 8'h3C) || (Inst1 == 8'h3D))) ||
                                  (HD6309 && InstPage2 && (Inst1[7:3] == 5'b00110)) ?
                                  TYPE_IMMEDIATE :
                                  (HD6309 && InstPage2 && (Inst1[7:2] == 6'b001110)) ?
                                  TYPE_INHERENT :
                                  (HD6309 && !InstPage2 && !InstPage3 && (Inst1 == 8'h14)) ?
                                  TYPE_INHERENT :
                                  addressing_mode_type(Inst1);

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
localparam EXGTFR_REG_W             =  4'H6;
localparam EXGTFR_REG_V             =  4'H7;
localparam EXGTFR_REG_E             =  4'HE;
localparam EXGTFR_REG_F             =  4'HF;

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
    if (HD6309 && InstPage2 && !InstPage3 && (hi >= 4'h8) && (hi <= 4'hb))
        result = 1'b0;
    else if (HD6309 && InstPage3 && (hi >= 4'H8))
    begin
        if ((lo == 4'h0) || (lo == 4'h1) || (lo == 4'h6) || (lo == 4'hB))
            result = 1'b1;
        else
            result = 1'b0;
    end
    else if ( (hi >= 4'H8) )
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

wire    IsTargetRegA   =  IsRegA(Inst1) && !(HD6309 && InstPage3);
wire    IsTargetRegE   =  HD6309 && InstPage3 && (Inst1[7:4] < 4'hc);
wire    IsTargetRegF   =  HD6309 && InstPage3 && (Inst1[7:4] >= 4'hc);
wire    IsHD6309Arith  = HD6309 && InstPage3 && (Inst1[7:4] >= 4'h8) &&
                         (Inst1[7:4] <= 4'hb) &&
                         ((Inst1[3:0] == 4'hd) || (Inst1[3:0] == 4'he) || (Inst1[3:0] == 4'hf));
wire    IsHD6309DivD   = IsHD6309Arith && (Inst1[3:0] == 4'hd);
wire    IsHD6309DivQ   = IsHD6309Arith && (Inst1[3:0] == 4'he);
wire    IsHD6309Muld   = IsHD6309Arith && (Inst1[3:0] == 4'hf);
assign IsHD6309TrapOpcode = HD6309 &&
    ((InstPage2 && !IsHD6309Page2Known(Inst1)) ||
     (InstPage3 && !((Inst1[7:3] == 5'b00110) || (Inst1[7:2] == 6'b001110) ||
      (Inst1 == 8'h3c) || (Inst1 == 8'h3d) || (Inst1 == 8'h3f) ||
      (Inst1 == 8'h43) || (Inst1 == 8'h4a) || (Inst1 == 8'h4c) ||
      (Inst1 == 8'h4d) || (Inst1 == 8'h4f) || (Inst1 == 8'h53) ||
      (Inst1 == 8'h5a) || (Inst1 == 8'h5c) || (Inst1 == 8'h5d) ||
      (Inst1 == 8'h5f) ||
      ((Inst1[7:4] >= 4'h8) && (Inst1[7:4] <= 4'hb) &&
       ((Inst1[3:0] == 4'h0) || (Inst1[3:0] == 4'h1) || (Inst1[3:0] == 4'h3) ||
        (Inst1[3:0] == 4'h6) || (Inst1[3:0] == 4'hb) ||
        (Inst1[3:0] == 4'hc) || (Inst1[3:0] == 4'hd) || (Inst1[3:0] == 4'he) ||
        (Inst1[3:0] == 4'hf))) ||
      ((Inst1[7:4] >= 4'hc) &&
       ((Inst1[3:0] == 4'h0) || (Inst1[3:0] == 4'h1) || (Inst1[3:0] == 4'h6) ||
        (Inst1[3:0] == 4'hb))) ||
      ((((Inst1[7:4] >= 4'h9) && (Inst1[7:4] <= 4'hb)) ||
        (Inst1[7:4] >= 4'hd)) && (Inst1[3:0] == 4'h7)))));
wire    IsHD6309BitOp  = HD6309 && InstPage3 && (Inst1[7:3] == 5'b00110);
wire    IsHD6309TFM    = HD6309 && InstPage3 && (Inst1[7:2] == 6'b001110);
wire    HDBitRegDest   = (tmp[7:6] == 2'b00) ? cc[tmp[2:0]] :
                         (tmp[7:6] == 2'b01) ? a[tmp[2:0]] : b[tmp[2:0]];
wire    HDBitRegSrc    = (tmp[7:6] == 2'b00) ? cc[tmp[5:3]] :
                         (tmp[7:6] == 2'b01) ? a[tmp[5:3]] : b[tmp[5:3]];
wire    HDBitMemSrc    = D[tmp[5:3]];
wire    HDBitResult    = (Inst1 == 8'h30) ? (HDBitRegDest & HDBitMemSrc) :
                         (Inst1 == 8'h31) ? (HDBitRegDest & ~HDBitMemSrc) :
                         (Inst1 == 8'h32) ? (HDBitRegDest | HDBitMemSrc) :
                         (Inst1 == 8'h33) ? (HDBitRegDest | ~HDBitMemSrc) :
                         (Inst1 == 8'h34) ? (HDBitRegDest ^ HDBitMemSrc) :
                         (Inst1 == 8'h35) ? (HDBitRegDest ^ ~HDBitMemSrc) : HDBitMemSrc;
wire [15:0] HDTFMSource = (tmp[7:4] == 4'h0) ? {a,b} :
                          (tmp[7:4] == 4'h1) ? x :
                          (tmp[7:4] == 4'h2) ? y :
                          (tmp[7:4] == 4'h3) ? u : s;
wire [15:0] HDTFMDest = (tmp[3:0] == 4'h0) ? {a,b} :
                        (tmp[3:0] == 4'h1) ? x :
                        (tmp[3:0] == 4'h2) ? y :
                        (tmp[3:0] == 4'h3) ? u : s;
wire [1:0] HDArithOp = IsHD6309DivD ? 2'd1 : IsHD6309DivQ ? 2'd2 : 2'd0;
wire [7:0] HDMemImmediateResult = (Inst1[3:0] == 4'h1) ? (tmp[15:8] | tmp[7:0]) :
                                 (Inst1[3:0] == 4'h2) ? (tmp[15:8] & tmp[7:0]) :
                                 (Inst1[3:0] == 4'h5) ? (tmp[15:8] ^ tmp[7:0]) :
                                                       (tmp[15:8] & tmp[7:0]);
wire [31:0] HDArithLHS = IsHD6309DivQ ? {a,b,w} : {16'h0000,a,b};
wire [15:0] HDMulFinal = tmp + (b[0] ? ea : 16'h0000);
wire [31:0] HDArithResult;
wire [7:0] HDArithFlags;
wire HDArithDivideByZero, HDArithRangeOverflow;
wire HDArithBusy;
wire HDArithStart = HD6309 && (CpuState == CPUSTATE_6309_ARITH_EXEC) &&
                    !HDArithStarted;
wire [15:0] HDArithRHS = IsHD6309DivD ? {8'h00,tmp[7:0]} : tmp;
wire [5:0] HDArithBaseCycles = IsHD6309DivD ?
    ((Inst1[7:4] == 4'h8) ? 6'd25 :
     (Inst1[7:4] == 4'h9) ? (md[0] ? 6'd26 : 6'd27) :
     (Inst1[7:4] == 4'ha) ? 6'd27 : (md[0] ? 6'd27 : 6'd28)) :
    IsHD6309DivQ ?
    ((Inst1[7:4] == 4'h8) ? 6'd34 :
     (Inst1[7:4] == 4'h9) ? (md[0] ? 6'd35 : 6'd36) :
     (Inst1[7:4] == 4'ha) ? 6'd36 : (md[0] ? 6'd36 : 6'd37)) :
    ((Inst1[7:4] == 4'h8) ? 6'd28 :
     (Inst1[7:4] == 4'h9) ? (md[0] ? 6'd29 : 6'd30) :
     (Inst1[7:4] == 4'ha) ? 6'd30 : (md[0] ? 6'd30 : 6'd31));
wire [5:0] HDArithConsumed = (Inst1[7:4] == 4'h8) ? (IsHD6309DivD ? 6'd4 : 6'd5) :
                             (Inst1[7:4] == 4'h9 || Inst1[7:4] == 4'ha) ?
                                 (IsHD6309DivD ? 6'd6 : 6'd7) :
                                 (IsHD6309DivD ? 6'd7 : 6'd8);
wire HDArithDivisorNegative = IsHD6309DivD ? tmp[7] : tmp[15];
wire HDArithDivisorZero = HDArithRHS == 16'd0;
wire [5:0] HDArithSignCycles = IsHD6309Muld ?
    ((a[7] || tmp[15]) ? 6'd2 : 6'd0) :
    ((IsHD6309DivD || IsHD6309DivQ) && !HDArithDivisorZero ?
        (a[7] ? 6'd1 : 6'd0) +
        (HDArithDivisorNegative ? 6'd1 : 6'd0) : 6'd0);
jtframe_hd6309_arith hd6309_arith(
    .clk(clk), .rst(!nRESET), .start(HDArithStart),
    .op(HDArithOp), .lhs(HDArithLHS), .rhs(HDArithRHS),
    .result(HDArithResult), .cc_flags(HDArithFlags),
    .divide_by_zero(HDArithDivideByZero), .range_overflow(HDArithRangeOverflow),
    .busy(HDArithBusy), .done(HDArithDone)
);
wire    HDNativeDataOp = HD6309 && md[0] && !InstPage2 && !InstPage3 &&
                         (IsALU8Set1(Inst1) || IsStore8 || IsALU16Opcode || IsStore16);
wire    HDNativeWideStore = HD6309 && md[0] && InstPage3 && IsStore8;
wire    HDNativeWideByte = HD6309 && md[0] && InstPage3 && IsALU8Set1(Inst1);
wire    HDNativePageWideALU = HD6309 && md[0] && (InstPage2 || InstPage3) &&
                              !IsHD6309Arith && IsALU16Opcode && (ALU16Opcode != ALUOP16_LD);
wire    HDNativeQMem = HD6309 && md[0] && InstPage2 && !InstPage3 &&
                      ((Inst1 == 8'hdc) || (Inst1 == 8'hdd) ||
                       (Inst1 == 8'hec) || (Inst1 == 8'hed) ||
                       (Inst1 == 8'hfc) || (Inst1 == 8'hfd));
wire    HDNativePageWideMem = HD6309 && md[0] && (InstPage2 || InstPage3) &&
                              !IsHD6309Arith && (IsALU16Opcode || IsStore16 || HDNativeQMem);
wire    HDNativeUnaryMem = HD6309 && md[0] && !InstPage2 && !InstPage3 && IsALU8Set0(Inst1);
wire    HDNativeJMP = HD6309 && md[0] && !InstPage2 && !InstPage3 && IsJMP(Inst1);
wire    HDNativeJSR = HD6309 && md[0] && !InstPage2 && !InstPage3 &&
                      ((Inst1 == 8'h9d) || (Inst1 == 8'had) || (Inst1 == 8'hbd));

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
            EXGTFR_REG_W:
                EXGTFRRegister   =  HD6309 ? w : 16'h0000;
            EXGTFR_REG_V:
                EXGTFRRegister   =  HD6309 ? v : 16'h0000;
            EXGTFR_REG_DP:
                EXGTFRRegister   =  HD6309 ? {dp,dp} : {8'HFF, dp};
            EXGTFR_REG_A:
                EXGTFRRegister   =  HD6309 ? {a,a} : {8'HFF, a};
            EXGTFR_REG_B:
                EXGTFRRegister   =  HD6309 ? {b,b} : {8'HFF, b};
            EXGTFR_REG_CC:
                EXGTFRRegister   =  HD6309 ? {cc,cc} : {8'HFF, cc};
            EXGTFR_REG_E:
                EXGTFRRegister   =  HD6309 ? {e,e} : 16'h0000;
            EXGTFR_REG_F:
                EXGTFRRegister   =  HD6309 ? {f,f} : 16'h0000;
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
    e_nxt      =  e;
    f_nxt      =  f;
    v_nxt      =  v;
    md_nxt     =  md;
    x_nxt      =  x;
    y_nxt      =  y;
    s_nxt      =  s;
    s_wr       =  0;
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

    ALU16_OP   =  4'H0;
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
        e_nxt      =  0;
        f_nxt      =  0;
        v_nxt      =  16'hFFFF;
        md_nxt     =  0;
        x_nxt      =  0;
        y_nxt      =  0;
        s_nxt      =  0;
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

            // The 6309 native execution unit completes ABX in its opcode
            // fetch slot.  The emulation path retains the 6809 padding state.
            else if (HD6309 && md[0] && (MappedInstruction == 8'h3A))
            begin
                Inst1_nxt = MappedInstruction;
                x_nxt = x + {8'h00,b};
                rAVMA = 1'b1;
                rLIC = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end
            else if (HD6309 && md[0] && MappedInstruction == OPCODE_INH_NOP)
            begin
                Inst1_nxt = MappedInstruction;
                rAVMA = 1'b1;
                rLIC = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end
            else if (HD6309 && md[0] && MappedInstruction == OPCODE_INH_DAA)
            begin
                Inst1_nxt = MappedInstruction;
                if (((cc[CC_C_BIT]) || (a[7:4] > 4'h9)) ||
                    ((a[7:4] > 4'h8) && (a[3:0] > 4'h9)))
                    tmp_nxt[7:4] = 4'h6;
                else
                    tmp_nxt[7:4] = 4'h0;
                if ((cc[CC_H_BIT]) || (a[3:0] > 4'h9))
                    tmp_nxt[3:0] = 4'h6;
                else
                    tmp_nxt[3:0] = 4'h0;
                {tmp_nxt[8],a_nxt} = {1'b0,a} + tmp_nxt[7:0];
                cc_nxt[CC_C_BIT] = cc[CC_C_BIT] | tmp_nxt[8];
                cc_nxt[CC_N_BIT] = a_nxt[7];
                cc_nxt[CC_Z_BIT] = (a_nxt == 8'h00);
                rAVMA = 1'b1;
                rLIC = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end
            else if (HD6309 && md[0] && MappedInstruction == OPCODE_INH_SEX)
            begin
                Inst1_nxt = MappedInstruction;
                a_nxt = {8{b[7]}};
                cc_nxt[CC_N_BIT] = b[7];
                cc_nxt[CC_Z_BIT] = (b == 8'h00);
                rAVMA = 1'b1;
                rLIC = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end
            else if (HD6309 && md[0] &&
                     ((MappedInstruction[7:4] == 4'h4) ||
                      (MappedInstruction[7:4] == 4'h5)) &&
                     IsALU8Set0(MappedInstruction))
            begin
                Inst1_nxt = MappedInstruction;
                ALU_OP = FastALU8Decode[4:0];
                ALU_A = MappedInstruction[7:4] == 4'h4 ? a : b;
                ALU_B = 8'h00;
                ALU_CC = cc;
                cc_nxt = ALU[15:8];
                if (FastALU8Decode[5]) begin
                    if (MappedInstruction[7:4] == 4'h4) a_nxt = ALU[7:0];
                    else b_nxt = ALU[7:0];
                end
                rAVMA = 1'b1;
                rLIC = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
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

        if (HD6309 && ((MappedInstruction == 8'h10) || (MappedInstruction == 8'h11)))
        begin
            // Repeated or mixed page selectors are illegal on HD6309 even
            // though the MC6809 accepts redundant prefix bytes.
            md_nxt[6] = 1'b1;
            rAVMA = 1'b1;
            rLIC = 1'b1;
            CpuState_nxt = CPUSTATE_6309_TRAP_START;
        end
        else if (Inst1_nxt == 8'H10)         // Page 2  Note, like the 6809, $10 $10 $10 $10 has the same effect as a single $10.
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
        else if (HD6309 && md[0] && InstPage3 &&
                 ((MappedInstruction == 8'h43) || (MappedInstruction == 8'h4A) ||
                  (MappedInstruction == 8'h4C) || (MappedInstruction == 8'h4D) ||
                  (MappedInstruction == 8'h4F) || (MappedInstruction == 8'h53) ||
                  (MappedInstruction == 8'h5A) || (MappedInstruction == 8'h5C) ||
                  (MappedInstruction == 8'h5D) || (MappedInstruction == 8'h5F)))
        begin
            Inst1_nxt = MappedInstruction;
            ALU_OP = FastALU8Decode[4:0];
            ALU_A = MappedInstruction[4] ? f : e;
            ALU_B = 8'h00;
            ALU_CC = cc;
            cc_nxt = ALU[15:8];
            if (FastALU8Decode[5]) begin
                if (MappedInstruction[4]) f_nxt = ALU[7:0];
                else                     e_nxt = ALU[7:0];
            end
            rAVMA = 1'b1;
            rLIC = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end
        else if (HD6309 && md[0] && InstPage2 && IsHD6309WideUnary(MappedInstruction))
        begin
            Inst1_nxt = MappedInstruction;
            cc_nxt = FastHDWideUnaryResult[23:16];
            if ((MappedInstruction[3:0] != 4'hD)) begin
                if (MappedInstruction[7:4] == 4'h4) {a_nxt,b_nxt} = FastHDWideUnaryResult[15:0];
                else                                      {e_nxt,f_nxt} = FastHDWideUnaryResult[15:0];
            end
            rAVMA = 1'b1;
            rLIC = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
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

        if (IsHD6309TrapOpcode || (HD6309 && !InstPage2 && !InstPage3 &&
                                    (Inst1 != 8'hcd) && (Inst1 != 8'h14) &&
                                    !IsHD6309MemImmediate(Inst1) &&
                                    IllegalInstruction(Inst1)))
        begin
            md_nxt[6] = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_TRAP_START;
            rLIC = 1'b1;
        end
        else if (IsIllegalInstruction)       // Apply configured legacy illegal-op behavior.
        begin

            rAVMA = 1'b1;
            CpuState_nxt = IllegalInstructionState;
            rLIC = 1'b1;
        end
        else if (IsHD6309MemImmediate(Inst1))
        begin
            // AIM/OIM/EIM/TIM carry an immediate mask before the effective
            // address operand, so the ordinary address-mode decoder must
            // start one byte later.
            tmp_nxt[7:0] = D[7:0];
            addr_nxt = pc;
            pc_nxt = pc_p1;
            rAVMA = 1'b1;
            case (AddrModeType)
                TYPE_DIRECT:   CpuState_nxt = CPUSTATE_6309_IMM_DIRECT_ADDR;
                TYPE_INDEXED:  CpuState_nxt = CPUSTATE_6309_IMM_INDEX_POST;
                TYPE_EXTENDED: CpuState_nxt = CPUSTATE_6309_IMM_EXT_HI;
                default: begin
                    md_nxt[6] = 1'b1;
                    CpuState_nxt = CPUSTATE_6309_TRAP_START;
                end
            endcase
        end
        else
        begin
            // First byte Decode for this stage
            case (AddrModeType)
                TYPE_INDEXED:
                begin
                    rAVMA = 1'b1;
                    CpuState_nxt = CPUSTATE_INDEXED_BASE;
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
                    if (HDNativeJMP) begin
                        pc_nxt = {dp,Inst2_nxt};
                        rAVMA = 1'b1;
                        rLIC = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                    end else if (HDNativeDataOp || HDNativeWideStore || HDNativeWideByte || HDNativePageWideMem ||
                                 HDNativeUnaryMem) begin
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_ALU_EA;
                    end else begin
                        rAVMA = 1'b0;
                        CpuState_nxt = CPUSTATE_DIRECT_DONTCARE;
                    end
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
                        CpuState_nxt = CPUSTATE_SYNC_PAD1;
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
                    else if ((Inst1 == OPCODE_INH_RTS) && !InstPage2)
                    begin
                        rAVMA = 1'b1;
                        CpuState_nxt   =  CPUSTATE_RTS_HI;
                    end
                    else if ((Inst1 == OPCODE_INH_RTI) && !InstPage2)
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
                        cc_nxt[CC_N_BIT] = b[7];
                        cc_nxt[CC_Z_BIT] = {b == 8'H00};
                        rLIC = 1'b1; // Instruction done!
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                        end
                    else if ((Inst1 == OPCODE_INH_ABX) && !InstPage2)
                    begin
                        x_nxt  =  x + {8'd0,b};
                        rAVMA = 1'b0;
                        CpuState_nxt   =  CPUSTATE_ABX_DONTCARE;
                    end
                    else if (HD6309 && InstPage2 && (Inst1[7:2] == 6'b001110))
                    begin
                        // 10 38/39 push or pull W through S; 10 3A/3B
                        // use U.  tmp[11] is reserved for the W stack bit.
                        tmp_nxt = 16'h0800;
                        tmp_nxt[14] = Inst1[1];
                        tmp_nxt[15] = 1'b0;
                        if (Inst1[0]) begin
                            rAVMA = 1'b0;
                            CpuState_nxt = CPUSTATE_PUL_ACTION;
                        end else begin
                            rAVMA = 1'b0;
                            CpuState_nxt = CPUSTATE_PSH_DONTCARE3;
                        end
                        NextState_nxt = CPUSTATE_FETCH_I1;
                    end
                    else if (HD6309 && InstPage3 &&
                             ((Inst1 == 8'h43) || (Inst1 == 8'h4A) ||
                              (Inst1 == 8'h4C) || (Inst1 == 8'h4D) ||
                              (Inst1 == 8'h4F) || (Inst1 == 8'h53) ||
                              (Inst1 == 8'h5A) || (Inst1 == 8'h5C) ||
                              (Inst1 == 8'h5D) || (Inst1 == 8'h5F)))
                    begin
                        ALU_OP = ALU8Op;
                        ALU_A = Inst1[4] ? f : e;
                        ALU_B = 8'h00;
                        ALU_CC = cc;
                        cc_nxt = ALU[15:8];
                        if (ALU8Writeback) begin
                            if (Inst1[4]) f_nxt = ALU[7:0];
                            else          e_nxt = ALU[7:0];
                        end
                        rAVMA = 1'b1;
                        rLIC = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                    end
                    else if (HD6309 && InstPage2 && IsHD6309WideUnary(Inst1))
                    begin
                        cc_nxt = HDWideUnaryResult[23:16];
                        if (Inst1[3:0] != 4'hD) begin
                            if (Inst1[7:4] == 4'h4) {a_nxt,b_nxt} = HDWideUnaryResult[15:0];
                            else                              {e_nxt,f_nxt} = HDWideUnaryResult[15:0];
                        end
                        rAVMA = 1'b1;
                        rLIC = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                    end
                    else if (HD6309 && !InstPage2 && !InstPage3 && (Inst1 == 8'h14))
                    begin
                        a_nxt = {8{w[15]}};
                        b_nxt = {8{w[15]}};
                        cc_nxt[CC_N_BIT] = w[15];
                        cc_nxt[CC_Z_BIT] = (w == 16'h0000);
                        pc_nxt = pc;
                        rAVMA = 1'b0;
                        CpuState_nxt = CPUSTATE_6309_SEXW_WAIT1;
                    end
                    else
                    begin
                        ALU_OP =  ALU8Op;
                        if (IsTargetRegE) ALU_A = e;
                        else if (IsTargetRegF) ALU_A = f;
                        else if (IsTargetRegA) ALU_A = a;
                        else ALU_A = b;

                        ALU_B  =  0;
                        ALU_CC =  cc;
                        cc_nxt =  ALU[15:8];

                        if (ALU8Writeback)
                        begin
                            if (IsTargetRegE) e_nxt = ALU[7:0];
                            else if (IsTargetRegF) f_nxt = ALU[7:0];
                            else if (IsTargetRegA) a_nxt = ALU[7:0];
                            else b_nxt = ALU[7:0];
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
                    if (IsHD6309Arith && (Inst1[7:4] == 4'h8))
                    begin
                        if (IsHD6309DivD) begin
                            tmp_nxt[7:0] = D[7:0];
                            CpuState_nxt = CPUSTATE_6309_ARITH_EXEC;
                        end else begin
                            tmp_nxt[15:8] = D[7:0];
                            CpuState_nxt = CPUSTATE_6309_ARITH_IMM_LO;
                        end
                        rAVMA = 1'b1;
                    end
                    else if (IsHD6309BitOp)
                    begin
                        tmp_nxt[7:0] = D[7:0];
                        CpuState_nxt = CPUSTATE_6309_BIT_ADDR;
                        rAVMA = 1'b1;
                    end
                    else if (IsHD6309TFM)
                    begin
                        if ((D[7:4] > 4'h4) || (D[3:0] > 4'h4)) begin
                            md_nxt[6] = 1'b1;
                            cc_nxt[CC_Z_BIT] = 1'b0;
                            CpuState_nxt = CPUSTATE_6309_TRAP_START;
                            rLIC = 1'b1;
                        end else begin
                            tmp_nxt[7:0] = D[7:0];
                            if (w == 16'h0000) CpuState_nxt = CPUSTATE_6309_TFM_FINAL1;
                            else CpuState_nxt = CPUSTATE_6309_TFM_READ;
                        end
                        rAVMA = 1'b1;
                    end
                    else if (HD6309 && !InstPage2 && !InstPage3 && (Inst1 == 8'hCD))
                    begin
                        a_nxt = D[7:0];
                        pc_nxt = pc_p1;
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_Q_IMM2;
                    end
                    else if (IsSpecialImmediate)
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
                        else if (((Inst1 == OPCODE_IMM_PSHS) | (Inst1 == OPCODE_IMM_PSHU)) &&
                                 !InstPage2 && !InstPage3)
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
                        else if (((Inst1 == OPCODE_IMM_PULS) | (Inst1 == OPCODE_IMM_PULU)) &&
                                 !InstPage2 && !InstPage3)
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
                        else if (HD6309 && InstPage3 && (Inst1 == 8'h3D))
                        begin
                            md_nxt[1:0] = D[1:0];
                            pc_nxt = pc_p1;
                            rAVMA = 1'b0;
                            CpuState_nxt = CPUSTATE_MD_DONTCARE1;
                        end
                        else if (HD6309 && InstPage3 && (Inst1 == 8'h3C))
                        begin
                            cc_nxt[CC_Z_BIT] = ((md[7:6] & D[7:6]) == 2'b00);
                            md_nxt[7:6] = md[7:6] & ~D[7:6];
                            pc_nxt = pc_p1;
                            rAVMA = 1'b1;
                            CpuState_nxt = CPUSTATE_MD_DONTCARE2;
                        end
                        else if (HD6309 && InstPage2 && (Inst1[7:3] == 5'b00110))
                        begin
                            cc_nxt = HDRegResult[23:16];
                            pc_nxt = pc_p1;
                            if (Inst1[2:0] != 3'd7) begin
                                if (HDRegWide) begin
                                    case (HDRegDst)
                                        4'h0,4'h8,4'h9: {a_nxt,b_nxt} = HDRegResult[15:0];
                                        4'h1: x_nxt = HDRegResult[15:0];
                                        4'h2: y_nxt = HDRegResult[15:0];
                                        4'h3: u_nxt = HDRegResult[15:0];
                                        4'h4: begin s_nxt = HDRegResult[15:0]; s_wr = 1'b1; end
                                        4'h5: pc_nxt = HDRegResult[15:0];
                                        4'h6,4'hE,4'hF: {e_nxt,f_nxt} = HDRegResult[15:0];
                                        4'h7: v_nxt = HDRegResult[15:0];
                                        default: begin end
                                    endcase
                                end else begin
                                    case (HDRegDst)
                                        4'h8: a_nxt = HDRegResult[7:0];
                                        4'h9: b_nxt = HDRegResult[7:0];
                                        // CC is written before NZVC are set. The result's
                                        // other bits remain as written by the instruction.
                                        4'hA: cc_nxt = HDRegResult[7:0] |
                                            (HDRegResult[23:16] &
                                             ((Inst1[2:0] <= 3'd3) ? 8'h0F : 8'h0C));
                                        4'hB: dp_nxt = HDRegResult[7:0];
                                        4'hE: e_nxt = HDRegResult[7:0];
                                        4'hF: f_nxt = HDRegResult[7:0];
                                        default: begin end
                                    endcase
                                end
                            end
                            rAVMA = 1'b0;
                            CpuState_nxt = CPUSTATE_6309_RR_WAIT;
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
                                EXGTFR_REG_S: begin
                                    s_nxt  =  EXGTFRRegA;
                                    s_wr   = 1;
                                end
                                EXGTFR_REG_PC:
                                    pc_nxt =  EXGTFRRegA;
                                EXGTFR_REG_W:
                                    if (HD6309) {e_nxt,f_nxt} = EXGTFRRegA;
                                EXGTFR_REG_V:
                                    if (HD6309) v_nxt = EXGTFRRegA;
                                EXGTFR_REG_DP:
                                    dp_nxt =  HD6309 ? EXGTFRRegA[15:8] : EXGTFRRegA[7:0];
                                EXGTFR_REG_A:
                                    a_nxt  =  HD6309 ? EXGTFRRegA[15:8] : EXGTFRRegA[7:0];
                                EXGTFR_REG_B:
                                    b_nxt  =  EXGTFRRegA[7:0];
                                EXGTFR_REG_CC:
                                    cc_nxt =  EXGTFRRegA[7:0];
                                EXGTFR_REG_E:
                                    if (HD6309) e_nxt = EXGTFRRegA[15:8];
                                EXGTFR_REG_F:
                                    if (HD6309) f_nxt = EXGTFRRegA[7:0];
                                default:
                                begin
                                end
                            endcase
                            rAVMA = 1'b0;
                            CpuState_nxt   = (HD6309 && md[0]) ? CPUSTATE_TFR_DONTCARE3 : CPUSTATE_TFR_DONTCARE1;

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
                                EXGTFR_REG_S: begin
                                    s_nxt  =  EXGTFRRegB;
                                    s_wr   = 1;
                                end
                                EXGTFR_REG_PC:
                                    pc_nxt =  EXGTFRRegB;
                                EXGTFR_REG_W:
                                    if (HD6309) {e_nxt,f_nxt} = EXGTFRRegB;
                                EXGTFR_REG_V:
                                    if (HD6309) v_nxt = EXGTFRRegB;
                                EXGTFR_REG_DP:
                                    dp_nxt =  HD6309 ? EXGTFRRegB[15:8] : EXGTFRRegB[7:0];
                                EXGTFR_REG_A:
                                    a_nxt  =  HD6309 ? EXGTFRRegB[15:8] : EXGTFRRegB[7:0];
                                EXGTFR_REG_B:
                                    b_nxt  =  EXGTFRRegB[7:0];
                                EXGTFR_REG_CC:
                                    cc_nxt =  EXGTFRRegB[7:0];
                                EXGTFR_REG_E:
                                    if (HD6309) e_nxt = EXGTFRRegB[15:8];
                                EXGTFR_REG_F:
                                    if (HD6309) f_nxt = EXGTFRRegB[7:0];
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
                                EXGTFR_REG_S: begin
                                    s_nxt  =  EXGTFRRegA;
                                    s_wr   = 1;
                                end
                                EXGTFR_REG_PC:
                                    pc_nxt =  EXGTFRRegA;
                                EXGTFR_REG_W:
                                    if (HD6309) {e_nxt,f_nxt} = EXGTFRRegA;
                                EXGTFR_REG_V:
                                    if (HD6309) v_nxt = EXGTFRRegA;
                                EXGTFR_REG_DP:
                                    dp_nxt =  HD6309 ? EXGTFRRegA[15:8] : EXGTFRRegA[7:0];
                                EXGTFR_REG_A:
                                    a_nxt  =  HD6309 ? EXGTFRRegA[15:8] : EXGTFRRegA[7:0];
                                EXGTFR_REG_B:
                                    b_nxt  =  EXGTFRRegA[7:0];
                                EXGTFR_REG_CC:
                                    cc_nxt =  EXGTFRRegA[7:0];
                                EXGTFR_REG_E:
                                    if (HD6309) e_nxt = EXGTFRRegA[15:8];
                                EXGTFR_REG_F:
                                    if (HD6309) f_nxt = EXGTFRRegA[7:0];
                                default:
                                begin
                                end
                            endcase
                            rAVMA = 1'b0;
                            CpuState_nxt   = (HD6309 && md[0]) ? CPUSTATE_EXG_DONTCARE4 : CPUSTATE_EXG_DONTCARE1;
                        end
                    end
                    // Determine if this is an 8-bit ALU operation.
                    else if (Is8BitInst)
                    begin
                        ALU_OP =  ALU8Op;
                        if (IsTargetRegE) ALU_A = e;
                        else if (IsTargetRegF) ALU_A = f;
                        else if (IsTargetRegA) ALU_A = a;
                        else ALU_A = b;

                        ALU_B  =  Inst2_nxt;
                        ALU_CC =  cc;
                        cc_nxt =  ALU[15:8];

                        if (ALU8Writeback)
                        begin
                            if (HD6309 && InstPage3 && (Inst1 == 8'h86))
                                e_nxt = ALU[7:0];
                            else if (HD6309 && InstPage3 && (Inst1 == 8'hC6))
                                f_nxt = ALU[7:0];
                            else if (IsTargetRegE)
                                e_nxt = ALU[7:0];
                            else if (IsTargetRegF)
                                f_nxt = ALU[7:0];
                            else if (IsTargetRegA)
                                a_nxt = ALU[7:0];
                            else
                                b_nxt = ALU[7:0];
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
        CpuState_nxt = (HD6309 && md[0] &&
                        ((Inst1 == INST_LBRA) || (Inst1 == INST_LBSR))) ?
                       CPUSTATE_LBRA_DONTCARE2 : CPUSTATE_LBRA_DONTCARE;
    end

    CPUSTATE_LBRA_DONTCARE:
    begin
        addr_nxt       =  16'HFFFF;
        if ( TakeBranch )
        begin
            if (HD6309 && md[0] && InstPage2)
            begin
                // Native HD6309 conditional long branches use the same
                // five-E interval whether taken or not. Apply the target
                // during this phase instead of entering the extra dummy.
                pc_nxt = pc + {Inst2[7:0], Inst3[7:0]};
                rLIC = 1'b1;
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end
            else
            begin
                rAVMA = 1'b0;
                CpuState_nxt = CPUSTATE_LBRA_DONTCARE2;
            end
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
                CpuState_nxt = (HD6309 && md[0]) ? CPUSTATE_BSR_DONTCARE2 : CPUSTATE_BSR_DONTCARE1;
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
            CpuState_nxt = (HD6309 && md[0]) ? CPUSTATE_BSR_DONTCARE2 : CPUSTATE_BSR_DONTCARE1;
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
        if (HD6309 && md[0]) begin
            rLIC = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end else begin
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_RTS_DONTCARE2;
        end
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
            ALU16_REG_W:
                ALU16_A    =  w;
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
                ALU16_REG_W:
                    {cc_nxt, e_nxt, f_nxt} = ALU16;
                ALU16_REG_Y:
                    {cc_nxt, y_nxt}        =  ALU16;
                ALU16_REG_U:
                    {cc_nxt, u_nxt}        =  ALU16;
                ALU16_REG_S:
                    {s_wr, cc_nxt, s_nxt}  =  {1'b1, ALU16 };
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
        else if (HDNativePageWideALU || HDNativeDataOp)
        begin
            rLIC = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
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

        // Native direct and extended JMP paths fold the address dummy into
        // this state, removing the extra emulation-mode cycle.
        // Is Figure 18/5 Column 3?
        if (IsHD6309MemImmediate(Inst1))
        begin
            tmp_nxt[15:8] = D[7:0];
            addr_nxt = ea;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_IMM_EXEC;
        end
        else if (IsHD6309Arith && (Inst1[7:4] != 4'h8))
        begin
            if (IsHD6309DivD) begin
                tmp_nxt[7:0] = D[7:0];
                CpuState_nxt = CPUSTATE_6309_ARITH_EXEC;
            end else begin
                tmp_nxt[15:8] = D[7:0];
                ea_nxt = ea_p1;
                CpuState_nxt = CPUSTATE_6309_ARITH_MEM_LO;
            end
            addr_nxt = ea;
            rAVMA = 1'b1;
        end
        else if (HD6309 && InstPage2 &&
            ((Inst1 == 8'hdc) || (Inst1 == 8'hec) || (Inst1 == 8'hfc)))
        begin
            addr_nxt = ea;
            a_nxt = D[7:0];
            ea_nxt = ea_p1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_QLOAD2;
        end
        else if (HD6309 && InstPage2 &&
                 ((Inst1 == 8'hdd) || (Inst1 == 8'hed) || (Inst1 == 8'hfd)))
        begin
            addr_nxt = ea;
            DOutput = a;
            RnWOut = 1'b0;
            ea_nxt = ea_p1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_QSTORE2;
        end
        else if (IsALU8Set1(Inst1) &&
                 !(HD6309 && (InstPage2 || InstPage3) && IsALU16Opcode))
        begin
            addr_nxt   =  ea;

            ALU_OP     =  ALU8Op;
            ALU_B      =  D[7:0];
            ALU_CC     =  cc;

            if (IsTargetRegE) ALU_A = e;
            else if (IsTargetRegF) ALU_A = f;
            else if (IsTargetRegA) ALU_A = a;
            else ALU_A = b;

            cc_nxt =  ALU[15:8];

            if ( (ALU8Writeback) )
            begin
                if (IsTargetRegE) e_nxt = ALU[7:0];
                else if (IsTargetRegF) f_nxt = ALU[7:0];
                else if (IsTargetRegA) a_nxt = ALU[7:0];
                else b_nxt = ALU[7:0];
            end

            rLIC = 1'b1; // Instruction done!
            rAVMA = 1'b1;
            CpuState_nxt   =  CPUSTATE_FETCH_I1;
        end

        // Is Figure 18/5 Column 4? (Store, 8 bits)
        else if (IsStore8 && !(HD6309 && (InstPage2 || InstPage3) && IsStore16))
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
                ST8_REG_E:
                begin
                    DOutput = e;
                    ALU_B = e;
                end
                ST8_REG_F:
                begin
                    DOutput = f;
                    ALU_B = f;
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
                ALU16_REG_W:
                    e_nxt          =  D[7:0];
                ALU16_REG_Y:
                    y_nxt[15:8]    =  D[7:0];
                ALU16_REG_S:
                    { s_wr, s_nxt[15:8] } = {1'b1, D[7:0]};
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
            ALU16_A        =  0;

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
                ST16_REG_W:
                begin
                    DOutput[7:0] = e;
                    ALU16_B = w;
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
                CpuState_nxt = (HD6309 && md[0]) ? CPUSTATE_TST_DONTCARE2 : CPUSTATE_TST_DONTCARE1;
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
            CpuState_nxt = HDNativeJSR ? CPUSTATE_JSR_RETLO : CPUSTATE_JSR_DONTCARE;
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
                    { s_wr, s_nxt } = {1'b1, ALU16[15:0] };
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
            ALU16_REG_W:
            begin
                f_nxt = D[7:0];
                ALU16_B[15:8] = e;
            end
            ALU16_REG_Y:
            begin
                y_nxt[7:0] =  D[7:0];
                ALU16_B[15:8] = y[15:8];
            end
            ALU16_REG_S:
            begin
                {s_wr, s_nxt[7:0] } = { 1'b1, D[7:0] };
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
        ALU16_A        =    0;
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
            ST16_REG_W:
                DOutput[7:0] = f;
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
            ALU16_REG_W:
                ALU16_A        =  w;
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
                ALU16_REG_W:
                    {cc_nxt, e_nxt, f_nxt} = ALU16;
                ALU16_REG_Y:
                    {cc_nxt, y_nxt}        =  ALU16;
                ALU16_REG_U:
                    {cc_nxt, u_nxt}        =  ALU16;
                ALU16_REG_S:
                    {s_wr, cc_nxt, s_nxt}  = {1'b1, ALU16};
                default:
                begin
                end
            endcase
        end
        else
            cc_nxt = ALU16[23:16];
        if (HDNativeDataOp || HDNativePageWideALU) begin
            rLIC = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end else begin
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_ALU16_DONTCARE;
        end
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
        if (HDNativeJMP) begin
            pc_nxt = {ea[15:8],D[7:0]};
            rLIC = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end else if (HDNativeDataOp || HDNativeWideStore || HDNativeWideByte || HDNativePageWideMem ||
                     HDNativeUnaryMem) begin
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_ALU_EA;
        end else begin
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_EXTENDED_DONTCARE;
        end
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

    CPUSTATE_6309_IMM_DIRECT_ADDR:
    begin
        ea_nxt = {dp,D[7:0]};
        // D is the direct address operand selected by PC. Keep the address
        // bus on that operand while latching EA; driving {DP,D} here feeds
        // the memory data back into its own address.
        addr_nxt = pc;
        pc_nxt = pc_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_ALU_EA;
    end

    CPUSTATE_6309_IMM_INDEX_POST:
    begin
        Inst2_nxt = D[7:0];
        addr_nxt = pc;
        pc_nxt = pc_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_INDEXED_BASE;
    end

    CPUSTATE_6309_IMM_EXT_HI:
    begin
        ea_nxt[15:8] = D[7:0];
        addr_nxt = pc;
        pc_nxt = pc_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_IMM_EXT_LO;
    end

    CPUSTATE_6309_IMM_EXT_LO:
    begin
        ea_nxt[7:0] = D[7:0];
        // As with direct mode, D is still the low address operand here.
        // Preserve the PC fetch address and let ALU_EA select the latched EA.
        addr_nxt = pc;
        pc_nxt = pc_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_ALU_EA;
    end

    CPUSTATE_6309_IMM_EXEC:
    begin
        tmp_nxt[7:0] = HDMemImmediateResult;
        cc_nxt[CC_N_BIT] = HDMemImmediateResult[7];
        cc_nxt[CC_Z_BIT] = (HDMemImmediateResult == 8'h00);
        cc_nxt[CC_V_BIT] = 1'b0;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_IMM_WRITE;
    end

    CPUSTATE_6309_IMM_WRITE:
    begin
        if (Inst1[3:0] != 4'hb) begin
            addr_nxt = ea;
            DOutput = tmp[7:0];
            RnWOut = 1'b0;
        end
        rLIC = 1'b1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
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

        if (HD6309 && ((Inst2 == 8'haf) || (Inst2 == 8'hb0)))
        begin
            // The AF/B0 encodings use a signed 16-bit offset from W; the
            // generic postbyte decoder sees these as extended-indirect and
            // postincrement forms, respectively.
            tmp_nxt[15:8] = D[7:0];
            pc_nxt = pc_p1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_WOFF_LO;
        end
        else if (HD6309 && ((Inst2 == 8'hcf) || (Inst2 == 8'hd0) ||
                            (Inst2 == 8'hef) || (Inst2 == 8'hf0)))
        begin
            ALU16_A = w;
            ALU16_B = ((Inst2 == 8'hcf) || (Inst2 == 8'hd0)) ? 16'h0002 : 16'hfffe;
            ALU16_OP = ALUOP16_ADD;
            if ((Inst2 == 8'hcf) || (Inst2 == 8'hd0)) begin
                ea_nxt = w;
                {e_nxt,f_nxt} = ALU16[15:0];
            end else begin
                ea_nxt = ALU16[15:0];
                {e_nxt,f_nxt} = ALU16[15:0];
            end
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_IDX_DONTCARE3;
        end
        else if (HD6309 && Inst2[7] && (IndexedMode == IDX_MODE_5BIT_OFFSET))
        begin
            // HD6309 E,R is the extended accumulator-offset form occupying
            // the legacy 5-bit-offset postbyte slot.
            ALU16_B = {{8{e[7]}},e};
            ea_nxt = ALU16[15:0];
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_IDX_DONTCARE3;
        end
        else if (HD6309 && (IndexedMode == IDX_MODE_F_OFFSET))
        begin
            ALU16_B = {{8{f[7]}},f};
            ea_nxt = ALU16[15:0];
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_IDX_DONTCARE3;
        end
        else if (HD6309 && (IndexedMode == IDX_MODE_W_OFFSET))
        begin
            ALU16_B = w;
            ea_nxt = ALU16[15:0];
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_IDX_DONTCARE3;
        end
        else if (HD6309 && ((Inst2 == 8'h8f) || (Inst2 == 8'h90)))
        begin
            ea_nxt = w;
            if (Inst2[4]) begin
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_INDIRECT_HI;
            end else if (IsJMP(Inst1)) begin
                pc_nxt = w;
                rLIC = 1'b1;
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end else begin
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_ALU_EA;
            end
        end
        else
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
                if (HD6309) begin
                    md_nxt[6] = 1'b1;
                    CpuState_nxt = CPUSTATE_6309_TRAP_START;
                end else CpuState_nxt = PostIllegalState;
            end

        endcase
    end

    CPUSTATE_6309_WOFF_LO:
    begin
        ALU16_A = w;
        ALU16_B = {tmp[15:8],D[7:0]};
        ALU16_OP = ALUOP16_ADD;
        ea_nxt = ALU16[15:0];
        pc_nxt = pc_p1;
        addr_nxt = pc;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_IDX_DONTCARE3;
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
        if (HD6309 && md[0] && IndexedRegister == IDX_REG_PC)
            CpuState_nxt = CPUSTATE_IDX_16OFF_DONTCARE3;
        else
            CpuState_nxt = CPUSTATE_IDX_16OFF_DONTCARE2;
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
        if (HD6309 && md[0] && IndexedRegister != IDX_REG_PC) begin
            if (IndexedIndirect) begin
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_INDIRECT_HI;
            end else if (IsJMP(Inst1)) begin
                pc_nxt = ea;
                rLIC = 1'b1;
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end else begin
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_ALU_EA;
            end
        end else if (IndexedRegister == IDX_REG_PC)
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
        if (HD6309 && md[0]) begin
            addr_nxt = 16'hffff;
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_IDX_16OFF_DONTCARE3;
        end else begin
            addr_nxt = pc_p1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_IDX_DOFF_DONTCARE2;
        end
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
        CpuState_nxt = (HD6309 && md[0] && (Inst2 == 8'h9f)) ?
                       CPUSTATE_INDIRECT_HI : CPUSTATE_IDX_EXTIND_DONTCARE;
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
        if (HD6309 && md[0] && a == 8'h01) begin
            {a_nxt,b_nxt} = HDMulFinal;
            cc_nxt[CC_Z_BIT] = (HDMulFinal == 16'h0000);
            cc_nxt[CC_C_BIT] = HDMulFinal[7];
            rLIC = 1'b1;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end else if (a != 8'H00)
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
        CpuState_nxt = (HD6309 && md[0]) ? CPUSTATE_PSH_DONTCARE3 : CPUSTATE_PSH_DONTCARE2;
    end

    CPUSTATE_PSH_DONTCARE2:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_DONTCARE3;
    end

    CPUSTATE_PSH_DONTCARE3:
    begin
        if ((tmp[7:0] == 8'h00) && !tmp[11])
        begin
            // A zero register mask has no stack write cycle.
            addr_nxt = pc;
            rAVMA = 1'b1;
            rLIC = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end
        else
        begin
            addr_nxt = (Inst1[1]) ? u : s;
            CpuState_nxt = CPUSTATE_PSH_ACTION;
        end
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
        else if (tmp[11])
        begin
            addr_nxt = (tmp[14]) ? u_m1 : s_m1;
            if (tmp[14]) u_nxt = u_m1;
            else s_nxt = s_m1;
            DOutput = tmp[15] ? w[15:8] : w[7:0];
            RnWOut = 1'b0;
            if (tmp[15]) begin
                tmp_nxt[11] = 1'b0;
                tmp_nxt[15] = 1'b0;
            end else tmp_nxt[15] = 1'b1;
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
        if ((tmp_nxt[7:0] == 8'H00) && !tmp_nxt[11])
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
        CpuState_nxt = (HD6309 && md[0]) ? CPUSTATE_PUL_ACTION : CPUSTATE_PUL_DONTCARE2;
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
                // Native RTI restores W only when the stacked CC selected an
                // entire frame. A short native FIRQ has E=0 and contains PC/CC.
                tmp_nxt[11] = HD6309 && md[0] && D[CC_E_BIT];
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
        else if (tmp[11])
        begin
            addr_nxt = (tmp[14]) ? u : s;
            if (tmp[14]) u_nxt = u_p1;
            else s_nxt = s_p1;
            if (tmp[15]) begin
                f_nxt = D[7:0];
                tmp_nxt[11] = 1'b0;
                tmp_nxt[15] = 1'b0;
                if (tmp_nxt[7:0] == 8'h00) begin
                    rAVMA = 1'b0;
                    CpuState_nxt = CPUSTATE_6309_WPUL_FINISH;
                end else begin
                    CpuState_nxt = CPUSTATE_PUL_ACTION;
                end
            end else begin
                e_nxt = D[7:0];
                tmp_nxt[15] = 1'b1;
            end
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
        tmp_nxt = 16'H20FF;
        if (HD6309 && md[0]) tmp_nxt[11] = 1'b1;
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        IntType_nxt = INTTYPE_NMI;
        cc_nxt[CC_E_BIT] = 1'b1;
    end

    CPUSTATE_IRQ_START:
    begin
        addr_nxt = pc;
        tmp_nxt = 16'H20FF;
        if (HD6309 && md[0]) tmp_nxt[11] = 1'b1;
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        IntType_nxt = INTTYPE_IRQ;
        cc_nxt[CC_E_BIT] = 1'b1;
    end

    CPUSTATE_FIRQ_START:
    begin
        addr_nxt = pc;
        if (HD6309 && md[1]) begin
            tmp_nxt = 16'H20FF;
            cc_nxt[CC_E_BIT] = 1'b1;
        end else begin
            tmp_nxt = 16'H2081;
            cc_nxt[CC_E_BIT] = 1'b0;
        end
        if (HD6309 && md[0] && md[1]) tmp_nxt[11] = 1'b1;
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_IRQ_DONTCARE;
        IntType_nxt = INTTYPE_FIRQ;
    end

    CPUSTATE_6309_TRAP_START:
    begin
        // HD6309 illegal-instruction and divide exceptions save the full
        // machine state and use the reserved $FFF0 vector, regardless of
        // the legacy ILLEGAL_INSTRUCTIONS simulation policy.
        addr_nxt = pc;
        tmp_nxt = 16'h00ff;
        if (md[0]) tmp_nxt[11] = 1'b1;
        cc_nxt[CC_E_BIT] = 1'b1;
        IntType_nxt = INTTYPE_HD_ILLEGAL;
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_ACTION;
    end

    CPUSTATE_6309_DIVZERO_PAD1:
    begin
        // First post-sample idle E cycle for divide-zero paths whose measured
        // schedule needs two; native direct/extended paths enter at PAD2.
        addr_nxt = pc;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_6309_DIVZERO_PAD2;
    end

    CPUSTATE_6309_DIVZERO_PAD2:
    begin
        addr_nxt = pc;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_6309_DIVZERO_START;
    end

    CPUSTATE_6309_DIVZERO_START:
    begin
        // Divide-by-zero shares the reserved vector but has one fewer
        // post-vector dead cycle than the generic illegal-opcode trap.
        addr_nxt = pc;
        tmp_nxt = 16'h00ff;
        if (md[0]) tmp_nxt[11] = 1'b1;
        cc_nxt[CC_E_BIT] = 1'b1;
        IntType_nxt = INTTYPE_HD_DIVZERO;
        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_ACTION;
    end

    CPUSTATE_SWI_START:
    begin
        addr_nxt = pc;
        tmp_nxt = 16'H00FF; // Save to the S stack, PC, U, Y, X, DP, B, A, CC
        if (HD6309 && md[0]) tmp_nxt[11] = 1'b1;

        NextState_nxt = CPUSTATE_IRQ_DONTCARE2;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_ACTION;
        if (InstPage3)
            IntType_nxt = INTTYPE_SWI3;
        else if (InstPage2)
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
            INTTYPE_HD_ILLEGAL:
            begin
                addr_nxt = `Reserved_VECTOR;
            end
            INTTYPE_HD_DIVZERO:
            begin
                addr_nxt = `Reserved_VECTOR;
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
            INTTYPE_HD_ILLEGAL:
            begin
                addr_nxt = `Reserved_VECTOR+16'H1;
                rLIC = 1'b1;
            end
            INTTYPE_HD_DIVZERO:
            begin
                addr_nxt = `Reserved_VECTOR+16'H1;
                rLIC = 1'b1;
            end
            default:
            begin
            end
        endcase

        pc_nxt[7:0] = D[7:0];
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = (IntType == INTTYPE_HD_DIVZERO) ?
                       CPUSTATE_FETCH_I1 : CPUSTATE_INT_DONTCARE;
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

    CPUSTATE_MD_DONTCARE1:
    begin
        addr_nxt = 16'hFFFF;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_MD_DONTCARE2;
    end

    CPUSTATE_MD_DONTCARE2:
    begin
        addr_nxt = 16'hFFFF;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_RR_WAIT:
    begin
        addr_nxt = 16'hFFFF;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_SEXW_WAIT1:
    begin
        addr_nxt = 16'hFFFF;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_6309_SEXW_WAIT2;
    end

    CPUSTATE_6309_SEXW_WAIT2:
    begin
        addr_nxt = pc;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_BIT_ADDR:
    begin
        ea_nxt = {dp,D[7:0]};
        pc_nxt = pc_p1;
        addr_nxt = pc;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_BIT_READ;
    end

    CPUSTATE_6309_BIT_READ:
    begin
        addr_nxt = ea;
        if (tmp[7:6] == 2'b11) begin
            CpuState_nxt = IllegalInstructionState;
            rLIC = 1'b1;
        end else if (Inst1 == 8'h37) begin
            tmp_nxt[15:8] = (D & ~(8'h01 << tmp[2:0])) |
                            (HDBitRegSrc ? (8'h01 << tmp[2:0]) : 8'h00);
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_BIT_WRITE;
        end else begin
            if (tmp[7:6] == 2'b00) cc_nxt[tmp[2:0]] = HDBitResult;
            else if (tmp[7:6] == 2'b01) a_nxt[tmp[2:0]] = HDBitResult;
            else b_nxt[tmp[2:0]] = HDBitResult;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_BIT_WAIT1;
        end
    end

    CPUSTATE_6309_BIT_WRITE:
    begin
        addr_nxt = ea;
        DOutput = tmp[15:8];
        RnWOut = 1'b0;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_BIT_WAIT1;
    end

    CPUSTATE_6309_BIT_WAIT1:
    begin
        addr_nxt = pc;
        if (md[0]) begin
            rAVMA = 1'b1;
            rLIC = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end else begin
            rAVMA = 1'b0;
            CpuState_nxt = CPUSTATE_6309_BIT_WAIT2;
        end
    end

    CPUSTATE_6309_BIT_WAIT2:
    begin
        addr_nxt = pc;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_TFM_READ:
    begin
        tmp_nxt[15:8] = D[7:0];
        addr_nxt = HDTFMSource;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_TFM_WRITE;
    end

    CPUSTATE_6309_TFM_WRITE:
    begin
        if ((NMILatched == 1'b0) || ((FIRQLatched == 1'b0) && !cc[CC_F_BIT]) ||
            ((IRQLatched == 1'b0) && !cc[CC_I_BIT])) begin
            // TFM may be interrupted after the source read but before the
            // destination write or address-register updates. Re-fetch it on RTI.
            cc_nxt[CC_Z_BIT] = 1'b0;
            pc_nxt = pc - 16'd3;
            addr_nxt = pc - 16'd3;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_FETCH_I1;
        end else begin
            // The original-device X+/X+ capture writes at incremented X after
            // the source read. Other TFM forms use the normal destination EA.
            if ((Inst1 == 8'h38) && (tmp[7:4] == 4'h1) && (tmp[3:0] == 4'h1))
                addr_nxt = x + 16'd1;
            else
                addr_nxt = HDTFMDest;
            DOutput = tmp[15:8];
            RnWOut = 1'b0;
            rAVMA = 1'b1;
            CpuState_nxt = CPUSTATE_6309_TFM_UPDATE;
        end
    end

    CPUSTATE_6309_TFM_UPDATE:
    begin
        if ((tmp[7:4] == tmp[3:0]) && ((Inst1 == 8'h38) || (Inst1 == 8'h39))) begin
            // When both operands name the same register, each side's address
            // update applies, as it does in the reference micro-operations.
            case (tmp[7:4])
                4'h0: {a_nxt,b_nxt} = (Inst1 == 8'h38) ? ({a,b} + 16'd2) : ({a,b} - 16'd2);
                4'h1: x_nxt = (Inst1 == 8'h38) ? (x + 16'd2) : (x - 16'd2);
                4'h2: y_nxt = (Inst1 == 8'h38) ? (y + 16'd2) : (y - 16'd2);
                4'h3: u_nxt = (Inst1 == 8'h38) ? (u + 16'd2) : (u - 16'd2);
                4'h4: s_nxt = (Inst1 == 8'h38) ? (s + 16'd2) : (s - 16'd2);
                default: begin end
            endcase
        end else begin
        if ((Inst1 == 8'h38) || (Inst1 == 8'h3A)) begin
            case (tmp[7:4])
                4'h0: {a_nxt,b_nxt} = {a,b} + 16'd1;
                4'h1: x_nxt = x + 16'd1;
                4'h2: y_nxt = y + 16'd1;
                4'h3: u_nxt = u + 16'd1;
                4'h4: s_nxt = s + 16'd1;
                default: begin end
            endcase
        end else if (Inst1 == 8'h39) begin
            case (tmp[7:4])
                4'h0: {a_nxt,b_nxt} = {a,b} - 16'd1;
                4'h1: x_nxt = x - 16'd1;
                4'h2: y_nxt = y - 16'd1;
                4'h3: u_nxt = u - 16'd1;
                4'h4: s_nxt = s - 16'd1;
                default: begin end
            endcase
        end
        if ((Inst1 == 8'h38) || (Inst1 == 8'h3B)) begin
            case (tmp[3:0])
                4'h0: {a_nxt,b_nxt} = {a,b} + 16'd1;
                4'h1: x_nxt = x + 16'd1;
                4'h2: y_nxt = y + 16'd1;
                4'h3: u_nxt = u + 16'd1;
                4'h4: s_nxt = s + 16'd1;
                default: begin end
            endcase
        end else if (Inst1 == 8'h39) begin
            case (tmp[3:0])
                4'h0: {a_nxt,b_nxt} = {a,b} - 16'd1;
                4'h1: x_nxt = x - 16'd1;
                4'h2: y_nxt = y - 16'd1;
                4'h3: u_nxt = u - 16'd1;
                4'h4: s_nxt = s - 16'd1;
                default: begin end
            endcase
        end
        end
        {e_nxt,f_nxt} = w - 16'd1;
        if (w == 16'd1) CpuState_nxt = CPUSTATE_6309_TFM_FINAL1;
        else CpuState_nxt = CPUSTATE_6309_TFM_READ;
        addr_nxt = 16'hffff;
        rAVMA = 1'b0;
    end

    CPUSTATE_6309_TFM_FINAL1:
    begin
        addr_nxt = 16'hffff;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_6309_TFM_FINAL2;
    end

    CPUSTATE_6309_TFM_FINAL2:
    begin
        addr_nxt = 16'hffff;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_6309_TFM_FINAL3;
    end

    CPUSTATE_6309_TFM_FINAL3:
    begin
        addr_nxt = pc;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        cc_nxt[CC_Z_BIT] = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_ARITH_IMM_LO:
    begin
        addr_nxt = pc;
        pc_nxt = pc_p1;
        tmp_nxt[7:0] = D[7:0];
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_ARITH_EXEC;
    end

    CPUSTATE_6309_ARITH_MEM_LO:
    begin
        addr_nxt = ea;
        tmp_nxt[7:0] = D[7:0];
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_ARITH_EXEC;
    end

    CPUSTATE_6309_ARITH_EXEC:
    begin
        addr_nxt = 16'hffff;
        if (!HDArithStarted) begin
            CpuState_nxt = CPUSTATE_6309_ARITH_EXEC;
            rAVMA = 1'b0;
        end else begin
            tmp_nxt[15] = 1'b0; // One-time DIVD signed-overflow timing adjustment marker.
            tmp_nxt[5:0] = HDArithBaseCycles + HDArithSignCycles - HDArithConsumed;
            CpuState_nxt = CPUSTATE_6309_ARITH_WAIT;
            rAVMA = 1'b0;
        end
    end

    CPUSTATE_6309_ARITH_WAIT:
    begin
        addr_nxt = pc;
        rAVMA = 1'b0;
        if (HDArithComplete && (IsHD6309DivD || IsHD6309DivQ) && HDArithDivideByZero) begin
            md_nxt[7] = 1'b1;
            // The original-device stack/vector schedule uses mode- and
            // addressing-dependent idle E cycles after the final divisor
            // sample; select the measured pad count below.
            cc_nxt[CC_N_BIT] = IsHD6309DivQ;
            cc_nxt[CC_Z_BIT] = 1'b1;
            cc_nxt[CC_V_BIT] = 1'b0;
            CpuState_nxt = (md[0] && (Inst1[7:4] != 4'h8) &&
                            (Inst1[7:4] != 4'ha)) ?
                           CPUSTATE_6309_DIVZERO_PAD2 : CPUSTATE_6309_DIVZERO_PAD1;
            rAVMA = 1'b1;
        end else if (!HDArithComplete) begin
            CpuState_nxt = CPUSTATE_6309_ARITH_WAIT;
            if (tmp[5:0] > 6'd1)
                tmp_nxt[5:0] = tmp[5:0] - 6'd1;
        end else begin
            if (IsHD6309Muld) begin
                {a_nxt,b_nxt} = HDArithResult[31:16];
                {e_nxt,f_nxt} = HDArithResult[15:0];
                cc_nxt[CC_N_BIT] = HDArithFlags[3];
                cc_nxt[CC_Z_BIT] = HDArithFlags[2];
                // The 6309 decoder and individual MULD entry preserve C;
                // Atkinson's consolidated table's C=0 cell conflicts here.
            end else if (HDArithRangeOverflow) begin
                cc_nxt[CC_N_BIT] = HDArithFlags[3];
                cc_nxt[CC_Z_BIT] = HDArithFlags[2];
                cc_nxt[CC_V_BIT] = HDArithFlags[1];
                cc_nxt[CC_C_BIT] = HDArithFlags[0];
                if (IsHD6309DivD) {a_nxt,b_nxt} = HDArithResult[15:0];
                else {a_nxt,b_nxt,e_nxt,f_nxt} = HDArithResult;
            end else begin
                cc_nxt[CC_N_BIT] = HDArithFlags[3];
                cc_nxt[CC_Z_BIT] = HDArithFlags[2];
                cc_nxt[CC_V_BIT] = HDArithFlags[1];
                cc_nxt[CC_C_BIT] = HDArithFlags[0];
                if (IsHD6309DivD) {a_nxt,b_nxt} = HDArithResult[15:0];
                else {a_nxt,b_nxt,e_nxt,f_nxt} = HDArithResult;
            end
            if (!tmp[15]) begin
                tmp_nxt[15] = 1'b1;
                if (HDArithRangeOverflow) begin
                    if (tmp[5:0] <= ((IsHD6309DivD ? 6'd13 : 6'd21) + 6'd1)) begin
                        rLIC = 1'b1;
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                    end else begin
                        tmp_nxt[5:0] = tmp[5:0] -
                                       (IsHD6309DivD ? 6'd14 : 6'd22);
                        CpuState_nxt = CPUSTATE_6309_ARITH_WAIT;
                    end
                end else if (IsHD6309DivD && HDArithFlags[1]) begin
                    if (tmp[5:0] <= 6'd2) begin
                        rLIC = 1'b1;
                        rAVMA = 1'b1;
                        CpuState_nxt = CPUSTATE_FETCH_I1;
                    end else begin
                        tmp_nxt[5:0] = tmp[5:0] - 6'd2;
                        CpuState_nxt = CPUSTATE_6309_ARITH_WAIT;
                    end
                end else if (tmp[5:0] <= 6'd1) begin
                    rLIC = 1'b1;
                    rAVMA = 1'b1;
                    CpuState_nxt = CPUSTATE_FETCH_I1;
                end else begin
                    tmp_nxt[5:0] = tmp[5:0] - 6'd1;
                    CpuState_nxt = CPUSTATE_6309_ARITH_WAIT;
                end
            end else if (tmp[5:0] <= 6'd1) begin
                rLIC = 1'b1;
                rAVMA = 1'b1;
                CpuState_nxt = CPUSTATE_FETCH_I1;
            end else begin
                tmp_nxt[5:0] = tmp[5:0] - 6'd1;
                CpuState_nxt = CPUSTATE_6309_ARITH_WAIT;
            end
        end
    end


    CPUSTATE_6309_WPUL_FINISH:
    begin
        addr_nxt = pc;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = NextState;
    end

    CPUSTATE_Q_IMM2:
    begin
        addr_nxt = addr_p1;
        pc_nxt = pc_p1;
        b_nxt = D[7:0];
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_Q_IMM3;
    end

    CPUSTATE_Q_IMM3:
    begin
        addr_nxt = addr_p1;
        pc_nxt = pc_p1;
        e_nxt = D[7:0];
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_Q_IMM4;
    end

    CPUSTATE_Q_IMM4:
    begin
        addr_nxt = addr_p1;
        pc_nxt = pc_p1;
        f_nxt = D[7:0];
        cc_nxt[CC_N_BIT] = a[7];
        cc_nxt[CC_Z_BIT] = ({a,b,e,D[7:0]} == 32'h00000000);
        cc_nxt[CC_V_BIT] = 1'b0;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_QLOAD2:
    begin
        addr_nxt = ea;
        b_nxt = D[7:0];
        ea_nxt = ea_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_QLOAD3;
    end

    CPUSTATE_6309_QLOAD3:
    begin
        addr_nxt = ea;
        e_nxt = D[7:0];
        ea_nxt = ea_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_QLOAD4;
    end

    CPUSTATE_6309_QLOAD4:
    begin
        addr_nxt = ea;
        f_nxt = D[7:0];
        cc_nxt[CC_N_BIT] = a[7];
        cc_nxt[CC_Z_BIT] = ({a,b,e,D[7:0]} == 32'h00000000);
        cc_nxt[CC_V_BIT] = 1'b0;
        rAVMA = 1'b1;
        rLIC = 1'b1;
        CpuState_nxt = CPUSTATE_FETCH_I1;
    end

    CPUSTATE_6309_QSTORE2:
    begin
        addr_nxt = ea;
        DOutput = b;
        RnWOut = 1'b0;
        ea_nxt = ea_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_QSTORE3;
    end

    CPUSTATE_6309_QSTORE3:
    begin
        addr_nxt = ea;
        DOutput = e;
        RnWOut = 1'b0;
        ea_nxt = ea_p1;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_6309_QSTORE4;
    end

    CPUSTATE_6309_QSTORE4:
    begin
        addr_nxt = ea;
        DOutput = f;
        RnWOut = 1'b0;
        cc_nxt[CC_N_BIT] = a[7];
        cc_nxt[CC_Z_BIT] = (w == 16'h0000) && ({a,b} == 16'h0000);
        cc_nxt[CC_V_BIT] = 1'b0;
        rAVMA = 1'b1;
        rLIC = 1'b1;
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

    CPUSTATE_SYNC_PAD1, CPUSTATE_SYNC_PAD2:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        rLIC = 1'b1;
        CpuState_nxt = (CpuState == CPUSTATE_SYNC_PAD2)
                     ? CPUSTATE_SYNC : CPUSTATE_SYNC_PAD2;
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
        if (HD6309 && md[0]) tmp_nxt[11] = 1'b1;

        NextState_nxt = CPUSTATE_CWAI_PAD1;
        rAVMA = 1'b0;
        CpuState_nxt = CPUSTATE_CWAI_DONTCARE1;
    end

    CPUSTATE_CWAI_DONTCARE1:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b1;
        CpuState_nxt = CPUSTATE_PSH_ACTION;
    end

    // The HD6309 takes 22 E cycles in emulation mode and 20 in native mode
    // before it starts accepting an interrupt.
    CPUSTATE_CWAI_PAD1, CPUSTATE_CWAI_PAD2,
    CPUSTATE_CWAI_PAD3, CPUSTATE_CWAI_PAD4:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        if (HD6309 && md[0] && (CpuState == CPUSTATE_CWAI_PAD2))
            CpuState_nxt = CPUSTATE_CWAI_POST;
        else if (HD6309 && !md[0] && (CpuState == CPUSTATE_CWAI_PAD4))
            CpuState_nxt = CPUSTATE_6309_CWAI_PAD5;
        else
            CpuState_nxt = (CpuState == CPUSTATE_CWAI_PAD4)
                         ? CPUSTATE_CWAI_POST : CpuState + 1'b1;
    end

    CPUSTATE_6309_CWAI_PAD5, CPUSTATE_6309_CWAI_PAD6:
    begin
        addr_nxt = 16'HFFFF;
        rAVMA = 1'b0;
        CpuState_nxt = (CpuState == CPUSTATE_6309_CWAI_PAD5)
                     ? CPUSTATE_6309_CWAI_PAD6 : CPUSTATE_CWAI_POST;
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

/* verilator lint_on CASEX */
/* verilator lint_on UNOPTFLAT */
/* verilator lint_on SIDEEFFECT */
