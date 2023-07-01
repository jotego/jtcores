-- EMACS settings: -*- tab-width: 4; indent-tabs-mode: t -*-
-- vim: tabstop=4:shiftwidth=4:noexpandtab
-- kate: tab-width 4; replace-tabs off; indent-width 4;
--
-- =============================================================================
-- Authors: Paul Genssler
--
-- Description:
-- ------------------------------------
-- TODO
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Paul Genssler - Dresden, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS is" BASIS,
-- WITHOUT WARRANTIES or CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.op_codes.all;

entity decoder is
	generic (
		interrupt_vector : unsigned(11 downto 0) := X"3FF"
	);
	Port (
		clk				: in	STD_LOGIC;
		clk2			: in	STD_LOGIC;
		reset			: in	STD_LOGIC;
		reset_int		: out	STD_LOGIC;
		reset_bram_en	: out	STD_LOGIC;
		rst_req			: in	std_logic;
		sleep			: in	STD_LOGIC;
		sleep_int		: out	STD_LOGIC;
		bram_pause		: out	STD_LOGIC;
		clk2_reset		: out	STD_LOGIC;
		interrupt		: in	STD_LOGIC;
		interrupt_ack	: out	STD_LOGIC;
		instruction		: in	unsigned (17 downto 0);
		opCode			: out	unsigned (5 downto 0);
		opA				: out	unsigned (3 downto 0);
		opB				: out	unsigned (7 downto 0);
		reg0			: in	unsigned (7 downto 0);
		reg1			: in	unsigned (7 downto 0);
		carry			: in	STD_LOGIC;
		zero			: in	STD_LOGIC;
		call			: out	STD_LOGIC;
		ret				: out	std_logic;
		inter_j			: out	std_logic;
		preserve_flags	: out	std_logic;
		restore_flags	: out	std_logic;
		jump			: out	STD_LOGIC;
		jmp_addr		: out	unsigned (11 downto 0);
		io_op_in		: out	std_logic;
		io_op_out		: out	std_logic;
		io_op_out_pp	: out	std_logic;
		io_kk_en		: out	std_logic;
		io_kk_port		: out	unsigned (3 downto 0);
		io_kk_data		: out	unsigned (7 downto 0);
		reg_address		: out	unsigned (7 downto 0);
		reg_select		: out	std_logic;
		reg_star		: out	std_logic;
		spm_addr_ss		: out	unsigned (7 downto 0);
		spm_ss			: out	std_logic;				-- 0: spm_addr = reg1, 1: spm_addr = spm_addr_ss		
		spm_we			: out	std_logic;
		spm_rd			: out	std_logic
	);
end decoder;

architecture Behavioral of decoder is
	
	signal clk2_reset_sleep : std_logic;
	signal clk2_reset_reset : std_logic;
	signal reset_int_o	: std_logic;
	signal reset_r		: std_logic;
	signal reg_select_o : std_logic;
	signal reg_select_i	: std_logic;
	signal opCode_o		: unsigned (5 downto 0);
	signal fetch		: std_logic;
	signal store		: std_logic;
	signal inter_en		: std_logic;
	signal inter_j_o	: std_logic;
	signal inter_block_regs	: std_logic;
	signal preserve_flags_o : std_logic;
	signal restore_flags_o	: std_logic;
	signal instr_used	: unsigned (17 downto 0);
	signal sleep_int_o	: std_logic;
	signal reg_sel_save	: std_logic;
	signal sxy_addr		: std_logic;
	
	signal bram_pause_sleep : std_logic;
	signal bram_pause_reset : std_logic;
	
	type sleep_state_t is (awake, sleeping, dawn, sunrise);
	signal sleep_state : sleep_state_t;
	
	type interrupt_state_t is (none, detected, inter_ack, interrupting, int_end);
	signal inter_state : interrupt_state_t;
	signal inter_state_nxt : interrupt_state_t;

	type reset_state_t is (none, detected, finishing, holding, bram_en);
	signal reset_state : reset_state_t;
	signal reset_state_nxt : reset_state_t;

