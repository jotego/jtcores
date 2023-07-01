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
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity pauloBlaze is
	generic (
		debug : boolean := false;
		hwbuild : unsigned(7 downto 0) := X"00";
		interrupt_vector : unsigned(11 downto 0) := X"3FF";
		scratch_pad_memory_size : integer := 64;
		stack_depth : positive := 30
	);
	port (
		-- control
		clk : in std_logic;
		reset : in std_logic;
		sleep : in std_logic;
		-- instruction memory
		address : out std_logic_vector(11 downto 0);
		instruction : in std_logic_vector(17 downto 0);
		bram_enable : out std_logic;
		-- i/o ports
		in_port : in std_logic_vector(7 downto 0);
		out_port : out std_logic_vector(7 downto 0);
		port_id : out std_logic_vector(7 downto 0);
		write_strobe : out std_logic;
		k_write_strobe : out std_logic;
		read_strobe : out std_logic;
		-- interrupts
		interrupt : in std_logic;
		interrupt_ack : out std_logic
	);
end pauloBlaze;
architecture Behavioral of pauloBlaze is

	signal clk2 : std_logic := '1'; -- high during 2nd clk cycle

	-- used for converting from slv to my internal unsigned
	signal address_u		: unsigned(11 downto 0);
	signal instruction_u	: unsigned(17 downto 0);
	signal in_port_u		: unsigned(7 downto 0);
	signal out_port_u		: unsigned(7 downto 0);
	signal port_id_u		: unsigned(7 downto 0);

	-- signals alu in
	signal opcode : unsigned(5 downto 0);
	signal opA : unsigned(3 downto 0);
	signal opB : unsigned(7 downto 0);
	-- signals alu out
	signal carry : STD_LOGIC;
	signal zero : STD_LOGIC;

	-- signals pc in
	signal rst_req : STD_LOGIC;
	signal ret : STD_LOGIC;
	signal call : STD_LOGIC;
	signal jump : STD_LOGIC;
	signal jmp_addr : unsigned (11 downto 0);

	-- signals decoder
	signal reset_int : std_logic;
	signal reset_bram_en : std_logic;
	signal io_op_in : std_logic;
	signal io_op_out : std_logic; 
	signal io_op_out_pp : std_logic; 
	signal io_kk_en : std_logic;
	signal io_kk_port : unsigned (3 downto 0);
	signal io_kk_data : unsigned (7 downto 0);
	signal spm_addr_ss : unsigned (7 downto 0);
	signal spm_ss : std_logic;
	signal spm_we : std_logic;
	signal spm_rd : std_logic;
	signal inter_j : std_logic;
	signal sleep_int : std_logic;
	signal bram_pause : std_logic;
	signal clk2_reset : std_logic;
	signal preserve_flags : std_logic;
	signal restore_flags : std_logic;
 
	-- general register file signals
	signal reg_select : std_logic;
	signal reg_star : std_logic;
	signal reg_reg0 : unsigned (7 downto 0);
	signal reg_reg1 : unsigned (7 downto 0);
	signal reg_address : unsigned (7 downto 0); 
	signal reg_value : unsigned (7 downto 0);
	signal reg_we : std_logic;
	-- signals register file from alu
	signal reg_value_a : unsigned (7 downto 0);
	signal reg_we_a : std_logic;
	-- signals register file from io
	signal reg_value_io : unsigned (7 downto 0);
	signal reg_we_io : std_logic;

 
