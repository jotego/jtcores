// jtsuperman_upd78c11.v
// NEC uPD78C11 MCU core, behavioural Verilog.
//
// Modelled on MAME's upd7810 emulator
// (src/devices/cpu/upd7810/, tag mame0287,
//  license:BSD-3-Clause, copyright-holders:Juergen Buchmueller).
// MAME is the reference; the trace harness at cores/risle/tools/mame_trace.lua
// is the verification anchor.
//
// Behavioural interpreter for the uPD78C11 instruction set used by the
// TC0030CMD C-chip.  It is not cycle-accurate; verification is one row per
// instruction retirement against the independent MAME-transcribed fixture.
// Peripheral blocks that the Rainbow Islands command path has not needed yet
// (timers, serial shifter, ADC conversion, full memory-mode remap) remain
// deliberately stubbed.
//
// Memory interface: synchronous single-cycle read. Read states present
// mem_addr for one clock in S_READ_WAIT, then consume mem_din in the
// requested state on the following clock.

`timescale 1ns/1ps

// Imported MCU behavioural model — relax the WIDTHEXPAND lint inside this
// file only.  Many half-carry / borrow expressions mix 4-bit nibble masks
// (& 4'hF) with 8-bit operands by design; rewriting each one is risky for
// no functional gain.  All other lint warnings stay enabled.
/* verilator lint_off WIDTHEXPAND */

module jtsuperman_upd78c11(
    input              clk,
    input              rstn,

    // external memory interface (combinational)
    output      [15:0] mem_addr,
    output       [7:0] mem_dout,
    output             mem_rd,
    output             mem_wr,
    input        [7:0] mem_din,

    // GPIO ports PA/PB/PC/PD — bidirectional in real silicon, modelled as
    // separate in/out buses here. For the first FPGA bring-up, the board
    // will drive the *_in buses from physical pins and take *_out from the
    // latched register values. CR0 is the first ADC result register; tied
    // off to zero externally until an ADC module lands (milestone >5).
    input        [7:0] pa_in,
    input        [7:0] pb_in,
    input        [7:0] pc_in,
    input        [7:0] pd_in,
    input        [7:0] cr0_in,
    // Additional ADC result registers. Real uPD78C10 has CR0-CR3; only
    // CR0 is used in the boot path so far, but CR1 (etc.) come up in
    // EPROM code. Testbench ties them to 0 (no ADC stimulus yet).
    input        [7:0] cr1_in,
    input        [7:0] cr2_in,
    input        [7:0] cr3_in,
    output       [7:0] pa_out,
    output       [7:0] pb_out,
    output       [7:0] pc_out,
    output       [7:0] pd_out,
    output       [7:0] pf_out,

    // External interrupt request — INTF1 (68k command-in). The caller
    // holds this high while the interrupt source is asserting. The core
    // captures the level on an instruction-retire boundary once IFF is
    // set, then dispatches via the $0010 vector.
    input              ext_int1_req,
    // Testbench-only one-shot: when high, force IFF <- 1. Used to
    // bypass the mask ROM's DI during bring-up so the pending INTF1
    // can dispatch. Real silicon uses EI naturally; this hack goes
    // away when we reach an EI organically or integrate with the 68k.
    input              dbg_force_iff,

    // trace taps (mirror the names MAME exports via device.state, in the
    // order the MAME harness writes into _state.tsv)
    output      [15:0] dbg_pc,        // PC the instruction was fetched from
                                      // (matches MAME .tr PC column)
    output      [15:0] dbg_pc_next,   // PC after retire (next instr addr)
    output       [7:0] dbg_a,
    output       [7:0] dbg_v,
    output      [15:0] dbg_bc,
    output      [15:0] dbg_de,
    output      [15:0] dbg_hl,
    output      [15:0] dbg_ea,
    output      [15:0] dbg_sp,
    output       [7:0] dbg_psw,
    output             dbg_iff,
    // Alternate register bank — zero until the first EXA/EXX/EXH swap
    // moves something into it.
    output       [7:0] dbg_ap,
    output       [7:0] dbg_vp,
    output      [15:0] dbg_bcp,
    output      [15:0] dbg_dep,
    output      [15:0] dbg_hlp,
    output      [15:0] dbg_eap,
    output       [7:0] dbg_mm,
    output       [7:0] dbg_mkh,
    output       [7:0] dbg_mkl,
    // single-cycle pulse asserted the cycle an instruction retires — used
    // by the testbench to latch state + emit one TSV row per instruction.
    output reg         dbg_retire,
    // trap: an opcode outside the implemented subset.  Testbench should
    // print context and stop.
    output             dbg_trap
);

// --------------- register file ---------------------------------------------
reg [15:0] pc;
reg [15:0] fetch_pc;   // PC the current instruction was fetched FROM —
                       // matches the address MAME's `.tr` puts in its PC column.
reg [15:0] sp;
reg [15:0] reg_ea;     // EA (aggregated as a 16-bit reg; low = EAL, high = EAH)
reg  [7:0] reg_a, reg_v;
reg  [7:0] reg_b, reg_c;
reg  [7:0] reg_d, reg_e;
reg  [7:0] reg_h, reg_l;
reg  [7:0] psw;
reg        iffr;
reg        iff_pending;

// Alternate register bank (A'/V'/BC'/DE'/HL'/EA'). Swapped in/out by
// EXA (0x10), EXX (0x11), EXH (0x50). Start zeroed at reset — MAME's
// upd7810.cpp initialises them the same way in device_reset().
reg [15:0] reg_eap;
reg  [7:0] reg_ap, reg_vp;
reg  [7:0] reg_bp, reg_cp;
reg  [7:0] reg_dp, reg_ep;
reg  [7:0] reg_hp, reg_lp;

// special-function registers
reg  [7:0] reg_mm;
reg  [7:0] reg_mcc;
reg  [7:0] reg_ma, reg_mb, reg_mc;
reg  [7:0] reg_mf;
reg  [7:0] reg_mkh, reg_mkl;
reg  [7:0] reg_anm;
reg  [7:0] reg_tmm;
reg  [7:0] reg_smh;            // serial-mode high (m37)
reg  [7:0] reg_sml;            // serial-mode low (stub latch)
reg  [7:0] reg_txb;            // serial transmit buffer (stub latch)
reg  [7:0] reg_etmm;           // event-timer mode (stub latch)
reg  [7:0] reg_mt, reg_zcm;    // 7807/ZC mode stubs
reg  [7:0] reg_eom;            // event-output mode (m37)
reg [15:0] reg_etm0;           // event-timer modulo 0 (m40, write-only stub)
reg [15:0] reg_etm1;           // event-timer modulo 1 (m40, write-only stub)
reg  [7:0] reg_pa, reg_pb, reg_pc, reg_pd;  // GPIO output latches
reg  [7:0] reg_pf;                           // Port F mask / output latch

assign pa_out = reg_pa;
assign pb_out = reg_pb;
assign pc_out = reg_pc;
assign pd_out = reg_pd;
assign pf_out = reg_pf;

assign dbg_pc      = fetch_pc;
assign dbg_pc_next = pc;
assign dbg_a   = reg_a;
assign dbg_v   = reg_v;
assign dbg_bc  = {reg_b, reg_c};
assign dbg_de  = {reg_d, reg_e};
assign dbg_hl  = {reg_h, reg_l};
assign dbg_ea  = reg_ea;
assign dbg_sp  = sp;
assign dbg_psw = psw;
assign dbg_iff = iffr;
assign dbg_ap  = reg_ap;
assign dbg_vp  = reg_vp;
assign dbg_bcp = {reg_bp, reg_cp};
assign dbg_dep = {reg_dp, reg_ep};
assign dbg_hlp = {reg_hp, reg_lp};
assign dbg_eap = reg_eap;
assign dbg_mm  = reg_mm;
assign dbg_mkh = reg_mkh;
assign dbg_mkl = reg_mkl;

// --------------- FSM -------------------------------------------------------
// States name the NEXT byte to fetch (if any) and the execution step.
// External memory is synchronous: read states are entered through
// S_READ_WAIT so mem_addr is presented one clock before mem_din is used.
localparam S_FETCH_OP    = 6'd0;
localparam S_FETCH_PFX   = 6'd1;
localparam S_FETCH_IM1   = 6'd2;
localparam S_FETCH_IM2   = 6'd3;
localparam S_EXECUTE     = 6'd4;
localparam S_MEM_WRITE   = 6'd5;   // d70 0x79: MOV (imm16),A  one-cycle store
localparam S_STAX_HL_INC = 6'd6;   // 0x3D: store A at (HL), then HL <- HL+1
localparam S_LDAX_HL_INC = 6'd7;   // 0x2D: load A from (HL), then HL <- HL+1
localparam S_CALL_PUSH_H = 6'd8;   // 0x40: SP <- SP-1; (SP) <- PC_hi
localparam S_CALL_PUSH_L = 6'd9;   // 0x40: SP <- SP-1; (SP) <- PC_lo; PC <- target
localparam S_RET_POP_L   = 6'd10;  // 0xB8: PC_lo <- (SP); SP <- SP+1
localparam S_RET_POP_H   = 6'd11;  // 0xB8: PC_hi <- (SP); SP <- SP+1
localparam S_REG_PUSH_H  = 6'd12;  // 0xB0-B4 PUSH VA/BC/DE/HL/EA — push high byte
localparam S_REG_PUSH_L  = 6'd13;  // 0xB0-B4                     — push low byte
localparam S_REG_POP_L   = 6'd14;  // 0xA0-A4 POP                 — pop low byte
localparam S_REG_POP_H   = 6'd15;  // 0xA0-A4                     — pop high byte
localparam S_SHLD_L      = 6'd16;  // d70 0x3E: write L at (imm16)
//                                    d70 0x0E: SSPD — write SPL at (imm16)
localparam S_SHLD_H      = 6'd17;  // d70 0x3E: write H at (imm16)+1
//                                    d70 0x0E: SSPD — write SPH at (imm16)+1
localparam S_MEM_READ_A  = 6'd18;  // d70 0x69: A <- (imm16)
localparam S_INDX        = 6'd19;  // d70 0x89-0xFF: indirect arith/logic
                                   // (ANAX/XRAX/ORAX, ADDNCX/GTAX/SUBNBX/LTAX,
                                   //  ADDX/ONAX/ADCX/OFFAX, SUBX/NEAX/SBBX/EQAX
                                   //  with 7 addressing modes each).  m30.
localparam S_TABLE_LO    = 6'd20;  // d48 0xA8: read (PC+A+1) -> C
localparam S_TABLE_HI    = 6'd21;  // d48 0xA8: read (PC+A+2) -> B
localparam S_CALT_READ_L = 6'd22;  // 0x80-9F: read (0x80+2i) -> imm_lo
localparam S_CALT_READ_H = 6'd23;  // 0x80-9F: read (0x80+2i+1) -> imm_hi; PC <- {hi,lo}
localparam S_LDAX_DE_INC = 6'd24;  // 0x2C: load A from (DE), then DE <- DE+1
// Interrupt entry pushes {PSW, PCH, PCL} in MAME's order (PSW first) and
// vectors to $0010 for INTF1. RETI undoes them in reverse and leaves IFF
// unchanged, per MAME. Clearing SK/L0/L1 prevents the ISR's first instruction
// from being skipped.
localparam S_INT_PSW     = 6'd25;  // push PSW at (SP-1), SP--
localparam S_INT_PCH     = 6'd26;  // push PC[15:8] at (SP-1), SP--
localparam S_INT_PCL     = 6'd27;  // push PC[7:0] at (SP-1), SP--, jump to vector
localparam S_RETI_PCL    = 6'd28;  // pop PC[7:0] from (SP), SP++
localparam S_RETI_PCH    = 6'd29;  // pop PC[15:8], assemble PC, SP++
localparam S_RETI_PSW    = 6'd30;  // pop PSW, SP++, retire
// Indirect memory ops — no auto-inc/dec. Address from a regpair selected
// by opcode low 3 bits (B/D/H via MAME convention: 0x29/2A/2B LDAX,
// 0x39/3A/3B STAX). Read form lands A; write form emits A.
localparam S_LDAX_IND    = 6'd31;  // 0x29/2A/2B LDAX (BC)/(DE)/(HL)
localparam S_STAX_IND    = 6'd32;  // 0x39/3A/3B STAX (BC)/(DE)/(HL)
localparam S_LSPD_LO     = 6'd33;  // d70 0x0F: SP_lo <- (imm16)
localparam S_LSPD_HI     = 6'd34;  // d70 0x0F: SP_hi <- (imm16)+1
localparam S_LDEAX_LO    = 6'd35;  // d48 0x82-0x8F: EAL <- (base_addr)
localparam S_LDEAX_HI    = 6'd36;  // d48 0x82-0x8F: EAH <- (base_addr)+1
localparam S_STEAX_LO    = 6'd45;  // d48 0x92-0x9F: (base_addr)   <- EAL  (m34)
localparam S_STEAX_HI    = 6'd46;  // d48 0x92-0x9F: (base_addr+1) <- EAH  (m34)
localparam S_RLDRRD_RD   = 6'd47;  // d48 0x38/0x39 RLD/RRD: read (HL) (m36)
localparam S_RLDRRD_WR   = 6'd48;  // d48 0x38/0x39 RLD/RRD: write (HL) (m36)
localparam S_LDAX_OFF    = 6'd49;  // primary 0xAB-0xAF LDAX with offset (m41)
localparam S_STAX_OFF    = 6'd50;  // primary 0xBB-0xBF STAX with offset (m41)
localparam S_BLOCK_RD    = 6'd51;  // primary 0x31 BLOCK: read (HL) (m42)
localparam S_BLOCK_WR    = 6'd52;  // primary 0x31 BLOCK: write (DE) (m42)
localparam S_READ_WAIT   = 6'd53;  // present read address for one cycle
localparam S_DIV_STEP    = 6'd54;  // d48 0x3D/3E/3F multi-cycle divider
// Page-address ops at primary 0x01/05/15/20/25/30/35/45/55/58-5F/63/65/71/75.
// Effective address = {V, wa} where wa is the first immediate byte.
//   S_PAGE_RD: read at {V,wa}; for read-only ops finalise & retire here.
//              For RMW ops (ANIW/ORIW/INRW/DCRW) compute new value into
//              imm_hi via NBA, transition to S_PAGE_WR.
//   S_PAGE_WR: write {V,wa} <- imm_hi (RMW + MVIW) or reg_a (STAW).
// MVIX_BC/DE/HL_xx (primary 0x49/4A/4B): write imm_lo at indirect from
// regpair selected by opcode low 3 bits.  S_MVIX shares the write step.
localparam S_PAGE_RD     = 6'd37;
localparam S_PAGE_WR     = 6'd38;
localparam S_MVIX        = 6'd39;
// LDAX/STAX with auto-decrement (m variants); + STAX_Dp.
localparam S_LDAX_DE_DEC = 6'd40;  // 0x2E LDAX (DE-)
localparam S_LDAX_HL_DEC = 6'd41;  // 0x2F LDAX (HL-)
localparam S_STAX_DE_INC = 6'd42;  // 0x3C STAX (DE+)
localparam S_STAX_DE_DEC = 6'd43;  // 0x3E STAX (DE-)
localparam S_STAX_HL_DEC = 6'd44;  // 0x3F STAX (HL-)
// SOFTI: software-interrupt entry to vector $0060.  Reuses S_INT_PSW/PCH/PCL
// pattern except for the vector address; we add an opcode discriminator
// inside S_INT_PCL to switch between $0010 (INTF1) and $0060 (SOFTI).
// RETS: like RET but sets SK at retire.  Reuses S_RET_POP_L/H.
localparam S_TRAP        = 6'd63;

reg [5:0] state;
reg [5:0] read_wait_state;
reg [7:0] opcode;   // first byte of the instruction (the primary opcode)
reg [7:0] sub_op;   // second byte when opcode is a prefix (0 otherwise)
reg [7:0] imm_lo, imm_hi;
reg [7:0] pc_lo_tmp; // RET holds pop'd low byte here across S_RET_POP_L -> _H
reg       int1_pending; // latched INTF1 request, cleared on dispatch
reg       softi_entry;  // S_INT_* path vector/PSW behavior selector
reg [15:0] div_quot;
reg  [8:0] div_rem;
reg  [7:0] div_divisor;
reg  [4:0] div_count;
reg  [1:0] div_sel;

function is_mem_read_state(input [5:0] s);
    case (s)
        S_FETCH_OP, S_FETCH_PFX, S_FETCH_IM1, S_FETCH_IM2,
        S_LDAX_HL_INC, S_LDAX_DE_INC, S_LDAX_IND,
        S_LSPD_LO, S_LSPD_HI, S_MEM_READ_A, S_INDX,
        S_TABLE_LO, S_TABLE_HI, S_LDEAX_LO, S_LDEAX_HI,
        S_RLDRRD_RD, S_LDAX_OFF, S_BLOCK_RD,
        S_CALT_READ_L, S_CALT_READ_H,
        S_RET_POP_L, S_RET_POP_H, S_REG_POP_L, S_REG_POP_H,
        S_RETI_PCL, S_RETI_PCH, S_RETI_PSW,
        S_PAGE_RD, S_LDAX_DE_DEC, S_LDAX_HL_DEC:
            is_mem_read_state = 1'b1;
        default:
            is_mem_read_state = 1'b0;
    endcase
endfunction

task goto_state(input [5:0] next_state);
    begin
        if (is_mem_read_state(next_state)) begin
            read_wait_state <= next_state;
            state           <= S_READ_WAIT;
        end else begin
            state           <= next_state;
        end
    end
endtask

// --------------- combinational decode helpers ------------------------------
function is_prefix_op(input [7:0] op);
    is_prefix_op = (op == 8'h48) || (op == 8'h4C) || (op == 8'h4D)
                || (op == 8'h60) || (op == 8'h64) || (op == 8'h70)
                || (op == 8'h74);
endfunction

// imm-byte count for a primary (non-prefix) opcode, in our supported subset
function [1:0] imm_count_primary(input [7:0] op);
    casez (op)
        8'h00:                                      imm_count_primary = 2'd0; // NOP
        8'hAA, 8'hBA:                               imm_count_primary = 2'd0; // EI / DI
        8'h02, 8'h12, 8'h22, 8'h32:                 imm_count_primary = 2'd0; // INX SP/BC/DE/HL
        8'h03, 8'h13, 8'h23, 8'h33:                 imm_count_primary = 2'd0; // DCX SP/BC/DE/HL
        8'h29, 8'h2A, 8'h2B:                        imm_count_primary = 2'd0; // LDAX (BC)/(DE)/(HL)
        8'h2C:                                      imm_count_primary = 2'd0; // LDAX (DE+)
        8'h2D:                                      imm_count_primary = 2'd0; // LDAX (HL+)
        8'h2E:                                      imm_count_primary = 2'd0; // LDAX (DE-)
        8'h2F:                                      imm_count_primary = 2'd0; // LDAX (HL-)
        8'h39, 8'h3A, 8'h3B:                        imm_count_primary = 2'd0; // STAX (BC)/(DE)/(HL)
        8'h3C:                                      imm_count_primary = 2'd0; // STAX (DE+)
        8'h3D:                                      imm_count_primary = 2'd0; // STAX (HL+)
        8'h3E:                                      imm_count_primary = 2'd0; // STAX (DE-)
        8'h3F:                                      imm_count_primary = 2'd0; // STAX (HL-)
        8'h61:                                      imm_count_primary = 2'd0; // DAA
        8'h72:                                      imm_count_primary = 2'd0; // SOFTI
        8'hB9:                                      imm_count_primary = 2'd0; // RETS
        8'b01111???:                                imm_count_primary = 2'd1; // CALF 0x78-0x7F
        8'h21:                                      imm_count_primary = 2'd0; // JB (PC <- BC)
        8'h31:                                      imm_count_primary = 2'd0; // BLOCK (m42)
        8'b100?????:                                imm_count_primary = 2'd0; // CALT 0x80-0x9F
        8'h41, 8'h42, 8'h43:                        imm_count_primary = 2'd0; // INR A/B/C
        8'h51, 8'h52, 8'h53:                        imm_count_primary = 2'd0; // DCR A/B/C
        8'hA0, 8'hA1, 8'hA2, 8'hA3, 8'hA4:          imm_count_primary = 2'd0; // POP VA/BC/DE/HL/EA
        // LDAX/STAX with offset (m41).  *_xx forms (0xAB/AF/BB/BF) take 1
        // imm byte; *_A/*_B/*_EA forms (0xAC-AE/0xBC-BE) take 0.
        8'hAB, 8'hAF, 8'hBB, 8'hBF:                 imm_count_primary = 2'd1;
        8'hAC, 8'hAD, 8'hAE,
        8'hBC, 8'hBD, 8'hBE:                        imm_count_primary = 2'd0;
        8'hA8:                                      imm_count_primary = 2'd0; // INX EA
        8'hA9:                                      imm_count_primary = 2'd0; // DCX EA
        8'hB0, 8'hB1, 8'hB2, 8'hB3, 8'hB4:          imm_count_primary = 2'd0; // PUSH VA/BC/DE/HL/EA
        8'hB8:                                      imm_count_primary = 2'd0; // RET
        8'h62:                                      imm_count_primary = 2'd0; // RETI
        8'h08, 8'h09,
        8'h0A, 8'h0B, 8'h0C, 8'h0D, 8'h0E, 8'h0F,
        8'h18, 8'h19,
        8'h1A, 8'h1B, 8'h1C, 8'h1D, 8'h1E, 8'h1F:   imm_count_primary = 2'd0; // MOV reg-reg
        8'h10, 8'h11, 8'h50:                        imm_count_primary = 2'd0; // EXA / EXX / EXH
        8'h68, 8'h69, 8'h6A, 8'h6B,
        8'h6C, 8'h6D, 8'h6E, 8'h6F:                 imm_count_primary = 2'd1; // MVI r,b
        8'h07, 8'h16, 8'h17:                        imm_count_primary = 2'd1; // ANI/XRI/ORI A,imm
        8'h26, 8'h36, 8'h46, 8'h56, 8'h66, 8'h76:   imm_count_primary = 2'd1; // ADINC/SUINB/ADI/ACI/SUI/SBI A,imm
        8'h27, 8'h37, 8'h47, 8'h57:                 imm_count_primary = 2'd1; // GTI/LTI/ONI/OFFI A,imm
        8'h67:                                      imm_count_primary = 2'd1; // NEI A,imm
        8'h77:                                      imm_count_primary = 2'd1; // EQI A,imm
        8'h4E, 8'h4F:                               imm_count_primary = 2'd1; // JRE (9-bit rel)
        8'h04, 8'h14, 8'h24, 8'h34, 8'h44:          imm_count_primary = 2'd2; // LXI SP/BC/DE/HL/EA,w
        8'h40:                                      imm_count_primary = 2'd2; // CALL w
        8'h54:                                      imm_count_primary = 2'd2; // JMP w
        // Page-address family (V:wa addressing).  All take wa as the first
        // immediate byte.  The 3-byte ones additionally take a data/imm byte.
        8'h01:                                      imm_count_primary = 2'd1; // LDAW wa
        8'h63:                                      imm_count_primary = 2'd1; // STAW wa
        8'h20:                                      imm_count_primary = 2'd1; // INRW wa
        8'h30:                                      imm_count_primary = 2'd1; // DCRW wa
        8'h58, 8'h59, 8'h5A, 8'h5B,
        8'h5C, 8'h5D, 8'h5E, 8'h5F:                 imm_count_primary = 2'd1; // BIT n,wa
        8'h05, 8'h15, 8'h25, 8'h35,
        8'h45, 8'h55, 8'h65, 8'h75,
        8'h71:                                      imm_count_primary = 2'd2; // {ANIW,ORIW,GTIW,LTIW,ONIW,OFFIW,NEIW,EQIW,MVIW} wa,xx
        8'h49, 8'h4A, 8'h4B:                        imm_count_primary = 2'd1; // MVIX (BC/DE/HL),xx
        8'b11??????:                                imm_count_primary = 2'd0; // JR (0xC0-0xFF)
        default:                                    imm_count_primary = 2'd0; // trap
    endcase
endfunction

// MAME clears L0/L1 before skip/execution according to the primary opcode
// table mask.  Almost every opcode clears both; the overlay forms preserve
// the bit they test/set.
function [7:0] l0_l1_clear_mask(input [7:0] op);
    case (op)
        8'h34:   l0_l1_clear_mask = 8'h08; // LXI H,w preserves L0
        8'h69:   l0_l1_clear_mask = 8'h04; // MVI A,xx preserves L1
        8'h6F:   l0_l1_clear_mask = 8'h08; // MVI L,xx preserves L0
        default: l0_l1_clear_mask = 8'h0C; // clear L0 and L1
    endcase
endfunction

// imm-byte count for a (prefix, subop) pair, in our supported subset
function [1:0] imm_count_prefix(input [7:0] pre, input [7:0] sub);
    casez ({pre, sub})
        // d48 SK/SKN family : 0 extra bytes
        16'h4808, 16'h480A, 16'h480B, 16'h480C,
        16'h4818, 16'h481A, 16'h481B, 16'h481C,
        // d48 misc 1-byte ops (no immediate after the sub-op byte)
        16'h4828, 16'h4829,                         // JEA, CALB
        16'h482D, 16'h482E, 16'h482F,               // MUL A/B/C
        16'h483A,
        // d48 misc inline ops (m35): HALT, STOP, DIV, DSLR/DSLL/DRLR/DRLL EA.
        16'h483B, 16'h48BB,                         // HALT, STOP
        16'h483D, 16'h483E, 16'h483F,               // DIV A/B/C
        16'h4838, 16'h4839,                         // RLD, RRD (m36)
        16'h48A0, 16'h48A4, 16'h48B0, 16'h48B4,     // DSLR/DSLL/DRLR/DRLL EA
        // SKIT/SKNIT family (m39): 36 ops (SKIT 0x40-0x4C+0x50-0x54,
        // SKNIT 0x60-0x6C+0x70-0x74).  Each takes 0 imm bytes after sub.
        16'h4840, 16'h4841, 16'h4842, 16'h4843,
        16'h4844, 16'h4845, 16'h4846, 16'h4847,
        16'h4848, 16'h4849, 16'h484A, 16'h484B,
        16'h484C,
        16'h4850, 16'h4851, 16'h4852, 16'h4853,
        16'h4854,
        16'h4860, 16'h4861, 16'h4862, 16'h4863,
        16'h4864, 16'h4865, 16'h4866, 16'h4867,
        16'h4868, 16'h4869, 16'h486A, 16'h486B,
        16'h486C,
        16'h4870, 16'h4871, 16'h4872, 16'h4873,
        16'h4874,
        // DMOV timer regs (m40): all 0 imm bytes after sub.
        16'h48C0, 16'h48C1, 16'h48D2, 16'h48D3:     imm_count_prefix = 2'd0;
        // d48 LDEAX/STEAX family (m34): most variants take 0 imm bytes.
        // The _D_xx (0x8B/0x9B) and _H_xx (0x8F/0x9F) forms take 1 imm
        // byte (the offset).
        16'h4882, 16'h4884, 16'h4885,
        16'h488C, 16'h488D, 16'h488E,
        16'h4892, 16'h4893, 16'h4894, 16'h4895,
        16'h489C, 16'h489D, 16'h489E:               imm_count_prefix = 2'd0;
        16'h488B, 16'h488F, 16'h489B, 16'h489F:     imm_count_prefix = 2'd1;
        // d48 TABLE : 0 extra bytes
        16'h48A8:                                   imm_count_prefix = 2'd0;
        // d4C MOV A,SFR : 0 extra bytes after sub.  Use a casez wildcard
        // to also catch the unmapped sub-ops that the EXECUTE block
        // handles as "read 0xFF" (silent no-trap).  m40.
        16'b0100_1100_????_????:                    imm_count_prefix = 2'd0;
        // d4D MOV SFR,A : 0 extra bytes after sub (same wildcard).
        16'b0100_1101_????_????:                    imm_count_prefix = 2'd0;
        // d64 SFR ops: every valid sub-op takes 1 imm byte after sub.
        // Use a casez on {pre,sub} where pre is exactly 0x64.  m38
        // generalisation covers all 14 op types on lower-half SFRs
        // (PA/PB/PC/PD/PF/MKH/MKL) and upper-half (ANM/SMH/EOM/TMM).
        16'b0110_0100_????_????:                    imm_count_prefix = 2'd1;
        // d60 prefix: register-register arithmetic/logic. imm_count = 0.
        // Currently implemented subset:
        //   0x08-0x0F ANA reg,A      0x10-0x17 XRA reg,A      0x18-0x1F ORA reg,A
        //   0x88-0x8F ANA A,reg      0x90-0x97 XRA A,reg      0x98-0x9F ORA A,reg
        //   0xC0-0xC7 ADD A,reg
        16'h6008, 16'h6009, 16'h600A, 16'h600B,
        16'h600C, 16'h600D, 16'h600E, 16'h600F,
        16'h6010, 16'h6011, 16'h6012, 16'h6013,
        16'h6014, 16'h6015, 16'h6016, 16'h6017,
        16'h6018, 16'h6019, 16'h601A, 16'h601B,
        16'h601C, 16'h601D, 16'h601E, 16'h601F,
        // d60 reg-dest arithmetic: ADDNC/GTA/SUBNB/LTA at 0x20-0x3F,
        // ADD/(illegal)/ADC/(illegal) at 0x40-0x5F, SUB/NEA/SBB/EQA at
        // 0x60-0x7F.  (0x08-0x1F handled below as logic ops; 0x80-0x9F
        // are A-dest logic ops.)
        16'h6020, 16'h6021, 16'h6022, 16'h6023,
        16'h6024, 16'h6025, 16'h6026, 16'h6027,
        16'h6028, 16'h6029, 16'h602A, 16'h602B,
        16'h602C, 16'h602D, 16'h602E, 16'h602F,
        16'h6030, 16'h6031, 16'h6032, 16'h6033,
        16'h6034, 16'h6035, 16'h6036, 16'h6037,
        16'h6038, 16'h6039, 16'h603A, 16'h603B,
        16'h603C, 16'h603D, 16'h603E, 16'h603F,
        16'h6040, 16'h6041, 16'h6042, 16'h6043,
        16'h6044, 16'h6045, 16'h6046, 16'h6047,
        16'h6050, 16'h6051, 16'h6052, 16'h6053,
        16'h6054, 16'h6055, 16'h6056, 16'h6057,
        16'h6060, 16'h6061, 16'h6062, 16'h6063,
        16'h6064, 16'h6065, 16'h6066, 16'h6067,
        16'h6068, 16'h6069, 16'h606A, 16'h606B,
        16'h606C, 16'h606D, 16'h606E, 16'h606F,
        16'h6070, 16'h6071, 16'h6072, 16'h6073,
        16'h6074, 16'h6075, 16'h6076, 16'h6077,
        16'h6078, 16'h6079, 16'h607A, 16'h607B,
        16'h607C, 16'h607D, 16'h607E, 16'h607F,
        16'h6088, 16'h6089, 16'h608A, 16'h608B,
        16'h608C, 16'h608D, 16'h608E, 16'h608F,
        16'h6090, 16'h6091, 16'h6092, 16'h6093,
        16'h6094, 16'h6095, 16'h6096, 16'h6097,
        16'h6098, 16'h6099, 16'h609A, 16'h609B,
        16'h609C, 16'h609D, 16'h609E, 16'h609F,
        // d60 A-dest arithmetic: ADDNC/GTA/SUBNB/LTA at 0xA0-0xBF,
        // ADD/ONA/ADC/OFFA at 0xC0-0xDF, SUB/NEA/SBB/EQA at 0xE0-0xFF.
        // Each row is 8 sub-ops selecting source register.
        16'h60A0, 16'h60A1, 16'h60A2, 16'h60A3,
        16'h60A4, 16'h60A5, 16'h60A6, 16'h60A7,
        16'h60A8, 16'h60A9, 16'h60AA, 16'h60AB,
        16'h60AC, 16'h60AD, 16'h60AE, 16'h60AF,
        16'h60B0, 16'h60B1, 16'h60B2, 16'h60B3,
        16'h60B4, 16'h60B5, 16'h60B6, 16'h60B7,
        16'h60B8, 16'h60B9, 16'h60BA, 16'h60BB,
        16'h60BC, 16'h60BD, 16'h60BE, 16'h60BF,
        16'h60C0, 16'h60C1, 16'h60C2, 16'h60C3,
        16'h60C4, 16'h60C5, 16'h60C6, 16'h60C7,
        16'h60C8, 16'h60C9, 16'h60CA, 16'h60CB,
        16'h60CC, 16'h60CD, 16'h60CE, 16'h60CF,
        16'h60D0, 16'h60D1, 16'h60D2, 16'h60D3,
        16'h60D4, 16'h60D5, 16'h60D6, 16'h60D7,
        16'h60D8, 16'h60D9, 16'h60DA, 16'h60DB,
        16'h60DC, 16'h60DD, 16'h60DE, 16'h60DF,
        16'h60E0, 16'h60E1, 16'h60E2, 16'h60E3,
        16'h60E4, 16'h60E5, 16'h60E6, 16'h60E7,
        16'h60E8, 16'h60E9, 16'h60EA, 16'h60EB,
        16'h60EC, 16'h60ED, 16'h60EE, 16'h60EF,
        16'h60F0, 16'h60F1, 16'h60F2, 16'h60F3,
        16'h60F4, 16'h60F5, 16'h60F6, 16'h60F7,
        16'h60F8, 16'h60F9, 16'h60FA, 16'h60FB,
        16'h60FC, 16'h60FD, 16'h60FE, 16'h60FF:     imm_count_prefix = 2'd0;
        // d70 prefix:
        //   0x41 EADD EA,A           : no extra bytes
        //   0x79 MOV (addr16),A      : 2 bytes (addr lo, hi)
        //   0x3E SHLD  (addr16)      : 2 bytes (addr lo, hi)
        16'h7041:                                   imm_count_prefix = 2'd0;
        // EADD EA,B/C and ESUB EA,A/B/C (m33): 0 imm bytes after sub.
        16'h7042, 16'h7043,                         // EADD EA,B/C
        16'h7061, 16'h7062, 16'h7063:               imm_count_prefix = 2'd0; // ESUB EA,A/B/C
        // SBCD/LBCD (addr16) (m33): 2 imm bytes (addr lo, hi) after sub.
        16'h701E, 16'h701F:                         imm_count_prefix = 2'd2;
        // d70 indirect arith/logic family (m30): 105 sub-ops, each takes
        // 0 imm bytes after the sub-op.  ANAX/XRAX/ORAX +
        // ADDNCX/GTAX/SUBNBX/LTAX + ADDX/ONAX/ADCX/OFFAX +
        // SUBX/NEAX/SBBX/EQAX, with 7 addressing modes per op.
        16'h7089, 16'h708A, 16'h708B, 16'h708C, 16'h708D, 16'h708E, 16'h708F,
        16'h7091, 16'h7092, 16'h7093, 16'h7094, 16'h7095, 16'h7096, 16'h7097,
        16'h7099, 16'h709A, 16'h709B, 16'h709C, 16'h709D, 16'h709E, 16'h709F,
        16'h70A1, 16'h70A2, 16'h70A3, 16'h70A4, 16'h70A5, 16'h70A6, 16'h70A7,
        16'h70A9, 16'h70AA, 16'h70AB, 16'h70AC, 16'h70AD, 16'h70AE, 16'h70AF,
        16'h70B1, 16'h70B2, 16'h70B3, 16'h70B4, 16'h70B5, 16'h70B6, 16'h70B7,
        16'h70B9, 16'h70BA, 16'h70BB, 16'h70BC, 16'h70BD, 16'h70BE, 16'h70BF,
        16'h70C1, 16'h70C2, 16'h70C3, 16'h70C4, 16'h70C5, 16'h70C6, 16'h70C7,
        16'h70C9, 16'h70CA, 16'h70CB, 16'h70CC, 16'h70CD, 16'h70CE, 16'h70CF,
        16'h70D1, 16'h70D2, 16'h70D3, 16'h70D4, 16'h70D5, 16'h70D6, 16'h70D7,
        16'h70D9, 16'h70DA, 16'h70DB, 16'h70DC, 16'h70DD, 16'h70DE, 16'h70DF,
        16'h70E1, 16'h70E2, 16'h70E3, 16'h70E4, 16'h70E5, 16'h70E6, 16'h70E7,
        16'h70E9, 16'h70EA, 16'h70EB, 16'h70EC, 16'h70ED, 16'h70EE, 16'h70EF,
        16'h70F1, 16'h70F2, 16'h70F3, 16'h70F4, 16'h70F5, 16'h70F6, 16'h70F7,
        16'h70F9, 16'h70FA, 16'h70FB, 16'h70FC, 16'h70FD, 16'h70FE, 16'h70FF: imm_count_prefix = 2'd0;
        // MOV reg,(addr16)  — 0x68 V, 0x69 A, 0x6A B, 0x6B C,
        //                    0x6C D, 0x6D E, 0x6E H, 0x6F L
        16'h7068, 16'h7069, 16'h706A, 16'h706B,
        16'h706C, 16'h706D, 16'h706E, 16'h706F:     imm_count_prefix = 2'd2;
        // MOV (addr16),reg (m33): 2 imm bytes (addr lo, hi) after sub.
        // 0x78 V, 0x79 A (m12), 0x7A B, 0x7B C, 0x7C D, 0x7D E, 0x7E H, 0x7F L.
        16'h7078, 16'h7079, 16'h707A, 16'h707B,
        16'h707C, 16'h707D, 16'h707E, 16'h707F:     imm_count_prefix = 2'd2;
        // d74 reg,xx forms — every sub-op in 0x08-0x7F takes 1 imm byte:
        //   0x08-0x1F: ANI / XRI / ORI reg,xx               (logic, m28)
        //   0x20-0x67: ADINC/GTI/SUINB/LTI/ADI/ONI/ACI/OFFI/SUI reg,xx (arith, m29)
        //   0x68-0x6F: NEI reg,xx                            (compare, m28)
        //   0x70-0x77: SBI reg,xx                            (arith, m29)
        //   0x78-0x7F: EQI reg,xx                            (compare, m28)
        16'h7408, 16'h7409, 16'h740A, 16'h740B,
        16'h740C, 16'h740D, 16'h740E, 16'h740F,
        16'h7410, 16'h7411, 16'h7412, 16'h7413,
        16'h7414, 16'h7415, 16'h7416, 16'h7417,
        16'h7418, 16'h7419, 16'h741A, 16'h741B,
        16'h741C, 16'h741D, 16'h741E, 16'h741F,
        16'h7420, 16'h7421, 16'h7422, 16'h7423,
        16'h7424, 16'h7425, 16'h7426, 16'h7427,
        16'h7428, 16'h7429, 16'h742A, 16'h742B,
        16'h742C, 16'h742D, 16'h742E, 16'h742F,
        16'h7430, 16'h7431, 16'h7432, 16'h7433,
        16'h7434, 16'h7435, 16'h7436, 16'h7437,
        16'h7438, 16'h7439, 16'h743A, 16'h743B,
        16'h743C, 16'h743D, 16'h743E, 16'h743F,
        16'h7440, 16'h7441, 16'h7442, 16'h7443,
        16'h7444, 16'h7445, 16'h7446, 16'h7447,
        16'h7448, 16'h7449, 16'h744A, 16'h744B,
        16'h744C, 16'h744D, 16'h744E, 16'h744F,
        16'h7450, 16'h7451, 16'h7452, 16'h7453,
        16'h7454, 16'h7455, 16'h7456, 16'h7457,
        16'h7458, 16'h7459, 16'h745A, 16'h745B,
        16'h745C, 16'h745D, 16'h745E, 16'h745F,
        16'h7460, 16'h7461, 16'h7462, 16'h7463,
        16'h7464, 16'h7465, 16'h7466, 16'h7467,
        16'h7468, 16'h7469, 16'h746A, 16'h746B,
        16'h746C, 16'h746D, 16'h746E, 16'h746F,
        16'h7470, 16'h7471, 16'h7472, 16'h7473,
        16'h7474, 16'h7475, 16'h7476, 16'h7477,
        16'h7478, 16'h7479, 16'h747A, 16'h747B,
        16'h747C, 16'h747D, 16'h747E, 16'h747F:     imm_count_prefix = 2'd1;
        16'h703E:                                   imm_count_prefix = 2'd2;
        16'h700E:                                   imm_count_prefix = 2'd2; // SSPD (addr16)
        16'h700F:                                   imm_count_prefix = 2'd2; // LSPD (addr16)
        16'h702E:                                   imm_count_prefix = 2'd2; // SDED (addr16)
        16'h702F:                                   imm_count_prefix = 2'd2; // LDED (addr16)
        16'h703F:                                   imm_count_prefix = 2'd2; // LHLD (addr16)
        // d74 page-arith *_wa (m31): each takes 1 wa byte after the sub-op.
        // ANAW/XRAW/ORAW/ADDNCW/GTAW/SUBNBW/LTAW/ADDW/ONAW/ADCW/OFFAW/
        // SUBW/NEAW/SBBW/EQAW — 15 sub-ops at column 0 of each row.
        16'h7488, 16'h7490, 16'h7498,
        16'h74A0, 16'h74A8, 16'h74B0, 16'h74B8,
        16'h74C0, 16'h74C8, 16'h74D0, 16'h74D8,
        16'h74E0, 16'h74E8, 16'h74F0, 16'h74F8:     imm_count_prefix = 2'd1;
        // d74 D*_EA_rp 16-bit ops (m32): 14 ops x 3 regpairs = 42 sub-ops
        // at columns 5/6/7 of each row.  Each takes 0 imm bytes after sub.
        // (Note: 0xC5/C6/C7 already counted above as DADD via the m18 path.)
        16'h748D, 16'h748E, 16'h748F,
        16'h7495, 16'h7496, 16'h7497,
        16'h749D, 16'h749E, 16'h749F,
        16'h74A5, 16'h74A6, 16'h74A7,
        16'h74AD, 16'h74AE, 16'h74AF,
        16'h74B5, 16'h74B6, 16'h74B7,
        16'h74BD, 16'h74BE, 16'h74BF,
        16'h74C5, 16'h74C6, 16'h74C7,
        16'h74CD, 16'h74CE, 16'h74CF,
        16'h74D5, 16'h74D6, 16'h74D7,
        16'h74DD, 16'h74DE, 16'h74DF,
        16'h74E5, 16'h74E6, 16'h74E7,
        16'h74ED, 16'h74EE, 16'h74EF,
        16'h74F5, 16'h74F6, 16'h74F7,
        16'h74FD, 16'h74FE, 16'h74FF:               imm_count_prefix = 2'd0;
        default:                                    imm_count_prefix = 2'd0;
    endcase
endfunction

// --------------- bus driving (combinational) -------------------------------
// Reg-pair selector for PUSH/POP.  Opcode low 3 bits pick: 0=VA 1=BC 2=DE
// 3=HL 4=EA.  We build {hi, lo} octets on the fly.
wire [7:0] push_hi =
      (opcode[2:0] == 3'd0) ? reg_v
    : (opcode[2:0] == 3'd1) ? reg_b
    : (opcode[2:0] == 3'd2) ? reg_d
    : (opcode[2:0] == 3'd3) ? reg_h
    :                         reg_ea[15:8];
wire [7:0] push_lo =
      (opcode[2:0] == 3'd0) ? reg_a
    : (opcode[2:0] == 3'd1) ? reg_c
    : (opcode[2:0] == 3'd2) ? reg_e
    : (opcode[2:0] == 3'd3) ? reg_l
    :                         reg_ea[7:0];

// Address mux: each memory-touching state names its own address source.
// For the no-offset LDAX (BC)/(DE)/(HL) and STAX (BC)/(DE)/(HL), the
// address source is picked by the low 3 bits of the opcode:
//   1 -> BC, 2 -> DE, 3 -> HL. (Opcodes 0x29/0x2A/0x2B and 0x39/0x3A/0x3B.)
// d74 D*_EA_rp regpair selector (m32): EA-vs-{BC|DE|HL} 16-bit ops at
// columns 5/6/7 of each row (DAN, DXR, DOR, DADDNC, DGT, DSUBNB, DLT,
// DADD, DON, DADC, DOFF, DSUB, DNE, DSBB, DEQ).  sub_op[2:0] picks rp.
wire [15:0] d74_rp =
      (sub_op[2:0] == 3'd5) ? {reg_b, reg_c}
    : (sub_op[2:0] == 3'd6) ? {reg_d, reg_e}
    :                         {reg_h, reg_l};
// Legacy alias for the original DADD-only wire; same selector.
wire [15:0] dadd_rp = d74_rp;

wire [15:0] ind_addr =
      (opcode[2:0] == 3'd1) ? {reg_b, reg_c}
    : (opcode[2:0] == 3'd2) ? {reg_d, reg_e}
    :                         {reg_h, reg_l};

// d64 SFR selector wires (m38).  Lower-half rows 0x00-0x7F target
// PA/PB/PC/PD/-/PF/MKH/MKL by sub_op[2:0]; upper-half rows 0x80-0xFF
// target ANM/SMH/-/EOM/-/TMM by sub_op[2:0] (cols 2/4/6/7 illegal).
wire [7:0] d64_sfr_lo =
      (sub_op[2:0] == 3'd0) ? reg_pa
    : (sub_op[2:0] == 3'd1) ? reg_pb
    : (sub_op[2:0] == 3'd2) ? reg_pc
    : (sub_op[2:0] == 3'd3) ? reg_pd
    : (sub_op[2:0] == 3'd5) ? reg_pf
    : (sub_op[2:0] == 3'd6) ? reg_mkh
    : (sub_op[2:0] == 3'd7) ? reg_mkl
    :                         8'h00;
wire [7:0] d64_sfr_hi =
      (sub_op[2:0] == 3'd0) ? reg_anm
    : (sub_op[2:0] == 3'd1) ? reg_smh
    : (sub_op[2:0] == 3'd3) ? (reg_eom & 8'h22)
    : (sub_op[2:0] == 3'd5) ? reg_tmm
    :                         8'h00;

// d48 LDEAX/STEAX base-address selector (m34).  Picks the source
// regpair (DE or HL) plus optional offset (A, B, EA, or imm_lo) per
// sub_op[3:0].  See MAME upd7810_opcodes.cpp:641-786 for the 17 ops.
//   sub[3:0]   variant
//     2/4      _D / _Dp     -> base = DE
//     3/5      _H / _Hp     -> base = HL  (existing _H is sub_op==0x83)
//     B        _D_xx        -> base = DE + imm_lo
//     C        _H_A         -> base = HL + A
//     D        _H_B         -> base = HL + B
//     E        _H_EA        -> base = HL + EA   (16-bit add)
//     F        _H_xx        -> base = HL + imm_lo
wire [15:0] eax_base_addr =
      (sub_op[3:0] == 4'h2) ? {reg_d, reg_e}
    : (sub_op[3:0] == 4'h3) ? {reg_h, reg_l}
    : (sub_op[3:0] == 4'h4) ? {reg_d, reg_e}
    : (sub_op[3:0] == 4'h5) ? {reg_h, reg_l}
    : (sub_op[3:0] == 4'hB) ? ({reg_d, reg_e} + {8'd0, imm_lo})
    : (sub_op[3:0] == 4'hC) ? ({reg_h, reg_l} + {8'd0, reg_a})
    : (sub_op[3:0] == 4'hD) ? ({reg_h, reg_l} + {8'd0, reg_b})
    : (sub_op[3:0] == 4'hE) ? ({reg_h, reg_l} + reg_ea)
    : (sub_op[3:0] == 4'hF) ? ({reg_h, reg_l} + {8'd0, imm_lo})
    :                         {reg_h, reg_l};   // fallback (matches old m12 _H)

// Primary LDAX/STAX with-offset addressing-mode selector (m41).
// opcode[3:0] picks the variant for both LDAX (0xAB-0xAF) and STAX
// (0xBB-0xBF):
//   B -> DE + imm_lo   (1 imm byte, _D_xx form)
//   C -> HL + A
//   D -> HL + B
//   E -> HL + EA       (16-bit add)
//   F -> HL + imm_lo   (1 imm byte, _H_xx form)
// MAME upd7810_opcodes.cpp: LDAX_D_xx 8675, LDAX_H_A 8682,
// LDAX_H_B 8689, LDAX_H_EA 8696, LDAX_H_xx 8703;
// STAX_D_xx 9009, STAX_H_A 9016, STAX_H_B 9023, STAX_H_EA 9030,
// STAX_H_xx 9037.
wire [15:0] lstax_off_addr =
      (opcode[3:0] == 4'hB) ? ({reg_d, reg_e} + {8'd0, imm_lo})
    : (opcode[3:0] == 4'hC) ? ({reg_h, reg_l} + {8'd0, reg_a})
    : (opcode[3:0] == 4'hD) ? ({reg_h, reg_l} + {8'd0, reg_b})
    : (opcode[3:0] == 4'hE) ? ({reg_h, reg_l} + reg_ea)
    : (opcode[3:0] == 4'hF) ? ({reg_h, reg_l} + {8'd0, imm_lo})
    :                         {reg_h, reg_l};

// d70 indirect arith addressing-mode selector (m30).  sub_op[2:0] picks
// the source register pair / post-modify behaviour for the 7 valid
// modes per row in the d70 indirect arith table:
//   1 = (BC), 2 = (DE), 3 = (HL),
//   4 = (DE+), 5 = (HL+), 6 = (DE-), 7 = (HL-).
// Slot 0 is illegal2 in MAME's table.  See upd7810_table.cpp:1543+.
wire [15:0] xind_addr =
      (sub_op[2:0] == 3'd1) ? {reg_b, reg_c}
    : (sub_op[2:0] == 3'd2) ? {reg_d, reg_e}
    : (sub_op[2:0] == 3'd3) ? {reg_h, reg_l}
    : (sub_op[2:0] == 3'd4) ? {reg_d, reg_e}
    : (sub_op[2:0] == 3'd5) ? {reg_h, reg_l}
    : (sub_op[2:0] == 3'd6) ? {reg_d, reg_e}
    :                         {reg_h, reg_l};

wire [5:0] bus_state = (state == S_READ_WAIT) ? read_wait_state : state;

assign mem_addr =
      (bus_state == S_MEM_WRITE)   ? {imm_hi, imm_lo}
    : (bus_state == S_STAX_HL_INC) ? {reg_h, reg_l}
    : (bus_state == S_LDAX_HL_INC) ? {reg_h, reg_l}
    : (bus_state == S_LDAX_DE_INC) ? {reg_d, reg_e}
    : (bus_state == S_LDAX_IND)    ? ind_addr
    : (bus_state == S_STAX_IND)    ? ind_addr
    : (bus_state == S_CALL_PUSH_H) ? (sp - 16'd1)
    : (bus_state == S_CALL_PUSH_L) ? (sp - 16'd1)
    : (bus_state == S_REG_PUSH_H)  ? (sp - 16'd1)
    : (bus_state == S_REG_PUSH_L)  ? (sp - 16'd1)
    : (bus_state == S_RET_POP_L)   ? sp
    : (bus_state == S_RET_POP_H)   ? sp
    : (bus_state == S_REG_POP_L)   ? sp
    : (bus_state == S_REG_POP_H)   ? sp
    : (bus_state == S_SHLD_L)      ? {imm_hi, imm_lo}
    : (bus_state == S_SHLD_H)      ? ({imm_hi, imm_lo} + 16'd1)
    : (bus_state == S_LSPD_LO)     ? {imm_hi, imm_lo}
    : (bus_state == S_LSPD_HI)     ? ({imm_hi, imm_lo} + 16'd1)
    : (bus_state == S_MEM_READ_A)  ? {imm_hi, imm_lo}
    : (bus_state == S_INDX)        ? xind_addr
    // TABLE (d48 0xA8) loads BC from memory at (PC + A + 1) and
    // (PC + A + 2) per MAME upd7810_opcodes.cpp line 803.
    //   ea = PC + A + 1;  C <- [ea];  B <- [ea + 1]
    // PC here is already advanced past the 2-byte d48/A8 opcode.
    : (bus_state == S_TABLE_LO)    ? (pc + {8'd0, reg_a} + 16'd1)
    : (bus_state == S_TABLE_HI)    ? (pc + {8'd0, reg_a} + 16'd2)
    // LDEAX/STEAX (d48 0x82-0x8F / 0x92-0x9F, m34): base address is
    // selected by sub_op[3:0] via eax_base_addr; HI cycle reads/writes
    // base+1.  m12 LDEAX_H (sub_op==0x83, base = HL) is the special
    // case the wire's fallback also handles.
    : (bus_state == S_LDEAX_LO)    ? eax_base_addr
    : (bus_state == S_LDEAX_HI)    ? (eax_base_addr + 16'd1)
    : (bus_state == S_STEAX_LO)    ? eax_base_addr
    : (bus_state == S_STEAX_HI)    ? (eax_base_addr + 16'd1)
    // RLD/RRD (d48 0x38/0x39, m36): read+modify+write (HL).
    : (bus_state == S_RLDRRD_RD)   ? {reg_h, reg_l}
    : (bus_state == S_RLDRRD_WR)   ? {reg_h, reg_l}
    // LDAX/STAX with offset (primary 0xAB-0xAF / 0xBB-0xBF, m41).
    : (bus_state == S_LDAX_OFF)    ? lstax_off_addr
    : (bus_state == S_STAX_OFF)    ? lstax_off_addr
    // BLOCK (primary 0x31, m42): read (HL), write (DE).
    : (bus_state == S_BLOCK_RD)    ? {reg_h, reg_l}
    : (bus_state == S_BLOCK_WR)    ? {reg_d, reg_e}
    // CALT (0x80-0x9F): target at 0x80 + 2*(opcode & 0x1F).  opcode[4:0]
    // is the table index; << 1 gives the byte offset within the table.
    : (bus_state == S_CALT_READ_L) ? (16'h0080 + {10'd0, opcode[4:0], 1'b0})
    : (bus_state == S_CALT_READ_H) ? (16'h0081 + {10'd0, opcode[4:0], 1'b0})
    // Interrupt entry / RETI: push/pop 3 bytes at SP (pre-dec on push,
    // post-inc on pop), matching the CALL/RET conventions.
    : (bus_state == S_INT_PSW)     ? (sp - 16'd1)
    : (bus_state == S_INT_PCH)     ? (sp - 16'd1)
    : (bus_state == S_INT_PCL)     ? (sp - 16'd1)
    : (bus_state == S_RETI_PCL)    ? sp
    : (bus_state == S_RETI_PCH)    ? sp
    : (bus_state == S_RETI_PSW)    ? sp
    // Page-address ops: effective addr = {V, wa}.  wa is in imm_lo.
    : (bus_state == S_PAGE_RD)     ? {reg_v, imm_lo}
    : (bus_state == S_PAGE_WR)     ? {reg_v, imm_lo}
    // MVIX (BC/DE/HL),xx — opcode low 3 bits select the regpair.
    : (bus_state == S_MVIX)        ?
          ((opcode[1:0] == 2'd1) ? {reg_b, reg_c} :
           (opcode[1:0] == 2'd2) ? {reg_d, reg_e} :
                                   {reg_h, reg_l})
    // LDAX/STAX with auto-decrement variants
    : (bus_state == S_LDAX_DE_DEC) ? {reg_d, reg_e}
    : (bus_state == S_LDAX_HL_DEC) ? {reg_h, reg_l}
    : (bus_state == S_STAX_DE_INC) ? {reg_d, reg_e}
    : (bus_state == S_STAX_DE_DEC) ? {reg_d, reg_e}
    : (bus_state == S_STAX_HL_DEC) ? {reg_h, reg_l}
    :                            pc;
assign mem_rd   = (bus_state == S_FETCH_OP)
                | (bus_state == S_FETCH_PFX)
                | (bus_state == S_FETCH_IM1)
                | (bus_state == S_FETCH_IM2)
                | (bus_state == S_LDAX_HL_INC)
                | (bus_state == S_LDAX_DE_INC)
                | (bus_state == S_LDAX_IND)
                | (bus_state == S_LSPD_LO)
                | (bus_state == S_LSPD_HI)
                | (bus_state == S_MEM_READ_A)
                | (bus_state == S_INDX)
                | (bus_state == S_TABLE_LO)
                | (bus_state == S_TABLE_HI)
                | (bus_state == S_LDEAX_LO)
                | (bus_state == S_LDEAX_HI)
                | (bus_state == S_RLDRRD_RD)
                | (bus_state == S_LDAX_OFF)
                | (bus_state == S_BLOCK_RD)
                | (bus_state == S_CALT_READ_L)
                | (bus_state == S_CALT_READ_H)
                | (bus_state == S_RET_POP_L)
                | (bus_state == S_RET_POP_H)
                | (bus_state == S_REG_POP_L)
                | (bus_state == S_REG_POP_H)
                | (bus_state == S_RETI_PCL)
                | (bus_state == S_RETI_PCH)
                | (bus_state == S_RETI_PSW)
                | (bus_state == S_PAGE_RD)
                | (bus_state == S_LDAX_DE_DEC)
                | (bus_state == S_LDAX_HL_DEC);
assign mem_wr   = (bus_state == S_MEM_WRITE)
                | (bus_state == S_STAX_HL_INC)
                | (bus_state == S_STAX_IND)
                | (bus_state == S_CALL_PUSH_H)
                | (bus_state == S_CALL_PUSH_L)
                | (bus_state == S_REG_PUSH_H)
                | (bus_state == S_REG_PUSH_L)
                | (bus_state == S_SHLD_L)
                | (bus_state == S_SHLD_H)
                | (bus_state == S_INT_PSW)
                | (bus_state == S_INT_PCH)
                | (bus_state == S_INT_PCL)
                | (bus_state == S_PAGE_WR)
                | (bus_state == S_MVIX)
                | (bus_state == S_STAX_DE_INC)
                | (bus_state == S_STAX_DE_DEC)
                | (bus_state == S_STAX_HL_DEC)
                | (bus_state == S_STEAX_LO)
                | (bus_state == S_STEAX_HI)
                | (bus_state == S_RLDRRD_WR)
                | (bus_state == S_STAX_OFF)
                | (bus_state == S_BLOCK_WR);
// d60 source-register selector — used by every reg-reg arith/logic op.
// Low 3 bits of sub_op pick from V/A/B/C/D/E/H/L per MAME convention.
wire [7:0] d60_rs = (sub_op[2:0]==3'd0) ? reg_v :
                    (sub_op[2:0]==3'd1) ? reg_a :
                    (sub_op[2:0]==3'd2) ? reg_b :
                    (sub_op[2:0]==3'd3) ? reg_c :
                    (sub_op[2:0]==3'd4) ? reg_d :
                    (sub_op[2:0]==3'd5) ? reg_e :
                    (sub_op[2:0]==3'd6) ? reg_h : reg_l;

// DAA (0x61) adjustment selector.  MAME upd7810_opcodes.cpp:8882 picks
// adj from (HC, low_nibble<10, high_nibble<10, CY).  Encoded as a
// straight Boolean cascade.
wire daa_l_lt10 = (reg_a[3:0]   < 4'd10);
wire daa_h_lt10 = (reg_a[7:4]   < 4'd10);
wire daa_h_lt9  = (reg_a[7:4]   < 4'd9);
wire daa_l_lt3  = (reg_a[3:0]   < 4'd3);
wire daa_cy     = psw[0];
wire daa_hc     = psw[4];
wire [7:0] daa_adj =
      // !HC branch
     (!daa_hc && daa_l_lt10 && daa_h_lt10 && !daa_cy) ? 8'h00
   : (!daa_hc && daa_l_lt10)                          ? 8'h60
   : (!daa_hc && daa_h_lt9   && !daa_cy)              ? 8'h06
   : (!daa_hc)                                         ? 8'h66
      // HC branch
   : ( daa_hc && daa_l_lt3   && daa_h_lt10 && !daa_cy) ? 8'h06
   : ( daa_hc && daa_l_lt3)                           ? 8'h66
	                                                       : 8'h00;
wire [8:0] daa_sum = {1'b0, reg_a} + {1'b0, daa_adj};

wire [7:0] exec_lmask = l0_l1_clear_mask(opcode);

// Data-out mux (only valid when mem_wr is high)
assign mem_dout =
      (bus_state == S_CALL_PUSH_H) ? pc[15:8]
    : (bus_state == S_CALL_PUSH_L) ? pc[7:0]
    : (bus_state == S_REG_PUSH_H)  ? push_hi
    : (bus_state == S_REG_PUSH_L)  ? push_lo
    // SHLD writes {L,H}; SSPD writes {SPL,SPH}; SDED writes {E,D};
    // SBCD writes {C,B} (m33).  Same states, data source selected by sub_op:
    //   sub_op == 0x3E -> SHLD: low=L,    high=H
    //   sub_op == 0x0E -> SSPD: low=SPL,  high=SPH
    //   sub_op == 0x2E -> SDED: low=E,    high=D
    //   sub_op == 0x1E -> SBCD: low=C,    high=B
    : (bus_state == S_SHLD_L)      ? ((sub_op == 8'h0E) ? sp[7:0]  :
                                   (sub_op == 8'h2E) ? reg_e   :
                                   (sub_op == 8'h1E) ? reg_c   : reg_l)
    : (bus_state == S_SHLD_H)      ? ((sub_op == 8'h0E) ? sp[15:8] :
                                   (sub_op == 8'h2E) ? reg_d   :
                                   (sub_op == 8'h1E) ? reg_b   : reg_h)
    // STEAX (d48 0x92-0x9F, m34): write reg_ea low byte first, then high.
    : (bus_state == S_STEAX_LO)    ? reg_ea[7:0]
    : (bus_state == S_STEAX_HI)    ? reg_ea[15:8]
    // RLD/RRD (d48 0x38/0x39, m36): write the computed byte (latched in
    // imm_hi during S_RLDRRD_RD) back to (HL).
    : (bus_state == S_RLDRRD_WR)   ? imm_hi
    // BLOCK (primary 0x31, m42): write the byte read in S_BLOCK_RD
    // (latched in imm_hi) to (DE).
    : (bus_state == S_BLOCK_WR)    ? imm_hi
    // S_MEM_WRITE for d70 MOV (addr16),reg (m33).  Reg selected by sub_op
    // low 3 bits: 0=V, 1=A, 2=B, 3=C, 4=D, 5=E, 6=H, 7=L.  Note that the
    // d60-style d60_rs wire happens to use the same encoding so it could
    // be reused, but this state runs outside the d60 prefix block — we
    // open-code the 8-way mux to keep the dependency local.
    : (bus_state == S_MEM_WRITE)   ? ((sub_op[2:0] == 3'd0) ? reg_v :
                                   (sub_op[2:0] == 3'd1) ? reg_a :
                                   (sub_op[2:0] == 3'd2) ? reg_b :
                                   (sub_op[2:0] == 3'd3) ? reg_c :
                                   (sub_op[2:0] == 3'd4) ? reg_d :
                                   (sub_op[2:0] == 3'd5) ? reg_e :
                                   (sub_op[2:0] == 3'd6) ? reg_h : reg_l)
    : (bus_state == S_INT_PSW)     ? psw
    : (bus_state == S_INT_PCH)     ? pc[15:8]
    : (bus_state == S_INT_PCL)     ? pc[7:0]
    // Page-address writes:
    //   - STAW (opcode 0x63): write reg_a.
    //   - MVIW (opcode 0x71): write imm_hi (the second operand byte).
    //   - RMW ops (ANIW/ORIW/INRW/DCRW): write imm_hi (set in S_PAGE_RD).
    : (bus_state == S_PAGE_WR)     ? ((opcode == 8'h63) ? reg_a : imm_hi)
    // MVIX (BC/DE/HL),xx: write imm_lo at the indirect address.
    : (bus_state == S_MVIX)        ? imm_lo
    // STAX with offset writes A through lstax_off_addr.  Keep this explicit
    // so the fallback below cannot hide future mux omissions.
    : (bus_state == S_STAX_OFF)    ? reg_a
    :                            reg_a;
assign dbg_trap = (bus_state == S_TRAP);

wire [8:0] div_divisor_ext = {1'b0, div_divisor};
wire [8:0] div_shift_rem   = {div_rem[7:0], div_quot[15]};
wire       div_take_sub    = (div_shift_rem >= div_divisor_ext);
wire [8:0] div_next_rem    = div_take_sub ? (div_shift_rem - div_divisor_ext)
                                           : div_shift_rem;
wire [15:0] div_next_quot  = {div_quot[14:0], div_take_sub};

// --------------- sequential ------------------------------------------------
always @(posedge clk) begin
    if (!rstn) begin
        state           <= S_READ_WAIT;
        read_wait_state <= S_FETCH_OP;
        pc         <= 16'h0000;
        sp         <= 16'h0000;
        reg_ea     <= 16'h0000;
        reg_a      <= 8'h00;
        reg_v      <= 8'h00;
        reg_b      <= 8'h00;
        reg_c      <= 8'h00;
        reg_d      <= 8'h00;
        reg_e      <= 8'h00;
        reg_h      <= 8'h00;
        reg_l      <= 8'h00;
        psw        <= 8'h00;
        iffr        <= 1'b0;
        iff_pending <= 1'b0;
        // Alternate register bank — zero at reset; only changes when
        // the program executes EXA/EXX/EXH.
        reg_ap     <= 8'h00;
        reg_vp     <= 8'h00;
        reg_bp     <= 8'h00;
        reg_cp     <= 8'h00;
        reg_dp     <= 8'h00;
        reg_ep     <= 8'h00;
        reg_hp     <= 8'h00;
        reg_lp     <= 8'h00;
        reg_eap    <= 16'h0000;
        // SFR reset values per uPD78C10 datasheet
        reg_mm     <= 8'h08;
        reg_mcc   <= 8'h00;
        reg_ma     <= 8'hFF;
        reg_mb     <= 8'hFF;
        reg_mc     <= 8'hFF;
        reg_mf     <= 8'hFF;
        reg_mkh    <= 8'hFF;
        reg_mkl    <= 8'hFF;
        reg_anm    <= 8'h00;
        reg_tmm    <= 8'hFF;
        reg_smh    <= 8'h00;          // SMH initial 0 (matches MAME default)
        reg_sml    <= 8'h00;
        reg_txb    <= 8'h00;
        reg_etmm   <= 8'h00;
        reg_mt     <= 8'h00;
        reg_zcm    <= 8'h00;
        reg_eom    <= 8'h00;          // EOM initial 0 (matches MAME default)
        reg_etm0   <= 16'h0000;       // ETM0 initial 0 (m40 stub)
        reg_etm1   <= 16'h0000;       // ETM1 initial 0 (m40 stub)
        reg_pa     <= 8'h00;
        reg_pb     <= 8'h00;
        reg_pc     <= 8'h00;
        reg_pd     <= 8'h00;
        reg_pf     <= 8'h00;
        opcode     <= 8'h00;
        sub_op     <= 8'h00;
        imm_lo     <= 8'h00;
        imm_hi     <= 8'h00;
        fetch_pc   <= 16'h0000;
        pc_lo_tmp    <= 8'h00;
        int1_pending <= 1'b0;
        softi_entry  <= 1'b0;
        div_quot     <= 16'h0000;
        div_rem      <= 9'h000;
        div_divisor  <= 8'h00;
        div_count    <= 5'd0;
        div_sel      <= 2'd0;
        dbg_retire <= 1'b0;
    end else begin
        dbg_retire <= 1'b0;
        // Latch INTF1 request level. Dispatch path (S_FETCH_OP) clears
        // it; meanwhile new pulses from the source re-latch freely.
        if (ext_int1_req)  int1_pending <= 1'b1;
        if (dbg_force_iff) begin
            iffr         <= 1'b1;
            iff_pending  <= 1'b1;
            reg_mkl[3]   <= 1'b0;  // debug-only IRQ force also unmasks INTF1
        end
        case (state)

        S_READ_WAIT: begin
            state <= read_wait_state;
        end

        S_DIV_STEP: begin
            div_quot  <= div_next_quot;
            div_rem   <= div_next_rem;
            div_count <= div_count - 5'd1;
            if (div_count == 5'd1) begin
                reg_ea <= div_next_quot;
                case (div_sel)
                    2'd0: reg_a <= div_next_rem[7:0];
                    2'd1: reg_b <= div_next_rem[7:0];
                    2'd2: reg_c <= div_next_rem[7:0];
                    default: ;
                endcase
                goto_state(S_FETCH_OP);
                dbg_retire <= 1'b1;
            end
        end

        // Cycle N: mem_din = ROM[pc]. Latch it and decide what comes next.
        S_FETCH_OP: begin
            // Interrupt dispatch check fires at every instruction-retire
            // boundary (we just entered S_FETCH_OP, meaning the previous
            // instruction retired). If INTF1 is pending, unmasked, and IFF
            // is set, dispatch instead of fetching. SK/L0/L1 in PSW are NOT
            // allowed to block the interrupt — but they DO get pushed
            // as part of PSW and then cleared (MAME upd7810.cpp check_irqs).
            if (int1_pending && iffr && !reg_mkl[3]) begin
                int1_pending <= 1'b0;
                iffr         <= 1'b0;
                iff_pending  <= 1'b0;
                softi_entry  <= 1'b0;
                goto_state(S_INT_PSW);
            end else begin
                iffr     <= dbg_force_iff ? 1'b1 : iff_pending;
                opcode   <= mem_din;
                sub_op   <= 8'h00;
                fetch_pc <= pc;     // capture the instruction address
                pc       <= pc + 16'd1;
                if (is_prefix_op(mem_din)) begin
                    goto_state(S_FETCH_PFX);
                end else begin
                    case (imm_count_primary(mem_din))
                        2'd0:    goto_state(S_EXECUTE);
                        2'd1:    goto_state(S_FETCH_IM1);
                        2'd2:    goto_state(S_FETCH_IM1);  // cascades to IM2
                        default: goto_state(S_TRAP);
                    endcase
                end
            end
        end

        S_FETCH_PFX: begin
            sub_op <= mem_din;
            pc     <= pc + 16'd1;
            case (imm_count_prefix(opcode, mem_din))
                2'd0:    goto_state(S_EXECUTE);
                2'd1:    goto_state(S_FETCH_IM1);
                2'd2:    goto_state(S_FETCH_IM1);
                default: goto_state(S_TRAP);
            endcase
        end

        S_FETCH_IM1: begin
            imm_lo <= mem_din;
            pc     <= pc + 16'd1;
            // Any decoder entry that reports two immediate bytes cascades
            // here.  Keep this table-driven so page ops like GTIW/LTIW/NEIW
            // cannot drift from imm_count_primary().
            if ((is_prefix_op(opcode) ? imm_count_prefix(opcode, sub_op)
                                      : imm_count_primary(opcode)) == 2'd2)
                goto_state(S_FETCH_IM2);
            else
                goto_state(S_EXECUTE);
        end

        S_FETCH_IM2: begin
            imm_hi <= mem_din;
            pc     <= pc + 16'd1;
            goto_state(S_EXECUTE);
        end

        S_EXECUTE: begin
            // Defaults: fall through to next fetch, retire.  Trap paths
            // override `state` AND clear dbg_retire (a trapped instruction
            // didn't retire — it faulted).
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
            psw[2]     <= psw[2] & ~exec_lmask[2];
            psw[3]     <= psw[3] & ~exec_lmask[3];

            if (psw[5] && opcode != 8'h72) begin
                // SK set: current instruction is skipped (MAME
                // upd7810.cpp:2040). Don't execute any side effect;
                // clear SK so the NEXT instruction runs normally.
                psw[5] <= 1'b0;
            end else begin
                // dispatch: opcode identifies either a primary op OR a
                // prefix op. In the prefix case, sub_op holds the
                // table index.
                casez (opcode)
                    8'h00: ;                                      // NOP
                    8'h54: pc <= {imm_hi, imm_lo};                // JMP w
                    8'h04: sp <= {imm_hi, imm_lo};                // LXI SP,w
                    8'h14: {reg_b, reg_c} <= {imm_hi, imm_lo};    // LXI BC,w
                    8'h24: {reg_d, reg_e} <= {imm_hi, imm_lo};    // LXI DE,w
                    8'h34: begin                                  // LXI HL,w (L0 overlay)
                        if (!psw[2]) begin
                            {reg_h, reg_l} <= {imm_hi, imm_lo};
                            psw[2] <= 1'b1;
                        end
                    end
                    8'h44: reg_ea <= {imm_hi, imm_lo};            // LXI EA,w

                    // INX/DCX regpair: pure arithmetic on the pair, no
                    // PSW updates per MAME's INX_*/DCX_* handlers.
                    8'h02: sp              <= sp              + 16'd1;  // INX SP
                    8'h12: {reg_b, reg_c}  <= {reg_b, reg_c}  + 16'd1;  // INX BC
                    8'h22: {reg_d, reg_e}  <= {reg_d, reg_e}  + 16'd1;  // INX DE
                    8'h32: {reg_h, reg_l}  <= {reg_h, reg_l}  + 16'd1;  // INX HL
                    8'hA8: reg_ea          <= reg_ea          + 16'd1;  // INX EA
                    8'h03: sp              <= sp              - 16'd1;  // DCX SP
                    8'h13: {reg_b, reg_c}  <= {reg_b, reg_c}  - 16'd1;  // DCX BC
                    8'h23: {reg_d, reg_e}  <= {reg_d, reg_e}  - 16'd1;  // DCX DE
                    8'h33: {reg_h, reg_l}  <= {reg_h, reg_l}  - 16'd1;  // DCX HL
                    8'hA9: reg_ea          <= reg_ea          - 16'd1;  // DCX EA

                    // MOV reg,reg (primary 0x08-0x0F: A <- EAH/EAL/B/C/D/E/H/L;
                    //              primary 0x18-0x1F: EAH/EAL/B/C/D/E/H/L <- A)
                    8'h08: reg_a         <= reg_ea[15:8];
                    8'h09: reg_a         <= reg_ea[7:0];
                    8'h0A: reg_a         <= reg_b;
                    8'h0B: reg_a         <= reg_c;
                    8'h0C: reg_a         <= reg_d;
                    8'h0D: reg_a         <= reg_e;
                    8'h0E: reg_a         <= reg_h;
                    8'h0F: reg_a         <= reg_l;
                    8'h18: reg_ea[15:8]  <= reg_a;
                    8'h19: reg_ea[7:0]   <= reg_a;
                    8'h1A: reg_b         <= reg_a;
                    8'h1B: reg_c         <= reg_a;
                    8'h1C: reg_d         <= reg_a;
                    8'h1D: reg_e         <= reg_a;
                    8'h1E: reg_h         <= reg_a;
                    8'h1F: reg_l         <= reg_a;

                    // DMOV: 16-bit reg-to-reg copy.  MAME upd7810_opcodes.cpp
                    // 9169/9175/9181 (EA<-src), 9292/9298/9304 (dst<-EA).
                    // No PSW updates.
                    8'hA5: reg_ea         <= {reg_b, reg_c};       // DMOV EA,BC
                    8'hA6: reg_ea         <= {reg_d, reg_e};       // DMOV EA,DE
                    8'hA7: reg_ea         <= {reg_h, reg_l};       // DMOV EA,HL
                    8'hB5: {reg_b, reg_c} <= reg_ea;               // DMOV BC,EA
                    8'hB6: {reg_d, reg_e} <= reg_ea;               // DMOV DE,EA
                    8'hB7: {reg_h, reg_l} <= reg_ea;               // DMOV HL,EA

                    // EXA (0x10): swap {EA, VA} with {EA', VA'}.
                    // MAME upd7810_opcodes.cpp:8025.
                    8'h10: begin
                        reg_a  <= reg_ap;   reg_ap  <= reg_a;
                        reg_v  <= reg_vp;   reg_vp  <= reg_v;
                        reg_ea <= reg_eap;  reg_eap <= reg_ea;
                    end
                    // EXX (0x11): swap BC/DE/HL with their primes.
                    // MAME upd7810_opcodes.cpp:8033.
                    8'h11: begin
                        reg_b <= reg_bp;   reg_bp <= reg_b;
                        reg_c <= reg_cp;   reg_cp <= reg_c;
                        reg_d <= reg_dp;   reg_dp <= reg_d;
                        reg_e <= reg_ep;   reg_ep <= reg_e;
                        reg_h <= reg_hp;   reg_hp <= reg_h;
                        reg_l <= reg_lp;   reg_lp <= reg_l;
                    end
                    // EXH (0x50): swap HL with HL' only.
                    // MAME upd7810_opcodes.cpp:8508.
                    8'h50: begin
                        reg_h <= reg_hp;   reg_hp <= reg_h;
                        reg_l <= reg_lp;   reg_lp <= reg_l;
                    end

                    // LDAX (HL+): two-cycle; read (HL) into A, then HL++.
                    8'h2D: begin
                        goto_state(S_LDAX_HL_INC);
                        dbg_retire <= 1'b0;
                    end
                    // LDAX (DE+): read (DE) into A, then DE++.
                    8'h2C: begin
                        goto_state(S_LDAX_DE_INC);
                        dbg_retire <= 1'b0;
                    end
                    // LDAX (BC)/(DE)/(HL) : no post-op on the regpair.
                    8'h29, 8'h2A, 8'h2B: begin
                        goto_state(S_LDAX_IND);
                        dbg_retire <= 1'b0;
                    end
                    // LDAX (DE-): read (DE) into A, then DE--.
                    8'h2E: begin goto_state(S_LDAX_DE_DEC); dbg_retire <= 1'b0; end
                    // LDAX (HL-): read (HL) into A, then HL--.
                    8'h2F: begin goto_state(S_LDAX_HL_DEC); dbg_retire <= 1'b0; end
                    // STAX (BC)/(DE)/(HL) : write A, no post-op.
                    8'h39, 8'h3A, 8'h3B: begin
                        goto_state(S_STAX_IND);
                        dbg_retire <= 1'b0;
                    end
                    // STAX (DE+) / (DE-) / (HL-) : write A, then ±1.
                    8'h3C: begin goto_state(S_STAX_DE_INC); dbg_retire <= 1'b0; end
                    8'h3E: begin goto_state(S_STAX_DE_DEC); dbg_retire <= 1'b0; end
                    8'h3F: begin goto_state(S_STAX_HL_DEC); dbg_retire <= 1'b0; end
                    // RETS (0xB9): like RET but sets SK at retire.  Reuses
                    // the RET pop states; S_RET_POP_H tail discriminates
                    // on opcode to set SK only for RETS.
                    8'hB9: begin
                        goto_state(S_RET_POP_L);
                        dbg_retire <= 1'b0;
                    end
                    // SOFTI (0x72): software-interrupt entry, vector $0060.
                    // Push PSW, PCH, PCL like INTF1; S_INT_PCL discriminates
                    // on opcode to pick the vector ($0010 vs $0060).
                    8'h72: begin
                        softi_entry <= 1'b1;
                        goto_state(S_INT_PSW);
                        dbg_retire <= 1'b0;
                    end
                    // CALF (0x78-0x7F): page-call, target = ((0x08|op&7)<<8)|imm
                    8'b01111???: begin
                        goto_state(S_CALL_PUSH_H);
                        dbg_retire <= 1'b0;
                    end
                    // DAA (0x61): BCD adjust per MAME upd7810_opcodes.cpp
                    // 8882.  Picks `adj` from (HC, low nibble, high nibble,
                    // CY), then tmp = A + adj; ZHC_ADD(tmp, A, CY) ; PSW |=
                    // old_cy.  The compute is data-dependent — uses the
                    // wire daa_adj defined at module level (needs reg_a +
                    // psw available; declared near d60_rs).
                    8'h61: begin
                        reg_a  <= daa_sum[7:0];
                        psw[6] <= (daa_sum[7:0] == 8'h00);
                        psw[0] <= psw[0] | (daa_sum[7:0] < reg_a);
                        psw[4] <= (daa_sum[3:0] < reg_a[3:0]);
                    end
                    8'hBA: begin                                  // DI
                        iffr        <= 1'b0;
                        iff_pending <= 1'b0;
                    end
                    8'hAA: iff_pending <= 1'b1;                   // EI (delayed one instruction)

                    // CALL w: push return PC (pc is already advanced past
                    // the 3-byte CALL by S_FETCH_IM2), then jump.  Two
                    // memory writes -> drop into S_CALL_PUSH_H; final
                    // retire happens in S_CALL_PUSH_L.
                    8'h40: begin
                        goto_state(S_CALL_PUSH_H);
                        dbg_retire <= 1'b0;
                    end

                    // CALT (0x80-0x9F): push return PC, then fetch target
                    // from a dispatch table at 0x80 + 2 * (op & 0x1F).
                    // Shares the push states with CALL; S_CALL_PUSH_L
                    // branches based on opcode to either set PC (CALL)
                    // or enter the CALT table-read phase.
                    8'b100?????: begin
                        goto_state(S_CALL_PUSH_H);
                        dbg_retire <= 1'b0;
                    end

                    // RET: pop two bytes from (SP), post-increment.
                    8'hB8: begin
                        goto_state(S_RET_POP_L);
                        dbg_retire <= 1'b0;
                    end

                    // RETI: pop PC then PSW.  Three reads retire in
                    // S_RETI_PSW; MAME does not alter IFF.
                    8'h62: begin
                        goto_state(S_RETI_PCL);
                        dbg_retire <= 1'b0;
                    end

                    // STAX (HL+): write A to (HL), then HL++.
                    8'h3D: begin
                        goto_state(S_STAX_HL_INC);
                        dbg_retire <= 1'b0;
                    end

                    // PUSH VA/BC/DE/HL/EA (0xB0-B4)
                    8'hB0, 8'hB1, 8'hB2, 8'hB3, 8'hB4: begin
                        goto_state(S_REG_PUSH_H);
                        dbg_retire <= 1'b0;
                    end

                    // POP VA/BC/DE/HL/EA (0xA0-A4)
                    8'hA0, 8'hA1, 8'hA2, 8'hA3, 8'hA4: begin
                        goto_state(S_REG_POP_L);
                        dbg_retire <= 1'b0;
                    end
                    // LDAX with offset (0xAB-0xAF, m41).  A <- mem[base]
                    // where base depends on opcode[3:0] via lstax_off_addr.
                    // 0xAB/AF take 1 imm byte (xx); 0xAC/AD/AE take 0.
                    // MAME upd7810_opcodes.cpp:8675-8709.
                    8'hAB, 8'hAC, 8'hAD, 8'hAE, 8'hAF: begin
                        goto_state(S_LDAX_OFF);
                        dbg_retire <= 1'b0;
                    end
                    // STAX with offset (0xBB-0xBF, m41).  mem[base] <- A.
                    // MAME upd7810_opcodes.cpp:9009-9043.
                    8'hBB, 8'hBC, 8'hBD, 8'hBE, 8'hBF: begin
                        goto_state(S_STAX_OFF);
                        dbg_retire <= 1'b0;
                    end
                    // BLOCK (0x31, m42): byte-by-byte block move (HL -> DE).
                    // Each iteration: WM(DE, RM(HL)); DE++; HL++; C--.
                    // C wrap from 0 to 0xFF: set CY, retire, advance PC.
                    // C non-wrap: clear CY, retire, decrement PC so the
                    // next fetch re-enters BLOCK (interrupt-resumable
                    // since PC is preserved at the BLOCK opcode).
                    // MAME upd7810_opcodes.cpp:8911.
                    8'h31: begin
                        goto_state(S_BLOCK_RD);
                        dbg_retire <= 1'b0;
                    end
                    8'h68: reg_v <= imm_lo;
                    8'h69: begin                                  // MVI A,imm (L1 overlay)
                        if (!psw[3]) begin
                            reg_a  <= imm_lo;
                            psw[3] <= 1'b1;
                        end
                    end
                    8'h6A: reg_b <= imm_lo;
                    8'h6B: reg_c <= imm_lo;
                    8'h6C: reg_d <= imm_lo;
                    8'h6D: reg_e <= imm_lo;
                    8'h6E: reg_h <= imm_lo;
                    8'h6F: begin                                  // MVI L,imm (L0 overlay)
                        if (!psw[2]) begin
                            reg_l  <= imm_lo;
                            psw[2] <= 1'b1;
                        end
                    end

                    // DCR r : r <- r - 1; Z/HC from result; SK set iff
                    //          underflow (r was 0). CY unchanged (MAME
                    //          saves/restores CY around ZHC_SUB/SKIP_CY).
                    8'h51: begin                                  // DCR A
                        reg_a  <= reg_a - 8'd1;
                        psw[6] <= (reg_a == 8'h01);
                        psw[4] <= (((reg_a - 8'd1) & 4'hF) > reg_a[3:0]);
                        if (reg_a == 8'h00) psw[5] <= 1'b1;
                    end
                    8'h52: begin                                  // DCR B
                        reg_b  <= reg_b - 8'd1;
                        psw[6] <= (reg_b == 8'h01);
                        psw[4] <= (((reg_b - 8'd1) & 4'hF) > reg_b[3:0]);
                        if (reg_b == 8'h00) psw[5] <= 1'b1;
                    end
                    8'h53: begin                                  // DCR C
                        reg_c  <= reg_c - 8'd1;
                        psw[6] <= (reg_c == 8'h01);
                        psw[4] <= (((reg_c - 8'd1) & 4'hF) > reg_c[3:0]);
                        if (reg_c == 8'h00) psw[5] <= 1'b1;
                    end

                    // INR r : symmetric to DCR. r <- r + 1; Z/HC from result;
                    //          SK on overflow (FF -> 00); CY unchanged.
                    8'h41: begin                                  // INR A
                        reg_a  <= reg_a + 8'd1;
                        psw[6] <= (reg_a == 8'hFF);
                        psw[4] <= (((reg_a + 8'd1) & 4'hF) < reg_a[3:0]);
                        if (reg_a == 8'hFF) psw[5] <= 1'b1;
                    end
                    8'h42: begin                                  // INR B
                        reg_b  <= reg_b + 8'd1;
                        psw[6] <= (reg_b == 8'hFF);
                        psw[4] <= (((reg_b + 8'd1) & 4'hF) < reg_b[3:0]);
                        if (reg_b == 8'hFF) psw[5] <= 1'b1;
                    end
                    8'h43: begin                                  // INR C
                        reg_c  <= reg_c + 8'd1;
                        psw[6] <= (reg_c == 8'hFF);
                        psw[4] <= (((reg_c + 8'd1) & 4'hF) < reg_c[3:0]);
                        if (reg_c == 8'hFF) psw[5] <= 1'b1;
                    end

                    // JR: 6-bit signed PC offset in the opcode byte.
                    // target = pc + sign_extend({op[5], op[4:0]}).
                    // pc has already been advanced past this 1-byte op.
                    8'b11??????:
                        pc <= pc + {{11{opcode[5]}}, opcode[4:0]};

                    // JB: PC <- BC (indirect jump via the BC register pair).
                    8'h21: pc <= {reg_b, reg_c};

                    // JRE: 9-bit PC-relative jump.  Opcode low bit is the
                    // sign bit; immediate byte holds the magnitude.
                    //   0x4E imm : PC += imm        (forward, 0..255)
                    //   0x4F imm : PC -= 256 - imm  (backward, -256..-1)
                    // PC has already been advanced past the 2-byte JRE.
                    8'h4E: pc <= pc + {8'd0, imm_lo};
                    8'h4F: pc <= pc - (16'd256 - {8'd0, imm_lo});

                    // EQI A,imm : Z = (A == imm); CY/HC from A-imm; SK set iff Z;
                    //             A unchanged.
                    8'h77: begin
                        psw[6] <= (reg_a == imm_lo);               // Z
                        psw[0] <= (imm_lo > reg_a);                // CY
                        psw[4] <= (((reg_a - imm_lo) & 4'hF) > reg_a[3:0]);
                        if (reg_a == imm_lo) psw[5] <= 1'b1;       // SKIP_Z
                    end

                    // NEI A,imm : same flag updates as EQI, but SK set
                    //             iff A != imm (SKIP_NZ in MAME).
                    8'h67: begin
                        psw[6] <= (reg_a == imm_lo);               // Z
                        psw[0] <= (imm_lo > reg_a);                // CY
                        psw[4] <= (((reg_a - imm_lo) & 4'hF) > reg_a[3:0]);
                        if (reg_a != imm_lo) psw[5] <= 1'b1;       // SKIP_NZ
                    end

                    // GTI A,imm : tmp = A - imm - 1; SKIP_NC iff A > imm.
                    8'h27: begin
                        psw[6] <= (({8'd0, reg_a} - {8'd0, imm_lo} - 16'd1) == 16'h0000);
                        psw[0] <= (reg_a <= imm_lo);               // CY set iff A <= imm
                        psw[4] <= (((reg_a - imm_lo - 8'd1) & 4'hF) > reg_a[3:0]);
                        if (reg_a > imm_lo) psw[5] <= 1'b1;        // SKIP_NC
                    end
                    // LTI A,imm : tmp = A - imm; SKIP_CY iff A < imm.
                    8'h37: begin
                        psw[6] <= (reg_a == imm_lo);
                        psw[0] <= (reg_a < imm_lo);
                        psw[4] <= (((reg_a - imm_lo) & 4'hF) > reg_a[3:0]);
                        if (reg_a < imm_lo) psw[5] <= 1'b1;        // SKIP_CY
                    end
                    // ONI A,imm : SK iff (A & imm) != 0.  PSW flags untouched.
                    8'h47: begin
                        if ((reg_a & imm_lo) != 8'h00) psw[5] <= 1'b1;
                    end
                    // OFFI A,imm : SK iff (A & imm) == 0.  PSW flags untouched.
                    8'h57: begin
                        if ((reg_a & imm_lo) == 8'h00) psw[5] <= 1'b1;
                    end

                    // Arithmetic-immediate block.  A <- A op imm, Z/CY
                    // set from the result.  ADINC/SUINB additionally
                    // set SK via SKIP_NC (skip if no carry/borrow).
                    // Z for 8-bit add/sub checks the TRUNCATED result, not
                    // a 9-bit sum compared to zero (the 9-bit compare
                    // misses wrap-to-zero on overflow).  Use explicit
                    // 8-bit result equality.
                    8'h46: begin                                  // ADI A,imm
                        reg_a  <= reg_a + imm_lo;
                        psw[6] <= (((reg_a + imm_lo) & 8'hFF) == 8'h00);
                        psw[0] <= (({1'b0, reg_a} + {1'b0, imm_lo}) > 9'h0FF);
                        psw[4] <= (((reg_a + imm_lo) & 4'hF) < reg_a[3:0]);
                    end
                    8'h56: begin                                  // ACI A,imm (+ CY)
                        reg_a  <= reg_a + imm_lo + {7'd0, psw[0]};
                        psw[6] <= (((reg_a + imm_lo + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                        psw[0] <= (({1'b0, reg_a} + {1'b0, imm_lo} + {8'd0, psw[0]}) > 9'h0FF);
                        psw[4] <= (((reg_a + imm_lo + {7'd0, psw[0]}) & 4'hF) < reg_a[3:0]);
                    end
                    8'h66: begin                                  // SUI A,imm
                        reg_a  <= reg_a - imm_lo;
                        psw[6] <= (((reg_a - imm_lo) & 8'hFF) == 8'h00);
                        psw[0] <= (imm_lo > reg_a);
                        psw[4] <= (((reg_a - imm_lo) & 4'hF) > reg_a[3:0]);
                    end
                    8'h76: begin                                  // SBI A,imm (- CY)
                        reg_a  <= reg_a - imm_lo - {7'd0, psw[0]};
                        psw[6] <= (((reg_a - imm_lo - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                        psw[0] <= (({1'b0, imm_lo} + {8'd0, psw[0]}) > {1'b0, reg_a});
                        psw[4] <= (((reg_a - imm_lo - {7'd0, psw[0]}) & 4'hF) > reg_a[3:0]);
                    end
                    8'h26: begin                                  // ADINC A,imm (SKIP_NC)
                        reg_a  <= reg_a + imm_lo;
                        psw[6] <= (((reg_a + imm_lo) & 8'hFF) == 8'h00);
                        psw[0] <= (({1'b0, reg_a} + {1'b0, imm_lo}) > 9'h0FF);
                        psw[4] <= (((reg_a + imm_lo) & 4'hF) < reg_a[3:0]);
                        if (({1'b0, reg_a} + {1'b0, imm_lo}) <= 9'h0FF)
                            psw[5] <= 1'b1;                       // SKIP_NC
                    end
                    8'h36: begin                                  // SUINB A,imm (SKIP_NC)
                        reg_a  <= reg_a - imm_lo;
                        psw[6] <= (((reg_a - imm_lo) & 8'hFF) == 8'h00);
                        psw[0] <= (imm_lo > reg_a);
                        psw[4] <= (((reg_a - imm_lo) & 4'hF) > reg_a[3:0]);
                        if (imm_lo <= reg_a) psw[5] <= 1'b1;      // SKIP_NC
                    end

                    // ANI/XRI/ORI A,imm : A <- A op imm.  Per MAME 6071/
                    // 6143/6215, only Z is updated — CY, HC, SK left alone.
                    // (Earlier port revisions cleared CY/HC and XRI also
                    // cleared SK, matching the buggy convention shared by
                    // the d60 logic ops; that's been corrected here.)
                    8'h07: begin
                        reg_a  <= reg_a & imm_lo;
                        psw[6] <= ((reg_a & imm_lo) == 8'h00);
                    end
                    8'h16: begin
                        reg_a  <= reg_a ^ imm_lo;
                        psw[6] <= ((reg_a ^ imm_lo) == 8'h00);
                    end
                    8'h17: begin
                        reg_a  <= reg_a | imm_lo;
                        psw[6] <= ((reg_a | imm_lo) == 8'h00);
                    end

                    8'h48: begin                                  // d48 SK/SKN/TABLE
                        case (sub_op)
                            8'h08: ;                              // SK NV : never
                            8'h0A: if ( psw[0]) psw[5] <= 1'b1;   // SK CY
                            8'h0B: if ( psw[4]) psw[5] <= 1'b1;   // SK HC
                            8'h0C: if ( psw[6]) psw[5] <= 1'b1;   // SK Z
                            8'h18: psw[5] <= 1'b1;                // SKN NV -> always skip
                            8'h1A: if (!psw[0]) psw[5] <= 1'b1;   // SKN CY
                            8'h1B: if (!psw[4]) psw[5] <= 1'b1;   // SKN HC
                            8'h1C: if (!psw[6]) psw[5] <= 1'b1;   // SKN Z
                            // CY flag manipulation (MAME upd7810_opcodes.cpp
                            // 191/197). psw[0] is CY.
                            8'h2A: psw[0] <= 1'b0;                // CLC
                            8'h2B: psw[0] <= 1'b1;                // STC
                            // Shift/rotate family for A/B/C.  sub_op bits:
                            //   [5:4] operation: 00/01=SLRC/SLLC (with SKIP_CY)
                            //                    10=SLR/SLL (no SKIP)
                            //                    11=RLR/RLL (rotate through CY)
                            //   [2]:   direction 0=right, 1=left
                            //   [1:0]: reg 01=A, 10=B, 11=C
                            // Sources: MAME upd7810_opcodes.cpp 28-75 (SLRC/SLLC),
                            //          132-171 (SLR/SLL), 220-266 (RLR/RLL).
                            8'h01: begin psw[0] <= reg_a[0];
                                         reg_a  <= reg_a >> 1;
                                         if (reg_a[0]) psw[5] <= 1'b1;
                                  end  // SLRC_A
                            8'h02: begin psw[0] <= reg_b[0];
                                         reg_b  <= reg_b >> 1;
                                         if (reg_b[0]) psw[5] <= 1'b1;
                                  end  // SLRC_B
                            8'h03: begin psw[0] <= reg_c[0];
                                         reg_c  <= reg_c >> 1;
                                         if (reg_c[0]) psw[5] <= 1'b1;
                                  end  // SLRC_C
                            8'h05: begin psw[0] <= reg_a[7];
                                         reg_a  <= reg_a << 1;
                                         if (reg_a[7]) psw[5] <= 1'b1;
                                  end  // SLLC_A
                            8'h06: begin psw[0] <= reg_b[7];
                                         reg_b  <= reg_b << 1;
                                         if (reg_b[7]) psw[5] <= 1'b1;
                                  end  // SLLC_B
                            8'h07: begin psw[0] <= reg_c[7];
                                         reg_c  <= reg_c << 1;
                                         if (reg_c[7]) psw[5] <= 1'b1;
                                  end  // SLLC_C
                            8'h21: begin psw[0] <= reg_a[0];
                                         reg_a  <= reg_a >> 1;
                                  end  // SLR_A
                            8'h22: begin psw[0] <= reg_b[0];
                                         reg_b  <= reg_b >> 1;
                                  end  // SLR_B
                            8'h23: begin psw[0] <= reg_c[0];
                                         reg_c  <= reg_c >> 1;
                                  end  // SLR_C
                            8'h25: begin psw[0] <= reg_a[7];
                                         reg_a  <= reg_a << 1;
                                  end  // SLL_A
                            8'h26: begin psw[0] <= reg_b[7];
                                         reg_b  <= reg_b << 1;
                                  end  // SLL_B
                            8'h27: begin psw[0] <= reg_c[7];
                                         reg_c  <= reg_c << 1;
                                  end  // SLL_C
                            8'h31: begin psw[0] <= reg_a[0];
                                         reg_a  <= {psw[0], reg_a[7:1]};
                                  end  // RLR_A (rotate right through CY)
                            8'h32: begin psw[0] <= reg_b[0];
                                         reg_b  <= {psw[0], reg_b[7:1]};
                                  end  // RLR_B
                            8'h33: begin psw[0] <= reg_c[0];
                                         reg_c  <= {psw[0], reg_c[7:1]};
                                  end  // RLR_C
                            8'h35: begin psw[0] <= reg_a[7];
                                         reg_a  <= {reg_a[6:0], psw[0]};
                                  end  // RLL_A (rotate left through CY)
                            8'h36: begin psw[0] <= reg_b[7];
                                         reg_b  <= {reg_b[6:0], psw[0]};
                                  end  // RLL_B
                            8'h37: begin psw[0] <= reg_c[7];
                                         reg_c  <= {reg_c[6:0], psw[0]};
                                  end  // RLL_C
                            // JEA (0x28): PC <- EA.  No flags.
                            // MAME upd7810_opcodes.cpp:174.
                            8'h28: pc <= reg_ea;
                            // CALB (0x29): push PC, then PC <- BC.  Reuses
                            // S_CALL_PUSH_H/L; S_CALL_PUSH_L decodes the
                            // (opcode==0x48, sub_op==0x29) case to set the
                            // target instead of using imm.  MAME 180.
                            8'h29: begin
                                goto_state(S_CALL_PUSH_H);
                                dbg_retire <= 1'b0;
                            end
                            // MUL A/B/C (0x2D/2E/2F): EA <- A * X.  No flags.
                            // MAME 203/210/216.  16-bit unsigned product.
                            8'h2D: reg_ea <= reg_a * reg_a;
                            8'h2E: reg_ea <= reg_a * reg_b;
                            8'h2F: reg_ea <= reg_a * reg_c;
                            // NEGA (0x3A): A <- -A (~A + 1).  Flags untouched
                            // per MAME 287 (no SET_Z, no ZHC_*).
                            8'h3A: reg_a <= ~reg_a + 8'd1;
                            // ===== SKIT/SKNIT family (m39) =====
                            // SKIT_X: skip if interrupt-source flag X is set;
                            //         then clear the flag.
                            // SKNIT_X: skip if X is NOT set; then clear the flag.
                            // Of the 18 flag sources MAME tracks, this MCU
                            // bring-up only models INTF1 (the 68k command-in
                            // request, latched in int1_pending).  For the
                            // other 17 sources, the flag is always 0 in our
                            // model — so SKIT_X is always a no-skip and
                            // SKNIT_X is always a skip (matching MAME's
                            // behaviour given a permanently-deasserted source).
                            // SKIT_NMI / SKNIT_NMI use the NMI pin level
                            // directly: NMI is never asserted in our model,
                            // so SKIT_NMI is always a skip and SKNIT_NMI is
                            // always a no-skip (note the inversion).
                            // MAME upd7810_opcodes.cpp:353-637.
                            8'h40: psw[5] <= 1'b1;                  // SKIT_NMI  (always skip)
                            8'h41: ;                                // SKIT_FT0  (no-skip)
                            8'h42: ;                                // SKIT_FT1
                            8'h43: begin                             // SKIT_F1
                                if (int1_pending) psw[5] <= 1'b1;
                                int1_pending <= 1'b0;
                            end
                            8'h44: ;                                // SKIT_F2
                            8'h45: ;                                // SKIT_FE0
                            8'h46: ;                                // SKIT_FE1
                            8'h47: ;                                // SKIT_FEIN
                            8'h48: ;                                // SKIT_FAD
                            8'h49: ;                                // SKIT_FSR
                            8'h4A: ;                                // SKIT_FST
                            8'h4B: ;                                // SKIT_ER
                            8'h4C: ;                                // SKIT_OV
                            8'h50: ;                                // SKIT_AN4
                            8'h51: ;                                // SKIT_AN5
                            8'h52: ;                                // SKIT_AN6
                            8'h53: ;                                // SKIT_AN7
                            8'h54: ;                                // SKIT_SB
                            8'h60: ;                                // SKNIT_NMI (no-skip)
                            8'h61: psw[5] <= 1'b1;                  // SKNIT_FT0 (always skip)
                            8'h62: psw[5] <= 1'b1;                  // SKNIT_FT1
                            8'h63: begin                             // SKNIT_F1
                                if (!int1_pending) psw[5] <= 1'b1;
                                int1_pending <= 1'b0;
                            end
                            8'h64: psw[5] <= 1'b1;                  // SKNIT_F2
                            8'h65: psw[5] <= 1'b1;                  // SKNIT_FE0
                            8'h66: psw[5] <= 1'b1;                  // SKNIT_FE1
                            8'h67: psw[5] <= 1'b1;                  // SKNIT_FEIN
                            8'h68: psw[5] <= 1'b1;                  // SKNIT_FAD
                            8'h69: psw[5] <= 1'b1;                  // SKNIT_FSR
                            8'h6A: psw[5] <= 1'b1;                  // SKNIT_FST
                            8'h6B: psw[5] <= 1'b1;                  // SKNIT_ER
                            8'h6C: psw[5] <= 1'b1;                  // SKNIT_OV
                            8'h70: psw[5] <= 1'b1;                  // SKNIT_AN4
                            8'h71: psw[5] <= 1'b1;                  // SKNIT_AN5
                            8'h72: psw[5] <= 1'b1;                  // SKNIT_AN6
                            8'h73: psw[5] <= 1'b1;                  // SKNIT_AN7
                            8'h74: psw[5] <= 1'b1;                  // SKNIT_SB
                            // ===== DMOV timer regs (m40) =====
                            // ECNT/ECPT are 16-bit timer counters; in this
                            // model timers don't tick, so they read as 0.
                            // ETM0/ETM1 are 16-bit modulo regs; we maintain
                            // them so DIV/etc reads round-trip, but they
                            // don't drive anything visible.
                            // MAME upd7810_opcodes.cpp:836-857.
                            8'hC0: reg_ea <= 16'h0000;              // DMOV EA,ECNT
                            8'hC1: reg_ea <= 16'h0000;              // DMOV EA,ECPT
                            8'hD2: reg_etm0 <= reg_ea;              // DMOV ETM0,EA
                            8'hD3: reg_etm1 <= reg_ea;              // DMOV ETM1,EA

                            // RLD/RRD (m36): BCD nibble swap with (HL).
                            // RLD: A.lo <- m.hi, m.hi <- m.lo, m.lo <- A.lo
                            //   i.e. A = (A & 0xF0) | (m >> 4);
                            //        (HL) = (m << 4) | (A_old & 0x0F)
                            // RRD: A.lo <- m.lo, m.lo <- m.hi, m.hi <- A.lo
                            //   i.e. A = (A & 0xF0) | (m & 0x0F);
                            //        (HL) = (A_old << 4) | (m >> 4)
                            // Two-cycle RMW: read in S_RLDRRD_RD, write in
                            // S_RLDRRD_WR.  No flags.  MAME 269/278.
                            8'h38, 8'h39: begin
                                goto_state(S_RLDRRD_RD);
                                dbg_retire <= 1'b0;
                            end
                            // ===== d48 misc inline ops (m35) =====
                            // HALT (0x3B): MAME 293 spins on the instruction
                            // until an interrupt fires.  We mirror MAME's
                            // PC -= 1 so the next fetch re-enters the same
                            // sub-op slot (consistent across HDL+fixture).
                            8'h3B: pc <= pc - 16'd1;
                            // STOP (0xBB): same idle behaviour for CMOS.
                            8'hBB: pc <= pc - 16'd1;
                            // DIV_A/B/C (0x3D/0x3E/0x3F): 16-bit dividend EA,
                            // 8-bit divisor X.  EA <- EA / X; X <- EA % X.
                            // Divide-by-zero: X <- EAL; EA <- 0xFFFF.
                            // MAME 302/319/336.
                            8'h3D: begin
                                if (reg_a != 8'h00) begin
                                    div_quot    <= reg_ea;
                                    div_rem     <= 9'h000;
                                    div_divisor <= reg_a;
                                    div_count   <= 5'd16;
                                    div_sel     <= 2'd0;
                                    state       <= S_DIV_STEP;
                                    dbg_retire  <= 1'b0;
                                end else begin
                                    reg_a  <= reg_ea[7:0];
                                    reg_ea <= 16'hFFFF;
                                end
                            end
                            8'h3E: begin
                                if (reg_b != 8'h00) begin
                                    div_quot    <= reg_ea;
                                    div_rem     <= 9'h000;
                                    div_divisor <= reg_b;
                                    div_count   <= 5'd16;
                                    div_sel     <= 2'd1;
                                    state       <= S_DIV_STEP;
                                    dbg_retire  <= 1'b0;
                                end else begin
                                    reg_b  <= reg_ea[7:0];
                                    reg_ea <= 16'hFFFF;
                                end
                            end
                            8'h3F: begin
                                if (reg_c != 8'h00) begin
                                    div_quot    <= reg_ea;
                                    div_rem     <= 9'h000;
                                    div_divisor <= reg_c;
                                    div_count   <= 5'd16;
                                    div_sel     <= 2'd2;
                                    state       <= S_DIV_STEP;
                                    dbg_retire  <= 1'b0;
                                end else begin
                                    reg_c  <= reg_ea[7:0];
                                    reg_ea <= 16'hFFFF;
                                end
                            end
                            // 16-bit shifts on EA (m35).
                            // DSLR_EA (0xA0): EA >>= 1, CY = old EA[0].
                            8'hA0: begin
                                psw[0] <= reg_ea[0];
                                reg_ea <= reg_ea >> 1;
                            end
                            // DSLL_EA (0xA4): EA <<= 1, CY = old EA[15].
                            8'hA4: begin
                                psw[0] <= reg_ea[15];
                                reg_ea <= reg_ea << 1;
                            end
                            // DRLR_EA (0xB0): rotate right through CY.
                            8'hB0: begin
                                psw[0] <= reg_ea[0];
                                reg_ea <= {psw[0], reg_ea[15:1]};
                            end
                            // DRLL_EA (0xB4): rotate left through CY.
                            8'hB4: begin
                                psw[0] <= reg_ea[15];
                                reg_ea <= {reg_ea[14:0], psw[0]};
                            end
                            // TABLE: EA_lo = (PC+A); EA_hi = (PC+A+1).
                            // Two-cycle memory read; retire in HI state.
                            8'hA8: begin
                                goto_state(S_TABLE_LO);
                                dbg_retire <= 1'b0;
                            end
                            // LDEAX family (d48 0x82-0x8F, m34): EAL = (base);
                            // EAH = (base+1).  base address picked by sub_op[3:0]
                            // via eax_base_addr; m12 0x83 (LDEAX_H) is a special
                            // case under the same machinery.  Two-cycle memory
                            // read; post-mod (Dp/Hp adds 2) happens in S_LDEAX_HI.
                            // MAME upd7810_opcodes.cpp:641-712.
                            8'h82, 8'h83, 8'h84, 8'h85,
                            8'h8B, 8'h8C, 8'h8D, 8'h8E, 8'h8F: begin
                                goto_state(S_LDEAX_LO);
                                dbg_retire <= 1'b0;
                            end
                            // STEAX family (d48 0x92-0x9F, m34): (base) = EAL;
                            // (base+1) = EAH.  Same address muxing as LDEAX.
                            // Two-cycle memory write; post-mod in S_STEAX_HI.
                            // MAME upd7810_opcodes.cpp:715-786.
                            8'h92, 8'h93, 8'h94, 8'h95,
                            8'h9B, 8'h9C, 8'h9D, 8'h9E, 8'h9F: begin
                                goto_state(S_STEAX_LO);
                                dbg_retire <= 1'b0;
                            end
                            default: begin goto_state(S_TRAP); dbg_retire <= 1'b0; end
                        endcase
                    end

                    8'h4C: begin                                  // d4C MOV A,*
                        case (sub_op)
                            8'hC0: reg_a <= pa_in;
                            8'hC1: reg_a <= pb_in;
                            8'hC2: reg_a <= pc_in;
                            8'hC3: reg_a <= pd_in;
                            8'hC5: reg_a <= reg_pf;     // MAME 885
                            8'hC6: reg_a <= reg_mkh;
                            8'hC7: reg_a <= reg_mkl;
                            8'hC8: reg_a <= reg_anm;
                            8'hC9: reg_a <= reg_smh;    // MOV A,SMH (m40)
                            8'hCB: reg_a <= (reg_eom & 8'h22); // MOV A,EOM (m40)
                            8'hCD: reg_a <= reg_tmm;
                            8'hD9: reg_a <= 8'h00;      // MOV A,RXB (serial stub)
                            8'hE0: reg_a <= cr0_in;
                            8'hE1: reg_a <= cr1_in;
                            8'hE2: reg_a <= cr2_in;
                            8'hE3: reg_a <= cr3_in;
                            // Unmapped SFRs: read 0xFF (open-bus) per real
                            // hardware convention.  Avoids a trap surface
                            // for any d4C variant we haven't explicitly
                            // modelled (timer regs, serial regs, etc.).
                            default: reg_a <= 8'hFF;
                        endcase
                    end

                    8'h4D: begin                                  // MOV {SFR,port},A
                        case (sub_op)
                            8'hC0: reg_pa  <= reg_a;
                            8'hC1: reg_pb  <= reg_a;
                            8'hC2: reg_pc  <= reg_a;
                            8'hC3: reg_pd  <= reg_a;
                            8'hC5: reg_pf  <= reg_a;     // MAME 990
                            8'hC6: reg_mkh <= reg_a;
                            8'hC7: reg_mkl <= reg_a;
                            8'hC8: reg_anm <= reg_a;
                            8'hC9: reg_smh <= reg_a;     // MOV SMH,A (m40)
                            8'hCA: reg_sml <= reg_a;     // MOV SML,A (serial stub)
                            8'hCB: reg_eom <= reg_a;     // MOV EOM,A (m40)
                            8'hCC: reg_etmm <= reg_a;    // MOV ETMM,A (timer stub)
                            8'hCD: reg_tmm <= reg_a;
                            8'hD0: reg_mm  <= reg_a;
                            8'hD1: reg_mcc <= reg_a;
                            8'hD2: reg_ma  <= reg_a;
                            8'hD3: reg_mb  <= reg_a;
                            8'hD4: reg_mc  <= reg_a;
                            8'hD7: reg_mf  <= reg_a;
                            8'hD8: reg_txb <= reg_a;     // MOV TXB,A (serial stub)
                            8'hE5: reg_mt  <= reg_a;     // MOV MT,A (7807 stub)
                            8'hE8: reg_zcm <= reg_a;     // MOV ZCM,A (ZC stub)
                            // Unmapped SFRs: drop write silently per real
                            // hardware convention (write to non-existent
                            // SFR is a no-op).
                            default: ;
                        endcase
                    end

                    8'h64: begin                                  // d64 SFR ops
                        // ===== d64 generic SFR-arith block (m38) =====
                        // 16 op rows on each of two halves (lower SFRs at
                        // 0x00-0x7F, upper SFRs at 0x80-0xFF).  sub_op[6:3]
                        // selects the op within each half; sub_op[2:0]
                        // selects the SFR.  Per MAME upd7810_opcodes.cpp:
                        //   MVI 2929+, ANI 2998+, XRI 3046+, ORI 3094+,
                        //   ADINC 3117+, GTI 3214+, SUINB 3247+, LTI 3344+,
                        //   ADI 3377+, ONI 3473+, ACI 3506+, OFFI 3602+,
                        //   SUI 3635+, NEI 3731+, SBI 3941+, EQI 4297+
                        //   (plus the upper-half mirrors at 4173+).
                        case (sub_op)
                            // === MVI lower-half SFRs ===
                            8'h00: reg_pa  <= imm_lo;
                            8'h01: reg_pb  <= imm_lo;
                            8'h02: reg_pc  <= imm_lo;
                            8'h03: reg_pd  <= imm_lo;
                            8'h05: reg_pf  <= imm_lo;
                            8'h06: reg_mkh <= imm_lo;
                            8'h07: reg_mkl <= imm_lo;
                            // === MVI upper-half SFRs ===
                            8'h80: reg_anm <= imm_lo;
                            8'h81: reg_smh <= imm_lo;
                            8'h83: reg_eom <= imm_lo;
                            8'h85: reg_tmm <= imm_lo;

                            // === ANI SFR,xx (0x08-0x0F lower, 0x88-0x8F upper) ===
                            // SFR &= xx; SET_Z only.  MAME 2998+/4188+.
                            8'h08, 8'h09, 8'h0A, 8'h0B,
                                   8'h0D, 8'h0E, 8'h0F: begin
                                psw[6] <= ((d64_sfr_lo & imm_lo) == 8'h00);
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  & imm_lo;
                                    3'd1: reg_pb  <= reg_pb  & imm_lo;
                                    3'd2: reg_pc  <= reg_pc  & imm_lo;
                                    3'd3: reg_pd  <= reg_pd  & imm_lo;
                                    3'd5: reg_pf  <= reg_pf  & imm_lo;
                                    3'd6: reg_mkh <= reg_mkh & imm_lo;
                                    3'd7: reg_mkl <= reg_mkl & imm_lo;
                                    default: ;
                                endcase
                            end
                            8'h88, 8'h89,        8'h8B,        8'h8D: begin
                                psw[6] <= ((d64_sfr_hi & imm_lo) == 8'h00);
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm & imm_lo;
                                    3'd1: reg_smh <= reg_smh & imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi & imm_lo;
                                    3'd5: reg_tmm <= reg_tmm & imm_lo;
                                    default: ;
                                endcase
                            end

                            // === XRI SFR,xx (0x10-0x17, 0x90-0x97) ===
                            8'h10, 8'h11, 8'h12, 8'h13,
                                   8'h15, 8'h16, 8'h17: begin
                                psw[6] <= ((d64_sfr_lo ^ imm_lo) == 8'h00);
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  ^ imm_lo;
                                    3'd1: reg_pb  <= reg_pb  ^ imm_lo;
                                    3'd2: reg_pc  <= reg_pc  ^ imm_lo;
                                    3'd3: reg_pd  <= reg_pd  ^ imm_lo;
                                    3'd5: reg_pf  <= reg_pf  ^ imm_lo;
                                    3'd6: reg_mkh <= reg_mkh ^ imm_lo;
                                    3'd7: reg_mkl <= reg_mkl ^ imm_lo;
                                    default: ;
                                endcase
                            end
                            8'h90, 8'h91,        8'h93,        8'h95: begin
                                psw[6] <= ((d64_sfr_hi ^ imm_lo) == 8'h00);
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm ^ imm_lo;
                                    3'd1: reg_smh <= reg_smh ^ imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi ^ imm_lo;
                                    3'd5: reg_tmm <= reg_tmm ^ imm_lo;
                                    default: ;
                                endcase
                            end

                            // === ORI SFR,xx (0x18-0x1F, 0x98-0x9F) ===
                            8'h18, 8'h19, 8'h1A, 8'h1B,
                                   8'h1D, 8'h1E, 8'h1F: begin
                                psw[6] <= ((d64_sfr_lo | imm_lo) == 8'h00);
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  | imm_lo;
                                    3'd1: reg_pb  <= reg_pb  | imm_lo;
                                    3'd2: reg_pc  <= reg_pc  | imm_lo;
                                    3'd3: reg_pd  <= reg_pd  | imm_lo;
                                    3'd5: reg_pf  <= reg_pf  | imm_lo;
                                    3'd6: reg_mkh <= reg_mkh | imm_lo;
                                    3'd7: reg_mkl <= reg_mkl | imm_lo;
                                    default: ;
                                endcase
                            end
                            8'h98, 8'h99,        8'h9B,        8'h9D: begin
                                psw[6] <= ((d64_sfr_hi | imm_lo) == 8'h00);
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm | imm_lo;
                                    3'd1: reg_smh <= reg_smh | imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi | imm_lo;
                                    3'd5: reg_tmm <= reg_tmm | imm_lo;
                                    default: ;
                                endcase
                            end

                            // === ADINC SFR,xx (0x20-0x27, 0xA0-0xA7) ===
                            // SFR += xx; ZHC_ADD; SKIP_NC.
                            8'h20, 8'h21, 8'h22, 8'h23,
                                   8'h25, 8'h26, 8'h27: begin
                                psw[6] <= (((d64_sfr_lo + imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d64_sfr_lo} + {1'b0, imm_lo}) > 9'h0FF;
                                psw[4] <= (((d64_sfr_lo + imm_lo) & 4'hF) < (d64_sfr_lo[3:0]));
                                if (({1'b0, d64_sfr_lo} + {1'b0, imm_lo}) <= 9'h0FF)
                                    psw[5] <= 1'b1;
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  + imm_lo;
                                    3'd1: reg_pb  <= reg_pb  + imm_lo;
                                    3'd2: reg_pc  <= reg_pc  + imm_lo;
                                    3'd3: reg_pd  <= reg_pd  + imm_lo;
                                    3'd5: reg_pf  <= reg_pf  + imm_lo;
                                    3'd6: reg_mkh <= reg_mkh + imm_lo;
                                    3'd7: reg_mkl <= reg_mkl + imm_lo;
                                    default: ;
                                endcase
                            end
                            8'hA0, 8'hA1,        8'hA3,        8'hA5: begin
                                psw[6] <= (((d64_sfr_hi + imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d64_sfr_hi} + {1'b0, imm_lo}) > 9'h0FF;
                                psw[4] <= (((d64_sfr_hi + imm_lo) & 4'hF) < (d64_sfr_hi[3:0]));
                                if (({1'b0, d64_sfr_hi} + {1'b0, imm_lo}) <= 9'h0FF)
                                    psw[5] <= 1'b1;
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm + imm_lo;
                                    3'd1: reg_smh <= reg_smh + imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi + imm_lo;
                                    3'd5: reg_tmm <= reg_tmm + imm_lo;
                                    default: ;
                                endcase
                            end

                            // === GTI SFR,xx (0x28-0x2F, 0xA8-0xAF) — compare SFR>xx ===
                            // tmp = SFR - xx - 1; ZHC_SUB; SKIP_NC.
                            8'h28, 8'h29, 8'h2A, 8'h2B,
                                   8'h2D, 8'h2E, 8'h2F: begin
                                psw[6] <= (({8'd0, d64_sfr_lo} - {8'd0, imm_lo} - 16'd1) == 16'h0000);
                                psw[0] <= (d64_sfr_lo <= imm_lo);
                                psw[4] <= (((d64_sfr_lo - imm_lo - 8'd1) & 4'hF) > (d64_sfr_lo[3:0]));
                                if (d64_sfr_lo > imm_lo) psw[5] <= 1'b1;
                            end
                            8'hA8, 8'hA9,        8'hAB,        8'hAD: begin
                                psw[6] <= (({8'd0, d64_sfr_hi} - {8'd0, imm_lo} - 16'd1) == 16'h0000);
                                psw[0] <= (d64_sfr_hi <= imm_lo);
                                psw[4] <= (((d64_sfr_hi - imm_lo - 8'd1) & 4'hF) > (d64_sfr_hi[3:0]));
                                if (d64_sfr_hi > imm_lo) psw[5] <= 1'b1;
                            end

                            // === SUINB SFR,xx (0x30-0x37, 0xB0-0xB7) ===
                            // SFR -= xx; ZHC_SUB; SKIP_NC.
                            8'h30, 8'h31, 8'h32, 8'h33,
                                   8'h35, 8'h36, 8'h37: begin
                                psw[6] <= (((d64_sfr_lo - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d64_sfr_lo);
                                psw[4] <= (((d64_sfr_lo - imm_lo) & 4'hF) > (d64_sfr_lo[3:0]));
                                if (imm_lo <= d64_sfr_lo) psw[5] <= 1'b1;
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  - imm_lo;
                                    3'd1: reg_pb  <= reg_pb  - imm_lo;
                                    3'd2: reg_pc  <= reg_pc  - imm_lo;
                                    3'd3: reg_pd  <= reg_pd  - imm_lo;
                                    3'd5: reg_pf  <= reg_pf  - imm_lo;
                                    3'd6: reg_mkh <= reg_mkh - imm_lo;
                                    3'd7: reg_mkl <= reg_mkl - imm_lo;
                                    default: ;
                                endcase
                            end
                            8'hB0, 8'hB1,        8'hB3,        8'hB5: begin
                                psw[6] <= (((d64_sfr_hi - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d64_sfr_hi);
                                psw[4] <= (((d64_sfr_hi - imm_lo) & 4'hF) > (d64_sfr_hi[3:0]));
                                if (imm_lo <= d64_sfr_hi) psw[5] <= 1'b1;
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm - imm_lo;
                                    3'd1: reg_smh <= reg_smh - imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi - imm_lo;
                                    3'd5: reg_tmm <= reg_tmm - imm_lo;
                                    default: ;
                                endcase
                            end

                            // === LTI SFR,xx (0x38-0x3F, 0xB8-0xBF) — compare SFR<xx ===
                            // tmp = SFR - xx; ZHC_SUB; SKIP_CY.
                            8'h38, 8'h39, 8'h3A, 8'h3B,
                                   8'h3D, 8'h3E, 8'h3F: begin
                                psw[6] <= (((d64_sfr_lo - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d64_sfr_lo);
                                psw[4] <= (((d64_sfr_lo - imm_lo) & 4'hF) > (d64_sfr_lo[3:0]));
                                if (imm_lo > d64_sfr_lo) psw[5] <= 1'b1;
                            end
                            8'hB8, 8'hB9,        8'hBB,        8'hBD: begin
                                psw[6] <= (((d64_sfr_hi - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d64_sfr_hi);
                                psw[4] <= (((d64_sfr_hi - imm_lo) & 4'hF) > (d64_sfr_hi[3:0]));
                                if (imm_lo > d64_sfr_hi) psw[5] <= 1'b1;
                            end

                            // === ADI SFR,xx (0x40-0x47, 0xC0-0xC7) ===
                            // SFR += xx; ZHC_ADD.  No skip.
                            8'h40, 8'h41, 8'h42, 8'h43,
                                   8'h45, 8'h46, 8'h47: begin
                                psw[6] <= (((d64_sfr_lo + imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d64_sfr_lo} + {1'b0, imm_lo}) > 9'h0FF;
                                psw[4] <= (((d64_sfr_lo + imm_lo) & 4'hF) < (d64_sfr_lo[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  + imm_lo;
                                    3'd1: reg_pb  <= reg_pb  + imm_lo;
                                    3'd2: reg_pc  <= reg_pc  + imm_lo;
                                    3'd3: reg_pd  <= reg_pd  + imm_lo;
                                    3'd5: reg_pf  <= reg_pf  + imm_lo;
                                    3'd6: reg_mkh <= reg_mkh + imm_lo;
                                    3'd7: reg_mkl <= reg_mkl + imm_lo;
                                    default: ;
                                endcase
                            end
                            8'hC0, 8'hC1,        8'hC3,        8'hC5: begin
                                psw[6] <= (((d64_sfr_hi + imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d64_sfr_hi} + {1'b0, imm_lo}) > 9'h0FF;
                                psw[4] <= (((d64_sfr_hi + imm_lo) & 4'hF) < (d64_sfr_hi[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm + imm_lo;
                                    3'd1: reg_smh <= reg_smh + imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi + imm_lo;
                                    3'd5: reg_tmm <= reg_tmm + imm_lo;
                                    default: ;
                                endcase
                            end

                            // === ONI SFR,xx (0x48-0x4F, 0xC8-0xCF) ===
                            // SK if (SFR & xx) != 0; no flag updates.
                            8'h48, 8'h49, 8'h4A, 8'h4B,
                                   8'h4D, 8'h4E, 8'h4F: begin
                                if ((d64_sfr_lo & imm_lo) != 8'h00)
                                    psw[5] <= 1'b1;
                            end
                            8'hC8, 8'hC9,        8'hCB,        8'hCD: begin
                                if ((d64_sfr_hi & imm_lo) != 8'h00)
                                    psw[5] <= 1'b1;
                            end

                            // === ACI SFR,xx (0x50-0x57, 0xD0-0xD7) ===
                            // SFR += xx + CY; ZHC_ADD with carry.  No skip.
                            8'h50, 8'h51, 8'h52, 8'h53,
                                   8'h55, 8'h56, 8'h57: begin
                                psw[6] <= (((d64_sfr_lo + imm_lo + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d64_sfr_lo} + {1'b0, imm_lo} + {8'd0, psw[0]}) > 9'h0FF;
                                psw[4] <= (((d64_sfr_lo + imm_lo + {7'd0, psw[0]}) & 4'hF) < (d64_sfr_lo[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  + imm_lo + {7'd0, psw[0]};
                                    3'd1: reg_pb  <= reg_pb  + imm_lo + {7'd0, psw[0]};
                                    3'd2: reg_pc  <= reg_pc  + imm_lo + {7'd0, psw[0]};
                                    3'd3: reg_pd  <= reg_pd  + imm_lo + {7'd0, psw[0]};
                                    3'd5: reg_pf  <= reg_pf  + imm_lo + {7'd0, psw[0]};
                                    3'd6: reg_mkh <= reg_mkh + imm_lo + {7'd0, psw[0]};
                                    3'd7: reg_mkl <= reg_mkl + imm_lo + {7'd0, psw[0]};
                                    default: ;
                                endcase
                            end
                            8'hD0, 8'hD1,        8'hD3,        8'hD5: begin
                                psw[6] <= (((d64_sfr_hi + imm_lo + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d64_sfr_hi} + {1'b0, imm_lo} + {8'd0, psw[0]}) > 9'h0FF;
                                psw[4] <= (((d64_sfr_hi + imm_lo + {7'd0, psw[0]}) & 4'hF) < (d64_sfr_hi[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm + imm_lo + {7'd0, psw[0]};
                                    3'd1: reg_smh <= reg_smh + imm_lo + {7'd0, psw[0]};
                                    3'd3: reg_eom <= d64_sfr_hi + imm_lo + {7'd0, psw[0]};
                                    3'd5: reg_tmm <= reg_tmm + imm_lo + {7'd0, psw[0]};
                                    default: ;
                                endcase
                            end

                            // === OFFI SFR,xx (0x58-0x5F, 0xD8-0xDF) ===
                            // SK if (SFR & xx) == 0; no flag updates.
                            8'h58, 8'h59, 8'h5A, 8'h5B,
                                   8'h5D, 8'h5E, 8'h5F: begin
                                if ((d64_sfr_lo & imm_lo) == 8'h00)
                                    psw[5] <= 1'b1;
                            end
                            8'hD8, 8'hD9,        8'hDB,        8'hDD: begin
                                if ((d64_sfr_hi & imm_lo) == 8'h00)
                                    psw[5] <= 1'b1;
                            end

                            // === SUI SFR,xx (0x60-0x67, 0xE0-0xE7) ===
                            // SFR -= xx; ZHC_SUB.  No skip.
                            8'h60, 8'h61, 8'h62, 8'h63,
                                   8'h65, 8'h66, 8'h67: begin
                                psw[6] <= (((d64_sfr_lo - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d64_sfr_lo);
                                psw[4] <= (((d64_sfr_lo - imm_lo) & 4'hF) > (d64_sfr_lo[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  - imm_lo;
                                    3'd1: reg_pb  <= reg_pb  - imm_lo;
                                    3'd2: reg_pc  <= reg_pc  - imm_lo;
                                    3'd3: reg_pd  <= reg_pd  - imm_lo;
                                    3'd5: reg_pf  <= reg_pf  - imm_lo;
                                    3'd6: reg_mkh <= reg_mkh - imm_lo;
                                    3'd7: reg_mkl <= reg_mkl - imm_lo;
                                    default: ;
                                endcase
                            end
                            8'hE0, 8'hE1,        8'hE3,        8'hE5: begin
                                psw[6] <= (((d64_sfr_hi - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d64_sfr_hi);
                                psw[4] <= (((d64_sfr_hi - imm_lo) & 4'hF) > (d64_sfr_hi[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm - imm_lo;
                                    3'd1: reg_smh <= reg_smh - imm_lo;
                                    3'd3: reg_eom <= d64_sfr_hi - imm_lo;
                                    3'd5: reg_tmm <= reg_tmm - imm_lo;
                                    default: ;
                                endcase
                            end

                            // === NEI SFR,xx (0x68-0x6F, 0xE8-0xEF) — compare SFR!=xx ===
                            // ZHC_SUB; SKIP_NZ.
                            8'h68, 8'h69, 8'h6A, 8'h6B,
                                   8'h6D, 8'h6E, 8'h6F: begin
                                psw[6] <= (d64_sfr_lo == imm_lo);
                                psw[0] <= (imm_lo > d64_sfr_lo);
                                psw[4] <= (((d64_sfr_lo - imm_lo) & 4'hF) > (d64_sfr_lo[3:0]));
                                if (d64_sfr_lo != imm_lo) psw[5] <= 1'b1;
                            end
                            8'hE8, 8'hE9,        8'hEB,        8'hED: begin
                                psw[6] <= (d64_sfr_hi == imm_lo);
                                psw[0] <= (imm_lo > d64_sfr_hi);
                                psw[4] <= (((d64_sfr_hi - imm_lo) & 4'hF) > (d64_sfr_hi[3:0]));
                                if (d64_sfr_hi != imm_lo) psw[5] <= 1'b1;
                            end

                            // === SBI SFR,xx (0x70-0x77, 0xF0-0xF7) ===
                            // SFR -= xx + CY; ZHC_SUB with carry.  No skip.
                            8'h70, 8'h71, 8'h72, 8'h73,
                                   8'h75, 8'h76, 8'h77: begin
                                psw[6] <= (((d64_sfr_lo - imm_lo - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, imm_lo} + {8'd0, psw[0]}) > {1'b0, d64_sfr_lo};
                                psw[4] <= (((d64_sfr_lo - imm_lo - {7'd0, psw[0]}) & 4'hF) > (d64_sfr_lo[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_pa  <= reg_pa  - imm_lo - {7'd0, psw[0]};
                                    3'd1: reg_pb  <= reg_pb  - imm_lo - {7'd0, psw[0]};
                                    3'd2: reg_pc  <= reg_pc  - imm_lo - {7'd0, psw[0]};
                                    3'd3: reg_pd  <= reg_pd  - imm_lo - {7'd0, psw[0]};
                                    3'd5: reg_pf  <= reg_pf  - imm_lo - {7'd0, psw[0]};
                                    3'd6: reg_mkh <= reg_mkh - imm_lo - {7'd0, psw[0]};
                                    3'd7: reg_mkl <= reg_mkl - imm_lo - {7'd0, psw[0]};
                                    default: ;
                                endcase
                            end
                            8'hF0, 8'hF1,        8'hF3,        8'hF5: begin
                                psw[6] <= (((d64_sfr_hi - imm_lo - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, imm_lo} + {8'd0, psw[0]}) > {1'b0, d64_sfr_hi};
                                psw[4] <= (((d64_sfr_hi - imm_lo - {7'd0, psw[0]}) & 4'hF) > (d64_sfr_hi[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_anm <= reg_anm - imm_lo - {7'd0, psw[0]};
                                    3'd1: reg_smh <= reg_smh - imm_lo - {7'd0, psw[0]};
                                    3'd3: reg_eom <= d64_sfr_hi - imm_lo - {7'd0, psw[0]};
                                    3'd5: reg_tmm <= reg_tmm - imm_lo - {7'd0, psw[0]};
                                    default: ;
                                endcase
                            end

                            // === EQI SFR,xx (0x78-0x7F, 0xF8-0xFF) — compare SFR==xx ===
                            // ZHC_SUB; SKIP_Z.
                            8'h78, 8'h79, 8'h7A, 8'h7B,
                                   8'h7D, 8'h7E, 8'h7F: begin
                                psw[6] <= (d64_sfr_lo == imm_lo);
                                psw[0] <= (imm_lo > d64_sfr_lo);
                                psw[4] <= (((d64_sfr_lo - imm_lo) & 4'hF) > (d64_sfr_lo[3:0]));
                                if (d64_sfr_lo == imm_lo) psw[5] <= 1'b1;
                            end
                            8'hF8, 8'hF9,        8'hFB,        8'hFD: begin
                                psw[6] <= (d64_sfr_hi == imm_lo);
                                psw[0] <= (imm_lo > d64_sfr_hi);
                                psw[4] <= (((d64_sfr_hi - imm_lo) & 4'hF) > (d64_sfr_hi[3:0]));
                                if (d64_sfr_hi == imm_lo) psw[5] <= 1'b1;
                            end

                            default: begin goto_state(S_TRAP); dbg_retire <= 1'b0; end
                        endcase
                    end

                    8'h60: begin                                  // d60 prefix
                        // ANA/XRA/ORA A,reg (0x88-0x9F).  MAME's handlers
                        // set Z from the result and clear CY/HC.  XRA
                        // handlers additionally clear SK; ANA/ORA leave
                        // SK alone.  (Transcribed from upd7810_opcodes.cpp
                        // ANA_A_A / XRA_A_A / ORA_A_A + spot checks.)
                        // Subop low 3 bits select the source register:
                        //   0:V 1:A 2:B 3:C 4:D 5:E 6:H 7:L
                        case (sub_op)
                            // ANA A, <reg>  : A = A & reg
                            8'h88, 8'h89, 8'h8A, 8'h8B,
                            8'h8C, 8'h8D, 8'h8E, 8'h8F: begin
                                reg_a <= reg_a &
                                    ((sub_op[2:0]==3'd0) ? reg_v :
                                     (sub_op[2:0]==3'd1) ? reg_a :
                                     (sub_op[2:0]==3'd2) ? reg_b :
                                     (sub_op[2:0]==3'd3) ? reg_c :
                                     (sub_op[2:0]==3'd4) ? reg_d :
                                     (sub_op[2:0]==3'd5) ? reg_e :
                                     (sub_op[2:0]==3'd6) ? reg_h : reg_l);
                                psw[6] <= ((reg_a &
                                    ((sub_op[2:0]==3'd0) ? reg_v :
                                     (sub_op[2:0]==3'd1) ? reg_a :
                                     (sub_op[2:0]==3'd2) ? reg_b :
                                     (sub_op[2:0]==3'd3) ? reg_c :
                                     (sub_op[2:0]==3'd4) ? reg_d :
                                     (sub_op[2:0]==3'd5) ? reg_e :
                                     (sub_op[2:0]==3'd6) ? reg_h : reg_l))
                                    == 8'h00);
                            end
                            // XRA A, <reg>  : A = A ^ reg.  MAME 1196 only
                            // SET_Z(A); CY/HC/SK left alone.
                            8'h90, 8'h91, 8'h92, 8'h93,
                            8'h94, 8'h95, 8'h96, 8'h97: begin
                                reg_a <= reg_a ^ d60_rs;
                                psw[6] <= ((reg_a ^ d60_rs) == 8'h00);
                            end
                            // ADD A, <reg>  : A = A + reg.  Full ZHC_ADD
                            // per MAME 7510: Z, CY, HC.  SK unchanged.
                            8'hC0, 8'hC1, 8'hC2, 8'hC3,
                            8'hC4, 8'hC5, 8'hC6, 8'hC7: begin
                                reg_a  <= reg_a + d60_rs;
                                psw[6] <= (((reg_a + d60_rs) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, reg_a} + {1'b0, d60_rs}) > 9'h0FF;
                                psw[4] <= (((reg_a + d60_rs) & 4'hF) < (reg_a[3:0]));
                            end
                            // ORA A, <reg>  : A = A | reg
                            8'h98, 8'h99, 8'h9A, 8'h9B,
                            8'h9C, 8'h9D, 8'h9E, 8'h9F: begin
                                reg_a <= reg_a |
                                    ((sub_op[2:0]==3'd0) ? reg_v :
                                     (sub_op[2:0]==3'd1) ? reg_a :
                                     (sub_op[2:0]==3'd2) ? reg_b :
                                     (sub_op[2:0]==3'd3) ? reg_c :
                                     (sub_op[2:0]==3'd4) ? reg_d :
                                     (sub_op[2:0]==3'd5) ? reg_e :
                                     (sub_op[2:0]==3'd6) ? reg_h : reg_l);
                                psw[6] <= ((reg_a |
                                    ((sub_op[2:0]==3'd0) ? reg_v :
                                     (sub_op[2:0]==3'd1) ? reg_a :
                                     (sub_op[2:0]==3'd2) ? reg_b :
                                     (sub_op[2:0]==3'd3) ? reg_c :
                                     (sub_op[2:0]==3'd4) ? reg_d :
                                     (sub_op[2:0]==3'd5) ? reg_e :
                                     (sub_op[2:0]==3'd6) ? reg_h : reg_l))
                                    == 8'h00);
                            end

                            // ===== Full d60 reg-reg arithmetic block ======
                            // All A-dest direction (A is destination, source
                            // selected by sub_op[2:0] via wire d60_rs).  Flag
                            // updates follow MAME's ZHC_ADD / ZHC_SUB +
                            // SKIP_* macros at upd7810_macros.h.
                            //
                            // Refs (MAME upd7810_opcodes.cpp):
                            //   ADDNC 7544, GTA 7793, SUBNB 7706, LTA 7820,
                            //   ADC   7572, ONA 7907, OFFA 7918,
                            //   SUB   7674, NEA 7847, SBB 7770, EQA 7878.

                            // ADDNC A,reg : A += reg; ZHC_ADD; SKIP_NC.
                            8'hA0, 8'hA1, 8'hA2, 8'hA3,
                            8'hA4, 8'hA5, 8'hA6, 8'hA7: begin
                                reg_a  <= reg_a + d60_rs;
                                psw[6] <= (((reg_a + d60_rs) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, reg_a} + {1'b0, d60_rs}) > 9'h0FF;
                                psw[4] <= (((reg_a + d60_rs) & 4'hF) < (reg_a[3:0]));
                                if (({1'b0, reg_a} + {1'b0, d60_rs}) <= 9'h0FF)
                                    psw[5] <= 1'b1;     // SKIP_NC
                            end
                            // GTA A,reg : compare; SK if A > reg.  Z/CY/HC
                            // computed from tmp = A - reg - 1 per MAME.
                            8'hA8, 8'hA9, 8'hAA, 8'hAB,
                            8'hAC, 8'hAD, 8'hAE, 8'hAF: begin
                                psw[6] <= (({8'd0, reg_a} - {8'd0, d60_rs} - 16'd1) == 16'h0000);
                                psw[0] <= (reg_a <= d60_rs);
                                psw[4] <= (((reg_a - d60_rs - 8'd1) & 4'hF) > reg_a[3:0]);
                                if (reg_a > d60_rs) psw[5] <= 1'b1;
                            end
                            // SUBNB A,reg : A -= reg; ZHC_SUB; SKIP_NC.
                            8'hB0, 8'hB1, 8'hB2, 8'hB3,
                            8'hB4, 8'hB5, 8'hB6, 8'hB7: begin
                                reg_a  <= reg_a - d60_rs;
                                psw[6] <= (((reg_a - d60_rs) & 8'hFF) == 8'h00);
                                psw[0] <= (d60_rs > reg_a);
                                psw[4] <= (((reg_a - d60_rs) & 4'hF) > (reg_a[3:0]));
                                if (d60_rs <= reg_a) psw[5] <= 1'b1;   // SKIP_NC
                            end
                            // LTA A,reg : compare; SK if A < reg.
                            8'hB8, 8'hB9, 8'hBA, 8'hBB,
                            8'hBC, 8'hBD, 8'hBE, 8'hBF: begin
                                psw[6] <= (reg_a == d60_rs);
                                psw[0] <= (reg_a < d60_rs);
                                psw[4] <= (((reg_a - d60_rs) & 4'hF) > reg_a[3:0]);
                                if (reg_a < d60_rs) psw[5] <= 1'b1;
                            end
                            // ONA A,reg : SK if (A & reg) != 0; Z affected.
                            8'hC8, 8'hC9, 8'hCA, 8'hCB,
                            8'hCC, 8'hCD, 8'hCE, 8'hCF: begin
                                if ((reg_a & d60_rs) != 8'h00) begin
                                    psw[6] <= 1'b0;
                                    psw[5] <= 1'b1;
                                end else begin
                                    psw[6] <= 1'b1;
                                end
                            end
                            // ADC A,reg : A += reg + CY; ZHC_ADD with carry.
                            8'hD0, 8'hD1, 8'hD2, 8'hD3,
                            8'hD4, 8'hD5, 8'hD6, 8'hD7: begin
                                reg_a  <= reg_a + d60_rs + {7'd0, psw[0]};
                                psw[6] <= (((reg_a + d60_rs + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, reg_a} + {1'b0, d60_rs} + {8'd0, psw[0]}) > 9'h0FF;
                                psw[4] <= (((reg_a + d60_rs + {7'd0, psw[0]}) & 4'hF) < (reg_a[3:0]));
                            end
                            // OFFA A,reg : SK if (A & reg) == 0; Z affected.
                            8'hD8, 8'hD9, 8'hDA, 8'hDB,
                            8'hDC, 8'hDD, 8'hDE, 8'hDF: begin
                                if ((reg_a & d60_rs) != 8'h00) begin
                                    psw[6] <= 1'b0;
                                end else begin
                                    psw[6] <= 1'b1;
                                    psw[5] <= 1'b1;
                                end
                            end
                            // SUB A,reg : A -= reg; ZHC_SUB.
                            8'hE0, 8'hE1, 8'hE2, 8'hE3,
                            8'hE4, 8'hE5, 8'hE6, 8'hE7: begin
                                reg_a  <= reg_a - d60_rs;
                                psw[6] <= (((reg_a - d60_rs) & 8'hFF) == 8'h00);
                                psw[0] <= (d60_rs > reg_a);
                                psw[4] <= (((reg_a - d60_rs) & 4'hF) > (reg_a[3:0]));
                            end
                            // NEA A,reg : compare; SK if A != reg.
                            8'hE8, 8'hE9, 8'hEA, 8'hEB,
                            8'hEC, 8'hED, 8'hEE, 8'hEF: begin
                                psw[6] <= (reg_a == d60_rs);
                                psw[0] <= (d60_rs > reg_a);
                                psw[4] <= (((reg_a - d60_rs) & 4'hF) > reg_a[3:0]);
                                if (reg_a != d60_rs) psw[5] <= 1'b1;
                            end
                            // SBB A,reg : A -= reg + CY; ZHC_SUB with carry.
                            8'hF0, 8'hF1, 8'hF2, 8'hF3,
                            8'hF4, 8'hF5, 8'hF6, 8'hF7: begin
                                reg_a  <= reg_a - d60_rs - {7'd0, psw[0]};
                                psw[6] <= (((reg_a - d60_rs - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {8'd0, psw[0]}) > {1'b0, reg_a};
                                psw[4] <= (((reg_a - d60_rs - {7'd0, psw[0]}) & 4'hF) > (reg_a[3:0]));
                            end
                            // EQA A,reg : compare; SK if A == reg.
                            8'hF8, 8'hF9, 8'hFA, 8'hFB,
                            8'hFC, 8'hFD, 8'hFE, 8'hFF: begin
                                psw[6] <= (reg_a == d60_rs);
                                psw[0] <= (d60_rs > reg_a);
                                psw[4] <= (((reg_a - d60_rs) & 4'hF) > reg_a[3:0]);
                                if (reg_a == d60_rs) psw[5] <= 1'b1;
                            end

                            // ===== d60 reg-dest direction =====
                            // reg op= A.  Destination selected by sub_op[2:0]
                            // (V/A/B/C/D/E/H/L); BEFORE value for ZHC is
                            // d60_rs (the dest reg's current value); AFTER is
                            // d60_rs op reg_a.

                            // ADDNC reg,A : reg += A; ZHC_ADD; SKIP_NC.
                            8'h20, 8'h21, 8'h22, 8'h23,
                            8'h24, 8'h25, 8'h26, 8'h27: begin
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v + reg_a;
                                    3'd1: reg_a <= reg_a + reg_a;
                                    3'd2: reg_b <= reg_b + reg_a;
                                    3'd3: reg_c <= reg_c + reg_a;
                                    3'd4: reg_d <= reg_d + reg_a;
                                    3'd5: reg_e <= reg_e + reg_a;
                                    3'd6: reg_h <= reg_h + reg_a;
                                    3'd7: reg_l <= reg_l + reg_a;
                                endcase
                                psw[6] <= (((d60_rs + reg_a) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {1'b0, reg_a}) > 9'h0FF;
                                psw[4] <= (((d60_rs + reg_a) & 4'hF) < (d60_rs[3:0]));
                                if (({1'b0, d60_rs} + {1'b0, reg_a}) <= 9'h0FF)
                                    psw[5] <= 1'b1;
                            end
                            // GTA reg,A : compare; SK if reg > A.
                            8'h28, 8'h29, 8'h2A, 8'h2B,
                            8'h2C, 8'h2D, 8'h2E, 8'h2F: begin
                                psw[6] <= (({8'd0, d60_rs} - {8'd0, reg_a} - 16'd1) == 16'h0000);
                                psw[0] <= (d60_rs <= reg_a);
                                psw[4] <= (((d60_rs - reg_a - 8'd1) & 4'hF) > d60_rs[3:0]);
                                if (d60_rs > reg_a) psw[5] <= 1'b1;
                            end
                            // SUBNB reg,A : reg -= A; ZHC_SUB; SKIP_NC.
                            8'h30, 8'h31, 8'h32, 8'h33,
                            8'h34, 8'h35, 8'h36, 8'h37: begin
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v - reg_a;
                                    3'd1: reg_a <= reg_a - reg_a;
                                    3'd2: reg_b <= reg_b - reg_a;
                                    3'd3: reg_c <= reg_c - reg_a;
                                    3'd4: reg_d <= reg_d - reg_a;
                                    3'd5: reg_e <= reg_e - reg_a;
                                    3'd6: reg_h <= reg_h - reg_a;
                                    3'd7: reg_l <= reg_l - reg_a;
                                endcase
                                psw[6] <= (((d60_rs - reg_a) & 8'hFF) == 8'h00);
                                psw[0] <= (reg_a > d60_rs);
                                psw[4] <= (((d60_rs - reg_a) & 4'hF) > (d60_rs[3:0]));
                                if (reg_a <= d60_rs) psw[5] <= 1'b1;
                            end
                            // LTA reg,A : compare; SK if reg < A.
                            8'h38, 8'h39, 8'h3A, 8'h3B,
                            8'h3C, 8'h3D, 8'h3E, 8'h3F: begin
                                psw[6] <= (d60_rs == reg_a);
                                psw[0] <= (d60_rs < reg_a);
                                psw[4] <= (((d60_rs - reg_a) & 4'hF) > d60_rs[3:0]);
                                if (d60_rs < reg_a) psw[5] <= 1'b1;
                            end
                            // ADD reg,A : reg += A; ZHC_ADD.
                            8'h40, 8'h41, 8'h42, 8'h43,
                            8'h44, 8'h45, 8'h46, 8'h47: begin
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v + reg_a;
                                    3'd1: reg_a <= reg_a + reg_a;
                                    3'd2: reg_b <= reg_b + reg_a;
                                    3'd3: reg_c <= reg_c + reg_a;
                                    3'd4: reg_d <= reg_d + reg_a;
                                    3'd5: reg_e <= reg_e + reg_a;
                                    3'd6: reg_h <= reg_h + reg_a;
                                    3'd7: reg_l <= reg_l + reg_a;
                                endcase
                                psw[6] <= (((d60_rs + reg_a) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {1'b0, reg_a}) > 9'h0FF;
                                psw[4] <= (((d60_rs + reg_a) & 4'hF) < (d60_rs[3:0]));
                            end
                            // ADC reg,A : reg += A + CY; ZHC_ADD with carry.
                            8'h50, 8'h51, 8'h52, 8'h53,
                            8'h54, 8'h55, 8'h56, 8'h57: begin
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v + reg_a + {7'd0, psw[0]};
                                    3'd1: reg_a <= reg_a + reg_a + {7'd0, psw[0]};
                                    3'd2: reg_b <= reg_b + reg_a + {7'd0, psw[0]};
                                    3'd3: reg_c <= reg_c + reg_a + {7'd0, psw[0]};
                                    3'd4: reg_d <= reg_d + reg_a + {7'd0, psw[0]};
                                    3'd5: reg_e <= reg_e + reg_a + {7'd0, psw[0]};
                                    3'd6: reg_h <= reg_h + reg_a + {7'd0, psw[0]};
                                    3'd7: reg_l <= reg_l + reg_a + {7'd0, psw[0]};
                                endcase
                                psw[6] <= (((d60_rs + reg_a + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {1'b0, reg_a} + {8'd0, psw[0]}) > 9'h0FF;
                                psw[4] <= (((d60_rs + reg_a + {7'd0, psw[0]}) & 4'hF) < (d60_rs[3:0]));
                            end
                            // SUB reg,A : reg -= A; ZHC_SUB.
                            8'h60, 8'h61, 8'h62, 8'h63,
                            8'h64, 8'h65, 8'h66, 8'h67: begin
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v - reg_a;
                                    3'd1: reg_a <= reg_a - reg_a;
                                    3'd2: reg_b <= reg_b - reg_a;
                                    3'd3: reg_c <= reg_c - reg_a;
                                    3'd4: reg_d <= reg_d - reg_a;
                                    3'd5: reg_e <= reg_e - reg_a;
                                    3'd6: reg_h <= reg_h - reg_a;
                                    3'd7: reg_l <= reg_l - reg_a;
                                endcase
                                psw[6] <= (((d60_rs - reg_a) & 8'hFF) == 8'h00);
                                psw[0] <= (reg_a > d60_rs);
                                psw[4] <= (((d60_rs - reg_a) & 4'hF) > (d60_rs[3:0]));
                            end
                            // NEA reg,A : compare; SK if reg != A.
                            8'h68, 8'h69, 8'h6A, 8'h6B,
                            8'h6C, 8'h6D, 8'h6E, 8'h6F: begin
                                psw[6] <= (d60_rs == reg_a);
                                psw[0] <= (reg_a > d60_rs);
                                psw[4] <= (((d60_rs - reg_a) & 4'hF) > d60_rs[3:0]);
                                if (d60_rs != reg_a) psw[5] <= 1'b1;
                            end
                            // SBB reg,A : reg -= A + CY; ZHC_SUB with carry.
                            8'h70, 8'h71, 8'h72, 8'h73,
                            8'h74, 8'h75, 8'h76, 8'h77: begin
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v - reg_a - {7'd0, psw[0]};
                                    3'd1: reg_a <= reg_a - reg_a - {7'd0, psw[0]};
                                    3'd2: reg_b <= reg_b - reg_a - {7'd0, psw[0]};
                                    3'd3: reg_c <= reg_c - reg_a - {7'd0, psw[0]};
                                    3'd4: reg_d <= reg_d - reg_a - {7'd0, psw[0]};
                                    3'd5: reg_e <= reg_e - reg_a - {7'd0, psw[0]};
                                    3'd6: reg_h <= reg_h - reg_a - {7'd0, psw[0]};
                                    3'd7: reg_l <= reg_l - reg_a - {7'd0, psw[0]};
                                endcase
                                psw[6] <= (((d60_rs - reg_a - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, reg_a} + {8'd0, psw[0]}) > {1'b0, d60_rs};
                                psw[4] <= (((d60_rs - reg_a - {7'd0, psw[0]}) & 4'hF) > (d60_rs[3:0]));
                            end
                            // EQA reg,A : compare; SK if reg == A.
                            8'h78, 8'h79, 8'h7A, 8'h7B,
                            8'h7C, 8'h7D, 8'h7E, 8'h7F: begin
                                psw[6] <= (d60_rs == reg_a);
                                psw[0] <= (reg_a > d60_rs);
                                psw[4] <= (((d60_rs - reg_a) & 4'hF) > d60_rs[3:0]);
                                if (d60_rs == reg_a) psw[5] <= 1'b1;
                            end

                            // ANA/XRA/ORA reg, A  (d60 0x08..0x1F): first-
                            // direction variants where the register is the
                            // destination. MAME ANA_B_A/XRA_B_A/ORA_B_A set
                            // Z from the result; we also clear CY/HC and
                            // (for XRA only) SK, matching the symmetry of
                            // the second-direction handlers above.
                            8'h08, 8'h09, 8'h0A, 8'h0B,
                            8'h0C, 8'h0D, 8'h0E, 8'h0F: begin
                                case (sub_op[2:0])
                                    3'd0: begin reg_v <= reg_v & reg_a;
                                               psw[6] <= ((reg_v & reg_a) == 8'h00); end
                                    3'd1: begin reg_a <= reg_a & reg_a;
                                               psw[6] <= (reg_a == 8'h00); end
                                    3'd2: begin reg_b <= reg_b & reg_a;
                                               psw[6] <= ((reg_b & reg_a) == 8'h00); end
                                    3'd3: begin reg_c <= reg_c & reg_a;
                                               psw[6] <= ((reg_c & reg_a) == 8'h00); end
                                    3'd4: begin reg_d <= reg_d & reg_a;
                                               psw[6] <= ((reg_d & reg_a) == 8'h00); end
                                    3'd5: begin reg_e <= reg_e & reg_a;
                                               psw[6] <= ((reg_e & reg_a) == 8'h00); end
                                    3'd6: begin reg_h <= reg_h & reg_a;
                                               psw[6] <= ((reg_h & reg_a) == 8'h00); end
                                    3'd7: begin reg_l <= reg_l & reg_a;
                                               psw[6] <= ((reg_l & reg_a) == 8'h00); end
                                endcase
                            end
                            8'h10, 8'h11, 8'h12, 8'h13,
                            8'h14, 8'h15, 8'h16, 8'h17: begin
                                case (sub_op[2:0])
                                    3'd0: begin reg_v <= reg_v ^ reg_a;
                                               psw[6] <= ((reg_v ^ reg_a) == 8'h00); end
                                    3'd1: begin reg_a <= 8'h00;
                                               psw[6] <= 1'b1; end
                                    3'd2: begin reg_b <= reg_b ^ reg_a;
                                               psw[6] <= ((reg_b ^ reg_a) == 8'h00); end
                                    3'd3: begin reg_c <= reg_c ^ reg_a;
                                               psw[6] <= ((reg_c ^ reg_a) == 8'h00); end
                                    3'd4: begin reg_d <= reg_d ^ reg_a;
                                               psw[6] <= ((reg_d ^ reg_a) == 8'h00); end
                                    3'd5: begin reg_e <= reg_e ^ reg_a;
                                               psw[6] <= ((reg_e ^ reg_a) == 8'h00); end
                                    3'd6: begin reg_h <= reg_h ^ reg_a;
                                               psw[6] <= ((reg_h ^ reg_a) == 8'h00); end
                                    3'd7: begin reg_l <= reg_l ^ reg_a;
                                               psw[6] <= ((reg_l ^ reg_a) == 8'h00); end
                                endcase
                            end
                            8'h18, 8'h19, 8'h1A, 8'h1B,
                            8'h1C, 8'h1D, 8'h1E, 8'h1F: begin
                                case (sub_op[2:0])
                                    3'd0: begin reg_v <= reg_v | reg_a;
                                               psw[6] <= ((reg_v | reg_a) == 8'h00); end
                                    3'd1: begin reg_a <= reg_a | reg_a;
                                               psw[6] <= (reg_a == 8'h00); end
                                    3'd2: begin reg_b <= reg_b | reg_a;
                                               psw[6] <= ((reg_b | reg_a) == 8'h00); end
                                    3'd3: begin reg_c <= reg_c | reg_a;
                                               psw[6] <= ((reg_c | reg_a) == 8'h00); end
                                    3'd4: begin reg_d <= reg_d | reg_a;
                                               psw[6] <= ((reg_d | reg_a) == 8'h00); end
                                    3'd5: begin reg_e <= reg_e | reg_a;
                                               psw[6] <= ((reg_e | reg_a) == 8'h00); end
                                    3'd6: begin reg_h <= reg_h | reg_a;
                                               psw[6] <= ((reg_h | reg_a) == 8'h00); end
                                    3'd7: begin reg_l <= reg_l | reg_a;
                                               psw[6] <= ((reg_l | reg_a) == 8'h00); end
                                endcase
                            end
                            default: begin goto_state(S_TRAP); dbg_retire <= 1'b0; end
                        endcase
                    end

                    8'h70: begin                                  // d70 prefix
                        case (sub_op)
                            // EADD EA,A: EA <- EA + A; Z/CY/HC updated
                            // (MAME EADD_EA_A uses ZHC_ADD with A zero-
                            // extended to 16 bits).
                            8'h41: begin
                                reg_ea <= reg_ea + {8'd0, reg_a};
                                psw[6] <= ((reg_ea + {8'd0, reg_a}) == 16'd0);
                                psw[0] <= ({1'b0, reg_ea} + {9'd0, reg_a})
                                          > 17'h0FFFF;
                                psw[4] <= (((reg_ea + {8'd0, reg_a}) & 4'hF) < reg_ea[3:0]);
                            end
                            // EADD EA,B and EA,C (m33).  MAME 4933 / 4942.
                            // Same as EA,A but with reg_b / reg_c as the
                            // zero-extended addend.
                            8'h42: begin
                                reg_ea <= reg_ea + {8'd0, reg_b};
                                psw[6] <= ((reg_ea + {8'd0, reg_b}) == 16'd0);
                                psw[0] <= ({1'b0, reg_ea} + {9'd0, reg_b}) > 17'h0FFFF;
                                psw[4] <= (((reg_ea + {8'd0, reg_b}) & 4'hF)
                                           < (reg_ea[3:0]));
                            end
                            8'h43: begin
                                reg_ea <= reg_ea + {8'd0, reg_c};
                                psw[6] <= ((reg_ea + {8'd0, reg_c}) == 16'd0);
                                psw[0] <= ({1'b0, reg_ea} + {9'd0, reg_c}) > 17'h0FFFF;
                                psw[4] <= (((reg_ea + {8'd0, reg_c}) & 4'hF)
                                           < (reg_ea[3:0]));
                            end
                            // ESUB EA,A/B/C (m33).  MAME 4951 / 4960 / 4969.
                            // tmp = EA - reg (zero-extended); ZHC_SUB; EA = tmp.
                            8'h61: begin
                                reg_ea <= reg_ea - {8'd0, reg_a};
                                psw[6] <= ((reg_ea - {8'd0, reg_a}) == 16'd0);
                                psw[0] <= ({8'd0, reg_a} > reg_ea);
                                psw[4] <= (((reg_ea - {8'd0, reg_a}) & 4'hF)
                                           > (reg_ea[3:0]));
                            end
                            8'h62: begin
                                reg_ea <= reg_ea - {8'd0, reg_b};
                                psw[6] <= ((reg_ea - {8'd0, reg_b}) == 16'd0);
                                psw[0] <= ({8'd0, reg_b} > reg_ea);
                                psw[4] <= (((reg_ea - {8'd0, reg_b}) & 4'hF)
                                           > (reg_ea[3:0]));
                            end
                            8'h63: begin
                                reg_ea <= reg_ea - {8'd0, reg_c};
                                psw[6] <= ((reg_ea - {8'd0, reg_c}) == 16'd0);
                                psw[0] <= ({8'd0, reg_c} > reg_ea);
                                psw[4] <= (((reg_ea - {8'd0, reg_c}) & 4'hF)
                                           > (reg_ea[3:0]));
                            end
                            // SBCD (addr16): write C at addr, B at addr+1.
                            // Reuses S_SHLD_L/S_SHLD_H states; mem_dout mux
                            // checks sub_op == 0x1E and picks reg_c/reg_b.
                            // MAME upd7810_opcodes.cpp:4852.
                            8'h1E: begin
                                goto_state(S_SHLD_L);
                                dbg_retire <= 1'b0;
                            end
                            // LBCD (addr16): C <- (addr); B <- (addr+1).
                            // Reuses S_LSPD_LO/S_LSPD_HI states; the body
                            // dispatches on sub_op == 0x1F to pick C/B.
                            // MAME upd7810_opcodes.cpp:4864.
                            8'h1F: begin
                                goto_state(S_LSPD_LO);
                                dbg_retire <= 1'b0;
                            end
                            // MOV (addr16),reg (m33): write reg to mem[addr16].
                            // sub picks reg per low 3 bits — 0x78 V, 0x79 A,
                            // 0x7A B, 0x7B C, 0x7C D, 0x7D E, 0x7E H, 0x7F L.
                            // mem_dout mux for S_MEM_WRITE selects via
                            // sub_op[2:0].  MAME 5066 et seq.
                            8'h78,                                // MOV (addr16),V (m33)
                            8'h79,                                // MOV (addr16),A (m12)
                            8'h7A, 8'h7B, 8'h7C,                  // B,C,D
                            8'h7D, 8'h7E, 8'h7F: begin            // E,H,L
                                goto_state(S_MEM_WRITE);
                                dbg_retire <= 1'b0;
                            end
                            // MOV reg,(addr16) — reg selected by low
                            // 3 bits (V/A/B/C/D/E/H/L). The memory read
                            // happens in S_MEM_READ_A regardless; the
                            // retire routing there picks the destination.
                            8'h68, 8'h69, 8'h6A, 8'h6B,
                            8'h6C, 8'h6D, 8'h6E, 8'h6F: begin
                                goto_state(S_MEM_READ_A);
                                dbg_retire <= 1'b0;
                            end
                            // d70 indirect arith/logic family (m30):
                            // 105 sub-ops at 0x89-0xFF where sub_op[2:0] != 0.
                            // Op selected by sub_op[7:3]; addressing mode by
                            // sub_op[2:0].  Memory read happens in S_INDX next
                            // cycle; flag/reg updates happen there too.
                            8'h89, 8'h8A, 8'h8B, 8'h8C, 8'h8D, 8'h8E, 8'h8F, // ANAX
                            8'h91, 8'h92, 8'h93, 8'h94, 8'h95, 8'h96, 8'h97, // XRAX
                            8'h99, 8'h9A, 8'h9B, 8'h9C, 8'h9D, 8'h9E, 8'h9F, // ORAX
                            8'hA1, 8'hA2, 8'hA3, 8'hA4, 8'hA5, 8'hA6, 8'hA7, // ADDNCX
                            8'hA9, 8'hAA, 8'hAB, 8'hAC, 8'hAD, 8'hAE, 8'hAF, // GTAX
                            8'hB1, 8'hB2, 8'hB3, 8'hB4, 8'hB5, 8'hB6, 8'hB7, // SUBNBX
                            8'hB9, 8'hBA, 8'hBB, 8'hBC, 8'hBD, 8'hBE, 8'hBF, // LTAX
                            8'hC1, 8'hC2, 8'hC3, 8'hC4, 8'hC5, 8'hC6, 8'hC7, // ADDX
                            8'hC9, 8'hCA, 8'hCB, 8'hCC, 8'hCD, 8'hCE, 8'hCF, // ONAX
                            8'hD1, 8'hD2, 8'hD3, 8'hD4, 8'hD5, 8'hD6, 8'hD7, // ADCX
                            8'hD9, 8'hDA, 8'hDB, 8'hDC, 8'hDD, 8'hDE, 8'hDF, // OFFAX
                            8'hE1, 8'hE2, 8'hE3, 8'hE4, 8'hE5, 8'hE6, 8'hE7, // SUBX
                            8'hE9, 8'hEA, 8'hEB, 8'hEC, 8'hED, 8'hEE, 8'hEF, // NEAX
                            8'hF1, 8'hF2, 8'hF3, 8'hF4, 8'hF5, 8'hF6, 8'hF7, // SBBX
                            8'hF9, 8'hFA, 8'hFB, 8'hFC, 8'hFD, 8'hFE, 8'hFF: // EQAX
                                                                begin
                                goto_state(S_INDX);
                                dbg_retire <= 1'b0;
                            end
                            8'h3E: begin                          // SHLD (addr16)
                                goto_state(S_SHLD_L);
                                dbg_retire <= 1'b0;
                            end
                            8'h2E: begin                          // SDED (addr16) — store DE
                                goto_state(S_SHLD_L);           // reuses SHLD states
                                dbg_retire <= 1'b0;
                            end
                            8'h0E: begin                          // SSPD (addr16) — store SP
                                goto_state(S_SHLD_L);
                                dbg_retire <= 1'b0;
                            end
                            8'h0F: begin                          // LSPD (addr16) — load SP
                                goto_state(S_LSPD_LO);
                                dbg_retire <= 1'b0;
                            end
                            8'h2F: begin                          // LDED (addr16) — load DE
                                goto_state(S_LSPD_LO);          // reuses LSPD states
                                dbg_retire <= 1'b0;
                            end
                            8'h3F: begin                          // LHLD (addr16) — load HL
                                goto_state(S_LSPD_LO);
                                dbg_retire <= 1'b0;
                            end
                            default: begin goto_state(S_TRAP); dbg_retire <= 1'b0; end
                        endcase
                    end

                    // d74 prefix: 16-bit EA arithmetic with reg-pair.
                    // MAME upd7810_opcodes.cpp:7628/7636/7644 (DADD EA, rp).
                    // Updates Z/CY/HC per the 16-bit ZHC_ADD macro (low
                    // nibble HC).
                    8'h74: begin
                        case (sub_op)
                            // ===== d74 D*_EA_rp 16-bit ops (m32) =====
                            // 14 ops at columns 5/6/7 of each row, plus the
                            // pre-existing DADD (m18).  rp is selected by
                            // sub_op[2:0] via d74_rp wire.  Flag semantics
                            // mirror MAME's 16-bit ZHC_ADD/ZHC_SUB.
                            // MAME upd7810_opcodes.cpp:
                            //   DAN 7376, DXR 7426, DOR 7440, DADDNC 7473,
                            //   DGT 7515, DSUBNB 7552, DLT 7593, DADD 7628,
                            //   DON 7664, DADC 7703, DOFF 7739, DSUB 7778,
                            //   DNE 7814, DSBB 7856, DEQ 7892.

                            // DAN EA,rp (0x8D-0x8F): EA &= rp; SET_Z (16-bit).
                            8'h8D, 8'h8E, 8'h8F: begin
                                reg_ea <= reg_ea & d74_rp;
                                psw[6] <= ((reg_ea & d74_rp) == 16'h0000);
                            end
                            // DXR EA,rp (0x95-0x97): EA ^= rp; SET_Z.
                            8'h95, 8'h96, 8'h97: begin
                                reg_ea <= reg_ea ^ d74_rp;
                                psw[6] <= ((reg_ea ^ d74_rp) == 16'h0000);
                            end
                            // DOR EA,rp (0x9D-0x9F): EA |= rp; SET_Z.
                            8'h9D, 8'h9E, 8'h9F: begin
                                reg_ea <= reg_ea | d74_rp;
                                psw[6] <= ((reg_ea | d74_rp) == 16'h0000);
                            end
                            // DADDNC EA,rp (0xA5-0xA7): EA += rp; ZHC_ADD; SKIP_NC.
                            8'hA5, 8'hA6, 8'hA7: begin
                                reg_ea <= reg_ea + d74_rp;
                                psw[6] <= ((reg_ea + d74_rp) == 16'h0000);
                                psw[0] <= ({1'b0, reg_ea} + {1'b0, d74_rp}) > 17'h0FFFF;
                                psw[4] <= (((reg_ea + d74_rp) & 4'hF) < (reg_ea[3:0]));
                                if (({1'b0, reg_ea} + {1'b0, d74_rp}) <= 17'h0FFFF)
                                    psw[5] <= 1'b1;
                            end
                            // DGT EA,rp (0xAD-0xAF): cmp EA>rp; ZHC_SUB(EA-rp-1);
                            // SKIP_NC (compare-only).
                            8'hAD, 8'hAE, 8'hAF: begin
                                psw[6] <= (({16'd0, reg_ea} - {16'd0, d74_rp} - 32'd1) == 32'h00000000);
                                psw[0] <= (reg_ea <= d74_rp);
                                psw[4] <= (((reg_ea - d74_rp - 16'd1) & 4'hF) > (reg_ea[3:0]));
                                if (reg_ea > d74_rp) psw[5] <= 1'b1;
                            end
                            // DSUBNB EA,rp (0xB5-0xB7): EA -= rp; ZHC_SUB; SKIP_NC.
                            8'hB5, 8'hB6, 8'hB7: begin
                                reg_ea <= reg_ea - d74_rp;
                                psw[6] <= ((reg_ea - d74_rp) == 16'h0000);
                                psw[0] <= (d74_rp > reg_ea);
                                psw[4] <= (((reg_ea - d74_rp) & 4'hF) > (reg_ea[3:0]));
                                if (d74_rp <= reg_ea) psw[5] <= 1'b1;
                            end
                            // DLT EA,rp (0xBD-0xBF): cmp EA<rp; ZHC_SUB; SKIP_CY.
                            8'hBD, 8'hBE, 8'hBF: begin
                                psw[6] <= ((reg_ea - d74_rp) == 16'h0000);
                                psw[0] <= (d74_rp > reg_ea);
                                psw[4] <= (((reg_ea - d74_rp) & 4'hF) > (reg_ea[3:0]));
                                if (reg_ea < d74_rp) psw[5] <= 1'b1;
                            end
                            // DADD EA,rp (0xC5-0xC7): EA += rp (no skip).  m18.
                            8'hC5, 8'hC6, 8'hC7: begin
                                reg_ea <= reg_ea + d74_rp;
                                psw[6] <= ((reg_ea + d74_rp) == 16'h0000);
                                psw[0] <= ({1'b0, reg_ea} + {1'b0, d74_rp}) > 17'h0FFFF;
                                psw[4] <= (((reg_ea + d74_rp) & 4'hF) < (reg_ea[3:0]));
                            end
                            // DON EA,rp (0xCD-0xCF): SK if (EA & rp) != 0; Z affected.
                            8'hCD, 8'hCE, 8'hCF: begin
                                if ((reg_ea & d74_rp) != 16'h0000) begin
                                    psw[6] <= 1'b0;
                                    psw[5] <= 1'b1;
                                end else begin
                                    psw[6] <= 1'b1;
                                end
                            end
                            // DADC EA,rp (0xD5-0xD7): EA += rp + CY (no skip).
                            8'hD5, 8'hD6, 8'hD7: begin
                                reg_ea <= reg_ea + d74_rp + {15'd0, psw[0]};
                                psw[6] <= ((reg_ea + d74_rp + {15'd0, psw[0]}) == 16'h0000);
                                psw[0] <= ({1'b0, reg_ea} + {1'b0, d74_rp} + {16'd0, psw[0]}) > 17'h0FFFF;
                                psw[4] <= (((reg_ea + d74_rp + {15'd0, psw[0]}) & 4'hF) < (reg_ea[3:0]));
                            end
                            // DOFF EA,rp (0xDD-0xDF): SK if (EA & rp) == 0; Z affected.
                            8'hDD, 8'hDE, 8'hDF: begin
                                if ((reg_ea & d74_rp) != 16'h0000) begin
                                    psw[6] <= 1'b0;
                                end else begin
                                    psw[6] <= 1'b1;
                                    psw[5] <= 1'b1;
                                end
                            end
                            // DSUB EA,rp (0xE5-0xE7): EA -= rp (no skip).
                            8'hE5, 8'hE6, 8'hE7: begin
                                reg_ea <= reg_ea - d74_rp;
                                psw[6] <= ((reg_ea - d74_rp) == 16'h0000);
                                psw[0] <= (d74_rp > reg_ea);
                                psw[4] <= (((reg_ea - d74_rp) & 4'hF) > (reg_ea[3:0]));
                            end
                            // DNE EA,rp (0xED-0xEF): cmp EA!=rp; ZHC_SUB; SKIP_NZ.
                            8'hED, 8'hEE, 8'hEF: begin
                                psw[6] <= (reg_ea == d74_rp);
                                psw[0] <= (d74_rp > reg_ea);
                                psw[4] <= (((reg_ea - d74_rp) & 4'hF) > (reg_ea[3:0]));
                                if (reg_ea != d74_rp) psw[5] <= 1'b1;
                            end
                            // DSBB EA,rp (0xF5-0xF7): EA -= rp + CY (no skip).
                            8'hF5, 8'hF6, 8'hF7: begin
                                reg_ea <= reg_ea - d74_rp - {15'd0, psw[0]};
                                psw[6] <= ((reg_ea - d74_rp - {15'd0, psw[0]}) == 16'h0000);
                                psw[0] <= ({1'b0, d74_rp} + {16'd0, psw[0]}) > {1'b0, reg_ea};
                                psw[4] <= (((reg_ea - d74_rp - {15'd0, psw[0]}) & 4'hF) > (reg_ea[3:0]));
                            end
                            // DEQ EA,rp (0xFD-0xFF): cmp EA==rp; ZHC_SUB; SKIP_Z.
                            8'hFD, 8'hFE, 8'hFF: begin
                                psw[6] <= (reg_ea == d74_rp);
                                psw[0] <= (d74_rp > reg_ea);
                                psw[4] <= (((reg_ea - d74_rp) & 4'hF) > (reg_ea[3:0]));
                                if (reg_ea == d74_rp) psw[5] <= 1'b1;
                            end
                            // ANI reg,xx (0x08-0x0F): reg = reg & imm; only Z.
                            // MAME 6062 et al.
                            8'h08, 8'h09, 8'h0A, 8'h0B,
                            8'h0C, 8'h0D, 8'h0E, 8'h0F: begin
                                case (sub_op[2:0])
                                    3'd0: begin reg_v <= reg_v & imm_lo;
                                               psw[6] <= ((reg_v & imm_lo) == 8'h00); end
                                    3'd1: begin reg_a <= reg_a & imm_lo;
                                               psw[6] <= ((reg_a & imm_lo) == 8'h00); end
                                    3'd2: begin reg_b <= reg_b & imm_lo;
                                               psw[6] <= ((reg_b & imm_lo) == 8'h00); end
                                    3'd3: begin reg_c <= reg_c & imm_lo;
                                               psw[6] <= ((reg_c & imm_lo) == 8'h00); end
                                    3'd4: begin reg_d <= reg_d & imm_lo;
                                               psw[6] <= ((reg_d & imm_lo) == 8'h00); end
                                    3'd5: begin reg_e <= reg_e & imm_lo;
                                               psw[6] <= ((reg_e & imm_lo) == 8'h00); end
                                    3'd6: begin reg_h <= reg_h & imm_lo;
                                               psw[6] <= ((reg_h & imm_lo) == 8'h00); end
                                    3'd7: begin reg_l <= reg_l & imm_lo;
                                               psw[6] <= ((reg_l & imm_lo) == 8'h00); end
                                endcase
                            end
                            // XRI reg,xx (0x10-0x17): reg ^= imm; only Z.
                            8'h10, 8'h11, 8'h12, 8'h13,
                            8'h14, 8'h15, 8'h16, 8'h17: begin
                                case (sub_op[2:0])
                                    3'd0: begin reg_v <= reg_v ^ imm_lo;
                                               psw[6] <= ((reg_v ^ imm_lo) == 8'h00); end
                                    3'd1: begin reg_a <= reg_a ^ imm_lo;
                                               psw[6] <= ((reg_a ^ imm_lo) == 8'h00); end
                                    3'd2: begin reg_b <= reg_b ^ imm_lo;
                                               psw[6] <= ((reg_b ^ imm_lo) == 8'h00); end
                                    3'd3: begin reg_c <= reg_c ^ imm_lo;
                                               psw[6] <= ((reg_c ^ imm_lo) == 8'h00); end
                                    3'd4: begin reg_d <= reg_d ^ imm_lo;
                                               psw[6] <= ((reg_d ^ imm_lo) == 8'h00); end
                                    3'd5: begin reg_e <= reg_e ^ imm_lo;
                                               psw[6] <= ((reg_e ^ imm_lo) == 8'h00); end
                                    3'd6: begin reg_h <= reg_h ^ imm_lo;
                                               psw[6] <= ((reg_h ^ imm_lo) == 8'h00); end
                                    3'd7: begin reg_l <= reg_l ^ imm_lo;
                                               psw[6] <= ((reg_l ^ imm_lo) == 8'h00); end
                                endcase
                            end
                            // ORI reg,xx (0x18-0x1F): reg |= imm; only Z.
                            8'h18, 8'h19, 8'h1A, 8'h1B,
                            8'h1C, 8'h1D, 8'h1E, 8'h1F: begin
                                case (sub_op[2:0])
                                    3'd0: begin reg_v <= reg_v | imm_lo;
                                               psw[6] <= ((reg_v | imm_lo) == 8'h00); end
                                    3'd1: begin reg_a <= reg_a | imm_lo;
                                               psw[6] <= ((reg_a | imm_lo) == 8'h00); end
                                    3'd2: begin reg_b <= reg_b | imm_lo;
                                               psw[6] <= ((reg_b | imm_lo) == 8'h00); end
                                    3'd3: begin reg_c <= reg_c | imm_lo;
                                               psw[6] <= ((reg_c | imm_lo) == 8'h00); end
                                    3'd4: begin reg_d <= reg_d | imm_lo;
                                               psw[6] <= ((reg_d | imm_lo) == 8'h00); end
                                    3'd5: begin reg_e <= reg_e | imm_lo;
                                               psw[6] <= ((reg_e | imm_lo) == 8'h00); end
                                    3'd6: begin reg_h <= reg_h | imm_lo;
                                               psw[6] <= ((reg_h | imm_lo) == 8'h00); end
                                    3'd7: begin reg_l <= reg_l | imm_lo;
                                               psw[6] <= ((reg_l | imm_lo) == 8'h00); end
                                endcase
                            end
                            // ===== d74 reg-imm arithmetic block (m29) =====
                            // Source register selected by sub_op[2:0] via
                            // d60_rs (V/A/B/C/D/E/H/L); destination is the
                            // same register for the writing variants.  Flag
                            // semantics mirror MAME's ZHC_ADD/ZHC_SUB.
                            // MAME upd7810_opcodes.cpp:
                            //   ADINC 6291, GTI 6395, SUINB 6498, LTI 6593,
                            //   ADI   6682, ONI 6776, ACI   6857, OFFI 6944,
                            //   SUI   7025, SBI 7201.

                            // ADINC reg,xx (0x20-0x27): reg += imm; ZHC_ADD;
                            // SKIP_NC.
                            8'h20, 8'h21, 8'h22, 8'h23,
                            8'h24, 8'h25, 8'h26, 8'h27: begin
                                psw[6] <= (((d60_rs + imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {1'b0, imm_lo}) > 9'h0FF;
                                psw[4] <= (((d60_rs + imm_lo) & 4'hF) < (d60_rs[3:0]));
                                if (({1'b0, d60_rs} + {1'b0, imm_lo}) <= 9'h0FF)
                                    psw[5] <= 1'b1;
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v + imm_lo;
                                    3'd1: reg_a <= reg_a + imm_lo;
                                    3'd2: reg_b <= reg_b + imm_lo;
                                    3'd3: reg_c <= reg_c + imm_lo;
                                    3'd4: reg_d <= reg_d + imm_lo;
                                    3'd5: reg_e <= reg_e + imm_lo;
                                    3'd6: reg_h <= reg_h + imm_lo;
                                    3'd7: reg_l <= reg_l + imm_lo;
                                endcase
                            end
                            // GTI reg,xx (0x28-0x2F): tmp = reg - imm - 1;
                            // ZHC_SUB(tmp, reg, 0); SKIP_NC.  Compare-only;
                            // SK if reg > imm.
                            8'h28, 8'h29, 8'h2A, 8'h2B,
                            8'h2C, 8'h2D, 8'h2E, 8'h2F: begin
                                psw[6] <= (({8'd0, d60_rs} - {8'd0, imm_lo} - 16'd1) == 16'h0000);
                                psw[0] <= (d60_rs <= imm_lo);
                                psw[4] <= (((d60_rs - imm_lo - 8'd1) & 4'hF) > (d60_rs[3:0]));
                                if (d60_rs > imm_lo) psw[5] <= 1'b1;
                            end
                            // SUINB reg,xx (0x30-0x37): reg -= imm; ZHC_SUB;
                            // SKIP_NC.
                            8'h30, 8'h31, 8'h32, 8'h33,
                            8'h34, 8'h35, 8'h36, 8'h37: begin
                                psw[6] <= (((d60_rs - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d60_rs);
                                psw[4] <= (((d60_rs - imm_lo) & 4'hF) > (d60_rs[3:0]));
                                if (imm_lo <= d60_rs) psw[5] <= 1'b1;
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v - imm_lo;
                                    3'd1: reg_a <= reg_a - imm_lo;
                                    3'd2: reg_b <= reg_b - imm_lo;
                                    3'd3: reg_c <= reg_c - imm_lo;
                                    3'd4: reg_d <= reg_d - imm_lo;
                                    3'd5: reg_e <= reg_e - imm_lo;
                                    3'd6: reg_h <= reg_h - imm_lo;
                                    3'd7: reg_l <= reg_l - imm_lo;
                                endcase
                            end
                            // LTI reg,xx (0x38-0x3F): tmp = reg - imm;
                            // ZHC_SUB; SKIP_CY.  Compare-only; SK if reg<imm.
                            8'h38, 8'h39, 8'h3A, 8'h3B,
                            8'h3C, 8'h3D, 8'h3E, 8'h3F: begin
                                psw[6] <= (((d60_rs - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d60_rs);
                                psw[4] <= (((d60_rs - imm_lo) & 4'hF) > (d60_rs[3:0]));
                                if (imm_lo > d60_rs) psw[5] <= 1'b1;
                            end
                            // ADI reg,xx (0x40-0x47): reg += imm; ZHC_ADD.
                            // No skip.
                            8'h40, 8'h41, 8'h42, 8'h43,
                            8'h44, 8'h45, 8'h46, 8'h47: begin
                                psw[6] <= (((d60_rs + imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {1'b0, imm_lo}) > 9'h0FF;
                                psw[4] <= (((d60_rs + imm_lo) & 4'hF) < (d60_rs[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v + imm_lo;
                                    3'd1: reg_a <= reg_a + imm_lo;
                                    3'd2: reg_b <= reg_b + imm_lo;
                                    3'd3: reg_c <= reg_c + imm_lo;
                                    3'd4: reg_d <= reg_d + imm_lo;
                                    3'd5: reg_e <= reg_e + imm_lo;
                                    3'd6: reg_h <= reg_h + imm_lo;
                                    3'd7: reg_l <= reg_l + imm_lo;
                                endcase
                            end
                            // ONI reg,xx (0x48-0x4F): SK if (reg & imm) != 0.
                            // No flags touched.
                            8'h48, 8'h49, 8'h4A, 8'h4B,
                            8'h4C, 8'h4D, 8'h4E, 8'h4F: begin
                                if ((d60_rs & imm_lo) != 8'h00) psw[5] <= 1'b1;
                            end
                            // ACI reg,xx (0x50-0x57): reg += imm + CY;
                            // ZHC_ADD with carry.  No skip.
                            8'h50, 8'h51, 8'h52, 8'h53,
                            8'h54, 8'h55, 8'h56, 8'h57: begin
                                psw[6] <= (((d60_rs + imm_lo + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, d60_rs} + {1'b0, imm_lo} + {8'd0, psw[0]}) > 9'h0FF;
                                psw[4] <= (((d60_rs + imm_lo + {7'd0, psw[0]}) & 4'hF) < (d60_rs[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v + imm_lo + {7'd0, psw[0]};
                                    3'd1: reg_a <= reg_a + imm_lo + {7'd0, psw[0]};
                                    3'd2: reg_b <= reg_b + imm_lo + {7'd0, psw[0]};
                                    3'd3: reg_c <= reg_c + imm_lo + {7'd0, psw[0]};
                                    3'd4: reg_d <= reg_d + imm_lo + {7'd0, psw[0]};
                                    3'd5: reg_e <= reg_e + imm_lo + {7'd0, psw[0]};
                                    3'd6: reg_h <= reg_h + imm_lo + {7'd0, psw[0]};
                                    3'd7: reg_l <= reg_l + imm_lo + {7'd0, psw[0]};
                                endcase
                            end
                            // OFFI reg,xx (0x58-0x5F): SK if (reg & imm) == 0.
                            // No flags touched.
                            8'h58, 8'h59, 8'h5A, 8'h5B,
                            8'h5C, 8'h5D, 8'h5E, 8'h5F: begin
                                if ((d60_rs & imm_lo) == 8'h00) psw[5] <= 1'b1;
                            end
                            // SUI reg,xx (0x60-0x67): reg -= imm; ZHC_SUB.
                            // No skip.
                            8'h60, 8'h61, 8'h62, 8'h63,
                            8'h64, 8'h65, 8'h66, 8'h67: begin
                                psw[6] <= (((d60_rs - imm_lo) & 8'hFF) == 8'h00);
                                psw[0] <= (imm_lo > d60_rs);
                                psw[4] <= (((d60_rs - imm_lo) & 4'hF) > (d60_rs[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v - imm_lo;
                                    3'd1: reg_a <= reg_a - imm_lo;
                                    3'd2: reg_b <= reg_b - imm_lo;
                                    3'd3: reg_c <= reg_c - imm_lo;
                                    3'd4: reg_d <= reg_d - imm_lo;
                                    3'd5: reg_e <= reg_e - imm_lo;
                                    3'd6: reg_h <= reg_h - imm_lo;
                                    3'd7: reg_l <= reg_l - imm_lo;
                                endcase
                            end
                            // NEI reg,xx (0x68-0x6F): tmp = reg - imm; ZHC_SUB;
                            // SKIP_NZ.  Compare-only, doesn't write reg.
                            // MAME 7102 et al.
                            8'h68, 8'h69, 8'h6A, 8'h6B,
                            8'h6C, 8'h6D, 8'h6E, 8'h6F: begin
                                psw[6] <= (d60_rs == imm_lo);
                                psw[0] <= (imm_lo > d60_rs);
                                psw[4] <= (((d60_rs - imm_lo) & 4'hF) > (d60_rs[3:0]));
                                if (d60_rs != imm_lo) psw[5] <= 1'b1;
                            end
                            // SBI reg,xx (0x70-0x77): reg -= imm + CY;
                            // ZHC_SUB with carry.  No skip.
                            8'h70, 8'h71, 8'h72, 8'h73,
                            8'h74, 8'h75, 8'h76, 8'h77: begin
                                psw[6] <= (((d60_rs - imm_lo - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                                psw[0] <= ({1'b0, imm_lo} + {8'd0, psw[0]}) > {1'b0, d60_rs};
                                psw[4] <= (((d60_rs - imm_lo - {7'd0, psw[0]}) & 4'hF) > (d60_rs[3:0]));
                                case (sub_op[2:0])
                                    3'd0: reg_v <= reg_v - imm_lo - {7'd0, psw[0]};
                                    3'd1: reg_a <= reg_a - imm_lo - {7'd0, psw[0]};
                                    3'd2: reg_b <= reg_b - imm_lo - {7'd0, psw[0]};
                                    3'd3: reg_c <= reg_c - imm_lo - {7'd0, psw[0]};
                                    3'd4: reg_d <= reg_d - imm_lo - {7'd0, psw[0]};
                                    3'd5: reg_e <= reg_e - imm_lo - {7'd0, psw[0]};
                                    3'd6: reg_h <= reg_h - imm_lo - {7'd0, psw[0]};
                                    3'd7: reg_l <= reg_l - imm_lo - {7'd0, psw[0]};
                                endcase
                            end
                            // EQI reg,xx (0x78-0x7F): tmp = reg - imm; ZHC_SUB;
                            // SKIP_Z.  Compare-only.  MAME 7278 et al.
                            8'h78, 8'h79, 8'h7A, 8'h7B,
                            8'h7C, 8'h7D, 8'h7E, 8'h7F: begin
                                psw[6] <= (d60_rs == imm_lo);
                                psw[0] <= (imm_lo > d60_rs);
                                psw[4] <= (((d60_rs - imm_lo) & 4'hF) > (d60_rs[3:0]));
                                if (d60_rs == imm_lo) psw[5] <= 1'b1;
                            end
                            // d74 page-arith *_wa family (m31): A vs mem at
                            // {V, wa}.  The wa byte is in imm_lo (loaded by
                            // the standard 1-imm fetch).  S_PAGE_RD does the
                            // read + compute, dispatching on (opcode, sub_op).
                            //   0x88 ANAW   0x90 XRAW   0x98 ORAW
                            //   0xA0 ADDNCW 0xA8 GTAW   0xB0 SUBNBW  0xB8 LTAW
                            //   0xC0 ADDW   0xC8 ONAW   0xD0 ADCW    0xD8 OFFAW
                            //   0xE0 SUBW   0xE8 NEAW   0xF0 SBBW    0xF8 EQAW
                            8'h88, 8'h90, 8'h98,
                            8'hA0, 8'hA8, 8'hB0, 8'hB8,
                            8'hC0, 8'hC8, 8'hD0, 8'hD8,
                            8'hE0, 8'hE8, 8'hF0, 8'hF8: begin
                                goto_state(S_PAGE_RD);
                                dbg_retire <= 1'b0;
                            end
                            default: begin goto_state(S_TRAP); dbg_retire <= 1'b0; end
                        endcase
                    end

                    // ---------------------------------------------------------
                    // Page-address family: read or RMW at {V, wa}.  S_PAGE_RD
                    // (one cycle) does the read+compute; for RMW ops it then
                    // transitions to S_PAGE_WR which writes imm_hi back.
                    // STAW (write-only) skips S_PAGE_RD and goes straight to
                    // S_PAGE_WR; the mem_dout mux selects reg_a for opcode
                    // 0x63 and imm_hi otherwise.  MVIW (write-only with imm
                    // already in imm_hi) likewise jumps to S_PAGE_WR.
                    // MVIX_BC/DE/HL: write imm_lo at indirect.
                    8'h01,                                       // LDAW wa
                    8'h05, 8'h15, 8'h25, 8'h35,                  // ANIW/ORIW/GTIW/LTIW wa,xx
                    8'h45, 8'h55, 8'h65, 8'h75,                  // ONIW/OFFIW/NEIW/EQIW wa,xx
                    8'h20, 8'h30,                                // INRW/DCRW wa
                    8'h58, 8'h59, 8'h5A, 8'h5B,                  // BIT 0..3, wa
                    8'h5C, 8'h5D, 8'h5E, 8'h5F: begin            // BIT 4..7, wa
                        goto_state(S_PAGE_RD);
                        dbg_retire <= 1'b0;
                    end
                    8'h63,                                       // STAW wa
                    8'h71: begin                                 // MVIW wa,xx
                        goto_state(S_PAGE_WR);
                        dbg_retire <= 1'b0;
                    end
                    8'h49, 8'h4A, 8'h4B: begin                   // MVIX (BC/DE/HL),xx
                        goto_state(S_MVIX);
                        dbg_retire <= 1'b0;
                    end

                    default: begin goto_state(S_TRAP); dbg_retire <= 1'b0; end
                endcase
            end
        end

        // One-cycle bus write: {imm_hi, imm_lo} <- reg_a. Combinational
        // mem_addr/mem_dout/mem_wr drive the bus; on the next edge the
        // store is complete and we retire + fetch the next opcode.
        S_MEM_WRITE: begin
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // STAX (HL+): store A at (HL), then HL <- HL+1.  Memory write
        // happens combinationally this cycle; on the edge we increment HL
        // and retire.
        S_STAX_HL_INC: begin
            {reg_h, reg_l} <= {reg_h, reg_l} + 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire     <= 1'b1;
        end
        // STAX (DE+) / (DE-) / (HL-) : write happens combinationally
        // this cycle; on the edge we ±1 the regpair and retire.
        S_STAX_DE_INC: begin
            {reg_d, reg_e} <= {reg_d, reg_e} + 16'd1;
            goto_state(S_FETCH_OP); dbg_retire <= 1'b1;
        end
        S_STAX_DE_DEC: begin
            {reg_d, reg_e} <= {reg_d, reg_e} - 16'd1;
            goto_state(S_FETCH_OP); dbg_retire <= 1'b1;
        end
        S_STAX_HL_DEC: begin
            {reg_h, reg_l} <= {reg_h, reg_l} - 16'd1;
            goto_state(S_FETCH_OP); dbg_retire <= 1'b1;
        end
        // LDAX (DE-) / (HL-) : same shape as the +1 variants.
        S_LDAX_DE_DEC: begin
            reg_a          <= mem_din;
            {reg_d, reg_e} <= {reg_d, reg_e} - 16'd1;
            goto_state(S_FETCH_OP); dbg_retire <= 1'b1;
        end
        S_LDAX_HL_DEC: begin
            reg_a          <= mem_din;
            {reg_h, reg_l} <= {reg_h, reg_l} - 16'd1;
            goto_state(S_FETCH_OP); dbg_retire <= 1'b1;
        end

        // CALL: push PC[15:8] at (SP-1), decrement SP.
        S_CALL_PUSH_H: begin
            sp    <= sp - 16'd1;
            goto_state(S_CALL_PUSH_L);
        end

        // CALL/CALT push-low: decrement SP and write PC[7:0].  For CALL,
        // update PC to the immediate target and retire.  For CALT, enter
        // the two-cycle table-read phase; retire happens in S_CALT_READ_H.
        S_CALL_PUSH_L: begin
            sp <= sp - 16'd1;
            if (opcode == 8'h40) begin
                pc         <= {imm_hi, imm_lo};
                goto_state(S_FETCH_OP);
                dbg_retire <= 1'b1;
            end else if (opcode[7:3] == 5'b01111) begin  // CALF 0x78-0x7F
                // PCH = 0x08 | (op & 7); PCL = imm_lo (the only operand byte).
                pc         <= {{4'b0000, 1'b1, opcode[2:0]}, imm_lo};
                goto_state(S_FETCH_OP);
                dbg_retire <= 1'b1;
            end else if (opcode == 8'h48 && sub_op == 8'h29) begin
                // CALB: PC <- BC.
                pc         <= {reg_b, reg_c};
                goto_state(S_FETCH_OP);
                dbg_retire <= 1'b1;
            end else begin  // CALT 0x80-0x9F
                goto_state(S_CALT_READ_L);
            end
        end

        // CALT: latch low byte of target from (0x80 + 2*idx).
        S_CALT_READ_L: begin
            imm_lo <= mem_din;
            goto_state(S_CALT_READ_H);
        end
        // CALT: latch high byte, assemble PC, retire.
        S_CALT_READ_H: begin
            pc         <= {mem_din, imm_lo};
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // RET: pop PC[7:0] from (SP), post-increment SP.
        S_RET_POP_L: begin
            pc_lo_tmp <= mem_din;
            sp        <= sp + 16'd1;
            goto_state(S_RET_POP_H);
        end

        // RET / RETS: pop PC[15:8] from (SP), post-increment SP, assemble
        // PC.  RETS (opcode 0xB9) additionally sets SK so the next
        // instruction is skipped.
        S_RET_POP_H: begin
            pc         <= {mem_din, pc_lo_tmp};
            sp         <= sp + 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
            if (opcode == 8'hB9) psw[5] <= 1'b1;  // RETS sets SK
        end

        // LDAX (HL+): A <- (HL); HL++.
        S_LDAX_HL_INC: begin
            reg_a          <= mem_din;
            {reg_h, reg_l} <= {reg_h, reg_l} + 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire     <= 1'b1;
        end

        // LDAX (DE+): A <- (DE); DE++.
        S_LDAX_DE_INC: begin
            reg_a          <= mem_din;
            {reg_d, reg_e} <= {reg_d, reg_e} + 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire     <= 1'b1;
        end

        // LDAX (BC)/(DE)/(HL) : A <- (pair). No pair mutation.
        S_LDAX_IND: begin
            reg_a      <= mem_din;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end
        // STAX (BC)/(DE)/(HL) : (pair) <- A. No pair mutation.
        S_STAX_IND: begin
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // 16-bit memory loads from {(addr+1), (addr)}.  Destination by
        // sub_op:
        //   sub_op == 0x0F -> LSPD: SP
        //   sub_op == 0x1F -> LBCD: BC  (C low, B high)        (m33)
        //   sub_op == 0x2F -> LDED: DE  (E low, D high)
        //   sub_op == 0x3F -> LHLD: HL  (L low, H high)
        S_LSPD_LO: begin
            case (sub_op)
                8'h0F: sp[7:0] <= mem_din;
                8'h1F: reg_c   <= mem_din;
                8'h2F: reg_e   <= mem_din;
                8'h3F: reg_l   <= mem_din;
                default: ;
            endcase
            goto_state(S_LSPD_HI);
        end
        S_LSPD_HI: begin
            case (sub_op)
                8'h0F: sp[15:8] <= mem_din;
                8'h1F: reg_b    <= mem_din;
                8'h2F: reg_d    <= mem_din;
                8'h3F: reg_h    <= mem_din;
                default: ;
            endcase
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // PUSH {VA,BC,DE,HL,EA}: push high byte at (SP-1), dec SP.
        S_REG_PUSH_H: begin
            sp    <= sp - 16'd1;
            goto_state(S_REG_PUSH_L);
        end
        // push low byte at (SP-1), dec SP, retire.
        S_REG_PUSH_L: begin
            sp         <= sp - 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // POP low byte from (SP) into the selected pair's low half, inc SP.
        S_REG_POP_L: begin
            case (opcode[2:0])
                3'd0: reg_a        <= mem_din;  // POP VA (low byte is A)
                3'd1: reg_c        <= mem_din;  // POP BC
                3'd2: reg_e        <= mem_din;  // POP DE
                3'd3: reg_l        <= mem_din;  // POP HL
                3'd4: reg_ea[7:0]  <= mem_din;  // POP EA
                default: ;
            endcase
            sp    <= sp + 16'd1;
            goto_state(S_REG_POP_H);
        end
        // POP high byte, inc SP, retire.
        S_REG_POP_H: begin
            case (opcode[2:0])
                3'd0: reg_v        <= mem_din;  // POP VA (high byte is V)
                3'd1: reg_b        <= mem_din;  // POP BC
                3'd2: reg_d        <= mem_din;  // POP DE
                3'd3: reg_h        <= mem_din;  // POP HL
                3'd4: reg_ea[15:8] <= mem_din;  // POP EA
                default: ;
            endcase
            sp         <= sp + 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // SHLD (addr16): write L at (addr), H at (addr+1).
        S_SHLD_L: goto_state(S_SHLD_H);
        S_SHLD_H: begin
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // MOV reg,(addr16): one-cycle read from (imm16) into the reg
        // selected by sub_op's low 3 bits (for d70+0x68..0x6F).
        S_MEM_READ_A: begin
            case (sub_op[2:0])
                3'd0: reg_v <= mem_din;   // MOV V,(addr16)
                3'd1: reg_a <= mem_din;   // MOV A,(addr16)
                3'd2: reg_b <= mem_din;   // MOV B,(addr16)
                3'd3: reg_c <= mem_din;   // MOV C,(addr16)
                3'd4: reg_d <= mem_din;   // MOV D,(addr16)
                3'd5: reg_e <= mem_din;   // MOV E,(addr16)
                3'd6: reg_h <= mem_din;   // MOV H,(addr16)
                3'd7: reg_l <= mem_din;   // MOV L,(addr16)
            endcase
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // d70 indirect arith/logic family (m30).
        // mem_din is the byte at xind_addr (combinational this cycle).
        // op selected by sub_op[7:3]; addressing mode by sub_op[2:0].
        // For modes 4/5 we post-increment DE/HL; for 6/7 we post-decrement.
        // Modes 1/2/3 leave the regpair unchanged.
        // MAME upd7810_opcodes.cpp:5154+ (ANAX/XRAX/ORAX 5154-5310,
        // ADDNCX/GTAX 5312-5437, SUBNBX/LTAX 5439-5564, ADDX/ONAX 5566-5691,
        // ADCX/OFFAX 5693-5818, SUBX/NEAX 5820-5944, SBBX/EQAX 5946-6072).
        S_INDX: begin
            case (sub_op[7:3])
                // ANAX (0x88-0x8F): A &= mem; SET_Z only.
                5'h11: begin
                    reg_a  <= reg_a & mem_din;
                    psw[6] <= ((reg_a & mem_din) == 8'h00);
                end
                // XRAX (0x90-0x97): A ^= mem; SET_Z only.
                5'h12: begin
                    reg_a  <= reg_a ^ mem_din;
                    psw[6] <= ((reg_a ^ mem_din) == 8'h00);
                end
                // ORAX (0x98-0x9F): A |= mem; SET_Z only.
                5'h13: begin
                    reg_a  <= reg_a | mem_din;
                    psw[6] <= ((reg_a | mem_din) == 8'h00);
                end
                // ADDNCX (0xA0-0xA7): A += mem; ZHC_ADD; SKIP_NC.
                5'h14: begin
                    reg_a  <= reg_a + mem_din;
                    psw[6] <= (((reg_a + mem_din) & 8'hFF) == 8'h00);
                    psw[0] <= ({1'b0, reg_a} + {1'b0, mem_din}) > 9'h0FF;
                    psw[4] <= (((reg_a + mem_din) & 4'hF) < (reg_a[3:0]));
                    if (({1'b0, reg_a} + {1'b0, mem_din}) <= 9'h0FF)
                        psw[5] <= 1'b1;
                end
                // GTAX (0xA8-0xAF): tmp = A - mem - 1; ZHC_SUB(tmp,A,0);
                // SKIP_NC (compare-only).
                5'h15: begin
                    psw[6] <= (({8'd0, reg_a} - {8'd0, mem_din} - 16'd1) == 16'h0000);
                    psw[0] <= (reg_a <= mem_din);
                    psw[4] <= (((reg_a - mem_din - 8'd1) & 4'hF) > (reg_a[3:0]));
                    if (reg_a > mem_din) psw[5] <= 1'b1;
                end
                // SUBNBX (0xB0-0xB7): A -= mem; ZHC_SUB; SKIP_NC.
                5'h16: begin
                    reg_a  <= reg_a - mem_din;
                    psw[6] <= (((reg_a - mem_din) & 8'hFF) == 8'h00);
                    psw[0] <= (mem_din > reg_a);
                    psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                    if (mem_din <= reg_a) psw[5] <= 1'b1;
                end
                // LTAX (0xB8-0xBF): tmp = A - mem; ZHC_SUB; SKIP_CY (cmp).
                5'h17: begin
                    psw[6] <= (((reg_a - mem_din) & 8'hFF) == 8'h00);
                    psw[0] <= (mem_din > reg_a);
                    psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                    if (reg_a < mem_din) psw[5] <= 1'b1;
                end
                // ADDX (0xC0-0xC7): A += mem; ZHC_ADD.  No skip.
                5'h18: begin
                    reg_a  <= reg_a + mem_din;
                    psw[6] <= (((reg_a + mem_din) & 8'hFF) == 8'h00);
                    psw[0] <= ({1'b0, reg_a} + {1'b0, mem_din}) > 9'h0FF;
                    psw[4] <= (((reg_a + mem_din) & 4'hF) < (reg_a[3:0]));
                end
                // ONAX (0xC8-0xCF): if (A & mem) PSW = (PSW & ~Z) | SK
                //                   else        PSW |= Z.  Updates Z!
                5'h19: begin
                    if ((reg_a & mem_din) != 8'h00) begin
                        psw[6] <= 1'b0;
                        psw[5] <= 1'b1;
                    end else begin
                        psw[6] <= 1'b1;
                    end
                end
                // ADCX (0xD0-0xD7): A += mem + CY; ZHC_ADD with carry.
                5'h1A: begin
                    reg_a  <= reg_a + mem_din + {7'd0, psw[0]};
                    psw[6] <= (((reg_a + mem_din + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                    psw[0] <= ({1'b0, reg_a} + {1'b0, mem_din} + {8'd0, psw[0]}) > 9'h0FF;
                    psw[4] <= (((reg_a + mem_din + {7'd0, psw[0]}) & 4'hF) < (reg_a[3:0]));
                end
                // OFFAX (0xD8-0xDF): if (A & mem) PSW &= ~Z
                //                    else         PSW = PSW | Z | SK.
                5'h1B: begin
                    if ((reg_a & mem_din) != 8'h00) begin
                        psw[6] <= 1'b0;
                    end else begin
                        psw[6] <= 1'b1;
                        psw[5] <= 1'b1;
                    end
                end
                // SUBX (0xE0-0xE7): A -= mem; ZHC_SUB.  No skip.
                5'h1C: begin
                    reg_a  <= reg_a - mem_din;
                    psw[6] <= (((reg_a - mem_din) & 8'hFF) == 8'h00);
                    psw[0] <= (mem_din > reg_a);
                    psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                end
                // NEAX (0xE8-0xEF): tmp = A - mem; ZHC_SUB; SKIP_NZ (cmp).
                5'h1D: begin
                    psw[6] <= (reg_a == mem_din);
                    psw[0] <= (mem_din > reg_a);
                    psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                    if (reg_a != mem_din) psw[5] <= 1'b1;
                end
                // SBBX (0xF0-0xF7): A -= mem + CY; ZHC_SUB with carry.
                5'h1E: begin
                    reg_a  <= reg_a - mem_din - {7'd0, psw[0]};
                    psw[6] <= (((reg_a - mem_din - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                    psw[0] <= ({1'b0, mem_din} + {8'd0, psw[0]}) > {1'b0, reg_a};
                    psw[4] <= (((reg_a - mem_din - {7'd0, psw[0]}) & 4'hF) > (reg_a[3:0]));
                end
                // EQAX (0xF8-0xFF): tmp = A - mem; ZHC_SUB; SKIP_Z (cmp).
                5'h1F: begin
                    psw[6] <= (reg_a == mem_din);
                    psw[0] <= (mem_din > reg_a);
                    psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                    if (reg_a == mem_din) psw[5] <= 1'b1;
                end
                default: ;  // illegal2 sub-ops should never reach here
            endcase
            // Post-modify the addressing-mode register pair.
            //   sub_op[2:0] == 4 (Dp): DE++
            //   sub_op[2:0] == 5 (Hp): HL++
            //   sub_op[2:0] == 6 (Dm): DE--
            //   sub_op[2:0] == 7 (Hm): HL--
            case (sub_op[2:0])
                3'd4: {reg_d, reg_e} <= {reg_d, reg_e} + 16'd1;
                3'd5: {reg_h, reg_l} <= {reg_h, reg_l} + 16'd1;
                3'd6: {reg_d, reg_e} <= {reg_d, reg_e} - 16'd1;
                3'd7: {reg_h, reg_l} <= {reg_h, reg_l} - 16'd1;
                default: ;
            endcase
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // TABLE: fetch C from (PC+A+1), then B from (PC+A+2).
        // (Populates the BC register pair, typically consumed by the
        //  following JB instruction as an indirect jump target.)
        S_TABLE_LO: begin
            reg_c <= mem_din;
            goto_state(S_TABLE_HI);
        end
        S_TABLE_HI: begin
            reg_b      <= mem_din;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // LDEAX family (d48 0x82-0x8F, m34): EAL <- (base), EAH <- (base+1).
        // base address is selected by sub_op[3:0] via eax_base_addr.
        // Post-mod (Dp/Hp) increments DE/HL by 2 in HI cycle.  No flags.
        S_LDEAX_LO: begin
            reg_ea[7:0] <= mem_din;
            goto_state(S_LDEAX_HI);
        end
        S_LDEAX_HI: begin
            reg_ea[15:8] <= mem_din;
            // Post-mod: sub_op[3:0]==4 -> DE+=2 (Dp); ==5 -> HL+=2 (Hp).
            case (sub_op[3:0])
                4'h4: {reg_d, reg_e} <= {reg_d, reg_e} + 16'd2;
                4'h5: {reg_h, reg_l} <= {reg_h, reg_l} + 16'd2;
                default: ;
            endcase
            goto_state(S_FETCH_OP);
            dbg_retire   <= 1'b1;
        end

        // STEAX family (d48 0x92-0x9F, m34): (base) <- EAL, (base+1) <- EAH.
        // base address is selected by sub_op[3:0] via eax_base_addr.
        // Same post-mod semantics as LDEAX (Dp/Hp inc by 2 in HI cycle).
        S_STEAX_LO: begin
            // Memory write happens combinationally this cycle.
            goto_state(S_STEAX_HI);
        end
        S_STEAX_HI: begin
            // Memory write happens combinationally this cycle.
            case (sub_op[3:0])
                4'h4: {reg_d, reg_e} <= {reg_d, reg_e} + 16'd2;
                4'h5: {reg_h, reg_l} <= {reg_h, reg_l} + 16'd2;
                default: ;
            endcase
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // RLD/RRD (d48 0x38/0x39, m36): BCD nibble swap with (HL).
        // mem_din is the byte at HL (combinational this cycle).  Compute
        // both the new A and the new mem byte using OLD A; latch new mem
        // byte to imm_hi for the WR cycle to send to mem_dout.
        // MAME upd7810_opcodes.cpp:269 (RLD), 278 (RRD).
        S_RLDRRD_RD: begin
            if (sub_op == 8'h38) begin
                // RLD: A <- A.hi | (m >> 4); m <- (m << 4) | A.lo
                reg_a   <= {reg_a[7:4], mem_din[7:4]};
                imm_hi  <= {mem_din[3:0], reg_a[3:0]};
            end else begin
                // RRD: A <- A.hi | (m & 0x0F); m <- (A << 4) | (m >> 4)
                reg_a   <= {reg_a[7:4], mem_din[3:0]};
                imm_hi  <= {reg_a[3:0], mem_din[7:4]};
            end
            goto_state(S_RLDRRD_WR);
            dbg_retire <= 1'b0;
        end
        S_RLDRRD_WR: begin
            // Memory write happens combinationally this cycle.  No flags.
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // LDAX with offset (primary 0xAB-0xAF, m41): A <- mem[base].
        // base = lstax_off_addr (set by mem_addr mux from opcode[3:0]).
        // No flags; no register post-modify.
        S_LDAX_OFF: begin
            reg_a      <= mem_din;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end
        // STAX with offset (primary 0xBB-0xBF, m41): mem[base] <- A.
        // mem_dout explicitly selects reg_a for S_STAX_OFF.  No flags; no
        // register post-modify.
        S_STAX_OFF: begin
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // BLOCK (primary 0x31, m42): byte-by-byte block move (HL -> DE).
        // S_BLOCK_RD reads (HL) into imm_hi as a temp.
        // S_BLOCK_WR writes that byte to (DE), then increments HL & DE,
        // decrements C, and decides whether to repeat:
        //   if C wraps (was 0, now 0xFF):  set CY, retire normally.
        //   else:                           clear CY, decrement PC so the
        //                                   next fetch re-enters BLOCK.
        // MAME upd7810_opcodes.cpp:8911.
        S_BLOCK_RD: begin
            imm_hi     <= mem_din;
            goto_state(S_BLOCK_WR);
            dbg_retire <= 1'b0;
        end
        S_BLOCK_WR: begin
            // Memory write happens combinationally this cycle.
            {reg_d, reg_e} <= {reg_d, reg_e} + 16'd1;
            {reg_h, reg_l} <= {reg_h, reg_l} + 16'd1;
            reg_c          <= reg_c - 8'd1;
            if (reg_c == 8'h00) begin
                // C will wrap to 0xFF — terminate the loop.
                psw[0]     <= 1'b1;       // CY set
            end else begin
                // C will be non-zero after the dec — repeat by stepping
                // PC back so the next fetch re-reads the BLOCK opcode.
                psw[0]     <= 1'b0;
                pc         <= pc - 16'd1;
            end
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // -----------------------------------------------------------------
        // Page-address family.  EA = {V, wa} where wa is in imm_lo.  In
        // S_PAGE_RD mem_din has the byte read from {V,wa}.  Read-only ops
        // finalise here and retire; RMW ops compute the new value into
        // imm_hi (NBA) and transition to S_PAGE_WR which writes it back.
        // MAME refs:
        //   LDAW         upd7810_opcodes.cpp:7931
        //   STAW         8930
        //   ANIW/ORIW    7960/8072
        //   GTIW/LTIW    8088/8108
        //   ONIW/OFFIW   8268/8198
        //   NEIW/EQIW    8208/8278
        //   INRW/DCRW    8140/8248
        //   BIT n,wa     ~7775..7886 (8 ops)
        // -----------------------------------------------------------------
        S_PAGE_RD: begin
            if (opcode == 8'h74) begin
                // d74 page-arith *_wa family (m31): A vs mem at {V, wa}.
                // mem_din is the read byte; wa is in imm_lo.  Op selected
                // by sub_op (column 0 of each row 0x88-0xF0).
                // MAME upd7810_opcodes.cpp:7366 et seq.
                case (sub_op)
                    8'h88: begin                       // ANAW wa: A &= m, Z only
                        reg_a  <= reg_a & mem_din;
                        psw[6] <= ((reg_a & mem_din) == 8'h00);
                    end
                    8'h90: begin                       // XRAW wa: A ^= m, Z only
                        reg_a  <= reg_a ^ mem_din;
                        psw[6] <= ((reg_a ^ mem_din) == 8'h00);
                    end
                    8'h98: begin                       // ORAW wa: A |= m, Z only
                        reg_a  <= reg_a | mem_din;
                        psw[6] <= ((reg_a | mem_din) == 8'h00);
                    end
                    8'hA0: begin                       // ADDNCW: A += m, SKIP_NC
                        reg_a  <= reg_a + mem_din;
                        psw[6] <= (((reg_a + mem_din) & 8'hFF) == 8'h00);
                        psw[0] <= ({1'b0, reg_a} + {1'b0, mem_din}) > 9'h0FF;
                        psw[4] <= (((reg_a + mem_din) & 4'hF) < (reg_a[3:0]));
                        if (({1'b0, reg_a} + {1'b0, mem_din}) <= 9'h0FF)
                            psw[5] <= 1'b1;
                    end
                    8'hA8: begin                       // GTAW: cmp A>m, SKIP_NC
                        psw[6] <= (({8'd0, reg_a} - {8'd0, mem_din} - 16'd1) == 16'h0000);
                        psw[0] <= (reg_a <= mem_din);
                        psw[4] <= (((reg_a - mem_din - 8'd1) & 4'hF) > (reg_a[3:0]));
                        if (reg_a > mem_din) psw[5] <= 1'b1;
                    end
                    8'hB0: begin                       // SUBNBW: A -= m, SKIP_NC
                        reg_a  <= reg_a - mem_din;
                        psw[6] <= (((reg_a - mem_din) & 8'hFF) == 8'h00);
                        psw[0] <= (mem_din > reg_a);
                        psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                        if (mem_din <= reg_a) psw[5] <= 1'b1;
                    end
                    8'hB8: begin                       // LTAW: cmp A<m, SKIP_CY
                        psw[6] <= (((reg_a - mem_din) & 8'hFF) == 8'h00);
                        psw[0] <= (mem_din > reg_a);
                        psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                        if (reg_a < mem_din) psw[5] <= 1'b1;
                    end
                    8'hC0: begin                       // ADDW: A += m (no skip)
                        reg_a  <= reg_a + mem_din;
                        psw[6] <= (((reg_a + mem_din) & 8'hFF) == 8'h00);
                        psw[0] <= ({1'b0, reg_a} + {1'b0, mem_din}) > 9'h0FF;
                        psw[4] <= (((reg_a + mem_din) & 4'hF) < (reg_a[3:0]));
                    end
                    8'hC8: begin                       // ONAW: SK if (A & m) != 0; Z affected
                        if ((reg_a & mem_din) != 8'h00) begin
                            psw[6] <= 1'b0;
                            psw[5] <= 1'b1;
                        end else begin
                            psw[6] <= 1'b1;
                        end
                    end
                    8'hD0: begin                       // ADCW: A += m + CY (no skip)
                        reg_a  <= reg_a + mem_din + {7'd0, psw[0]};
                        psw[6] <= (((reg_a + mem_din + {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                        psw[0] <= ({1'b0, reg_a} + {1'b0, mem_din} + {8'd0, psw[0]}) > 9'h0FF;
                        psw[4] <= (((reg_a + mem_din + {7'd0, psw[0]}) & 4'hF) < (reg_a[3:0]));
                    end
                    8'hD8: begin                       // OFFAW: SK if (A & m) == 0; Z affected
                        if ((reg_a & mem_din) != 8'h00) begin
                            psw[6] <= 1'b0;
                        end else begin
                            psw[6] <= 1'b1;
                            psw[5] <= 1'b1;
                        end
                    end
                    8'hE0: begin                       // SUBW: A -= m (no skip)
                        reg_a  <= reg_a - mem_din;
                        psw[6] <= (((reg_a - mem_din) & 8'hFF) == 8'h00);
                        psw[0] <= (mem_din > reg_a);
                        psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                    end
                    8'hE8: begin                       // NEAW: cmp A!=m, SKIP_NZ
                        psw[6] <= (reg_a == mem_din);
                        psw[0] <= (mem_din > reg_a);
                        psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                        if (reg_a != mem_din) psw[5] <= 1'b1;
                    end
                    8'hF0: begin                       // SBBW: A -= m + CY (no skip)
                        reg_a  <= reg_a - mem_din - {7'd0, psw[0]};
                        psw[6] <= (((reg_a - mem_din - {7'd0, psw[0]}) & 8'hFF) == 8'h00);
                        psw[0] <= ({1'b0, mem_din} + {8'd0, psw[0]}) > {1'b0, reg_a};
                        psw[4] <= (((reg_a - mem_din - {7'd0, psw[0]}) & 4'hF) > (reg_a[3:0]));
                    end
                    8'hF8: begin                       // EQAW: cmp A==m, SKIP_Z
                        psw[6] <= (reg_a == mem_din);
                        psw[0] <= (mem_din > reg_a);
                        psw[4] <= (((reg_a - mem_din) & 4'hF) > (reg_a[3:0]));
                        if (reg_a == mem_din) psw[5] <= 1'b1;
                    end
                    default: ;
                endcase
                goto_state(S_FETCH_OP);
                dbg_retire <= 1'b1;
            end else casez (opcode)
                8'h01: begin                           // LDAW wa
                    reg_a      <= mem_din;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // BIT n, wa : SK iff (m & (1<<n)) != 0.  No other flags.
                8'h58, 8'h59, 8'h5A, 8'h5B,
                8'h5C, 8'h5D, 8'h5E, 8'h5F: begin
                    if ((mem_din & (8'd1 << opcode[2:0])) != 8'h00)
                        psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // ONIW wa,xx: SK iff (m & imm_hi) != 0.  No other flags.
                8'h45: begin
                    if ((mem_din & imm_hi) != 8'h00) psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // OFFIW wa,xx: SK iff (m & imm_hi) == 0.  No other flags.
                8'h55: begin
                    if ((mem_din & imm_hi) == 8'h00) psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // NEIW wa,xx: tmp = m - imm_hi.  Z, CY (borrow), SKIP_NZ.
                8'h65: begin
                    psw[6] <= (mem_din == imm_hi);
                    psw[0] <= (imm_hi > mem_din);
                    psw[4] <= (((mem_din - imm_hi) & 4'hF) > mem_din[3:0]);
                    if (mem_din != imm_hi) psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // EQIW wa,xx: tmp = m - imm_hi.  Z, CY, SKIP_Z.
                8'h75: begin
                    psw[6] <= (mem_din == imm_hi);
                    psw[0] <= (imm_hi > mem_din);
                    psw[4] <= (((mem_din - imm_hi) & 4'hF) > mem_din[3:0]);
                    if (mem_din == imm_hi) psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // GTIW wa,xx: SKIP_NC iff m > imm_hi.
                8'h25: begin
                    psw[6] <= (({8'd0, mem_din} - {8'd0, imm_hi} - 16'd1) == 16'h0000);
                    psw[0] <= (mem_din <= imm_hi);
                    psw[4] <= (((mem_din - imm_hi - 8'd1) & 4'hF) > mem_din[3:0]);
                    if (mem_din > imm_hi) psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // LTIW wa,xx: SKIP_CY iff m < imm_hi.
                8'h35: begin
                    psw[6] <= (mem_din == imm_hi);
                    psw[0] <= (mem_din < imm_hi);
                    psw[4] <= (((mem_din - imm_hi) & 4'hF) > mem_din[3:0]);
                    if (mem_din < imm_hi) psw[5] <= 1'b1;
                    goto_state(S_FETCH_OP);
                    dbg_retire <= 1'b1;
                end
                // ANIW wa,xx: m = m & imm_hi.  Per MAME 7960, only Z is
                // updated — CY/HC/SK left alone.
                8'h05: begin
                    imm_hi     <= mem_din & imm_hi;
                    psw[6]     <= ((mem_din & imm_hi) == 8'h00);
                    goto_state(S_PAGE_WR);
                    dbg_retire <= 1'b0;
                end
                // ORIW wa,xx: m = m | imm_hi.  Per MAME 8072, only Z.
                8'h15: begin
                    imm_hi     <= mem_din | imm_hi;
                    psw[6]     <= ((mem_din | imm_hi) == 8'h00);
                    goto_state(S_PAGE_WR);
                    dbg_retire <= 1'b0;
                end
                // INRW wa: m = m + 1.  Z from result, CY preserved (per
                // MAME ZHC_ADD + restore-CY pattern), SKIP_CY iff m was 0xFF.
                8'h20: begin
                    imm_hi     <= mem_din + 8'd1;
                    psw[6]     <= ((mem_din + 8'd1) == 8'h00);
                    psw[4]     <= (((mem_din + 8'd1) & 4'hF) < mem_din[3:0]);
                    if (mem_din == 8'hFF) psw[5] <= 1'b1;
                    goto_state(S_PAGE_WR);
                    dbg_retire <= 1'b0;
                end
                // DCRW wa: m = m - 1.  Z, CY preserved, SKIP_CY iff m was 0.
                8'h30: begin
                    imm_hi     <= mem_din - 8'd1;
                    psw[6]     <= ((mem_din - 8'd1) == 8'h00);
                    psw[4]     <= (((mem_din - 8'd1) & 4'hF) > mem_din[3:0]);
                    if (mem_din == 8'h00) psw[5] <= 1'b1;
                    goto_state(S_PAGE_WR);
                    dbg_retire <= 1'b0;
                end
                default: begin
                    goto_state(S_TRAP);
                    dbg_retire <= 1'b0;
                end
            endcase
        end

        S_PAGE_WR: begin
            // mem_dout mux selects reg_a (STAW) or imm_hi (everyone else).
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        S_MVIX: begin
            // mem_dout = imm_lo at indirect address selected by opcode[1:0].
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // Interrupt entry.  Hardware INTF1 vectors to $0010 and clears
        // SK/L0/L1; SOFTI vectors to $0060 and preserves live SK (L0/L1
        // were already cleared by the opcode table mask in S_EXECUTE).
        // dbg_retire fires at S_INT_PCL so the trace shows one row for
        // the interrupt/software-interrupt entry boundary.
        S_INT_PSW: begin
            sp    <= sp - 16'd1;
            goto_state(S_INT_PCH);
        end
        S_INT_PCH: begin
            sp    <= sp - 16'd1;
            goto_state(S_INT_PCL);
        end
        S_INT_PCL: begin
            sp         <= sp - 16'd1;
            pc         <= softi_entry ? 16'h0060 : 16'h0010;
            if (!softi_entry)
                psw    <= psw & 8'b11010011;  // clear SK (bit5), L1 (bit3), L0 (bit2)
            softi_entry <= 1'b0;
            fetch_pc   <= pc;           // makes the retire row show the
                                        // saved-PC for trace alignment
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // RETI: pop PC, then PSW. MAME does not alter IFF here.
        S_RETI_PCL: begin
            pc_lo_tmp <= mem_din;
            sp        <= sp + 16'd1;
            goto_state(S_RETI_PCH);
        end
        S_RETI_PCH: begin
            pc    <= {mem_din, pc_lo_tmp};
            sp    <= sp + 16'd1;
            goto_state(S_RETI_PSW);
        end
        S_RETI_PSW: begin
            psw        <= mem_din;
            sp         <= sp + 16'd1;
            goto_state(S_FETCH_OP);
            dbg_retire <= 1'b1;
        end

        // park on a trap so the testbench can print context and stop
        S_TRAP: goto_state(S_TRAP);

        default: goto_state(S_TRAP);
        endcase
    end
end

endmodule
/* verilator lint_on WIDTHEXPAND */