begin
	reset_int	<= reset_int_o;
	clk2_reset  <= clk2_reset_sleep or clk2_reset_reset;
	bram_pause  <= bram_pause_sleep or bram_pause_reset;
	
	opCode		<= opCode_o;
	opCode_o	<= instr_used(17 downto 12);
	opA			<= instr_used(11 downto 8);
	opB			<= instr_used(7 downto 0);
	jmp_addr	<= instr_used(11 downto 0) when sxy_addr = '0' else reg0(3 downto 0) & reg1;

	reg_address	<= instr_used(11 downto 4);
	reg_select	<= reg_select_o;
	
	spm_addr_ss	<= instr_used(7 downto 0);
	spm_ss 		<= opCode_o(0);
	spm_rd 		<= fetch;	
	
	io_op_out_pp	<= instr_used(12);			-- constant value (pp) or register as data on the output
	io_kk_data		<= instr_used(11 downto 4);
	io_kk_port		<= instr_used(3 downto 0);
	
	sleep_int		<= sleep_int_o or inter_block_regs;
	inter_j			<= inter_j_o;
	
	restore_flags	<= restore_flags_o;

	decompose : process (instr_used, reset_int_o, zero, carry, opCode_o) 
	begin
		jump <= '0';
		sxy_addr <= '0';
		call <= '0';
		ret <= '0';
		io_op_in <= '0';
		io_op_out <= '0';
		io_kk_en <= '0';
		fetch <= '0';
		store <= '0';
		
		if (reset_int_o = '0') then
			case opCode_o is
			when OP_JUMP_AAA => 
				jump <= '1';
			when OP_JUMP_SX_SY =>
				jump <= '1';
				sxy_addr <= '1';
			when OP_JUMP_Z_AAA | OP_JUMP_NZ_AAA =>
				jump <= zero xor instr_used(14);	-- inst(14) == opCode_o(2): 0 -> Z; 1 -> NZ
			when OP_JUMP_C_AAA | OP_JUMP_NC_AAA =>
				jump <= carry xor instr_used(14);	-- inst(14) == opCode_o(2): 0 -> C; 1 -> NC
			when OP_CALL_AAA =>
				call <= '1';
			when OP_CALL_SX_SY =>
				call <= '1';
				sxy_addr <= '1';
			when OP_CALL_Z_AAA | OP_CALL_NZ_AAA =>
				call <= zero xor instr_used(14);	-- inst(14) == opCode_o(2): 0 -> Z; 1 -> NZ
			when OP_CALL_C_AAA | OP_CALL_NC_AAA =>
				call <= carry xor instr_used(14);	-- inst(14) == opCode_o(2): 0 -> C; 1 -> NC
			when OP_RETURN | OP_RETURNI_DISABLE | OP_LOADRETURN_SX_KK =>
				ret <= '1';
			when OP_RETURN_Z | OP_RETURN_NZ =>
				ret <= zero xor instr_used(14);	-- inst(14) == opCode_o(2): 0 -> Z; 1 -> NZ
			when OP_RETURN_C | OP_RETURN_NC =>
				ret <= carry xor instr_used(14);	-- inst(14) == opCode_o(2): 0 -> C; 1 -> NC
			when OP_INPUT_SX_SY | OP_INPUT_SX_PP =>
				io_op_in <= '1';
			when OP_OUTPUT_SX_SY | OP_OUTPUT_SX_PP =>
				io_op_out <= '1';
			when OP_OUTPUTK_KK_P =>
				io_kk_en <= '1';
			when OP_FETCH_SX_SY | OP_FETCH_SX_SS =>
--				spm_rd <= '1';
				fetch <= '1';
			when OP_STORE_SX_SY | OP_STORE_SX_SS =>