begin
	bram_enable <= clk2 and not bram_pause when reset_int = '0' else reset_bram_en;
	-- in case of a reset there is a state where reset_bram_en will be high for one clk cycle, just before
	-- the internal reset will be deasserted
 
	clk2_gen : process (clk) begin
		if (rising_edge(clk)) then
			if (clk2_reset = '1') then
				clk2 <= '1';
			else
				clk2 <= not clk2;
			end if;
		end if; 
	end process clk2_gen;
	
	address			<= std_logic_vector(address_u);
	instruction_u	<= unsigned(instruction);
	in_port_u		<= unsigned(in_port);
	out_port		<= std_logic_vector(out_port_u);
	port_id			<= std_logic_vector(port_id_u);

	pc : entity work.program_counter 
		generic map(
			interrupt_vector => interrupt_vector,
			stack_depth => stack_depth
		)
		port map(
			clk         => clk, 
			reset       => reset_int, 
			rst_req     => rst_req, 
			bram_pause  => bram_pause, 
			call        => call, 
			ret         => ret, 
			inter_j     => inter_j, 
			jump        => jump, 
			jmp_addr    => jmp_addr, 
			address     => address_u 
		);

	-- alu
	alu_inst : entity work.pauloALU
		generic map(
			hwbuild	=> hwbuild, 
			debug 	=> debug
		)
		port map(
			clk               => clk, 
			clk2              => clk2, 
			reset             => reset_int, 
			sleep_int         => sleep_int, 
			opcode            => opcode, 
			-- opA => opA,
			opB               => opB, 
			preserve_flags    => preserve_flags, 
			restore_flags     => restore_flags, 
			carry             => carry, 
			zero              => zero, 
			reg_value         => reg_value_a, 
			reg_we            => reg_we_a, 
			reg_reg0          => reg_reg0, 
			reg_reg1          => reg_reg1
		);

	decoder_inst : entity work.decoder
		generic map(
			interrupt_vector  => interrupt_vector
		)
		port map(
			clk                      => clk, 
			clk2                     => clk2, 
			reset                    => reset, 
			reset_int                => reset_int, 
			reset_bram_en            => reset_bram_en, 
			rst_req                  => rst_req, 
			sleep                    => sleep, 
			sleep_int                => sleep_int, 
			bram_pause               => bram_pause, 
			clk2_reset               => clk2_reset, 
			interrupt                => interrupt, 
			interrupt_ack            => interrupt_ack, 
			instruction              => instruction_u, 
			opcode                   => opcode, 
			opA                      => opA, 
			opB                      => opB, 
			reg0                     => reg_reg0, 
			reg1                     => reg_reg1, 
			carry                    => carry, 
			zero                     => zero, 
			call                     => call, 
			ret                      => ret, 
			inter_j                  => inter_j, 
			preserve_flags           => preserve_flags, 
			restore_flags            => restore_flags, 
			jmp_addr                 => jmp_addr, 
			jump                     => jump, 
			io_op_in                 => io_op_in, 
			io_op_out                => io_op_out, 
			io_op_out_pp             => io_op_out_pp, 
			io_kk_en                 => io_kk_en, 
			io_kk_port               => io_kk_port, 
			io_kk_data               => io_kk_data, 
			reg_address              => reg_address, 
			reg_select               => reg_select, 
			reg_star                 => reg_star, 
			spm_addr_ss              => spm_addr_ss, 
			spm_ss                   => spm_ss, 
			spm_we                   => spm_we, 
			spm_rd                   => spm_rd
		);

	reg_value <= reg_value_io when (io_op_in or io_op_out) = '1' else reg_value_a when reg_we_a = '1' else reg_reg0;
	reg_we <= reg_we_io or reg_we_a or reg_star or spm_rd;

	register_file : entity work.reg_file
		generic map(
			scratch_pad_memory_size  => scratch_pad_memory_size
		)
		port map(
			clk          => clk,
			reg_address  => reg_address, 
			reg_select   => reg_select, 
			reg_star     => reg_star, 
			value        => reg_value, 
			write_en     => reg_we, 
			reg0         => reg_reg0, 
			reg1         => reg_reg1, 
			spm_addr_ss  => spm_addr_ss, 
			spm_ss       => spm_ss, 
			spm_we       => spm_we, 
			spm_rd       => spm_rd
		);

	io_inst : entity work.io_module
		port map(
			clk             => clk, 
			clk2            => clk2, 
			reset           => reset_int, 
			reg_value       => reg_value_io, 
			reg_we          => reg_we_io, 
			reg_reg0        => reg_reg0, 
			reg_reg1        => reg_reg1, 
			out_data        => opB, 
			io_op_in        => io_op_in, 
			io_op_out       => io_op_out, 
			io_op_out_pp    => io_op_out_pp, 
			io_kk_en        => io_kk_en, 
			io_kk_port      => io_kk_port, 
			io_kk_data      => io_kk_data, 
			-- actual i/o module ports
			in_port         => in_port_u, 
			port_id         => port_id_u, 
			out_port        => out_port_u, 
			read_strobe     => read_strobe, 
			write_strobe    => write_strobe, 
			k_write_strobe  => k_write_strobe
		);

end Behavioral;
