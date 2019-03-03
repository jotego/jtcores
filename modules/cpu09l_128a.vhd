--===========================================================================--
--                                                                           --
--        Synthesizable 6809 instruction compatible VHDL CPU core            --
--                                                                           --
--===========================================================================--
--
-- File name      : cpu09l.vhd
--
-- Entity name    : cpu09
--
-- Purpose        : 6809 instruction compatible CPU core written in VHDL
--                  with Last Instruction Cycle, bus available, bus status,
--                  and instruction fetch signals.
--                  Not cycle compatible with the original 6809 CPU
--
-- Dependencies   : ieee.std_logic_1164
--                  ieee.std_logic_unsigned
--
-- Author         : John E. Kent
--
-- Email          : dilbert57@opencores.org
--
-- Web            : http://opencores.org/project,system09
--
-- Description    : VMA (valid memory address) is hight whenever a valid memory
--                  access is made by an instruction fetch, interrupt vector fetch
--                  or a data read or write otherwise it is low indicating an idle
--                  bus cycle.
--                  IFETCH (instruction fetch output) is high whenever an
--                  instruction byte is read i.e. the program counter is applied
--                  to the address bus.
--                  LIC (last instruction cycle output) is normally low
--                  but goes high on the last cycle of an instruction.
--                  BA (bus available output) is normally low but goes high while
--                  waiting in a Sync instruction state or the CPU is halted
--                  i.e. a DMA grant.
--                  BS (bus status output) is normally low but goes high during an
--                  interrupt or reset vector fetch or the processor is halted
--                  i.e. a DMA grant.
--
--  Copyright (C) 2003 - 2010 John Kent
--
--  This program is free software: you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation, either version 3 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--===========================================================================--
--                                                                           --
--                                Revision History                           --
--                                                                           --
--===========================================================================--
--
-- Version 0.1 - 26 June 2003 - John Kent
-- Added extra level in state stack
-- fixed some calls to the extended addressing state
--
-- Version 0.2 - 5 Sept 2003 - John Kent
-- Fixed 16 bit indexed offset (was doing read rather than fetch)
-- Added/Fixed STY and STS instructions.
-- ORCC_STATE ANDed CC state rather than ORed it - Now fixed
-- CMPX Loaded ACCA and ACCB - Now fixed
--
-- Version 1.0 - 6 Sep 2003 - John Kent
-- Initial release to Open Cores
-- reversed clock edge
--
-- Version 1.1 - 29 November 2003 John kent
--	ACCA and ACCB indexed offsets are 2's complement.
-- ALU Right Mux now sign extends ACCA & ACCB offsets
-- Absolute Indirect addressing performed a read on the
-- second byte of the address rather than a fetch
-- so it formed an incorrect address. Now fixed.
--
-- Version 1.2 - 29 November 2003 John Kent
-- LEAX and LEAY affect the Z bit only
--	LEAS and LEAU do not affect any condition codes
-- added an extra ALU control for LEA.
--
-- Version 1.3 - 12 December 2003 John Kent
-- CWAI did not work, was missed a PUSH_ST on calling
-- the ANDCC_STATE. Thanks go to Ghassan Kraidy for
-- finding this fault.
--
-- Version 1.4 - 12 December 2003 John Kent
-- Missing cc_ctrl assignment in otherwise case of
-- lea_state resulted in cc_ctrl being latched in
-- that state.
-- The otherwise statement should never be reached,
-- and has been fixed simply to resolve synthesis warnings.
--
-- Version 1.5 - 17 january 2004 John kent
-- The clear instruction used "alu_ld8" to control the ALU
-- rather than "alu_clr". This mean the Carry was not being
-- cleared correctly.
--
-- Version 1.6 - 24 January 2004 John Kent
-- Fixed problems in PSHU instruction
--
-- Version 1.7 - 25 January 2004 John Kent
-- removed redundant "alu_inx" and "alu_dex'
-- Removed "test_alu" and "test_cc"
-- STD instruction did not set condition codes
-- JMP direct was not decoded properly
-- CLR direct performed an unwanted read cycle
-- Bogus "latch_md" in Page2 indexed addressing
--
-- Version 1.8 - 27 January 2004 John Kent
-- CWAI in decode1_state should increment the PC.
-- ABX is supposed to be an unsigned addition.
-- Added extra ALU function
-- ASR8 slightly changed in the ALU.
--
--	Version 1.9 - 20 August 2005
-- LSR8 is now handled in ASR8 and ROR8 case in the ALU,
-- rather than LSR16. There was a problem with single
-- operand instructions using the MD register which is
-- sign extended on the first 8 bit fetch.
--
-- Version 1.10 - 13 September 2005
-- TFR & EXG instructions did not work for the Condition Code Register
-- An extra case has been added to the ALU for the alu_tfr control
-- to assign the left ALU input (alu_left) to the condition code
-- outputs (cc_out).
--
-- Version 1.11 - 16 September 2005
-- JSR ,X should not predecrement S before calculating the jump address.
-- The reason is that JSR [0,S] needs S to point to the top of the stack
-- to fetch a valid vector address. The solution is to have the addressing
-- mode microcode called before decrementing S and then decrementing S in
-- JSR_STATE. JSR_STATE in turn calls PUSH_RETURN_LO_STATE rather than
-- PUSH_RETURN_HI_STATE so that both the High & Low halves of the PC are
-- pushed on the stack. This adds one extra bus cycle, but resolves the
-- addressing conflict. I've also removed the pre-decement S in
-- JSR EXTENDED as it also calls JSR_STATE.
--
-- Version 1.12 - 6th June 2006
-- 6809 Programming reference manual says V is not affected by ASR, LSR and ROR
-- This is different to the 6800. CLR should reset the V bit.
--
-- Version 1.13 - 7th July 2006
-- Disable NMI on reset until S Stack pointer has been loaded.
-- Added nmi_enable signal in sp_reg process and nmi_handler process.
--
-- Version 1.14 - 11th July 2006
-- 1. Added new state to RTI called rti_entire_state.
-- This state tests the CC register after it has been loaded
-- from the stack. Previously the current CC was tested which
-- was incorrect. The Entire Flag should be set before the
-- interrupt stacks the CC.
-- 2. On bogus Interrupts, int_cc_state went to rti_state,
-- which was an enumerated state, but not defined anywhere.
-- rti_state has been changed to rti_cc_state so that bogus interrupt
-- will perform an RTI after entering that state.
-- 3. Sync should generate an interrupt if the interrupt masks
-- are cleared. If the interrupt masks are set, then an interrupt
-- will cause the the PC to advance to the next instruction.
-- Note that I don't wait for an interrupt to be asserted for
-- three clock cycles.
-- 4. Added new ALU control state "alu_mul". "alu_mul" is used in
-- the Multiply instruction replacing "alu_add16". This is similar
-- to "alu_add16" except it sets the Carry bit to B7 of the result
-- in ACCB, sets the Zero bit if the 16 bit result is zero, but
-- does not affect The Half carry (H), Negative (N) or Overflow (V)
-- flags. The logic was re-arranged so that it adds md or zero so
-- that the Carry condition code is set on zero multiplicands.
-- 5. DAA (Decimal Adjust Accumulator) should set the Negative (N)
-- and Zero Flags. It will also affect the Overflow (V) flag although
-- the operation is undefined. It's anyones guess what DAA does to V.
--
-- Version 1.15 - 25th Feb 2007 - John Kent
-- line 9672 changed "if Halt <= '1' then" to "if Halt = '1' then"
-- Changed sensitivity lists.
--
-- Version 1.16 - 5th February 2008 - John Kent
-- FIRQ interrupts should take priority over IRQ Interrupts.
-- This presumably means they should be tested for before IRQ
-- when they happen concurrently.
--
-- Version 1.17 - 18th February 2008 - John Kent
-- NMI in CWAI should mask IRQ and FIRQ interrupts
--
-- Version 1.18 - 21st February 2008 - John Kent
-- Removed default register settings in each case statement
-- and placed them at the beginning of the state sequencer.
-- Modified the SYNC instruction so that the interrupt vector(iv)
-- is not set unless an unmasked FIRQ or IRQ is received.
--
-- Version 1.19 - 25th February 2008 - John Kent
-- Enumerated separate states for FIRQ/FAST and NMIIRQ/ENTIRE
-- Enumerated separate states for MASKI and MASKIF states
-- Removed code on BSR/JSR in fetch cycle
--
-- Version 1.20 - 8th October 2011 - John Kent
-- added fetch output which should go high during the fetch cycle
--
-- Version 1.21 - 8th October 2011 - John Kent
-- added Last Instruction Cycle signal
-- replaced fetch with ifetch (instruction fetch) signal
-- added ba & bs (bus available & bus status) signals
--
-- Version 1.22 - 2011-10-29 John Kent
-- The halt state isn't correct.
-- The halt state is entered into from the fetch_state
-- It returned to the fetch state which may re-run an execute cycle
-- on the accumulator and it won't necessarily be the last instruction cycle
-- I've changed the halt state to return to the decode1_state
--
-- Version 1.23 - 2011-10-30 John Kent
-- sample halt in the change_state process if lic is high (last instruction cycle)
--
-- Version 1.24 - 2011-11-01 John Kent
-- Handle interrupts in change_state process
-- Sample interrupt inputs on last instruction cycle
-- Remove iv_ctrl and implement iv (interrupt vector) in change_state process.
-- Generate fic (first instruction cycle) from lic (last instruction cycle)
-- and use it to complete the dual operand execute cycle before servicing
-- halt or interrupts requests.
-- rename lic to lic_out on the entity declaration so that lic can be tested internally.
-- add int_firq1_state and int_nmirq1_state to allow for the dual operand execute cycle
-- integrated nmi_ctrl into change_state process
-- Reduces the microcode state stack to one entry (saved_state)
-- imm16_state jumps directly to the fetch_state
-- pull_return_lo states jumps directly to the fetch_state
-- duplicate andcc_state as cwai_state
-- rename exg1_state as exg2 state and duplicate tfr_state as exg1_state
--
-- Version 1.25 - 2011-11-27 John Kent
-- Changed the microcode for saving registers on an interrupt into a microcode subroutine.
-- Removed SWI servicing from the change state process and made SWI, SWI2 & SWI3
-- call the interrupt microcode subroutine.
-- Added additional states for nmi, and irq for interrupt servicing.
-- Added additional states for nmi/irq, firq, and swi interrupts to mask I & F flags.
--
-- Version 1.26 - 2013-03-18 John Kent
-- pre-initialized cond_true variable to true in state sequencer
-- re-arranged change_state process slightly
--
-- Version 1.27 - 2015-05-30 John Kent
-- Added test in state machine for masked IRQ and FIRQ in Sync_state.
--
-- Version 1.28 - 2015-05-30 John Kent.
-- Moved IRQ and FIRQ test from state machine to the state sequencer Sync_state.
--
-- Version 1.28a - Temporary tweaked release - 2018-02-08 DarFPGA
-- Add wait_cycles process to retrieve original cycle count for some (few) instructions.
-- Only those used by vectrex exec_rom (and spike rom) during drawing.
-- Beware that external hold (hold_in) is no more active.
--
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity cpu09 is
	port (
		clk      :	in std_logic;                     -- E clock input (falling edge)
		ce       :	in std_logic;
		rst      :  in std_logic;                     -- reset input (active high)
		vma      : out std_logic;                     -- valid memory address (active high)
      lic_out  : out std_logic;                     -- last instruction cycle (active high)
      ifetch   : out std_logic;                     -- instruction fetch cycle (active high)
      opfetch  : out std_logic;                     -- opcode fetch (active high)
      ba       : out std_logic;                     -- bus available (high on sync wait or DMA grant)
      bs       : out std_logic;                     -- bus status (high on interrupt or reset vector fetch or DMA grant)
		addr     : out std_logic_vector(15 downto 0); -- address bus output
		rw       : out std_logic;                     -- read not write output
	   data_out : out std_logic_vector(7 downto 0);  -- data bus output
	   data_in  :  in std_logic_vector(7 downto 0);  -- data bus input
		irq      :  in std_logic;                     -- interrupt request input (active high)
		firq     :  in std_logic;                     -- fast interrupt request input (active high)
		nmi      :  in std_logic;                     -- non maskable interrupt request input (active high)
		halt     :  in std_logic                      -- halt input (active high) grants DMA
		);
end cpu09;

architecture rtl of cpu09 is

  constant EBIT : integer := 7;
  constant FBIT : integer := 6;
  constant HBIT : integer := 5;
  constant IBIT : integer := 4;
  constant NBIT : integer := 3;
  constant ZBIT : integer := 2;
  constant VBIT : integer := 1;
  constant CBIT : integer := 0;

  --
  -- Interrupt vector modifiers
  --
  constant RST_VEC  : std_logic_vector(2 downto 0) := "111";
  constant NMI_VEC  : std_logic_vector(2 downto 0) := "110";
  constant SWI_VEC  : std_logic_vector(2 downto 0) := "101";
  constant IRQ_VEC  : std_logic_vector(2 downto 0) := "100";
  constant FIRQ_VEC : std_logic_vector(2 downto 0) := "011";
  constant SWI2_VEC : std_logic_vector(2 downto 0) := "010";
  constant SWI3_VEC : std_logic_vector(2 downto 0) := "001";
  constant RESV_VEC : std_logic_vector(2 downto 0) := "000";

	type state_type is (-- Start off in Reset
	                    reset_state,
							  -- Fetch Interrupt Vectors (including reset)
							  vect_lo_state, vect_hi_state, vect_idle_state,
                       -- Fetch Instruction Cycle
                       fetch_state,
							  -- Decode Instruction Cycles
                       decode1_state, decode2_state, decode3_state,
							  -- Calculate Effective Address
						     imm16_state,
		                 indexed_state, index8_state, index16_state, index16_2_state,
							  pcrel8_state, pcrel16_state, pcrel16_2_state,
							  indexaddr_state, indexaddr2_state,
						     postincr1_state, postincr2_state,
							  indirect_state, indirect2_state, indirect3_state,
                       extended_state,
							  -- single ops
							  single_op_read_state,
						     single_op_exec_state,
	                    single_op_write_state,
							  -- Dual op states
							  dual_op_read8_state, dual_op_read16_state, dual_op_read16_2_state,
						     dual_op_write8_state, dual_op_write16_state,
                       --
						     sync_state, halt_state, cwai_state,
							  --
							  andcc_state, orcc_state,
							  tfr_state,
                       exg_state, exg1_state, exg2_state,
							  lea_state,
							  -- Multiplication
						     mul_state, mulea_state, muld_state,
						     mul0_state, mul1_state, mul2_state, mul3_state,
						     mul4_state, mul5_state, mul6_state, mul7_state,
							  --  Branches
							  lbranch_state, sbranch_state,
							  -- Jumps, Subroutine Calls and Returns
                       jsr_state, jmp_state,
                       push_return_hi_state, push_return_lo_state,
                       pull_return_hi_state, pull_return_lo_state,
							  -- Interrupt cycles
							  int_nmi_state, int_nmi1_state,
							  int_irq_state, int_irq1_state,
                       int_firq_state,  int_firq1_state,
							  int_entire_state, int_fast_state,
							  int_pcl_state,  int_pch_state,
						     int_upl_state,  int_uph_state,
						     int_iyl_state,  int_iyh_state,
						     int_ixl_state,  int_ixh_state,
						     int_dp_state,
				           int_accb_state, int_acca_state,
						     int_cc_state,
						     int_cwai_state,
							  int_nmimask_state, int_firqmask_state, int_swimask_state, int_irqmask_state,
							  -- Return From Interrupt
						     rti_cc_state,   rti_entire_state,
							  rti_acca_state, rti_accb_state,
						     rti_dp_state,
						     rti_ixl_state,  rti_ixh_state,
						     rti_iyl_state,  rti_iyh_state,
						     rti_upl_state,  rti_uph_state,
						     rti_pcl_state,  rti_pch_state,
							  -- Push Registers using SP
							  pshs_state,
						     pshs_pcl_state,  pshs_pch_state,
						     pshs_upl_state,  pshs_uph_state,
						     pshs_iyl_state,  pshs_iyh_state,
						     pshs_ixl_state,  pshs_ixh_state,
						     pshs_dp_state,
						     pshs_acca_state, pshs_accb_state,
						     pshs_cc_state,
							  -- Pull Registers using SP
							  puls_state,
							  puls_cc_state,
							  puls_acca_state, puls_accb_state,
							  puls_dp_state,
						     puls_ixl_state,  puls_ixh_state,
						     puls_iyl_state,  puls_iyh_state,
						     puls_upl_state,  puls_uph_state,
						     puls_pcl_state,  puls_pch_state,
							  -- Push Registers using UP
							  pshu_state,
						     pshu_pcl_state,  pshu_pch_state,
						     pshu_spl_state,  pshu_sph_state,
						     pshu_iyl_state,  pshu_iyh_state,
						     pshu_ixl_state,  pshu_ixh_state,
						     pshu_dp_state,
						     pshu_acca_state, pshu_accb_state,
						     pshu_cc_state,
							  -- Pull Registers using UP
							  pulu_state,
							  pulu_cc_state,
							  pulu_acca_state, pulu_accb_state,
							  pulu_dp_state,
						     pulu_ixl_state,  pulu_ixh_state,
						     pulu_iyl_state,  pulu_iyh_state,
						     pulu_spl_state,  pulu_sph_state,
						     pulu_pcl_state,  pulu_pch_state );

	type st_type    is (reset_st, push_st, idle_st );
	type iv_type    is (latch_iv, swi3_iv, swi2_iv, firq_iv, irq_iv, swi_iv, nmi_iv, reset_iv);
	type addr_type  is (idle_ad, fetch_ad, read_ad, write_ad, pushu_ad, pullu_ad, pushs_ad, pulls_ad, int_hi_ad, int_lo_ad );
	type dout_type  is (cc_dout, acca_dout, accb_dout, dp_dout,
                       ix_lo_dout, ix_hi_dout, iy_lo_dout, iy_hi_dout,
                       up_lo_dout, up_hi_dout, sp_lo_dout, sp_hi_dout,
                       pc_lo_dout, pc_hi_dout, md_lo_dout, md_hi_dout );
   type op_type    is (reset_op, fetch_op, latch_op );
   type pre_type   is (reset_pre, fetch_pre, latch_pre );
   type cc_type    is (reset_cc, load_cc, pull_cc, latch_cc );
   type acca_type  is (reset_acca, load_acca, load_hi_acca, pull_acca, latch_acca );
   type accb_type  is (reset_accb, load_accb, pull_accb, latch_accb );
   type dp_type    is (reset_dp, load_dp, pull_dp, latch_dp );
	type ix_type    is (reset_ix, load_ix, pull_lo_ix, pull_hi_ix, latch_ix );
	type iy_type    is (reset_iy, load_iy, pull_lo_iy, pull_hi_iy, latch_iy );
	type sp_type    is (reset_sp, latch_sp, load_sp, pull_hi_sp, pull_lo_sp );
	type up_type    is (reset_up, latch_up, load_up, pull_hi_up, pull_lo_up );
	type pc_type    is (reset_pc, latch_pc, load_pc, pull_lo_pc, pull_hi_pc, incr_pc );
   type md_type    is (reset_md, latch_md, load_md, fetch_first_md, fetch_next_md, shiftl_md );
   type ea_type    is (reset_ea, latch_ea, load_ea, fetch_first_ea, fetch_next_ea );
	type left_type  is (cc_left, acca_left, accb_left, dp_left,
							  ix_left, iy_left, up_left, sp_left,
                       accd_left, md_left, pc_left, ea_left );
	type right_type is (ea_right, zero_right, one_right, two_right,
                       acca_right, accb_right, accd_right,
							  md_right, md_sign5_right, md_sign8_right );
   type alu_type   is (alu_add8, alu_sub8, alu_add16, alu_sub16, alu_adc, alu_sbc,
                       alu_and, alu_ora, alu_eor,
                       alu_tst, alu_inc, alu_dec, alu_clr, alu_neg, alu_com,
						     alu_lsr16, alu_lsl16,
						     alu_ror8, alu_rol8, alu_mul,
						     alu_asr8, alu_asl8, alu_lsr8,
						     alu_andcc, alu_orcc, alu_sex, alu_tfr, alu_abx,
							  alu_seif, alu_sei, alu_see, alu_cle,
						     alu_ld8, alu_st8, alu_ld16, alu_st16, alu_lea, alu_nop, alu_daa );

	signal op_code:     std_logic_vector(7 downto 0);
	signal pre_code:    std_logic_vector(7 downto 0);
  	signal acca:        std_logic_vector(7 downto 0);
  	signal accb:        std_logic_vector(7 downto 0);
   signal cc:          std_logic_vector(7 downto 0);
	signal cc_out:      std_logic_vector(7 downto 0);
	signal dp:          std_logic_vector(7 downto 0);
	signal xreg:        std_logic_vector(15 downto 0);
	signal yreg:        std_logic_vector(15 downto 0);
	signal sp:          std_logic_vector(15 downto 0);
	signal up:          std_logic_vector(15 downto 0);
	signal ea:          std_logic_vector(15 downto 0);
	signal pc:	        std_logic_vector(15 downto 0);
	signal md:          std_logic_vector(15 downto 0);
   signal left:        std_logic_vector(15 downto 0);
   signal right:       std_logic_vector(15 downto 0);
	signal out_alu:     std_logic_vector(15 downto 0);
	signal iv:          std_logic_vector(2 downto 0);
	signal nmi_req:     std_logic;
	signal nmi_ack:     std_logic;
	signal nmi_enable:  std_logic;
   signal fic:         std_logic; -- first instruction cycle
   signal lic:         std_logic; -- last instruction cycle

	signal state:        state_type;
	signal next_state:   state_type;
	signal return_state: state_type;
	signal saved_state:  state_type;
	signal st_ctrl:      st_type;
	signal iv_ctrl:      iv_type;
   signal pc_ctrl:      pc_type;
   signal ea_ctrl:      ea_type;
   signal op_ctrl:      op_type;
	signal pre_ctrl:     pre_type;
	signal md_ctrl:      md_type;
	signal acca_ctrl:    acca_type;
	signal accb_ctrl:    accb_type;
	signal ix_ctrl:      ix_type;
	signal iy_ctrl:      iy_type;
	signal cc_ctrl:      cc_type;
	signal dp_ctrl:      dp_type;
	signal sp_ctrl:      sp_type;
	signal up_ctrl:      up_type;
	signal left_ctrl:    left_type;
	signal right_ctrl:   right_type;
   signal alu_ctrl:     alu_type;
   signal addr_ctrl:    addr_type;
   signal dout_ctrl:    dout_type;


	signal cnt_cycles : std_logic_vector(3 downto 0) := "0000" ;
	signal hold : std_logic;