--				spm_we <= '1';
				store <= '1';				
			when others =>

			end case;
		end if;
	end process decompose;

	reg_proc : process (clk) begin
		if (rising_edge(clk)) then
			if (reset_int_o = '1') then 
				reg_select_o <= '0';
				reg_sel_save <= '0';
			else
				reg_star <= '0';
				spm_we 		<= store and not clk2;
				
				if (preserve_flags_o = '1') then
					reg_sel_save <= reg_select_o;
				elsif (restore_flags_o = '1') then
					reg_select_o <= reg_sel_save;
				elsif (opCode_o = OP_REGBANK_A) then
					reg_select_o <= instr_used(0);
				elsif (opCode_o = OP_STAR_SX_SY) then
					reg_select_o <= not reg_select_o;
					reg_star <= '1';
				end if;
			end if;
		end if;
	end process reg_proc;

	inter_en_p : process (clk) begin
		if (rising_edge(clk)) then
			if (reset_int_o = '1') then 
				inter_en <= '0';
			else
				if (opCode_o = OP_ENABLE_INTERRUPT or opCode_o = OP_RETURNI_ENABLE) then
					inter_en <= instr_used(0);			-- bit 0 contains set/erase
				else
					inter_en <= inter_en;
				end if;
			end if;
		end if;
	end process inter_en_p;
	
	inter_state_com_p : process (inter_state, instruction, interrupt, inter_en, clk2, opCode_o) begin
		inter_state_nxt <= inter_state;
		instr_used <= instruction;
		preserve_flags_o <= '0';
		inter_j_o <= '0';
		interrupt_ack <= '0';
		inter_block_regs <= '0';
		restore_flags_o <= '0';
		
		case (inter_state) is
		when none => 
			if (interrupt = '1') then
				inter_state_nxt <= detected;
			end if;
		when detected => 
			if (inter_en = '1' and clk2 = '0') then
				inter_block_regs <= '1';
				inter_state_nxt <= inter_ack;
			end if;
		when inter_ack => 
			instr_used <= (others => '0');
			preserve_flags_o <= '1';
			interrupt_ack <= '1';
			inter_block_regs <= '1';
			inter_j_o <= '1';
			inter_state_nxt <= interrupting;
		when interrupting => 
			if (opCode_o = OP_RETURNI_ENABLE and clk2 = '1') then
				inter_state_nxt <= int_end;
				restore_flags_o <= '1';
			end if;
		when int_end => 
			inter_state_nxt <= none;
		end case;
	end process inter_state_com_p;
	
	inter_state_clk_p : process (clk) begin
		if (rising_edge(clk)) then
			if (reset_int_o = '1') then
				inter_state <= none;	
			else 
				if (sleep = '0') then 
					inter_state <= inter_state_nxt;	
					preserve_flags	<= preserve_flags_o;
				end if;
			end if;
		end if;
	end process inter_state_clk_p;
	

	sleep_sm : process (clk) begin
		if (rising_edge(clk)) then
			if (reset_int_o = '1') then 
				sleep_state <= awake;
				bram_pause_sleep <= '0';
				sleep_int_o <= '0';
				clk2_reset_sleep <= '0';
			else
				bram_pause_sleep <= '0';
				sleep_int_o <= '0';
				clk2_reset_sleep <= '0';
				case sleep_state is
				when awake =>
					if (sleep = '1') then
						sleep_state <= sleeping;
					end if;
				when sleeping =>
					bram_pause_sleep <= '1';
					sleep_int_o <= '1';
					if (sleep = '0') then
						clk2_reset_sleep <= '1';
						sleep_int_o <= '0';
						sleep_state <= dawn;
						
						if (clk2 = '1') then
							bram_pause_sleep <= '0';
						end if;
					end if;
				when dawn =>
					sleep_state <= sunrise;
				when sunrise =>
					sleep_int_o <= '1';
					if (clk2 = '1') then
						sleep_int_o <= '0';
						sleep_state <= awake;
					end if;
				end case;
			end if;
		end if;	
	end process sleep_sm;


	rst_state_com_p : process (reset, rst_req, reset_state) begin
		reset_state_nxt <= reset_state;
		reset_int_o <= '0';
		bram_pause_reset <= '0';
		reset_bram_en <= '0';
		clk2_reset_reset <= '0';
		case (reset_state) is 
			when none => 
				if (reset = '1') then
					reset_state_nxt <= detected;
				elsif (rst_req = '1') then
					reset_state_nxt <= holding;
				end if;
			when detected =>
				bram_pause_reset <= '1';
				reset_int_o <= '1';
				if (reset = '0') then
					reset_state_nxt <= finishing;
				end if;
			when finishing =>
				bram_pause_reset <= '1';
				reset_int_o <= '1';
				reset_state_nxt <= holding;
			when holding =>
				bram_pause_reset <= '1';
				reset_int_o <= '1';
				clk2_reset_reset <= '1';
				reset_state_nxt <= bram_en;
			when bram_en =>
				reset_int_o <= '1';
				reset_bram_en <= '1';
				reset_state_nxt <= none;
		end case;
	end process rst_state_com_p;
	
	rst_state_clk_p : process (clk) begin
		if (rising_edge(clk)) then
			reset_state <= reset_state_nxt;
		end if;
	end process rst_state_clk_p;

end Behavioral;