begin

wait_cycles: process(clk)
begin
  if clk'event and clk = '0' then
		if ce = '1' then
		 if lic = '1' then
			case op_code is
			when X"A6" => hold <= '1'; cnt_cycles <= X"1"; -- additional cycles for vectrex tuning
			when X"97" => hold <= '1'; cnt_cycles <= X"1";
			when X"8C" => hold <= '1'; cnt_cycles <= X"1";
			when X"D7" => hold <= '1'; cnt_cycles <= X"1";
			when X"1F" => hold <= '1'; cnt_cycles <= X"3";
			when X"B3" => hold <= '1'; cnt_cycles <= X"2";
			when X"0A" => hold <= '1'; cnt_cycles <= X"2";
			when X"0C" => hold <= '1'; cnt_cycles <= X"2";
			when X"1E" => hold <= '1'; cnt_cycles <= X"3";  -- exg @117A/7C spike (allow time enough for timer to end before pc=11A4)
			when others=> null;
			end case;
		 end if;

		 if hold = '1' then
			if cnt_cycles = X"1" then
 			  hold <= '0';
			end if;
			cnt_cycles <= cnt_cycles - '1';
		 end if;
		end if;
	end if;
end process;

----------------------------------
--
-- State machine stack
--
----------------------------------
--state_stack_proc: process( clk, hold, state_stack, st_ctrl,
--                           return_state, fetch_state  )
state_stack_proc: process( clk, st_ctrl, return_state )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
	   case st_ctrl is
      when reset_st =>
        saved_state <= fetch_state;
      when push_st =>
		  saved_state <= return_state;
		when others =>
        null;
 	   end case;
    end if;
	end if;
  end if;
end process;

----------------------------------
--
-- Interrupt Vector control
--
----------------------------------
--
int_vec_proc: process( clk, iv_ctrl )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
      case iv_ctrl is
      when reset_iv =>
        iv <= RST_VEC;
      when nmi_iv =>
        iv <= NMI_VEC;
      when swi_iv =>
        iv <= SWI_VEC;
      when irq_iv =>
        iv <= IRQ_VEC;
      when firq_iv =>
        iv <= FIRQ_VEC;
      when swi2_iv =>
        iv <= SWI2_VEC;
      when swi3_iv =>
        iv <= SWI3_VEC;
		when others =>
		  null;
      end case;
    end if; -- hold
	end if;
  end if; -- clk
end process;

----------------------------------
--
-- Program Counter Control
--
----------------------------------

--pc_reg: process( clk, pc_ctrl, hold, pc, out_alu, data_in )
pc_reg: process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case pc_ctrl is
	 when reset_pc =>
	   pc <= (others=>'0');
	 when load_pc =>
	   pc <= out_alu(15 downto 0);
	 when pull_lo_pc =>
	   pc(7 downto 0) <= data_in;
	 when pull_hi_pc =>
	   pc(15 downto 8) <= data_in;
	 when incr_pc =>
	   pc <= pc + 1;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

----------------------------------
--
-- Effective Address  Control
--
----------------------------------

--ea_reg: process( clk, ea_ctrl, hold, ea, out_alu, data_in, dp )
ea_reg: process( clk )
begin

  if clk'event and clk = '0' then
	if ce = '1' then
    if hold= '0' then
    case ea_ctrl is
	 when reset_ea =>
	   ea <= (others=>'0');
	 when fetch_first_ea =>
	   ea(7 downto 0) <= data_in;
      ea(15 downto 8) <= dp;
  	 when fetch_next_ea =>
	   ea(15 downto 8) <= ea(7 downto 0);
      ea(7 downto 0)  <= data_in;
	 when load_ea =>
	   ea <= out_alu(15 downto 0);
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- Accumulator A
--
--------------------------------
--acca_reg : process( clk, acca_ctrl, hold, out_alu, acca, data_in )
acca_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case acca_ctrl is
    when reset_acca =>
	   acca <= (others=>'0');
	 when load_acca =>
	   acca <= out_alu(7 downto 0);
	 when load_hi_acca =>
	   acca <= out_alu(15 downto 8);
	 when pull_acca =>
	   acca <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- Accumulator B
--
--------------------------------
--accb_reg : process( clk, accb_ctrl, hold, out_alu, accb, data_in )
accb_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case accb_ctrl is
    when reset_accb =>
	   accb <= (others=>'0');
	 when load_accb =>
	   accb <= out_alu(7 downto 0);
	 when pull_accb =>
	   accb <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- X Index register
--
--------------------------------
--ix_reg : process( clk, ix_ctrl, hold, out_alu, xreg, data_in )
ix_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case ix_ctrl is
    when reset_ix =>
	   xreg <= (others=>'0');
	 when load_ix =>
	   xreg <= out_alu(15 downto 0);
	 when pull_hi_ix =>
	   xreg(15 downto 8) <= data_in;
	 when pull_lo_ix =>
	   xreg(7 downto 0) <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- Y Index register
--
--------------------------------
--iy_reg : process( clk, iy_ctrl, hold, out_alu, yreg, data_in )
iy_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case iy_ctrl is
    when reset_iy =>
	   yreg <= (others=>'0');
	 when load_iy =>
	   yreg <= out_alu(15 downto 0);
	 when pull_hi_iy =>
	   yreg(15 downto 8) <= data_in;
	 when pull_lo_iy =>
	   yreg(7 downto 0) <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- S stack pointer
--
--------------------------------
--sp_reg : process( clk, sp_ctrl, hold, sp, out_alu, data_in, nmi_enable )
sp_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case sp_ctrl is
    when reset_sp =>
	   sp <= (others=>'0');
		nmi_enable <= '0';
	 when load_sp =>
	   sp <= out_alu(15 downto 0);
		nmi_enable <= '1';
	 when pull_hi_sp =>
	   sp(15 downto 8) <= data_in;
	 when pull_lo_sp =>
	   sp(7 downto 0) <= data_in;
		nmi_enable <= '1';
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- U stack pointer
--
--------------------------------
--up_reg : process( clk, up_ctrl, hold, up, out_alu, data_in )
up_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case up_ctrl is
    when reset_up =>
	   up <= (others=>'0');
	 when load_up =>
	   up <= out_alu(15 downto 0);
	 when pull_hi_up =>
	   up(15 downto 8) <= data_in;
	 when pull_lo_up =>
	   up(7 downto 0) <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- Memory Data
--
--------------------------------
--md_reg : process( clk, md_ctrl, hold, out_alu, data_in, md )
md_reg : process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case md_ctrl is
    when reset_md =>
	   md <= (others=>'0');
	 when load_md =>
	   md <= out_alu(15 downto 0);
	 when fetch_first_md => -- sign extend md for branches
	   md(15 downto 8) <= data_in(7) & data_in(7) & data_in(7) & data_in(7) &
	                      data_in(7) & data_in(7) & data_in(7) & data_in(7) ;
	   md(7 downto 0) <= data_in;
	 when fetch_next_md =>
	   md(15 downto 8) <= md(7 downto 0);
		md(7 downto 0) <= data_in;
	 when shiftl_md =>
	   md(15 downto 1) <= md(14 downto 0);
		md(0) <= '0';
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;


----------------------------------
--
-- Condition Codes
--
----------------------------------

--cc_reg: process( clk, cc_ctrl, hold, cc_out, cc, data_in )
cc_reg: process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case cc_ctrl is
	 when reset_cc =>
	   cc <= "11010000"; -- set EBIT, FBIT & IBIT
	 when load_cc =>
	   cc <= cc_out;
  	 when pull_cc =>
      cc <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

----------------------------------
--
-- Direct Page register
--
----------------------------------

--dp_reg: process( clk, dp_ctrl, hold, out_alu, dp, data_in )
dp_reg: process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case dp_ctrl is
	 when reset_dp =>
	   dp <= (others=>'0');
	 when load_dp =>
	   dp <= out_alu(7 downto 0);
  	 when pull_dp =>
      dp <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;


----------------------------------
--
-- op code register
--
----------------------------------

--op_reg: process( clk, op_ctrl, hold, op_code, data_in )
op_reg: process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case op_ctrl is
	 when reset_op =>
	   op_code <= "00010010";
  	 when fetch_op =>
      op_code <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;


----------------------------------
--
-- pre byte op code register
--
----------------------------------

--pre_reg: process( clk, pre_ctrl, hold, pre_code, data_in )
pre_reg: process( clk )
begin
  if clk'event and clk = '0' then
	if ce = '1' then
    if hold = '0' then
    case pre_ctrl is
	 when reset_pre =>
	   pre_code <= (others=>'0');
  	 when fetch_pre =>
      pre_code <= data_in;
	 when others =>
      null;
    end case;
	 end if;
	end if;
  end if;
end process;

--------------------------------
--
-- state machine
--
--------------------------------

--change_state: process( clk, rst, state, hold, next_state )
change_state: process( clk )
begin
  if clk'event and clk = '0' then

    if rst = '1' then
      fic     <= '0';
	   nmi_ack <= '0';
 	   state   <= reset_state;
    elsif ce = '1' and hold = '0' then

		  fic <= lic;
		  --
		  -- nmi request is not cleared until nmi input goes low
		  --
		  if (nmi_req = '0') and (nmi_ack='1') then
          nmi_ack <= '0';
		  end if;

		  if (nmi_req = '1') and (nmi_ack = '0')  and (state = int_nmimask_state) then
          nmi_ack <= '1';
		  end if;

        if lic = '1' then
          if halt = '1' then
			   state <= halt_state;

          -- service non maskable interrupts
          elsif (nmi_req = '1') and (nmi_ack = '0') then
			   state <= int_nmi_state;
				 --
				 -- FIRQ & IRQ are level sensitive
				 --
          elsif (firq = '1') and (cc(FBIT) = '0') then
			   state  <= int_firq_state;

			 elsif (irq = '1') and (cc(IBIT) = '0') then
			   state <= int_irq_state;
			 --
			 -- Version 1.27 2015-05-30
			 -- Exit sync_state on masked interrupt.
			 --
			 -- Version 1.28 2015-05-30
			 -- Move this code to the state sequencer
			 -- near line 5566.
			 --
			 -- elsif  (state = sync_state) and ((firq = '1') or (irq = '1'))then
			 --   state <= fetch_state;
          --
			 else
			   state <= next_state;
          end if; -- halt, nmi, firq, irq
		  else
		    state <= next_state;
        end if; -- lic
	 end if; -- reset/hold
  end if; -- clk
end process;

------------------------------------
--
-- Detect Edge of NMI interrupt
--
------------------------------------

--nmi_handler : process( clk, rst, nmi, nmi_ack, nmi_req, nmi_enable )
nmi_handler : process( rst, clk )
begin
  if rst='1' then
	 nmi_req <= '0';
  elsif clk'event and clk='0' then
	if ce = '1' then
	   if (nmi='1') and (nmi_ack='0') and (nmi_enable='1') then
	     nmi_req <= '1';
	   else
		  if (nmi='0') and (nmi_ack='1') then
	       nmi_req <= '0';
		  end if;
		end if;
	end if;
  end if;
end process;


----------------------------------
--
-- Address output multiplexer
--
----------------------------------

addr_mux: process( addr_ctrl, pc, ea, up, sp, iv )
begin
  ifetch <= '0';
  vma    <= '1';
  case addr_ctrl is
    when fetch_ad =>
	   addr   <= pc;
      rw     <= '1';
      ifetch <= '1';
	 when read_ad =>
	   addr   <= ea;
      rw     <= '1';
    when write_ad =>
	   addr   <= ea;
		rw     <= '0';
	 when pushs_ad =>
	   addr   <= sp;
		rw     <= '0';
    when pulls_ad =>
	   addr   <= sp;
      rw     <= '1';
	 when pushu_ad =>
	   addr   <= up;
		rw     <= '0';
    when pullu_ad =>
	   addr   <= up;
      rw     <= '1';
	 when int_hi_ad =>
	   addr   <= "111111111111" & iv & "0";
      rw     <= '1';
    when int_lo_ad =>
	   addr   <= "111111111111" & iv & "1";
      rw     <= '1';
	 when others =>
      addr   <= "1111111111111111";
      rw     <= '1';
      vma    <= '0';
  end case;
end process;

--------------------------------
--
-- Data Bus output
--
--------------------------------
dout_mux : process( dout_ctrl, md, acca, accb, dp, xreg, yreg, sp, up, pc, cc )
begin
    case dout_ctrl is
	 when cc_dout => -- condition code register
	   data_out <= cc;
	 when acca_dout => -- accumulator a
	   data_out <= acca;
	 when accb_dout => -- accumulator b
	   data_out <= accb;
	 when dp_dout => -- direct page register
	   data_out <= dp;
	 when ix_lo_dout => -- X index reg
	   data_out <= xreg(7 downto 0);
	 when ix_hi_dout => -- X index reg
	   data_out <= xreg(15 downto 8);
	 when iy_lo_dout => -- Y index reg
	   data_out <= yreg(7 downto 0);
	 when iy_hi_dout => -- Y index reg
	   data_out <= yreg(15 downto 8);
	 when up_lo_dout => -- U stack pointer
	   data_out <= up(7 downto 0);
	 when up_hi_dout => -- U stack pointer
	   data_out <= up(15 downto 8);
	 when sp_lo_dout => -- S stack pointer
	   data_out <= sp(7 downto 0);
	 when sp_hi_dout => -- S stack pointer
	   data_out <= sp(15 downto 8);
	 when md_lo_dout => -- alu output
	   data_out <= md(7 downto 0);
	 when md_hi_dout => -- alu output
	   data_out <= md(15 downto 8);
	 when pc_lo_dout => -- low order pc
	   data_out <= pc(7 downto 0);
	 when pc_hi_dout => -- high order pc
	   data_out <= pc(15 downto 8);
    end case;
end process;

----------------------------------
--
-- Left Mux
--
----------------------------------

left_mux: process( left_ctrl, acca, accb, cc, dp, xreg, yreg, up, sp, pc, ea, md )
begin
  case left_ctrl is
	 when cc_left =>
	   left(15 downto 8) <= "00000000";
		left(7 downto 0)  <= cc;
	 when acca_left =>
	   left(15 downto 8) <= "00000000";
		left(7 downto 0)  <= acca;
	 when accb_left =>
	   left(15 downto 8) <= "00000000";
		left(7 downto 0)  <= accb;
	 when dp_left =>
	   left(15 downto 8) <= "00000000";
		left(7 downto 0)  <= dp;
	 when accd_left =>
	   left(15 downto 8) <= acca;
		left(7 downto 0)  <= accb;
	 when md_left =>
	   left <= md;
	 when ix_left =>
	   left <= xreg;
	 when iy_left =>
	   left <= yreg;
	 when sp_left =>
	   left <= sp;
	 when up_left =>
	   left <= up;
	 when pc_left =>
	   left <= pc;
	 when others =>
--	 when ea_left =>
	   left <= ea;
    end case;
end process;

----------------------------------
--
-- Right Mux
--
----------------------------------

right_mux: process( right_ctrl, md, acca, accb, ea )
begin
  case right_ctrl is
	 when ea_right =>
	   right <= ea;
	 when zero_right =>
	   right <= "0000000000000000";
	 when one_right =>
	   right <= "0000000000000001";
	 when two_right =>
	   right <= "0000000000000010";
	 when acca_right =>
	   if acca(7) = '0' then
	     right <= "00000000" & acca(7 downto 0);
		else
		  right <= "11111111" & acca(7 downto 0);
		end if;
	 when accb_right =>
	   if accb(7) = '0' then
	     right <= "00000000" & accb(7 downto 0);
		else
		  right <= "11111111" & accb(7 downto 0);
		end if;
	 when accd_right =>
	   right <= acca & accb;
	 when md_sign5_right =>
	   if md(4) = '0' then
	     right <= "00000000000" & md(4 downto 0);
		else
		  right <= "11111111111" & md(4 downto 0);
		end if;
	 when md_sign8_right =>
	   if md(7) = '0' then
	     right <= "00000000" & md(7 downto 0);
		else
		  right <= "11111111" & md(7 downto 0);
		end if;
	 when others =>
--	 when md_right =>
	   right <= md;
    end case;
end process;

----------------------------------
--
-- Arithmetic Logic Unit
--
----------------------------------

alu: process( alu_ctrl, cc, left, right, out_alu, cc_out )
variable valid_lo, valid_hi : boolean;
variable carry_in : std_logic;
variable daa_reg : std_logic_vector(7 downto 0);
begin

  case alu_ctrl is
  	 when alu_adc | alu_sbc |
  	      alu_rol8 | alu_ror8 =>
	   carry_in := cc(CBIT);
    when alu_asr8 =>
	   carry_in := left(7);
  	 when others =>
	   carry_in := '0';
  end case;

  valid_lo := left(3 downto 0) <= 9;
  valid_hi := left(7 downto 4) <= 9;

  --
  -- CBIT HBIT VHI VLO DAA
  --    0    0   0   0 66 (!VHI : hi_nybble>8)
  --    0    0   0   1 60
  --    0    0   1   1 00
  --    0    0   1   0 06 ( VHI : hi_nybble<=8)
  --
  --    0    1   1   0 06
  --    0    1   1   1 06
  --    0    1   0   1 66
  --    0    1   0   0 66
  --
  --    1    1   0   0 66
  --    1    1   0   1 66
  --    1    1   1   1 66
  --    1    1   1   0 66
  --
  --    1    0   1   0 66
  --    1    0   1   1 60
  --    1    0   0   1 60
  --    1    0   0   0 66
  --
  -- 66 = (!VHI & !VLO) + (CBIT & HBIT) + (HBIT & !VHI) + (CBIT & !VLO)
  --    = (CBIT & (HBIT + !VLO)) + (!VHI & (HBIT + !VLO))
  --    = (!VLO & (CBIT + !VHI)) + (HBIT & (CBIT + !VHI))
  -- 60 = (CBIT & !HBIT & VLO) + (!HBIT & !VHI & VLO)
  --    = (!HBIT & VLO & (CBIT + !VHI))
  -- 06 = (!CBIT & VHI & (!VLO + VHI)
  -- 00 = (!CBIT & !HBIT & VHI & VLO)
  --
  if (cc(CBIT) = '0') then
    -- CBIT=0
    if( cc(HBIT) = '0' ) then
	   -- HBIT=0
		if valid_lo then
		  -- lo <= 9 (no overflow in low nybble)
		  if valid_hi then
		    -- hi <= 9 (no overflow in either low or high nybble)
		    daa_reg := "00000000";
		  else
		    -- hi > 9 (overflow in high nybble only)
		    daa_reg := "01100000";
		  end if;
		else
		  -- lo > 9 (overflow in low nybble)
		  --
		  -- since there is already an overflow in the low nybble
		  -- you need to make room in the high nybble for the low nybble carry
		  -- so compare the high nybble with 8 rather than 9
		  -- if the high nybble is 9 there will be an overflow on the high nybble
		  -- after the decimal adjust which means it will roll over to an invalid BCD digit
		  --
	     if( left(7 downto 4) <= 8 ) then
		    -- hi <= 8 (overflow in low nybble only)
		    daa_reg := "00000110";
		  else
		    -- hi > 8 (overflow in low and high nybble)
			 daa_reg := "01100110";
		  end if;
		end if;
    else
	   -- HBIT=1 (overflow in low nybble)
		if valid_hi then
		  -- hi <= 9 (overflow in low nybble only)
		  daa_reg := "00000110";
		else
		  -- hi > 9 (overflow in low and high nybble)
		  daa_reg := "01100110";
	   end if;
	 end if;
  else
    -- CBIT=1 (carry => overflow in high nybble)
    if ( cc(HBIT) = '0' )then
	   -- HBIT=0 (half carry clear => may or may not be an overflow in the low nybble)
		if valid_lo then
		  -- lo <=9  (overflow in high nybble only)
		  daa_reg := "01100000";
	   else
		  -- lo >9  (overflow in low and high nybble)
		  daa_reg := "01100110";
		end if;
 	 else
	   -- HBIT=1 (overflow in low and high nybble)
		daa_reg := "01100110";
	 end if;
  end if;

  case alu_ctrl is
  	 when alu_add8 | alu_inc |
  	      alu_add16 | alu_adc | alu_mul =>
		out_alu <= left + right + ("000000000000000" & carry_in);
  	 when alu_sub8 | alu_dec |
  	      alu_sub16 | alu_sbc =>
	   out_alu <= left - right - ("000000000000000" & carry_in);
    when alu_abx =>
	   out_alu <= left + ("00000000" & right(7 downto 0)) ;
  	 when alu_and =>
	   out_alu   <= left and right; 	-- and/bit
  	 when alu_ora =>
	   out_alu   <= left or right; 	-- or
  	 when alu_eor =>
	   out_alu   <= left xor right; 	-- eor/xor
  	 when alu_lsl16 | alu_asl8 | alu_rol8 =>
	   out_alu   <= left(14 downto 0) & carry_in; 	-- rol8/asl8/lsl16
  	 when alu_lsr16 =>
	   out_alu   <= carry_in & left(15 downto 1); 	-- lsr16
  	 when alu_lsr8 | alu_asr8 | alu_ror8 =>
	   out_alu   <= "00000000" & carry_in & left(7 downto 1); 	-- ror8/asr8/lsr8
  	 when alu_neg =>
	   out_alu   <= right - left; 	-- neg (right=0)
  	 when alu_com =>
	   out_alu   <= not left;
  	 when alu_clr | alu_ld8 | alu_ld16 | alu_lea =>
	   out_alu   <= right; 	         -- clr, ld
	 when alu_st8 | alu_st16 | alu_andcc | alu_orcc | alu_tfr =>
	   out_alu   <= left;
	 when alu_daa =>
	   out_alu   <= left + ("00000000" & daa_reg);
	 when alu_sex =>
	   if left(7) = '0' then
	      out_alu <= "00000000" & left(7 downto 0);
		else
		   out_alu <= "11111111" & left(7 downto 0);
		end if;
  	 when others =>
	   out_alu   <= left; -- nop
    end case;

	 --
	 -- carry bit
	 --
    case alu_ctrl is
  	 when alu_add8 | alu_adc  =>
      cc_out(CBIT) <= (left(7) and right(7)) or
		                (left(7) and not out_alu(7)) or
						   (right(7) and not out_alu(7));
  	 when alu_sub8 | alu_sbc =>
      cc_out(CBIT) <= ((not left(7)) and right(7)) or
		                ((not left(7)) and out_alu(7)) or
						         (right(7) and out_alu(7));
  	 when alu_add16  =>
      cc_out(CBIT) <= (left(15) and right(15)) or
		                (left(15) and not out_alu(15)) or
						   (right(15) and not out_alu(15));
  	 when alu_sub16 =>
      cc_out(CBIT) <= ((not left(15)) and right(15)) or
		                ((not left(15)) and out_alu(15)) or
						         (right(15) and out_alu(15));
	 when alu_ror8 | alu_lsr16 | alu_lsr8 | alu_asr8 =>
	   cc_out(CBIT) <= left(0);
	 when alu_rol8 | alu_asl8 =>
	   cc_out(CBIT) <= left(7);
	 when alu_lsl16 =>
	   cc_out(CBIT) <= left(15);
	 when alu_com =>
	   cc_out(CBIT) <= '1';
	 when alu_neg | alu_clr =>
	   cc_out(CBIT) <= out_alu(7) or out_alu(6) or out_alu(5) or out_alu(4) or
		                out_alu(3) or out_alu(2) or out_alu(1) or out_alu(0);
    when alu_mul =>
		cc_out(CBIT) <= out_alu(7);
    when alu_daa =>
	   if ( daa_reg(7 downto 4) = "0110" ) then
		  cc_out(CBIT) <= '1';
		else
		  cc_out(CBIT) <= '0';
	   end if;
  	 when alu_andcc =>
      cc_out(CBIT) <= left(CBIT) and cc(CBIT);
  	 when alu_orcc =>
      cc_out(CBIT) <= left(CBIT) or cc(CBIT);
  	 when alu_tfr =>
      cc_out(CBIT) <= left(CBIT);
  	 when others =>
      cc_out(CBIT) <= cc(CBIT);
    end case;
	 --
	 -- Zero flag
	 --
    case alu_ctrl is
  	 when alu_add8 | alu_sub8 |
	      alu_adc | alu_sbc |
  	      alu_and | alu_ora | alu_eor |
  	      alu_inc | alu_dec |
			alu_neg | alu_com | alu_clr |
			alu_rol8 | alu_ror8 | alu_asr8 | alu_asl8 | alu_lsr8 |
		   alu_ld8  | alu_st8 | alu_sex | alu_daa =>
      cc_out(ZBIT) <= not( out_alu(7)  or out_alu(6)  or out_alu(5)  or out_alu(4)  or
	                        out_alu(3)  or out_alu(2)  or out_alu(1)  or out_alu(0) );
  	 when alu_add16 | alu_sub16 | alu_mul |
  	      alu_lsl16 | alu_lsr16 |
		   alu_ld16  | alu_st16 | alu_lea =>
      cc_out(ZBIT) <= not( out_alu(15) or out_alu(14) or out_alu(13) or out_alu(12) or
	                        out_alu(11) or out_alu(10) or out_alu(9)  or out_alu(8)  or
  	                        out_alu(7)  or out_alu(6)  or out_alu(5)  or out_alu(4)  or
	                        out_alu(3)  or out_alu(2)  or out_alu(1)  or out_alu(0) );
  	 when alu_andcc =>
      cc_out(ZBIT) <= left(ZBIT) and cc(ZBIT);
  	 when alu_orcc =>
      cc_out(ZBIT) <= left(ZBIT) or cc(ZBIT);
  	 when alu_tfr =>
      cc_out(ZBIT) <= left(ZBIT);
  	 when others =>
      cc_out(ZBIT) <= cc(ZBIT);
    end case;

    --
	 -- negative flag
	 --
    case alu_ctrl is
  	 when alu_add8 | alu_sub8 |
	      alu_adc | alu_sbc |
	      alu_and | alu_ora | alu_eor |
  	      alu_rol8 | alu_ror8 | alu_asr8 | alu_asl8 | alu_lsr8 |
  	      alu_inc | alu_dec | alu_neg | alu_com | alu_clr |
			alu_ld8  | alu_st8 | alu_sex | alu_daa =>
      cc_out(NBIT) <= out_alu(7);
	 when alu_add16 | alu_sub16 |
	      alu_lsl16 | alu_lsr16 |
			alu_ld16 | alu_st16 =>
		cc_out(NBIT) <= out_alu(15);
  	 when alu_andcc =>
      cc_out(NBIT) <= left(NBIT) and cc(NBIT);
  	 when alu_orcc =>
      cc_out(NBIT) <= left(NBIT) or cc(NBIT);
  	 when alu_tfr =>
      cc_out(NBIT) <= left(NBIT);
  	 when others =>
      cc_out(NBIT) <= cc(NBIT);
    end case;

    --
	 -- Interrupt mask flag
    --
    case alu_ctrl is
  	 when alu_andcc =>
      cc_out(IBIT) <= left(IBIT) and cc(IBIT);
  	 when alu_orcc =>
      cc_out(IBIT) <= left(IBIT) or cc(IBIT);
  	 when alu_tfr =>
      cc_out(IBIT) <= left(IBIT);
    when alu_seif | alu_sei =>
	   cc_out(IBIT) <= '1';
  	 when others =>
		cc_out(IBIT) <= cc(IBIT);             -- interrupt mask
    end case;

    --
    -- Half Carry flag
	 --
    case alu_ctrl is
  	 when alu_add8 | alu_adc =>
      cc_out(HBIT) <= (left(3) and right(3)) or
                     (right(3) and not out_alu(3)) or
                      (left(3) and not out_alu(3));
  	 when alu_andcc =>
      cc_out(HBIT) <= left(HBIT) and cc(HBIT);
  	 when alu_orcc =>
      cc_out(HBIT) <= left(HBIT) or cc(HBIT);
  	 when alu_tfr =>
      cc_out(HBIT) <= left(HBIT);
  	 when others =>
		cc_out(HBIT) <= cc(HBIT);
    end case;

    --
    -- Overflow flag
	 --
    case alu_ctrl is
  	 when alu_add8 | alu_adc =>
      cc_out(VBIT) <= (left(7)  and      right(7)  and (not out_alu(7))) or
                 ((not left(7)) and (not right(7)) and      out_alu(7));
	 when alu_sub8 | alu_sbc =>
      cc_out(VBIT) <= (left(7)  and (not right(7)) and (not out_alu(7))) or
                 ((not left(7)) and      right(7)  and      out_alu(7));
  	 when alu_add16 =>
      cc_out(VBIT) <= (left(15)  and      right(15)  and (not out_alu(15))) or
                 ((not left(15)) and (not right(15)) and      out_alu(15));
	 when alu_sub16 =>
      cc_out(VBIT) <= (left(15)  and (not right(15)) and (not out_alu(15))) or
                 ((not left(15)) and      right(15) and       out_alu(15));
	 when alu_inc =>
	   cc_out(VBIT) <= ((not left(7)) and left(6) and left(5) and left(4) and
		                      left(3)  and left(2) and left(1) and left(0));
	 when alu_dec | alu_neg =>
	   cc_out(VBIT) <= (left(7)  and (not left(6)) and (not left(5)) and (not left(4)) and
		            (not left(3)) and (not left(2)) and (not left(1)) and (not left(0)));
-- 6809 Programming reference manual says
-- V not affected by ASR, LSR and ROR
-- This is different to the 6800
-- John Kent 6th June 2006
--	 when alu_asr8 =>
--	   cc_out(VBIT) <= left(0) xor left(7);
--	 when alu_lsr8 | alu_lsr16 =>
--	   cc_out(VBIT) <= left(0);
--	 when alu_ror8 =>
--      cc_out(VBIT) <= left(0) xor cc(CBIT);
    when alu_lsl16 =>
      cc_out(VBIT) <= left(15) xor left(14);
	 when alu_rol8 | alu_asl8 =>
      cc_out(VBIT) <= left(7) xor left(6);
--
-- 11th July 2006 - John Kent
-- What DAA does with V is anyones guess
-- It is undefined in the 6809 programming manual
--
	 when alu_daa =>
      cc_out(VBIT) <= left(7) xor out_alu(7) xor cc(CBIT);
-- CLR resets V Bit
-- John Kent 6th June 2006
	 when alu_and | alu_ora | alu_eor | alu_com | alu_clr |
	      alu_st8 | alu_st16 | alu_ld8 | alu_ld16 | alu_sex =>
      cc_out(VBIT) <= '0';
  	 when alu_andcc =>
      cc_out(VBIT) <= left(VBIT) and cc(VBIT);
  	 when alu_orcc =>
      cc_out(VBIT) <= left(VBIT) or cc(VBIT);
  	 when alu_tfr =>
      cc_out(VBIT) <= left(VBIT);
  	 when others =>
		cc_out(VBIT) <= cc(VBIT);
    end case;

	 case alu_ctrl is
  	 when alu_andcc =>
      cc_out(FBIT) <= left(FBIT) and cc(FBIT);
  	 when alu_orcc =>
      cc_out(FBIT) <= left(FBIT) or cc(FBIT);
  	 when alu_tfr =>
      cc_out(FBIT) <= left(FBIT);
    when alu_seif =>
	   cc_out(FBIT) <= '1';
	 when others =>
      cc_out(FBIT) <= cc(FBIT);
	 end case;

	 case alu_ctrl is
  	 when alu_andcc =>
      cc_out(EBIT) <= left(EBIT) and cc(EBIT);
  	 when alu_orcc =>
      cc_out(EBIT) <= left(EBIT) or cc(EBIT);
  	 when alu_tfr =>
      cc_out(EBIT) <= left(EBIT);
    when alu_see =>
	   cc_out(EBIT) <= '1';
    when alu_cle =>
	   cc_out(EBIT) <= '0';
	 when others =>
	   cc_out(EBIT) <= cc(EBIT);
	 end case;
end process;

------------------------------------
--
-- state sequencer
--
------------------------------------
process( state, saved_state,
         op_code, pre_code,
			cc, ea, md, iv, fic, halt,
         nmi_req, firq, irq, lic )
variable cond_true : boolean;  -- variable used to evaluate coditional branches
begin
  cond_true  := (1=1);
  ba         <= '0';
  bs         <= '0';
  lic        <= '0';
  opfetch    <= '0';
  iv_ctrl    <= latch_iv;
  -- Registers preserved
  cc_ctrl    <= latch_cc;
  acca_ctrl  <= latch_acca;
  accb_ctrl  <= latch_accb;
  dp_ctrl    <= latch_dp;
  ix_ctrl    <= latch_ix;
  iy_ctrl    <= latch_iy;
  up_ctrl    <= latch_up;
  sp_ctrl    <= latch_sp;
  pc_ctrl    <= latch_pc;
  md_ctrl    <= latch_md;
  ea_ctrl    <= latch_ea;
  op_ctrl    <= latch_op;
  pre_ctrl   <= latch_pre;
  -- ALU Idle
  left_ctrl  <= pc_left;
  right_ctrl <= zero_right;
  alu_ctrl   <= alu_nop;
  -- Bus idle
  addr_ctrl  <= idle_ad;
  dout_ctrl  <= cc_dout;
  -- Next State Fetch
  st_ctrl      <= idle_st;
  return_state <= fetch_state;
  next_state   <= fetch_state;

  case state is
  when reset_state =>        --  released from reset
    -- reset the registers
    iv_ctrl    <= reset_iv;
    op_ctrl    <= reset_op;
    pre_ctrl   <= reset_pre;
    cc_ctrl    <= reset_cc;
    acca_ctrl  <= reset_acca;
    accb_ctrl  <= reset_accb;
    dp_ctrl    <= reset_dp;
    ix_ctrl    <= reset_ix;
    iy_ctrl    <= reset_iy;
    up_ctrl    <= reset_up;
    sp_ctrl    <= reset_sp;
    pc_ctrl    <= reset_pc;
    ea_ctrl    <= reset_ea;
    md_ctrl    <= reset_md;
    st_ctrl    <= reset_st;
    next_state <= vect_hi_state;

  --
  -- Jump via interrupt vector
  -- iv holds interrupt type
  -- fetch PC hi from vector location
  --
  when vect_hi_state =>
    -- fetch pc low interrupt vector
    pc_ctrl    <= pull_hi_pc;
    addr_ctrl  <= int_hi_ad;
    bs         <= '1';
    next_state <= vect_lo_state;

  --
  -- jump via interrupt vector
  -- iv holds vector type
  -- fetch PC lo from vector location
  --
  when vect_lo_state =>
    -- fetch the vector low byte
    pc_ctrl    <= pull_lo_pc;
    addr_ctrl  <= int_lo_ad;
    bs         <= '1';
    next_state <= fetch_state;

  when vect_idle_state =>
    --
    -- Last Instruction Cycle for SWI, SWI2 & SWI3
    --
    if op_code = "00111111" then
      lic      <= '1';
    end if;
    next_state <= fetch_state;

  --
  -- Here to fetch an instruction
  -- PC points to opcode
  --
  when fetch_state =>
    -- fetch the op code
    opfetch    <= '1';
    op_ctrl    <= fetch_op;
    pre_ctrl   <= fetch_pre;
    ea_ctrl    <= reset_ea;
    -- Fetch op code
    addr_ctrl  <= fetch_ad;
    -- Advance the PC to fetch next instruction byte
    pc_ctrl    <= incr_pc;
    next_state <= decode1_state;

  --
  -- Here to decode instruction
  -- and fetch next byte of intruction
  -- whether it be necessary or not
  --
  when decode1_state =>
	-- fetch first byte of address or immediate data
    ea_ctrl    <= fetch_first_ea;
    md_ctrl    <= fetch_first_md;
    addr_ctrl  <= fetch_ad;
    case op_code(7 downto 4) is
    --
    -- direct single op (2 bytes)
    -- 6809 => 6 cycles
    -- cpu09 => 5 cycles
    -- 1 op=(pc) / pc=pc+1
    -- 2 ea_hi=dp / ea_lo=(pc) / pc=pc+1
    -- 3 md_lo=(ea) / pc=pc
    -- 4 alu_left=md / md=alu_out / pc=pc
    -- 5 (ea)=md_lo / pc=pc
    --
    -- Exception is JMP
    -- 6809 => 3 cycles
    -- cpu09 => 3 cycles
    -- 1 op=(pc) / pc=pc+1
    -- 2 ea_hi=dp / ea_lo=(pc) / pc=pc+1
    -- 3 pc=ea
               --
	when "0000" =>
      -- advance the PC
      pc_ctrl    <= incr_pc;

      case op_code(3 downto 0) is
      when "1110" => -- jmp
        next_state <= jmp_state;

      when "1111" => -- clr
        next_state <= single_op_exec_state;

      when others =>
        next_state <= single_op_read_state;

      end case;

    -- acca / accb inherent instructions
	when "0001" =>
      case op_code(3 downto 0) is
      --
      -- Page2 pre byte
      -- pre=(pc) / pc=pc+1
      -- op=(pc) / pc=pc+1
      --
      when "0000" => -- page2
        opfetch    <= '1';
        op_ctrl    <= fetch_op;
        -- advance pc
        pc_ctrl    <= incr_pc;
        next_state <= decode2_state;

      --
      -- Page3 pre byte
      -- pre=(pc) / pc=pc+1
      -- op=(pc) / pc=pc+1
      --
      when "0001" => -- page3
        opfetch    <= '1';
        op_ctrl    <= fetch_op;
        -- advance pc
        pc_ctrl    <= incr_pc;
        next_state <= decode3_state;

      --
      -- nop - No operation ( 1 byte )
      -- 6809 => 2 cycles
      -- cpu09 => 2 cycles
      -- 1 op=(pc) / pc=pc+1
      -- 2 decode
      --
      when "0010" => -- nop
        lic          <= '1';
        next_state   <= fetch_state;

      --
      -- sync - halt execution until an interrupt is received
      -- interrupt may be NMI, IRQ or FIRQ
      -- program execution continues if the
      -- interrupt is asserted for 3 clock cycles
      -- note that registers are not pushed onto the stack
      -- CPU09 => Interrupts need only be asserted for one clock cycle
      --
      when "0011" => -- sync
        next_state   <= sync_state;

      --
      -- lbra -- long branch (3 bytes)
      -- 6809 => 5 cycles
      -- cpu09 => 4 cycles
      -- 1 op=(pc) / pc=pc+1
      -- 2 md_hi=sign(pc) / md_lo=(pc) / pc=pc+1
      -- 3 md_hi=md_lo / md_lo=(pc) / pc=pc+1
      -- 4 pc=pc+md
      --
      when "0110" =>
        -- increment the pc
        pc_ctrl    <= incr_pc;
        next_state <= lbranch_state;

      --
      -- lbsr - long branch to subroutine (3 bytes)
      -- 6809 => 9 cycles
      -- cpu09 => 6 cycles
      -- 1 op=(pc) /pc=pc+1
      -- 2 md_hi=sign(pc) / md_lo=(pc) / pc=pc+1 / sp=sp-1
      -- 3 md_hi=md_lo / md_lo=(pc) / pc=pc+1
      -- 4 (sp)= pc_lo / sp=sp-1 / pc=pc
      -- 5 (sp)=pc_hi / pc=pc
      -- 6 pc=pc+md
      --
      when "0111" =>
        -- pre decrement sp
        left_ctrl  <= sp_left;
        right_ctrl <= one_right;
        alu_ctrl   <= alu_sub16;
        sp_ctrl    <= load_sp;
        -- increment the pc
        pc_ctrl    <= incr_pc;
        next_state <= lbranch_state;

      --
      -- Decimal Adjust Accumulator
      --
      when "1001" => -- daa
        left_ctrl  <= acca_left;
        right_ctrl <= accb_right;
        alu_ctrl   <= alu_daa;
        cc_ctrl    <= load_cc;
        acca_ctrl  <= load_acca;
        lic        <= '1';
        next_state <= fetch_state;

      --
      -- OR Condition Codes
      --
      when "1010" => -- orcc
        -- increment the pc
        pc_ctrl      <= incr_pc;
        next_state   <= orcc_state;

      --
      -- AND Condition Codes
      --
      when "1100" => -- andcc
        -- increment the pc
        pc_ctrl      <= incr_pc;
        next_state   <= andcc_state;

      --
      -- Sign Extend
      --
      when "1101" => -- sex
        left_ctrl  <= accb_left;
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_sex;
        cc_ctrl    <= load_cc;
        acca_ctrl  <= load_hi_acca;
        lic        <= '1';
        next_state <= fetch_state;

      --
      -- Exchange Registers
      --
      when "1110" => -- exg
        -- increment the pc
        pc_ctrl    <= incr_pc;
        next_state <= exg_state;

      --
      -- Transfer Registers
      --
      when "1111" => -- tfr
        -- increment the pc
        pc_ctrl      <= incr_pc;
        next_state   <= tfr_state;

      when others =>
        -- increment the pc
        pc_ctrl    <= incr_pc;
        lic        <= '1';
        next_state <= fetch_state;
      end case;

    --
    -- Short branch conditional
    -- 6809 => always 3 cycles
    -- cpu09 => always = 3 cycles
    -- 1 op=(pc) / pc=pc+1
    -- 2 md_hi=sign(pc) / md_lo=(pc) / pc=pc+1 / test cc
    -- 3 if cc tru pc=pc+md else pc=pc
    --
    when "0010" => -- branch conditional
      -- increment the pc
      pc_ctrl    <= incr_pc;
      next_state <= sbranch_state;

    --
    -- Single byte stack operators
    -- Do not advance PC
    --
    when "0011" =>
      --
      -- lea - load effective address (2+ bytes)
      -- 6809 => 4 cycles + addressing mode
      -- cpu09 => 4 cycles + addressing mode
      -- 1 op=(pc) / pc=pc+1
      -- 2 md_lo=(pc) / pc=pc+1
      -- 3 calculate ea
      -- 4 ix/iy/sp/up = ea
      --
      case op_code(3 downto 0) is
	   when "0000" |  -- leax
           "0001" |  -- leay
           "0010" |  -- leas
           "0011" => -- leau
        -- advance PC
        pc_ctrl      <= incr_pc;
        st_ctrl      <= push_st;
        return_state <= lea_state;
        next_state   <= indexed_state;

      --
      -- pshs - push registers onto sp stack
      -- 6809 => 5 cycles + registers
      -- cpu09 => 3 cycles + registers
      --  1 op=(pc) / pc=pc+1
      --  2 ea_lo=(pc) / pc=pc+1
      --  3 if ea(7 downto 0) != "00000000" then sp=sp-1
      --  4 if ea(7) = 1 (sp)=pcl, sp=sp-1
      --  5 if ea(7) = 1 (sp)=pch
      --    if ea(6 downto 0) != "0000000" then sp=sp-1
      --  6 if ea(6) = 1 (sp)=upl, sp=sp-1
      --  7 if ea(6) = 1 (sp)=uph
      --    if ea(5 downto 0) != "000000" then sp=sp-1
      --  8 if ea(5) = 1 (sp)=iyl, sp=sp-1
      --  9 if ea(5) = 1 (sp)=iyh
      --    if ea(4 downto 0) != "00000" then sp=sp-1
      -- 10 if ea(4) = 1 (sp)=ixl, sp=sp-1
      -- 11 if ea(4) = 1 (sp)=ixh
      --    if ea(3 downto 0) != "0000" then sp=sp-1
      -- 12 if ea(3) = 1 (sp)=dp
      --    if ea(2 downto 0) != "000" then sp=sp-1
      -- 13 if ea(2) = 1 (sp)=accb
      --    if ea(1 downto 0) != "00" then sp=sp-1
      -- 14 if ea(1) = 1 (sp)=acca
      --    if ea(0 downto 0) != "0" then sp=sp-1
      -- 15 if ea(0) = 1 (sp)=cc
      --
      when "0100" => -- pshs
        -- advance PC
        pc_ctrl    <= incr_pc;
        next_state <= pshs_state;

      --
      -- puls - pull registers of sp stack
      -- 6809 => 5 cycles + registers
      -- cpu09 => 3 cycles + registers
      --
      when "0101" => -- puls
        -- advance PC
        pc_ctrl    <= incr_pc;
        next_state <= puls_state;

      --
      -- pshu - push registers onto up stack
      -- 6809 => 5 cycles + registers
      -- cpu09 => 3 cycles + registers
      --
      when "0110" => -- pshu
        -- advance PC
        pc_ctrl    <= incr_pc;
        next_state <= pshu_state;

      --
      -- pulu - pull registers of up stack
      -- 6809 => 5 cycles + registers
      -- cpu09 => 3 cycles + registers
      --
      when "0111" => -- pulu
        -- advance PC
        pc_ctrl    <= incr_pc;
        next_state <= pulu_state;

      --
      -- rts - return from subroutine
      -- 6809 => 5 cycles
      -- cpu09 => 4 cycles
      -- 1 op=(pc) / pc=pc+1
      -- 2 decode op
      -- 3 pc_hi = (sp) / sp=sp+1
      -- 4 pc_lo = (sp) / sp=sp+1
      --
      when "1001" =>
  		  next_state   <= pull_return_hi_state;

      --
      -- ADD accb to index register
      -- *** Note: this is an unsigned addition.
      --           does not affect any condition codes
      -- 6809 => 3 cycles
      -- cpu09 => 2 cycles
      -- 1 op=(pc) / pc=pc+1
      -- 2 alu_left=ix / alu_right=accb / ix=alu_out / pc=pc
      --
      when "1010" => -- abx
        lic          <= '1';
        left_ctrl    <= ix_left;
        right_ctrl   <= accb_right;
        alu_ctrl     <= alu_abx;
        ix_ctrl      <= load_ix;
        next_state   <= fetch_state;

      --
      -- Return From Interrupt
      --
      when "1011" => -- rti
        next_state   <= rti_cc_state;

      --
      -- CWAI
      --
      when "1100" => -- cwai #$<cc_mask>
        -- pre decrement sp
        left_ctrl    <= sp_left;
        right_ctrl   <= one_right;
        alu_ctrl     <= alu_sub16;
        sp_ctrl      <= load_sp;
        -- increment pc
        pc_ctrl      <= incr_pc;
        next_state   <= cwai_state;

      --
      -- MUL Multiply
      --
      when "1101" => -- mul
        next_state   <= mul_state;

      --
      -- SWI Software Interrupt
      --
      when "1111" => -- swi
        -- predecrement SP
        left_ctrl    <= sp_left;
        right_ctrl   <= one_right;
        alu_ctrl     <= alu_sub16;
        sp_ctrl      <= load_sp;
        iv_ctrl      <= swi_iv;
        st_ctrl      <= push_st;
        return_state <= int_swimask_state;
        next_state   <= int_entire_state;

      when others =>
        lic          <= '1';
        next_state   <= fetch_state;

      end case;
				 --
    -- Accumulator A Single operand
    -- source = acca, dest = acca
    -- Do not advance PC
    -- Typically 2 cycles 1 bytes
    -- 1 opcode fetch
    -- 2 post byte fetch / instruction decode
    -- Note that there is no post byte
    -- so do not advance PC in decode cycle
    -- Re-run opcode fetch cycle after decode
    --
    when "0100" => -- acca single op
      left_ctrl  <= acca_left;
      case op_code(3 downto 0) is

      when "0000" => -- neg
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_neg;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "0011" => -- com
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_com;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "0100" => -- lsr
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_lsr8;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

	   when "0110" => -- ror
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_ror8;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "0111" => -- asr
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_asr8;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "1000" => -- asl
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_asl8;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "1001" => -- rol
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_rol8;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "1010" => -- dec
        right_ctrl <= one_right;
        alu_ctrl   <= alu_dec;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "1011" => -- undefined
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        acca_ctrl  <= latch_acca;
        cc_ctrl    <= latch_cc;

      when "1100" => -- inc
        right_ctrl <= one_right;
        alu_ctrl   <= alu_inc;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when "1101" => -- tst
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_st8;
        acca_ctrl  <= latch_acca;
        cc_ctrl    <= load_cc;

      when "1110" => -- jmp (not defined)
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        acca_ctrl  <= latch_acca;
        cc_ctrl    <= latch_cc;

      when "1111" => -- clr
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_clr;
        acca_ctrl  <= load_acca;
        cc_ctrl    <= load_cc;

      when others =>
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        acca_ctrl  <= latch_acca;
        cc_ctrl    <= latch_cc;

      end case;
      lic        <= '1';
      next_state <= fetch_state;

      --
      -- Single Operand accb
      -- source = accb, dest = accb
      -- Typically 2 cycles 1 bytes
      -- 1 opcode fetch
      -- 2 post byte fetch / instruction decode
      -- Note that there is no post byte
      -- so do not advance PC in decode cycle
      -- Re-run opcode fetch cycle after decode
      --
    when "0101" =>
      left_ctrl  <= accb_left;
      case op_code(3 downto 0) is
      when "0000" => -- neg
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_neg;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "0011" => -- com
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_com;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "0100" => -- lsr
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_lsr8;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "0110" => -- ror
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_ror8;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "0111" => -- asr
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_asr8;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "1000" => -- asl
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_asl8;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "1001" => -- rol
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_rol8;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "1010" => -- dec
        right_ctrl <= one_right;
        alu_ctrl   <= alu_dec;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "1011" => -- undefined
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        accb_ctrl  <= latch_accb;
        cc_ctrl    <= latch_cc;

      when "1100" => -- inc
        right_ctrl <= one_right;
        alu_ctrl   <= alu_inc;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when "1101" => -- tst
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_st8;
        accb_ctrl  <= latch_accb;
        cc_ctrl    <= load_cc;

      when "1110" => -- jmp (undefined)
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        accb_ctrl  <= latch_accb;
        cc_ctrl    <= latch_cc;

      when "1111" => -- clr
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_clr;
        accb_ctrl  <= load_accb;
        cc_ctrl    <= load_cc;

      when others =>
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        accb_ctrl  <= latch_accb;
        cc_ctrl    <= latch_cc;
      end case;
      lic          <= '1';
      next_state   <= fetch_state;

    --
    -- Single operand indexed
    -- Two byte instruction so advance PC
    -- EA should hold index offset
    --
    when "0110" => -- indexed single op
      -- increment the pc
      pc_ctrl    <= incr_pc;
      st_ctrl    <= push_st;

      case op_code(3 downto 0) is
      when "1110" => -- jmp
        return_state <= jmp_state;

      when "1111" => -- clr
        return_state <= single_op_exec_state;

      when others =>
        return_state <= single_op_read_state;

      end case;
      next_state <= indexed_state;

    --
    -- Single operand extended addressing
    -- three byte instruction so advance the PC
    -- Low order EA holds high order address
    --
    when "0111" => -- extended single op
      -- increment PC
      pc_ctrl    <= incr_pc;
      st_ctrl    <= push_st;

      case op_code(3 downto 0) is
      when "1110" => -- jmp
        return_state <= jmp_state;

      when "1111" => -- clr
        return_state <= single_op_exec_state;

      when others =>
        return_state <= single_op_read_state;

      end case;
      next_state <= extended_state;

    when "1000" => -- acca immediate
      -- increment the pc
      pc_ctrl    <= incr_pc;

      case op_code(3 downto 0) is
      when "0011" | -- subd #
           "1100" | -- cmpx #
           "1110" => -- ldx #
        next_state   <= imm16_state;

      --
      -- bsr offset - Branch to subroutine (2 bytes)
      -- 6809 => 7 cycles
      -- cpu09 => 5 cycles
      -- 1 op=(pc) / pc=pc+1
      -- 2 md_hi=sign(pc) / md_lo=(pc) / sp=sp-1 / pc=pc+1
      -- 3 (sp)=pc_lo / sp=sp-1
      -- 4 (sp)=pc_hi
      -- 5 pc=pc+md
      --
      when "1101" => -- bsr
        -- pre decrement SP
        left_ctrl  <= sp_left;
        right_ctrl <= one_right;
        alu_ctrl   <= alu_sub16;
        sp_ctrl    <= load_sp;
	     --
	     st_ctrl      <= push_st;
        return_state <= sbranch_state;
        next_state   <= push_return_lo_state;

      when others =>
        lic          <= '1';
        next_state   <= fetch_state;

      end case;

    when "1001" => -- acca direct
      -- increment the pc
      pc_ctrl    <= incr_pc;
      case op_code(3 downto 0) is
      when "0011" | -- subd
           "1100" | -- cmpx
           "1110" => -- ldx
        next_state   <= dual_op_read16_state;

      when "0111" =>  -- sta direct
        next_state <= dual_op_write8_state;

	   --
      -- jsr direct - Jump to subroutine in direct page (2 bytes)
      -- 6809 => 7 cycles
      -- cpu09 => 5 cycles
      -- 1 op=(pc) / pc=pc+1
      -- 2 ea_hi=0 / ea_lo=(pc) / sp=sp-1 / pc=pc+1
      -- 3 (sp)=pc_lo / sp=sp-1
      -- 4 (sp)=pc_hi
      -- 5 pc=ea
      --
      when "1101" => -- jsr direct
        -- pre decrement sp
        left_ctrl  <= sp_left;
        right_ctrl <= one_right;
        alu_ctrl   <= alu_sub16;
        sp_ctrl    <= load_sp;
        --
        st_ctrl      <= push_st;
        return_state <= jmp_state;
        next_state   <= push_return_lo_state;


      when "1111" => -- stx direct
        -- idle ALU
        left_ctrl  <= ix_left;
        right_ctrl <= zero_right;
        alu_ctrl   <= alu_nop;
        cc_ctrl    <= latch_cc;
        sp_ctrl    <= latch_sp;
        next_state <= dual_op_write16_state;

      when others =>
        next_state   <= dual_op_read8_state;

      end case;

    when "1010" => -- acca indexed
      -- increment the pc
      pc_ctrl    <= incr_pc;
      case op_code(3 downto 0) is
      when "0011" | -- subd
           "1100" | -- cmpx
           "1110" => -- ldx
        st_ctrl      <= push_st;
        return_state <= dual_op_read16_state;
        next_state   <= indexed_state;

      when "0111" =>  -- staa ,x
        st_ctrl      <= push_st;
        return_state <= dual_op_write8_state;
        next_state   <= indexed_state;

      when "1101" => -- jsr ,x
        -- DO NOT pre decrement SP
        st_ctrl      <= push_st;
        return_state <= jsr_state;
        next_state   <= indexed_state;

      when "1111" => -- stx ,x
        st_ctrl      <= push_st;
        return_state <= dual_op_write16_state;
        next_state   <= indexed_state;

      when others =>
        st_ctrl      <= push_st;
        return_state <= dual_op_read8_state;
        next_state   <= indexed_state;

      end case;

   when "1011" => -- acca extended
     -- increment the pc
     pc_ctrl    <= incr_pc;
     case op_code(3 downto 0) is
     when "0011" | -- subd
          "1100" | -- cmpx
          "1110" => -- ldx
       st_ctrl      <= push_st;
       return_state <= dual_op_read16_state;
       next_state   <= extended_state;

     when "0111" =>  -- staa >
       st_ctrl      <= push_st;
       return_state <= dual_op_write8_state;
       next_state   <= extended_state;

     when "1101" => -- jsr >extended
     -- DO NOT pre decrement sp
       st_ctrl      <= push_st;
       return_state <= jsr_state;
       next_state   <= extended_state;

     when "1111" => -- stx >
       st_ctrl      <= push_st;
       return_state <= dual_op_write16_state;
       next_state   <= extended_state;

     when others =>
       st_ctrl      <= push_st;
       return_state <= dual_op_read8_state;
       next_state   <= extended_state;

     end case;

   when "1100" => -- accb immediate
     -- increment the pc
     pc_ctrl    <= incr_pc;
     case op_code(3 downto 0) is
     when "0011" | -- addd #
          "1100" | -- ldd #
          "1110" => -- ldu #
       next_state   <= imm16_state;

     when others =>
       lic          <= '1';
       next_state   <= fetch_state;

     end case;

   when "1101" => -- accb direct
     -- increment the pc
     pc_ctrl    <= incr_pc;
     case op_code(3 downto 0) is
     when "0011" | -- addd
          "1100" | -- ldd
          "1110" => -- ldu
       next_state   <= dual_op_read16_state;

     when "0111" =>  -- stab direct
       next_state   <= dual_op_write8_state;

     when "1101" =>  -- std direct
       next_state   <= dual_op_write16_state;

     when "1111" => -- stu direct
       next_state   <= dual_op_write16_state;

     when others =>
       next_state   <= dual_op_read8_state;

     end case;

   when "1110" => -- accb indexed
     -- increment the pc
     pc_ctrl    <= incr_pc;
     case op_code(3 downto 0) is
     when "0011" | -- addd
          "1100" | -- ldd
          "1110" => -- ldu
       st_ctrl      <= push_st;
       return_state <= dual_op_read16_state;
       next_state   <= indexed_state;

     when "0111" =>  -- stab indexed
       st_ctrl      <= push_st;
       return_state <= dual_op_write8_state;
       next_state   <= indexed_state;

     when "1101" =>  -- std indexed
       st_ctrl      <= push_st;
       return_state <= dual_op_write16_state;
       next_state   <= indexed_state;

     when "1111" => -- stu indexed
       st_ctrl      <= push_st;
       return_state <= dual_op_write16_state;
       next_state   <= indexed_state;

     when others =>
       st_ctrl      <= push_st;
       return_state <= dual_op_read8_state;
       next_state   <= indexed_state;

     end case;

   when "1111" => -- accb extended
     -- increment the pc
     pc_ctrl    <= incr_pc;
     case op_code(3 downto 0) is
     when "0011" | -- addd
		    "1100" | -- ldd
	       "1110" => -- ldu
	    st_ctrl      <= push_st;
	    return_state <= dual_op_read16_state;
       next_state   <= extended_state;

     when "0111" =>  -- stab extended
	    st_ctrl      <= push_st;
	    return_state <= dual_op_write8_state;
       next_state   <= extended_state;

     when "1101" =>  -- std extended
       st_ctrl      <= push_st;
	    return_state <= dual_op_write16_state;
	    next_state   <= extended_state;

	  when "1111" => -- stu  extended
	    st_ctrl      <= push_st;
	    return_state <= dual_op_write16_state;
	    next_state   <= extended_state;

	  when others =>
	    st_ctrl      <= push_st;
	    return_state <= dual_op_read8_state;
	    next_state   <= extended_state;
     end case;
	--
   -- not sure why I need this
   --
   when others =>
	  lic <= '1';
	  next_state <= fetch_state;
	end case;

			 --
			 -- Here to decode prefix 2 instruction
			 -- and fetch next byte of intruction
			 -- whether it be necessary or not
			 --
          when decode2_state =>
				 -- fetch first byte of address or immediate data
             ea_ctrl    <= fetch_first_ea;
				 md_ctrl    <= fetch_first_md;
             addr_ctrl  <= fetch_ad;
			    case op_code(7 downto 4) is
				 --
				 -- lbcc -- long branch conditional
				 -- 6809 => branch 6 cycles, no branch 5 cycles
				 -- cpu09 => always 5 cycles
				 -- 1 pre=(pc) / pc=pc+1
				 -- 2 op=(pc) / pc=pc+1
				 -- 3 md_hi=sign(pc) / md_lo=(pc) / pc=pc+1
             -- 4 md_hi=md_lo / md_lo=(pc) / pc=pc+1
				 -- 5 if cond pc=pc+md else pc=pc
				 --
	          when "0010" =>
					-- increment the pc
               pc_ctrl    <= incr_pc;
					next_state <= lbranch_state;

				 --
				 -- Single byte stack operators
				 -- Do not advance PC
				 --
	          when "0011" =>
	            case op_code(3 downto 0) is
		         when "1111" => -- swi 2
					   -- predecrement sp
		            left_ctrl    <= sp_left;
		            right_ctrl   <= one_right;
						alu_ctrl     <= alu_sub16;
						sp_ctrl      <= load_sp;
						iv_ctrl      <= swi2_iv;
						st_ctrl      <= push_st;
						return_state <= vect_hi_state;
						next_state   <= int_entire_state;

		         when others =>
                 lic          <= '1';
					  next_state   <= fetch_state;
		         end case;

	          when "1000" => -- acca immediate
				   -- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpd #
					     "1100" | -- cmpy #
					     "1110" => -- ldy #
					  next_state   <= imm16_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

	          when "1001" => -- acca direct
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpd <
					     "1100" | -- cmpy <
					     "1110" => -- ldy <
					  next_state   <= dual_op_read16_state;

					when "1111" => -- sty <
				     next_state   <= dual_op_write16_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

	          when "1010" => -- acca indexed
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpd ,ind
					     "1100" | -- cmpy ,ind
					     "1110" => -- ldy ,ind
				     st_ctrl      <= push_st;
				     return_state <= dual_op_read16_state;
					  next_state   <= indexed_state;

					when "1111" => -- sty ,ind
				     st_ctrl      <= push_st;
				     return_state <= dual_op_write16_state;
				     next_state   <= indexed_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;
               end case;

             when "1011" => -- acca extended
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpd <
					     "1100" | -- cmpy <
					     "1110" => -- ldy <
				     st_ctrl      <= push_st;
				     return_state <= dual_op_read16_state;
					  next_state   <= extended_state;

					when "1111" => -- sty >
				     st_ctrl      <= push_st;
				     return_state <= dual_op_write16_state;
				     next_state   <= extended_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

	          when "1100" => -- accb immediate
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- undef #
					     "1100" | -- undef #
					     "1110" => -- lds #
					  next_state   <= imm16_state;

					when others =>
				     next_state   <= fetch_state;

               end case;

	          when "1101" => -- accb direct
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- undef <
					     "1100" | -- undef <
					     "1110" => -- lds <
					  next_state   <= dual_op_read16_state;

					when "1111" => -- sts <
				     next_state   <= dual_op_write16_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

	          when "1110" => -- accb indexed
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- undef ,ind
					     "1100" | -- undef ,ind
					     "1110" => -- lds ,ind
				     st_ctrl      <= push_st;
				     return_state <= dual_op_read16_state;
					  next_state   <= indexed_state;

					when "1111" => -- sts ,ind
				     st_ctrl      <= push_st;
				     return_state <= dual_op_write16_state;
				     next_state   <= indexed_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

             when "1111" => -- accb extended
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- undef >
					     "1100" | -- undef >
					     "1110" => -- lds >
				     st_ctrl      <= push_st;
				     return_state <= dual_op_read16_state;
					  next_state   <= extended_state;

					when "1111" => -- sts >
				     st_ctrl      <= push_st;
				     return_state <= dual_op_write16_state;
				     next_state   <= extended_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;
               end case;

	          when others =>
               lic          <= '1';
 		         next_state   <= fetch_state;
             end case;
			 --
			 -- Here to decode instruction
			 -- and fetch next byte of intruction
			 -- whether it be necessary or not
			 --
          when decode3_state =>
             ea_ctrl    <= fetch_first_ea;
				 md_ctrl    <= fetch_first_md;
             addr_ctrl  <= fetch_ad;
             dout_ctrl  <= md_lo_dout;
			    case op_code(7 downto 4) is
				 --
				 -- Single byte stack operators
				 -- Do not advance PC
				 --
	          when "0011" =>
	            case op_code(3 downto 0) is
		         when "1111" => -- swi3
					   -- predecrement sp
		            left_ctrl    <= sp_left;
		            right_ctrl   <= one_right;
						alu_ctrl     <= alu_sub16;
						sp_ctrl      <= load_sp;
						iv_ctrl      <= swi3_iv;
						st_ctrl      <= push_st;
						return_state <= vect_hi_state;
						next_state   <= int_entire_state;
		         when others =>
                 lic          <= '1';
					  next_state   <= fetch_state;
		         end case;

	          when "1000" => -- acca immediate
				   -- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpu #
					     "1100" | -- cmps #
					     "1110" => -- undef #
					  next_state   <= imm16_state;
					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;
               end case;

	          when "1001" => -- acca direct
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpu <
					     "1100" | -- cmps <
					     "1110" => -- undef <
					  next_state   <= dual_op_read16_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

	          when "1010" => -- acca indexed
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpu ,X
					     "1100" | -- cmps ,X
					     "1110" => -- undef ,X
				     st_ctrl      <= push_st;
				     return_state <= dual_op_read16_state;
					  next_state   <= indexed_state;

					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;

               end case;

             when "1011" => -- acca extended
					-- increment the pc
               pc_ctrl    <= incr_pc;
					case op_code(3 downto 0) is
               when "0011" | -- cmpu >
					     "1100" | -- cmps >
					     "1110" => -- undef >
				     st_ctrl      <= push_st;
				     return_state <= dual_op_read16_state;
					  next_state   <= extended_state;
					when others =>
                 lic          <= '1';
				     next_state   <= fetch_state;
               end case;

	          when others =>
               lic          <= '1';
 		         next_state   <= fetch_state;
             end case;

           --
			  -- here if ea holds low byte
			  -- Direct
			  -- Extended
			  -- Indexed
			  -- read memory location
			  --
			  when single_op_read_state =>
					-- read memory into md
				   md_ctrl    <= fetch_first_md;
               addr_ctrl  <= read_ad;
					dout_ctrl  <= md_lo_dout;
					next_state <= single_op_exec_state;

	        when single_op_exec_state =>
	            case op_code(3 downto 0) is
		         when "0000" => -- neg
                   left_ctrl  <= md_left;
					    right_ctrl <= zero_right;
					    alu_ctrl   <= alu_neg;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
 	            when "0011" => -- com
                   left_ctrl  <= md_left;
		             right_ctrl <= zero_right;
					    alu_ctrl   <= alu_com;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "0100" => -- lsr
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_lsr8;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "0110" => -- ror
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_ror8;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "0111" => -- asr
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_asr8;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "1000" => -- asl
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_asl8;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "1001" => -- rol
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_rol8;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "1010" => -- dec
                   left_ctrl  <= md_left;
		             right_ctrl <= one_right;
					    alu_ctrl   <= alu_dec;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "1011" => -- undefined
                   lic        <= '1';
				       next_state <= fetch_state;
		         when "1100" => -- inc
                   left_ctrl  <= md_left;
		             right_ctrl <= one_right;
					    alu_ctrl   <= alu_inc;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when "1101" => -- tst
                   left_ctrl  <= md_left;
		             right_ctrl <= zero_right;
					    alu_ctrl   <= alu_st8;
					    cc_ctrl    <= load_cc;
                   lic        <= '1';
				       next_state <= fetch_state;
		         when "1110" => -- jmp
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_ld16;
                   pc_ctrl    <= load_pc;
                   lic          <= '1';
				       next_state <= fetch_state;
		         when "1111" => -- clr
                   left_ctrl  <= md_left;
						 right_ctrl <= zero_right;
					    alu_ctrl   <= alu_clr;
					    cc_ctrl    <= load_cc;
				       md_ctrl    <= load_md;
				       next_state <= single_op_write_state;
		         when others =>
                 lic        <= '1';
				     next_state <= fetch_state;
		         end case;
           --
			  -- single operand 8 bit write
			  -- Write low 8 bits of ALU output
			  -- EA holds address
			  -- MD holds data
			  --
			  when single_op_write_state =>
				 -- write ALU low byte output
             addr_ctrl  <= write_ad;
             dout_ctrl  <= md_lo_dout;
             lic        <= '1';
				 next_state <= fetch_state;

           --
			  -- here if ea holds address of low byte
			  -- read memory location
			  --
			  when dual_op_read8_state =>
				   -- read first data byte from ea
				   md_ctrl    <= fetch_first_md;
               addr_ctrl  <= read_ad;
               lic        <= '1';
					next_state <= fetch_state;

				--
				-- Here to read a 16 bit value into MD
				-- pointed to by the EA register
				-- The first byte is read
				-- and the EA is incremented
				--
			   when dual_op_read16_state =>
					-- increment the effective address
               left_ctrl  <= ea_left;
               right_ctrl <= one_right;
               alu_ctrl   <= alu_add16;
               ea_ctrl    <= load_ea;
					-- read the high byte of the 16 bit data
				   md_ctrl    <= fetch_first_md;
               addr_ctrl  <= read_ad;
					next_state <= dual_op_read16_2_state;

				--
				-- here to read the second byte
			   -- pointed to by EA into MD
				--
			   when dual_op_read16_2_state =>
					-- read the low byte of the 16 bit data
				   md_ctrl    <= fetch_next_md;
               addr_ctrl  <= read_ad;
               lic        <= '1';
					next_state <= fetch_state;

           --
			  -- 16 bit Write state
			  -- EA hold address of memory to write to
			  -- Advance the effective address in ALU
			  -- decode op_code to determine which
			  -- register to write
			  --
			  when dual_op_write16_state =>
				 -- increment the effective address
				 left_ctrl  <= ea_left;
				 right_ctrl <= one_right;
				 alu_ctrl   <= alu_add16;
			    ea_ctrl    <= load_ea;
 				 -- write the ALU hi byte at ea
             addr_ctrl  <= write_ad;
				 if op_code(6) = '0' then
				   case op_code(3 downto 0) is
			      when "1111" => -- stx / sty
					  case pre_code is
					  when "00010000" => -- page 2 -- sty
	                dout_ctrl  <= iy_hi_dout;
				     when others =>     -- page 1 -- stx
                   dout_ctrl  <= ix_hi_dout;
					  end case;
				   when others =>
                 dout_ctrl  <= md_hi_dout;
				   end case;
             else
				   case op_code(3 downto 0) is
			      when "1101" => -- std
                 dout_ctrl  <= acca_dout; -- acca is high byte of ACCD
			      when "1111" => -- stu / sts
					  case pre_code is
					  when "00010000" => -- page 2 -- sts
	                dout_ctrl  <= sp_hi_dout;
					  when others =>     -- page 1 -- stu
	                dout_ctrl  <= up_hi_dout;
					  end case;
				   when others =>
                 dout_ctrl  <= md_hi_dout;
				   end case;
             end if;
				 next_state   <= dual_op_write8_state;

           --
			  -- Dual operand 8 bit write
           -- Write 8 bit accumulator
			  -- or low byte of 16 bit register
			  -- EA holds address
			  -- decode opcode to determine
			  -- which register to apply to the bus
			  -- Also set the condition codes here
			  --
			  when dual_op_write8_state =>
			    if op_code(6) = '0' then
				   case op_code(3 downto 0) is
					when "0111" => -- sta
                 dout_ctrl  <= acca_dout;
					when "1111" => -- stx / sty
					  case pre_code is
					  when "00010000" => -- page 2 -- sty
	                dout_ctrl  <= iy_lo_dout;
				     when others =>     -- page 1 -- stx
                   dout_ctrl  <= ix_lo_dout;
					  end case;
					when others =>
                 dout_ctrl  <= md_lo_dout;
					end case;
             else
				   case op_code(3 downto 0) is
					when "0111" => -- stb
                 dout_ctrl  <= accb_dout;
					when "1101" => -- std
                 dout_ctrl  <= accb_dout; -- accb is low byte of accd
					when "1111" => -- stu / sts
					  case pre_code is
					  when "00010000" => -- page 2 -- sts
	                dout_ctrl  <= sp_lo_dout;
					  when others =>     -- page 1 -- stu
	                dout_ctrl  <= up_lo_dout;
					  end case;
					when others =>
                 dout_ctrl  <= md_lo_dout;
					end case;
             end if;
				 -- write ALU low byte output
             addr_ctrl    <= write_ad;
             lic          <= '1';
				 next_state   <= fetch_state;

			  --
			  -- 16 bit immediate addressing mode
			  --
			  when imm16_state =>
				   -- increment pc
               pc_ctrl    <= incr_pc;
				   -- fetch next immediate byte
			      md_ctrl    <= fetch_next_md;
               addr_ctrl  <= fetch_ad;
               lic        <= '1';
					next_state <= fetch_state;

           --
			  -- md & ea holds 8 bit index offset
			  -- calculate the effective memory address
			  -- using the alu
			  --
           when indexed_state =>
				 --
				 -- decode indexing mode
				 --
				 if md(7) = '0' then
				   case md(6 downto 5) is
					when "00" =>
			        left_ctrl  <= ix_left;
					when "01" =>
			        left_ctrl  <= iy_left;
					when "10" =>
			        left_ctrl  <= up_left;
					when others =>
					-- when "11" =>
			        left_ctrl  <= sp_left;
					end case;
				   right_ctrl   <= md_sign5_right;
				   alu_ctrl     <= alu_add16;
               ea_ctrl      <= load_ea;
					next_state   <= saved_state;

				 else
				   case md(3 downto 0) is
					when "0000" =>     -- ,R+
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
			          left_ctrl  <= sp_left;
					  end case;
					  --
				     right_ctrl <= zero_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
                 next_state <= postincr1_state;

					when "0001" =>     -- ,R++
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= zero_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
                 next_state <= postincr2_state;

					when "0010" =>     -- ,-R
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
                   ix_ctrl    <= load_ix;
					  when "01" =>
			          left_ctrl  <= iy_left;
                   iy_ctrl    <= load_iy;
					  when "10" =>
			          left_ctrl  <= up_left;
                   up_ctrl    <= load_up;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
                   sp_ctrl    <= load_sp;
					  end case;
				     right_ctrl   <= one_right;
				     alu_ctrl     <= alu_sub16;
                 ea_ctrl      <= load_ea;
					  next_state   <= saved_state;

					when "0011" =>     -- ,--R
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
                   ix_ctrl    <= load_ix;
					  when "01" =>
			          left_ctrl  <= iy_left;
                   iy_ctrl    <= load_iy;
					  when "10" =>
			          left_ctrl  <= up_left;
                   up_ctrl    <= load_up;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
                   sp_ctrl    <= load_sp;
					  end case;
				     right_ctrl <= two_right;
				     alu_ctrl   <= alu_sub16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "0100" =>     -- ,R (zero offset)
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= zero_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "0101" =>     -- ACCB,R
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= accb_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "0110" =>     -- ACCA,R
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= acca_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "0111" =>     -- undefined
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= zero_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "1000" =>     -- offset8,R
                 md_ctrl    <= fetch_first_md; -- pick up 8 bit offset
                 addr_ctrl  <= fetch_ad;
                 pc_ctrl    <= incr_pc;
                 next_state <= index8_state;

					when "1001" =>     -- offset16,R
                 md_ctrl    <= fetch_first_md; -- pick up first byte of 16 bit offset
                 addr_ctrl  <= fetch_ad;
                 pc_ctrl    <= incr_pc;
                 next_state <= index16_state;

					when "1010" =>     -- undefined
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= zero_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  --
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "1011" =>     -- ACCD,R
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= accd_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

					when "1100" =>     -- offset8,PC
					  -- fetch 8 bit offset
                 md_ctrl    <= fetch_first_md;
                 addr_ctrl  <= fetch_ad;
                 pc_ctrl    <= incr_pc;
                 next_state <= pcrel8_state;

					when "1101" =>     -- offset16,PC
					  -- fetch offset
                 md_ctrl    <= fetch_first_md;
                 addr_ctrl  <= fetch_ad;
                 pc_ctrl    <= incr_pc;
                 next_state <= pcrel16_state;

					when "1110" =>     -- undefined
				     case md(6 downto 5) is
					  when "00" =>
			          left_ctrl  <= ix_left;
					  when "01" =>
			          left_ctrl  <= iy_left;
					  when "10" =>
			          left_ctrl  <= up_left;
					  when others =>
					  -- when "11" =>
			          left_ctrl  <= sp_left;
					  end case;
				     right_ctrl <= zero_right;
				     alu_ctrl   <= alu_add16;
                 ea_ctrl    <= load_ea;
					  if md(4) = '0' then
					    next_state   <= saved_state;
					  else
					    next_state   <= indirect_state;
					  end if;

               when others =>
--    			when "1111" =>     -- [,address]
					  -- advance PC to pick up address
                 md_ctrl    <= fetch_first_md;
                 addr_ctrl  <= fetch_ad;
					  pc_ctrl    <= incr_pc;
                 next_state <= indexaddr_state;
					end case;
				 end if;

			  -- load index register with ea plus one
			  when postincr1_state =>
			    left_ctrl  <= ea_left;
			    right_ctrl <= one_right;
			    alu_ctrl   <= alu_add16;
				 case md(6 downto 5) is
			    when "00" =>
               ix_ctrl    <= load_ix;
				 when "01" =>
               iy_ctrl    <= load_iy;
				 when "10" =>
               up_ctrl    <= load_up;
				 when others =>
				 -- when "11" =>
               sp_ctrl    <= load_sp;
			    end case;
				 -- return to previous state
			    if md(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;

			  -- load index register with ea plus two
			  when postincr2_state =>
				 -- increment register by two (address)
			    left_ctrl  <= ea_left;
			    right_ctrl <= two_right;
			    alu_ctrl   <= alu_add16;
				 case md(6 downto 5) is
			    when "00" =>
               ix_ctrl    <= load_ix;
				 when "01" =>
               iy_ctrl    <= load_iy;
				 when "10" =>
               up_ctrl    <= load_up;
				 when others =>
				 -- when "11" =>
               sp_ctrl    <= load_sp;
			    end case;
				 -- return to previous state
			    if md(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;
           --
			  -- ea = index register + md (8 bit signed offset)
			  -- ea holds post byte
			  --
			  when index8_state =>
				 case ea(6 downto 5) is
			    when "00" =>
			      left_ctrl  <= ix_left;
			    when "01" =>
			      left_ctrl  <= iy_left;
				 when "10" =>
			      left_ctrl  <= up_left;
				 when others =>
				 -- when "11" =>
			      left_ctrl  <= sp_left;
				 end case;
				 -- ea = index reg + md
			    right_ctrl <= md_sign8_right;
			    alu_ctrl   <= alu_add16;
             ea_ctrl    <= load_ea;
				 -- return to previous state
			    if ea(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;

			  -- fetch low byte of 16 bit indexed offset
			  when index16_state =>
				 -- advance pc
             pc_ctrl    <= incr_pc;
				 -- fetch low byte
             md_ctrl    <= fetch_next_md;
             addr_ctrl  <= fetch_ad;
				 next_state <= index16_2_state;

			  -- ea = index register + md (16 bit offset)
			  -- ea holds post byte
			  when index16_2_state =>
				 case ea(6 downto 5) is
			    when "00" =>
			      left_ctrl  <= ix_left;
			    when "01" =>
			      left_ctrl  <= iy_left;
				 when "10" =>
			      left_ctrl  <= up_left;
				 when others =>
				 -- when "11" =>
			      left_ctrl  <= sp_left;
				 end case;
				 -- ea = index reg + md
			    right_ctrl <= md_right;
			    alu_ctrl   <= alu_add16;
             ea_ctrl    <= load_ea;
				 -- return to previous state
			    if ea(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;
           --
			  -- pc relative with 8 bit signed offest
			  -- md holds signed offset
			  --
			  when pcrel8_state =>
				 -- ea = pc + signed md
			    left_ctrl  <= pc_left;
			    right_ctrl <= md_sign8_right;
			    alu_ctrl   <= alu_add16;
             ea_ctrl    <= load_ea;
				 -- return to previous state
			    if ea(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;

			  -- pc relative addressing with 16 bit offset
			  -- pick up the low byte of the offset in md
			  -- advance the pc
			  when pcrel16_state =>
				 -- advance pc
             pc_ctrl    <= incr_pc;
				 -- fetch low byte
             md_ctrl    <= fetch_next_md;
             addr_ctrl  <= fetch_ad;
				 next_state <= pcrel16_2_state;

			  -- pc relative with16 bit signed offest
			  -- md holds signed offset
			  when pcrel16_2_state =>
				 -- ea = pc +  md
			    left_ctrl  <= pc_left;
			    right_ctrl <= md_right;
			    alu_ctrl   <= alu_add16;
             ea_ctrl    <= load_ea;
				 -- return to previous state
			    if ea(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;

			  -- indexed to address
			  -- pick up the low byte of the address
			  -- advance the pc
			  when indexaddr_state =>
				 -- advance pc
             pc_ctrl    <= incr_pc;
				 -- fetch low byte
             md_ctrl    <= fetch_next_md;
             addr_ctrl  <= fetch_ad;
				 next_state <= indexaddr2_state;

			  -- indexed to absolute address
			  -- md holds address
			  -- ea hold indexing mode byte
			  when indexaddr2_state =>
				 -- ea = md
			    left_ctrl  <= pc_left;
			    right_ctrl <= md_right;
			    alu_ctrl   <= alu_ld16;
             ea_ctrl    <= load_ea;
				 -- return to previous state
			    if ea(4) = '0' then
					 next_state   <= saved_state;
				 else
					 next_state   <= indirect_state;
				 end if;

           --
			  -- load md with high byte of indirect address
			  -- pointed to by ea
			  -- increment ea
			  --
			  when indirect_state =>
				 -- increment ea
			    left_ctrl  <= ea_left;
			    right_ctrl <= one_right;
			    alu_ctrl   <= alu_add16;
             ea_ctrl    <= load_ea;
				 -- fetch high byte
             md_ctrl    <= fetch_first_md;
             addr_ctrl  <= read_ad;
				 next_state <= indirect2_state;
           --
			  -- load md with low byte of indirect address
			  -- pointed to by ea
			  -- ea has previously been incremented
			  --
			  when indirect2_state =>
				 -- fetch high byte
             md_ctrl    <= fetch_next_md;
             addr_ctrl  <= read_ad;
             dout_ctrl  <= md_lo_dout;
				 next_state <= indirect3_state;
			  --
			  -- complete idirect addressing
			  -- by loading ea with md
			  --
			  when indirect3_state =>
				 -- load ea with md
			    left_ctrl  <= ea_left;
			    right_ctrl <= md_right;
			    alu_ctrl   <= alu_ld16;
             ea_ctrl    <= load_ea;
				 -- return to previous state
				 next_state   <= saved_state;

           --
			  -- ea holds the low byte of the absolute address
			  -- Move ea low byte into ea high byte
			  -- load new ea low byte to for absolute 16 bit address
			  -- advance the program counter
			  --
			  when extended_state => -- fetch ea low byte
					-- increment pc
               pc_ctrl      <= incr_pc;
					-- fetch next effective address bytes
					ea_ctrl      <= fetch_next_ea;
               addr_ctrl    <= fetch_ad;
				   -- return to previous state
				   next_state   <= saved_state;

				when lea_state => -- here on load effective address
					-- load index register with effective address
               left_ctrl  <= pc_left;
					right_ctrl <= ea_right;
				   alu_ctrl   <= alu_lea;
					case op_code(3 downto 0) is
					when "0000" => -- leax
                   cc_ctrl    <= load_cc;
                   ix_ctrl    <= load_ix;
					when "0001" => -- leay
                   cc_ctrl    <= load_cc;
                   iy_ctrl    <= load_iy;
					when "0010" => -- leas
                   sp_ctrl    <= load_sp;
					when "0011" => -- leau
                   up_ctrl    <= load_up;
					when others =>
					    null;
					end case;
               lic          <= '1';
               next_state   <= fetch_state;

				--
				-- jump to subroutine
				-- sp=sp-1
				-- call push_return_lo_state to save pc
				-- return to jmp_state
				--
				when jsr_state =>
					-- decrement sp
               left_ctrl    <= sp_left;
					right_ctrl   <= one_right;
				   alu_ctrl     <= alu_sub16;
               sp_ctrl      <= load_sp;
					-- call push_return_state
					st_ctrl      <= push_st;
					return_state <= jmp_state;
               next_state   <= push_return_lo_state;

				--
				-- Load pc with ea
				-- (JMP)
				--
				when jmp_state =>
					-- load PC with effective address
               left_ctrl  <= pc_left;
					right_ctrl <= ea_right;
				   alu_ctrl   <= alu_ld16;
					pc_ctrl    <= load_pc;
               lic        <= '1';
               next_state <= fetch_state;

				--
				-- long branch or branch to subroutine
				-- pick up next md byte
				-- md_hi = md_lo
				-- md_lo = (pc)
				-- pc=pc+1
				-- if a lbsr push return address
				-- continue to sbranch_state
				-- to evaluate conditional branches
				--
				when lbranch_state =>
					pc_ctrl    <= incr_pc;
					-- fetch the next byte into md_lo
               md_ctrl    <= fetch_next_md;
               addr_ctrl  <= fetch_ad;
					-- if lbsr - push return address
					-- then continue on to short branch
					if op_code = "00010111" then
					  st_ctrl      <= push_st;
					  return_state <= sbranch_state;
                 next_state   <= push_return_lo_state;
					else
                 next_state   <= sbranch_state;
					end if;

				 --
				 -- here to execute conditional branch
				 -- short conditional branch md = signed 8 bit offset
				 -- long branch md = 16 bit offset
				 --
	          when sbranch_state =>
               left_ctrl  <= pc_left;
					right_ctrl <= md_right;
				   alu_ctrl   <= alu_add16;
					-- Test condition for branch
			      if op_code(7 downto 4) = "0010" then -- conditional branch
                 case op_code(3 downto 0) is
		           when "0000" => -- bra
					    cond_true := (1 = 1);
		           when "0001" => -- brn
					    cond_true := (1 = 0);
		           when "0010" => -- bhi
					    cond_true := ((cc(CBIT) or cc(ZBIT)) = '0');
		           when "0011" => -- bls
					    cond_true := ((cc(CBIT) or cc(ZBIT)) = '1');
		           when "0100" => -- bcc/bhs
					    cond_true := (cc(CBIT) = '0');
		           when "0101" => -- bcs/blo
					    cond_true := (cc(CBIT) = '1');
		           when "0110" => -- bne
		             cond_true := (cc(ZBIT) = '0');
		           when "0111" => -- beq
					    cond_true := (cc(ZBIT) = '1');
		           when "1000" => -- bvc
					    cond_true := (cc(VBIT) = '0');
		           when "1001" => -- bvs
					    cond_true := (cc(VBIT) = '1');
		           when "1010" => -- bpl
					    cond_true := (cc(NBIT) = '0');
		           when "1011" => -- bmi
					    cond_true := (cc(NBIT) = '1');
		           when "1100" => -- bge
					    cond_true := ((cc(NBIT) xor cc(VBIT)) = '0');
		           when "1101" => -- blt
					    cond_true := ((cc(NBIT) xor cc(VBIT)) = '1');
		           when "1110" => -- bgt
					    cond_true := ((cc(ZBIT) or (cc(NBIT) xor cc(VBIT))) = '0');
		           when "1111" => -- ble
					    cond_true := ((cc(ZBIT) or (cc(NBIT) xor cc(VBIT))) = '1');
		           when others =>
					    null;
		           end case;
				   end if;
  					if cond_true then
					  pc_ctrl    <= load_pc;
               end if;
               lic          <= '1';
					next_state   <= fetch_state;

				 --
				 -- push return address onto the S stack
				 --
				 -- (sp) = pc_lo
				 -- sp = sp - 1
				 --
				 when push_return_lo_state =>
					  -- decrement the sp
                 left_ctrl  <= sp_left;
                 right_ctrl <= one_right;
                 alu_ctrl   <= alu_sub16;
                 sp_ctrl    <= load_sp;
                 -- write PC low
                 addr_ctrl  <= pushs_ad;
                 dout_ctrl  <= pc_lo_dout;
                 next_state <= push_return_hi_state;

				--
				-- push program counter hi byte onto the stack
				-- (sp) = pc_hi
				-- sp = sp
				-- return to originating state
				--
				when push_return_hi_state =>
					  -- write pc hi bytes
                 addr_ctrl    <= pushs_ad;
                 dout_ctrl    <= pc_hi_dout;
                 next_state   <= saved_state;

             --
             -- RTS pull return address from stack
             --
				 when pull_return_hi_state =>
					  -- increment the sp
                 left_ctrl  <= sp_left;
                 right_ctrl <= one_right;
                 alu_ctrl   <= alu_add16;
                 sp_ctrl    <= load_sp;
                 -- read pc hi
					  pc_ctrl    <= pull_hi_pc;
                 addr_ctrl  <= pulls_ad;
                 next_state <= pull_return_lo_state;

				when pull_return_lo_state =>
					  -- increment the SP
                 left_ctrl  <= sp_left;
                 right_ctrl <= one_right;
                 alu_ctrl   <= alu_add16;
                 sp_ctrl    <= load_sp;
					  -- read pc low
					  pc_ctrl    <= pull_lo_pc;
                 addr_ctrl  <= pulls_ad;
                 dout_ctrl  <= pc_lo_dout;
 					  --
                 lic          <= '1';
                 next_state   <= fetch_state;

				 when andcc_state =>
					  -- AND CC with md
                 left_ctrl  <= md_left;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_andcc;
                 cc_ctrl    <= load_cc;
 					  --
                 lic        <= '1';
				     next_state <= fetch_state;

				 when orcc_state =>
					  -- OR CC with md
                 left_ctrl  <= md_left;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_orcc;
                 cc_ctrl    <= load_cc;
 					  --
                 lic        <= '1';
				     next_state <= fetch_state;

				 when tfr_state =>
					  -- select source register
					  case md(7 downto 4) is
					  when "0000" =>
					    left_ctrl <= accd_left;
					  when "0001" =>
					    left_ctrl <= ix_left;
					  when "0010" =>
					    left_ctrl <= iy_left;
					  when "0011" =>
					    left_ctrl <= up_left;
					  when "0100" =>
					    left_ctrl <= sp_left;
					  when "0101" =>
					    left_ctrl <= pc_left;
					  when "1000" =>
					    left_ctrl <= acca_left;
					  when "1001" =>
					    left_ctrl <= accb_left;
					  when "1010" =>
					    left_ctrl <= cc_left;
					  when "1011" =>
					    left_ctrl <= dp_left;
					  when others =>
                   left_ctrl  <= md_left;
					  end case;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_tfr;
					  -- select destination register
					  case md(3 downto 0) is
					  when "0000" => -- accd
                   acca_ctrl  <= load_hi_acca;
                   accb_ctrl  <= load_accb;
					  when "0001" => -- ix
                   ix_ctrl    <= load_ix;
					  when "0010" => -- iy
                   iy_ctrl    <= load_iy;
					  when "0011" => -- up
                   up_ctrl    <= load_up;
					  when "0100" => -- sp
                   sp_ctrl    <= load_sp;
					  when "0101" => -- pc
                   pc_ctrl    <= load_pc;
					  when "1000" => -- acca
                   acca_ctrl  <= load_acca;
					  when "1001" => -- accb
                   accb_ctrl  <= load_accb;
					  when "1010" => -- cc
                   cc_ctrl    <= load_cc;
					  when "1011" => --dp
                   dp_ctrl    <= load_dp;
					  when others =>
					    null;
					  end case;
 					  --
                 lic          <= '1';
				     next_state   <= fetch_state;

				 when exg_state =>
					  -- save destination register
					  case md(3 downto 0) is
					  when "0000" =>
					    left_ctrl <= accd_left;
					  when "0001" =>
					    left_ctrl <= ix_left;
					  when "0010" =>
					    left_ctrl <= iy_left;
					  when "0011" =>
					    left_ctrl <= up_left;
					  when "0100" =>
					    left_ctrl <= sp_left;
					  when "0101" =>
					    left_ctrl <= pc_left;
					  when "1000" =>
					    left_ctrl <= acca_left;
					  when "1001" =>
					    left_ctrl <= accb_left;
					  when "1010" =>
					    left_ctrl <= cc_left;
					  when "1011" =>
					    left_ctrl <= dp_left;
					  when others =>
                   left_ctrl  <= md_left;
					  end case;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_tfr;
                 ea_ctrl    <= load_ea;
 					  -- call tranfer microcode
				     next_state   <= exg1_state;

				 when exg1_state =>
					  -- select source register
					  case md(7 downto 4) is
					  when "0000" =>
					    left_ctrl <= accd_left;
					  when "0001" =>
					    left_ctrl <= ix_left;
					  when "0010" =>
					    left_ctrl <= iy_left;
					  when "0011" =>
					    left_ctrl <= up_left;
					  when "0100" =>
					    left_ctrl <= sp_left;
					  when "0101" =>
					    left_ctrl <= pc_left;
					  when "1000" =>
					    left_ctrl <= acca_left;
					  when "1001" =>
					    left_ctrl <= accb_left;
					  when "1010" =>
					    left_ctrl <= cc_left;
					  when "1011" =>
					    left_ctrl <= dp_left;
					  when others =>
                   left_ctrl  <= md_left;
					  end case;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_tfr;
					  -- select destination register
					  case md(3 downto 0) is
					  when "0000" => -- accd
                   acca_ctrl  <= load_hi_acca;
                   accb_ctrl  <= load_accb;
					  when "0001" => -- ix
                   ix_ctrl    <= load_ix;
					  when "0010" => -- iy
                   iy_ctrl    <= load_iy;
					  when "0011" => -- up
                   up_ctrl    <= load_up;
					  when "0100" => -- sp
                   sp_ctrl    <= load_sp;
					  when "0101" => -- pc
                   pc_ctrl    <= load_pc;
					  when "1000" => -- acca
                   acca_ctrl  <= load_acca;
					  when "1001" => -- accb
                   accb_ctrl  <= load_accb;
					  when "1010" => -- cc
                   cc_ctrl    <= load_cc;
					  when "1011" => --dp
                   dp_ctrl    <= load_dp;
					  when others =>
					    null;
					  end case;
				     next_state   <= exg2_state;

				 when exg2_state =>
					  -- restore destination
                 left_ctrl  <= ea_left;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_tfr;
					  -- save as source register
					  case md(7 downto 4) is
					  when "0000" => -- accd
                   acca_ctrl  <= load_hi_acca;
                   accb_ctrl  <= load_accb;
					  when "0001" => -- ix
                   ix_ctrl    <= load_ix;
					  when "0010" => -- iy
                   iy_ctrl    <= load_iy;
					  when "0011" => -- up
                   up_ctrl    <= load_up;
					  when "0100" => -- sp
                   sp_ctrl    <= load_sp;
					  when "0101" => -- pc
                   pc_ctrl    <= load_pc;
					  when "1000" => -- acca
                   acca_ctrl  <= load_acca;
					  when "1001" => -- accb
                   accb_ctrl  <= load_accb;
					  when "1010" => -- cc
                   cc_ctrl    <= load_cc;
					  when "1011" => --dp
                   dp_ctrl    <= load_dp;
					  when others =>
					    null;
					  end case;
                 lic          <= '1';
				     next_state   <= fetch_state;

				 when mul_state =>
					  -- move acca to md
                 left_ctrl  <= acca_left;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_st16;
                 md_ctrl    <= load_md;
				     next_state <= mulea_state;

				 when mulea_state =>
					  -- move accb to ea
                 left_ctrl  <= accb_left;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_st16;
                 ea_ctrl    <= load_ea;
				     next_state <= muld_state;

				 when muld_state =>
					  -- clear accd
                 left_ctrl  <= acca_left;
                 right_ctrl <= zero_right;
                 alu_ctrl   <= alu_ld8;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
				     next_state <= mul0_state;

				 when mul0_state =>
					  -- if bit 0 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(0) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul1_state;

				 when mul1_state =>
					  -- if bit 1 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(1) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul2_state;

				 when mul2_state =>
					  -- if bit 2 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(2) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul3_state;

				 when mul3_state =>
					  -- if bit 3 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(3) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul4_state;

				 when mul4_state =>
					  -- if bit 4 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(4) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul5_state;

				 when mul5_state =>
					  -- if bit 5 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(5) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul6_state;

				 when mul6_state =>
					  -- if bit 6 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(6) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
				     next_state <= mul7_state;

				 when mul7_state =>
					  -- if bit 7 of ea set, add accd to md
                 left_ctrl  <= accd_left;
					  if ea(7) = '1' then
                   right_ctrl <= md_right;
					  else
                   right_ctrl <= zero_right;
					  end if;
                 alu_ctrl   <= alu_mul;
                 cc_ctrl    <= load_cc;
                 acca_ctrl  <= load_hi_acca;
                 accb_ctrl  <= load_accb;
                 md_ctrl    <= shiftl_md;
                 lic          <= '1';
				     next_state <= fetch_state;

			  --
			  -- Enter here on pushs
			  -- ea holds post byte
			  --
			  when pshs_state =>
             -- decrement sp if any registers to be pushed
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 -- idle	address
             addr_ctrl  <= idle_ad;
			    dout_ctrl  <= cc_dout;
				 if ea(7 downto 0) = "00000000" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 if ea(7) = '1' then
               next_state <= pshs_pcl_state;
				 elsif ea(6) = '1' then
               next_state <= pshs_upl_state;
				 elsif ea(5) = '1' then
 				   next_state <= pshs_iyl_state;
				 elsif ea(4) = '1' then
 				   next_state <= pshs_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state <= pshs_dp_state;
				 elsif ea(2) = '1' then
 				   next_state <= pshs_accb_state;
				 elsif ea(1) = '1' then
 				   next_state <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state <= pshs_cc_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when pshs_pcl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write pc low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= pc_lo_dout;
             next_state <= pshs_pch_state;

			  when pshs_pch_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(6 downto 0) = "0000000" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 -- write pc hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= pc_hi_dout;
				 if ea(6) = '1' then
               next_state <= pshs_upl_state;
				 elsif ea(5) = '1' then
 				   next_state <= pshs_iyl_state;
				 elsif ea(4) = '1' then
 				   next_state <= pshs_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state <= pshs_dp_state;
				 elsif ea(2) = '1' then
 				   next_state <= pshs_accb_state;
				 elsif ea(1) = '1' then
 				   next_state <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state <= pshs_cc_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;


			  when pshs_upl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write pc low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= up_lo_dout;
             next_state <= pshs_uph_state;

			  when pshs_uph_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(5 downto 0) = "000000" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 -- write pc hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= up_hi_dout;
				 if ea(5) = '1' then
 				   next_state   <= pshs_iyl_state;
				 elsif ea(4) = '1' then
 				   next_state   <= pshs_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state   <= pshs_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshs_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshs_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshs_iyl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write iy low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= iy_lo_dout;
             next_state <= pshs_iyh_state;

			  when pshs_iyh_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(4 downto 0) = "00000" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 -- write iy hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= iy_hi_dout;
				 if ea(4) = '1' then
 				   next_state   <= pshs_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state   <= pshs_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshs_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshs_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshs_ixl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write ix low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= ix_lo_dout;
             next_state <= pshs_ixh_state;

			  when pshs_ixh_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(3 downto 0) = "0000" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 -- write ix hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= ix_hi_dout;
				 if ea(3) = '1' then
 				   next_state   <= pshs_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshs_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshs_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshs_dp_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(2 downto 0) = "000" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 -- write dp
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= dp_dout;
				 if ea(2) = '1' then
 				   next_state   <= pshs_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshs_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshs_accb_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(1 downto 0) = "00" then
               sp_ctrl    <= latch_sp;
				 else
               sp_ctrl    <= load_sp;
				 end if;
				 -- write accb
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= accb_dout;
				 if ea(1) = '1' then
 				   next_state   <= pshs_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshs_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshs_acca_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(0) = '1' then
               sp_ctrl    <= load_sp;
				 else
               sp_ctrl    <= latch_sp;
				 end if;
				 -- write acca
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= acca_dout;
				 if ea(0) = '1' then
 				   next_state   <= pshs_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshs_cc_state =>
             -- idle sp
				 -- write cc
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= cc_dout;
             lic          <= '1';
             next_state <= fetch_state;

			  --
			  -- enter here on PULS
			  -- ea hold register mask
			  --
			  when puls_state =>
				 if ea(0) = '1' then
 				   next_state <= puls_cc_state;
				 elsif ea(1) = '1' then
 				   next_state <= puls_acca_state;
				 elsif ea(2) = '1' then
 				   next_state <= puls_accb_state;
				 elsif ea(3) = '1' then
 				   next_state <= puls_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= puls_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= puls_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when puls_cc_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read cc
             cc_ctrl    <= pull_cc;
             addr_ctrl  <= pulls_ad;
				 if ea(1) = '1' then
 				   next_state <= puls_acca_state;
				 elsif ea(2) = '1' then
 				   next_state <= puls_accb_state;
				 elsif ea(3) = '1' then
 				   next_state <= puls_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= puls_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= puls_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when puls_acca_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read acca
				 acca_ctrl  <= pull_acca;
             addr_ctrl  <= pulls_ad;
				 if ea(2) = '1' then
 				   next_state <= puls_accb_state;
				 elsif ea(3) = '1' then
 				   next_state <= puls_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= puls_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= puls_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic          <= '1';
				   next_state <= fetch_state;
				 end if;

			  when puls_accb_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read accb
				 accb_ctrl  <= pull_accb;
             addr_ctrl  <= pulls_ad;
				 if ea(3) = '1' then
 				   next_state <= puls_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= puls_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= puls_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when puls_dp_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read dp
				 dp_ctrl    <= pull_dp;
             addr_ctrl  <= pulls_ad;
				 if ea(4) = '1' then
 				   next_state <= puls_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= puls_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when puls_ixh_state =>
             -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- pull ix hi
				 ix_ctrl    <= pull_hi_ix;
             addr_ctrl  <= pulls_ad;
             next_state <= puls_ixl_state;

		  	  when puls_ixl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read ix low
				 ix_ctrl    <= pull_lo_ix;
             addr_ctrl  <= pulls_ad;
				 if ea(5) = '1' then
 				   next_state <= puls_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when puls_iyh_state =>
             -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- pull iy hi
				 iy_ctrl    <= pull_hi_iy;
             addr_ctrl  <= pulls_ad;
             next_state   <= puls_iyl_state;

		  	  when puls_iyl_state =>
             -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read iy low
				 iy_ctrl    <= pull_lo_iy;
             addr_ctrl  <= pulls_ad;
				 if ea(6) = '1' then
               next_state <= puls_uph_state;
				 elsif ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when puls_uph_state =>
             -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- pull up hi
				 up_ctrl    <= pull_hi_up;
             addr_ctrl  <= pulls_ad;
             next_state <= puls_upl_state;

		  	  when puls_upl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read up low
				 up_ctrl    <= pull_lo_up;
             addr_ctrl  <= pulls_ad;
				 if ea(7) = '1' then
               next_state <= puls_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when puls_pch_state =>
             -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- pull pc hi
				 pc_ctrl    <= pull_hi_pc;
             addr_ctrl  <= pulls_ad;
             next_state <= puls_pcl_state;

		  	  when puls_pcl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read pc low
				 pc_ctrl    <= pull_lo_pc;
             addr_ctrl  <= pulls_ad;
             lic        <= '1';
             next_state <= fetch_state;

			  --
			  -- Enter here on pshu
			  -- ea holds post byte
			  --
			  when pshu_state =>
             -- decrement up if any registers to be pushed
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(7 downto 0) = "00000000" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write idle bus
				 if ea(7) = '1' then
               next_state   <= pshu_pcl_state;
				 elsif ea(6) = '1' then
               next_state   <= pshu_spl_state;
				 elsif ea(5) = '1' then
 				   next_state   <= pshu_iyl_state;
				 elsif ea(4) = '1' then
 				   next_state   <= pshu_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state   <= pshu_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshu_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;
			  --
			  -- push PC onto U stack
			  --
			  when pshu_pcl_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             up_ctrl    <= load_up;
				 -- write pc low
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= pc_lo_dout;
             next_state <= pshu_pch_state;

			  when pshu_pch_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(6 downto 0) = "0000000" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write pc hi
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= pc_hi_dout;
				 if ea(6) = '1' then
               next_state   <= pshu_spl_state;
				 elsif ea(5) = '1' then
 				   next_state   <= pshu_iyl_state;
				 elsif ea(4) = '1' then
 				   next_state   <= pshu_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state   <= pshu_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshu_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_spl_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             up_ctrl    <= load_up;
				 -- write sp low
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= sp_lo_dout;
             next_state <= pshu_sph_state;

			  when pshu_sph_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(5 downto 0) = "000000" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write sp hi
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= sp_hi_dout;
				 if ea(5) = '1' then
 				   next_state   <= pshu_iyl_state;
				 elsif ea(4) = '1' then
 				   next_state   <= pshu_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state   <= pshu_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshu_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_iyl_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             up_ctrl    <= load_up;
				 -- write iy low
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= iy_lo_dout;
             next_state <= pshu_iyh_state;

			  when pshu_iyh_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(4 downto 0) = "00000" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write iy hi
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= iy_hi_dout;
				 if ea(4) = '1' then
 				   next_state   <= pshu_ixl_state;
				 elsif ea(3) = '1' then
 				   next_state   <= pshu_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshu_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_ixl_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             up_ctrl    <= load_up;
				 -- write ix low
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= ix_lo_dout;
             next_state <= pshu_ixh_state;

			  when pshu_ixh_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(3 downto 0) = "0000" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write ix hi
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= ix_hi_dout;
				 if ea(3) = '1' then
 				   next_state   <= pshu_dp_state;
				 elsif ea(2) = '1' then
 				   next_state   <= pshu_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_dp_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(2 downto 0) = "000" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write dp
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= dp_dout;
				 if ea(2) = '1' then
 				   next_state   <= pshu_accb_state;
				 elsif ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_accb_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(1 downto 0) = "00" then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write accb
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= accb_dout;
				 if ea(1) = '1' then
 				   next_state   <= pshu_acca_state;
				 elsif ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_acca_state =>
             -- decrement up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
				 if ea(0) = '0' then
               up_ctrl    <= latch_up;
				 else
               up_ctrl    <= load_up;
				 end if;
				 -- write acca
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= acca_dout;
				 if ea(0) = '1' then
 				   next_state   <= pshu_cc_state;
				 else
               lic          <= '1';
				   next_state   <= fetch_state;
				 end if;

			  when pshu_cc_state =>
             -- idle up
				 -- write cc
             addr_ctrl  <= pushu_ad;
			    dout_ctrl  <= cc_dout;
             lic        <= '1';
             next_state <= fetch_state;

			  --
			  -- enter here on PULU
			  -- ea hold register mask
			  --
			  when pulu_state =>
				 -- idle UP
				 -- idle bus
				 if ea(0) = '1' then
 				   next_state <= pulu_cc_state;
				 elsif ea(1) = '1' then
 				   next_state <= pulu_acca_state;
				 elsif ea(2) = '1' then
 				   next_state <= pulu_accb_state;
				 elsif ea(3) = '1' then
 				   next_state <= pulu_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= pulu_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= pulu_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when pulu_cc_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read cc
             cc_ctrl    <= pull_cc;
             addr_ctrl  <= pullu_ad;
				 if ea(1) = '1' then
 				   next_state <= pulu_acca_state;
				 elsif ea(2) = '1' then
 				   next_state <= pulu_accb_state;
				 elsif ea(3) = '1' then
 				   next_state <= pulu_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= pulu_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= pulu_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when pulu_acca_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read acca
				 acca_ctrl  <= pull_acca;
             addr_ctrl  <= pullu_ad;
				 if ea(2) = '1' then
 				   next_state <= pulu_accb_state;
				 elsif ea(3) = '1' then
 				   next_state <= pulu_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= pulu_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= pulu_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when pulu_accb_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read accb
				 accb_ctrl  <= pull_accb;
             addr_ctrl  <= pullu_ad;
				 if ea(3) = '1' then
 				   next_state <= pulu_dp_state;
				 elsif ea(4) = '1' then
 				   next_state <= pulu_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= pulu_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

			  when pulu_dp_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read dp
				 dp_ctrl    <= pull_dp;
             addr_ctrl  <= pullu_ad;
				 if ea(4) = '1' then
 				   next_state <= pulu_ixh_state;
				 elsif ea(5) = '1' then
 				   next_state <= pulu_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when pulu_ixh_state =>
             -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read ix hi
				 ix_ctrl    <= pull_hi_ix;
             addr_ctrl  <= pullu_ad;
             next_state <= pulu_ixl_state;

		  	  when pulu_ixl_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read ix low
				 ix_ctrl    <= pull_lo_ix;
             addr_ctrl  <= pullu_ad;
				 if ea(5) = '1' then
 				   next_state <= pulu_iyh_state;
				 elsif ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when pulu_iyh_state =>
             -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read iy hi
				 iy_ctrl    <= pull_hi_iy;
             addr_ctrl  <= pullu_ad;
             next_state <= pulu_iyl_state;

		  	  when pulu_iyl_state =>
             -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read iy low
				 iy_ctrl    <= pull_lo_iy;
             addr_ctrl  <= pullu_ad;
				 if ea(6) = '1' then
               next_state <= pulu_sph_state;
				 elsif ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when pulu_sph_state =>
             -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read sp hi
				 sp_ctrl    <= pull_hi_sp;
             addr_ctrl  <= pullu_ad;
             next_state <= pulu_spl_state;

		  	  when pulu_spl_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read sp low
				 sp_ctrl    <= pull_lo_sp;
             addr_ctrl  <= pullu_ad;
				 if ea(7) = '1' then
               next_state <= pulu_pch_state;
				 else
               lic        <= '1';
				   next_state <= fetch_state;
				 end if;

		  	  when pulu_pch_state =>
             -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- pull pc hi
				 pc_ctrl    <= pull_hi_pc;
             addr_ctrl  <= pullu_ad;
             next_state <= pulu_pcl_state;

		  	  when pulu_pcl_state =>
				 -- increment up
             left_ctrl  <= up_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             up_ctrl    <= load_up;
				 -- read pc low
				 pc_ctrl    <= pull_lo_pc;
             addr_ctrl  <= pullu_ad;
             lic        <= '1';
             next_state <= fetch_state;

			  --
			  -- pop the Condition codes
			  --
			  when rti_cc_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read cc
             cc_ctrl    <= pull_cc;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_entire_state;

			  --
			  -- Added RTI cycle 11th July 2006 John Kent.
			  -- test the "Entire" Flag
			  -- that has just been popped off the stack
			  --
			  when rti_entire_state =>
				 --
				 -- The Entire flag must be recovered from the stack
				 -- before testing.
				 --
				 if cc(EBIT) = '1' then
               next_state   <= rti_acca_state;
				 else
               next_state   <= rti_pch_state;
				 end if;

			  when rti_acca_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read acca
				 acca_ctrl  <= pull_acca;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_accb_state;

			  when rti_accb_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read accb
				 accb_ctrl  <= pull_accb;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_dp_state;

			  when rti_dp_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read dp
				 dp_ctrl    <= pull_dp;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_ixh_state;

			  when rti_ixh_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read ix hi
				 ix_ctrl    <= pull_hi_ix;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_ixl_state;

			  when rti_ixl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read ix low
				 ix_ctrl    <= pull_lo_ix;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_iyh_state;

			  when rti_iyh_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read iy hi
				 iy_ctrl    <= pull_hi_iy;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_iyl_state;

			  when rti_iyl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read iy low
				 iy_ctrl    <= pull_lo_iy;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_uph_state;


			  when rti_uph_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read up hi
				 up_ctrl    <= pull_hi_up;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_upl_state;

			  when rti_upl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- read up low
             up_ctrl    <= pull_lo_up;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_pch_state;

			  when rti_pch_state =>
	          -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
				 -- pull pc hi
				 pc_ctrl    <= pull_hi_pc;
             addr_ctrl  <= pulls_ad;
             next_state <= rti_pcl_state;

			  when rti_pcl_state =>
				 -- increment sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_add16;
             sp_ctrl    <= load_sp;
	          -- pull pc low
				 pc_ctrl    <= pull_lo_pc;
             addr_ctrl  <= pulls_ad;
             lic        <= '1';
             next_state <= fetch_state;

			  --
			  -- here on NMI interrupt
			  -- Complete execute cycle of the last instruction.
           -- If it was a dual operand instruction
           --
			  when int_nmi_state =>
             next_state   <= int_nmi1_state;

			  -- Idle bus cycle
           when int_nmi1_state =>
             -- pre decrement sp
             left_ctrl    <= sp_left;
             right_ctrl   <= one_right;
             alu_ctrl     <= alu_sub16;
             sp_ctrl      <= load_sp;
				 iv_ctrl      <= nmi_iv;
				 st_ctrl      <= push_st;
				 return_state <= int_nmimask_state;
             next_state   <= int_entire_state;

			  --
			  -- here on IRQ interrupt
			  -- Complete execute cycle of the last instruction.
           -- If it was a dual operand instruction
           --
			  when int_irq_state =>
             next_state   <= int_irq1_state;

			  -- pre decrement the sp
			  -- Idle bus cycle
           when int_irq1_state =>
             -- pre decrement sp
             left_ctrl    <= sp_left;
             right_ctrl   <= one_right;
             alu_ctrl     <= alu_sub16;
             sp_ctrl      <= load_sp;
				 iv_ctrl      <= irq_iv;
				 st_ctrl      <= push_st;
				 return_state <= int_irqmask_state;
             next_state   <= int_entire_state;

			  --
			  -- here on FIRQ interrupt
			  -- Complete execution cycle of the last instruction
           -- if it was a dual operand instruction
           --
			  when int_firq_state =>
             next_state   <= int_firq1_state;

			  -- Idle bus cycle
           when int_firq1_state =>
             -- pre decrement sp
             left_ctrl    <= sp_left;
             right_ctrl   <= one_right;
             alu_ctrl     <= alu_sub16;
             sp_ctrl      <= load_sp;
				 iv_ctrl      <= firq_iv;
				 st_ctrl      <= push_st;
				 return_state <= int_firqmask_state;
             next_state   <= int_fast_state;

           --
           -- CWAI entry point
           -- stack pointer already pre-decremented
           -- mask condition codes
           --
           when cwai_state =>
              -- AND CC with md
              left_ctrl    <= md_left;
              right_ctrl   <= zero_right;
              alu_ctrl     <= alu_andcc;
              cc_ctrl      <= load_cc;
				  st_ctrl      <= push_st;
				  return_state <= int_cwai_state;
				  next_state   <= int_entire_state;

			  --
			  -- wait here for an interrupt
			  --
			  when int_cwai_state =>
             if (nmi_req = '1') then
				   iv_ctrl    <= nmi_iv;
			      next_state <= int_nmimask_state;
				 --
				 -- FIRQ & IRQ are level sensitive
				 --
             elsif (firq = '1') and (cc(FBIT) = '0') then
				   iv_ctrl     <= firq_iv;
  			      next_state  <= int_firqmask_state;

			    elsif (irq = '1') and (cc(IBIT) = '0') then
				   iv_ctrl     <= irq_iv;
			      next_state  <= int_irqmask_state;
			    else
				   next_state <= int_cwai_state;
             end if;

           --
			  -- State to mask I Flag and F Flag (NMI)
			  --
			  when int_nmimask_state =>
			    alu_ctrl   <= alu_seif;
				 cc_ctrl    <= load_cc;
             next_state <= vect_hi_state;

           --
			  -- State to mask I Flag and F Flag (FIRQ)
			  --
			  when int_firqmask_state =>
			    alu_ctrl   <= alu_seif;
				 cc_ctrl    <= load_cc;
             next_state <= vect_hi_state;


           --
			  -- State to mask I Flag and F Flag (SWI)
			  --
			  when int_swimask_state =>
			    alu_ctrl   <= alu_seif;
				 cc_ctrl    <= load_cc;
             next_state <= vect_hi_state;

           --
			  -- State to mask I Flag only (IRQ)
			  --
           when int_irqmask_state =>
				 alu_ctrl   <= alu_sei;
				 cc_ctrl    <= load_cc;
             next_state <= vect_hi_state;

			  --
			  -- set Entire Flag on SWI, SWI2, SWI3 and CWAI, IRQ and NMI
			  -- before stacking all registers
			  --
			  when int_entire_state =>
             -- set entire flag
             alu_ctrl   <= alu_see;
             cc_ctrl    <= load_cc;
             next_state <= int_pcl_state;

			  --
			  -- clear Entire Flag on FIRQ
			  -- before stacking all registers
			  --
			  when int_fast_state =>
             -- clear entire flag
             alu_ctrl   <= alu_cle;
             cc_ctrl    <= load_cc;
             next_state <= int_pcl_state;

			  when int_pcl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write pc low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= pc_lo_dout;
             next_state <= int_pch_state;

			  when int_pch_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write pc hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= pc_hi_dout;
				 if cc(EBIT) = '1' then
               next_state   <= int_upl_state;
				 else
               next_state   <= int_cc_state;
				 end if;

			  when int_upl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write up low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= up_lo_dout;
             next_state <= int_uph_state;

			  when int_uph_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write ix hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= up_hi_dout;
             next_state <= int_iyl_state;

			  when int_iyl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write ix low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= iy_lo_dout;
             next_state <= int_iyh_state;

			  when int_iyh_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write ix hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= iy_hi_dout;
             next_state <= int_ixl_state;

			  when int_ixl_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write ix low
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= ix_lo_dout;
             next_state <= int_ixh_state;

			  when int_ixh_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write ix hi
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= ix_hi_dout;
             next_state <= int_dp_state;

			  when int_dp_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write accb
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= dp_dout;
             next_state <= int_accb_state;

			  when int_accb_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write accb
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= accb_dout;
             next_state <= int_acca_state;

			  when int_acca_state =>
             -- decrement sp
             left_ctrl  <= sp_left;
             right_ctrl <= one_right;
             alu_ctrl   <= alu_sub16;
             sp_ctrl    <= load_sp;
				 -- write acca
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= acca_dout;
             next_state <= int_cc_state;

			  when int_cc_state =>
				 -- write cc
             addr_ctrl  <= pushs_ad;
			    dout_ctrl  <= cc_dout;
				 next_state <= saved_state;

			  --
			  -- According to the 6809 programming manual:
			  -- If an interrupt is received and is masked
			  -- or lasts for less than three cycles, the PC
			  -- will advance to the next instruction.
			  -- If an interrupt is unmasked and lasts
			  -- for more than three cycles, an interrupt
			  -- will be generated.
			  -- Note that I don't wait 3 clock cycles.
			  -- John Kent 11th July 2006
			  --
			  when sync_state =>
             lic        <= '1';
             ba         <= '1';
			 --
			 -- Version 1.28 2015-05-30
			 -- Exit sync_state on interrupt.
			 -- If the interrupts are active
			 -- they will be caught in the state_machine process
			 -- and the interrupt service routine microcode will be executed.
			 -- Masked interrupts will exit the sync_state.
			 -- Moved from the state_machine process to the state_sequencer process
			 --
				if (firq = '1') or (irq = '1') then
               next_state <= fetch_state;
				else
	            next_state <= sync_state;
            end if;

			  when halt_state =>
           --
           -- 2011-10-30 John Kent
           -- ba & bs should be high
             ba           <= '1';
             bs           <= '1';
				 if halt = '1' then
               next_state   <= halt_state;
				 else
               next_state   <= fetch_state;
				 end if;

		  end case;

--
-- Ver 1.23 2011-10-30 John Kent
-- First instruction cycle might be
-- fetch_state
-- halt_state
-- int_nmirq_state
-- int_firq_state
--
        if fic = '1' then
        		   --
					case op_code(7 downto 6) is
					when "10" => -- acca
				     case op_code(3 downto 0) is
					  when "0000" => -- suba
					    left_ctrl  <= acca_left;
					    right_ctrl <= md_right;
					    alu_ctrl   <= alu_sub8;
						 cc_ctrl    <= load_cc;
					    acca_ctrl  <= load_acca;
					  when "0001" => -- cmpa
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_sub8;
						 cc_ctrl     <= load_cc;
					  when "0010" => -- sbca
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_sbc;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "0011" =>
					    case pre_code is
						 when "00010000" => -- page 2 -- cmpd
					      left_ctrl   <= accd_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_sub16;
						   cc_ctrl     <= load_cc;
						 when "00010001" => -- page 3 -- cmpu
					      left_ctrl   <= up_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_sub16;
						   cc_ctrl     <= load_cc;
						 when others => -- page 1 -- subd
					      left_ctrl   <= accd_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_sub16;
						   cc_ctrl     <= load_cc;
					      acca_ctrl   <= load_hi_acca;
						   accb_ctrl   <= load_accb;
						 end case;
					  when "0100" => -- anda
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_and;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "0101" => -- bita
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_and;
						 cc_ctrl     <= load_cc;
					  when "0110" => -- ldaa
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_ld8;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "0111" => -- staa
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_st8;
						 cc_ctrl     <= load_cc;
					  when "1000" => -- eora
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_eor;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "1001" => -- adca
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_adc;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "1010" => -- oraa
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_ora;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "1011" => -- adda
					    left_ctrl   <= acca_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_add8;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_acca;
					  when "1100" =>
					    case pre_code is
						 when "00010000" => -- page 2 -- cmpy
					      left_ctrl   <= iy_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_sub16;
						   cc_ctrl     <= load_cc;
						 when "00010001" => -- page 3 -- cmps
					      left_ctrl   <= sp_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_sub16;
						   cc_ctrl     <= load_cc;
						 when others => -- page 1 -- cmpx
					      left_ctrl   <= ix_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_sub16;
						   cc_ctrl     <= load_cc;
						 end case;
					  when "1101" => -- bsr / jsr
					    null;
					  when "1110" => -- ldx
					    case pre_code is
						 when "00010000" => -- page 2 -- ldy
					      left_ctrl   <= iy_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_ld16;
						   cc_ctrl     <= load_cc;
                     iy_ctrl     <= load_iy;
						 when others =>   -- page 1 -- ldx
					      left_ctrl   <= ix_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_ld16;
						   cc_ctrl     <= load_cc;
                     ix_ctrl     <= load_ix;
						 end case;
					  when "1111" => -- stx
					    case pre_code is
						 when "00010000" => -- page 2 -- sty
					      left_ctrl   <= iy_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_st16;
						   cc_ctrl     <= load_cc;
						 when others =>     -- page 1 -- stx
					      left_ctrl   <= ix_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_st16;
						   cc_ctrl     <= load_cc;
						 end case;
					  when others =>
					    null;
					  end case;
					when "11" => -- accb dual op
				     case op_code(3 downto 0) is
					  when "0000" => -- subb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_sub8;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "0001" => -- cmpb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_sub8;
						 cc_ctrl     <= load_cc;
					  when "0010" => -- sbcb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_sbc;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "0011" => -- addd
					    left_ctrl   <= accd_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_add16;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_hi_acca;
						 accb_ctrl   <= load_accb;
					  when "0100" => -- andb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_and;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "0101" => -- bitb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_and;
						 cc_ctrl     <= load_cc;
					  when "0110" => -- ldab
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_ld8;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "0111" => -- stab
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_st8;
						 cc_ctrl     <= load_cc;
					  when "1000" => -- eorb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_eor;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "1001" => -- adcb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_adc;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "1010" => -- orab
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_ora;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "1011" => -- addb
					    left_ctrl   <= accb_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_add8;
						 cc_ctrl     <= load_cc;
                   accb_ctrl   <= load_accb;
					  when "1100" => -- ldd
					    left_ctrl   <= accd_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_ld16;
						 cc_ctrl     <= load_cc;
					    acca_ctrl   <= load_hi_acca;
                   accb_ctrl   <= load_accb;
					  when "1101" => -- std
					    left_ctrl   <= accd_left;
					    right_ctrl  <= md_right;
					    alu_ctrl    <= alu_st16;
						 cc_ctrl     <= load_cc;
					  when "1110" => -- ldu
					    case pre_code is
						 when "00010000" => -- page 2 -- lds
					      left_ctrl   <= sp_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_ld16;
						   cc_ctrl     <= load_cc;
						   sp_ctrl     <= load_sp;
						 when others => -- page 1 -- ldu
					      left_ctrl   <= up_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_ld16;
						   cc_ctrl     <= load_cc;
                     up_ctrl     <= load_up;
						 end case;
					  when "1111" =>
					    case pre_code is
						 when "00010000" => -- page 2 -- sts
					      left_ctrl   <= sp_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_st16;
						   cc_ctrl     <= load_cc;
						 when others =>     -- page 1 -- stu
					      left_ctrl   <= up_left;
					      right_ctrl  <= md_right;
					      alu_ctrl    <= alu_st16;
						   cc_ctrl     <= load_cc;
						 end case;
					  when others =>
					    null;
					  end case;
					when others =>
					  null;
					end case;

       end if; -- first instruction cycle (fic)
       lic_out <= lic;
end process;

end rtl;

