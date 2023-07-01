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

library work;
use	work.op_codes.all;

entity reg_file is
	generic (
		debug	: boolean := false;
		scratch_pad_memory_size	: integer := 64
	);
	port (
		clk			: in std_logic;
		value		: in unsigned (7 downto 0);
		write_en	: in std_logic;
		reg0		: out unsigned (7 downto 0);
		reg1		: out unsigned (7 downto 0);
		reg_address	: in unsigned (7 downto 0);
		reg_select	: in std_logic;
		reg_star	: in std_logic;
		spm_addr_ss	: in unsigned (7 downto 0);
		spm_ss		: in std_logic;				-- 0: spm_addr = reg1, 1: spm_addr = spm_addr_ss
		spm_we		: in std_logic;
		spm_rd		: in std_logic
	);
end reg_file;

architecture Behavioral of reg_file is

	-- Logarithms: log*ceil*
	-- From PoC-Library https://github.com/VLSI-EDA/PoC
	-- ==========================================================================
	function log2ceil(arg : positive) return natural is
	variable tmp : positive   := 1;
	variable log : natural    := 0;
	begin
	if arg = 1 then return 0; end if;
	while arg > tmp loop
	  tmp := tmp * 2;
	  log := log + 1;
	end loop;
	return log;
	end function;
	
	type reg_file_t is array (31 downto 0) of unsigned(7 downto 0);
	signal reg 			: reg_file_t := (others=>(others=>'0'));

	type scratchpad_t is array(integer range <>) of unsigned(7 downto 0);
	signal scratchpad	: scratchpad_t((scratch_pad_memory_size-1) downto 0) := (others=>(others=>'0')); 
 
	constant spm_addr_width	: integer := log2ceil(scratch_pad_memory_size);	-- address failsafes into a truncated one
	signal spm_addr		: unsigned ( spm_addr_width-1 downto 0);
	
	signal spm_read		: unsigned (7 downto 0);
	
	signal reg0_buf		: unsigned ( 7 downto 0);
	signal reg0_o		: unsigned ( 7 downto 0);

	signal reg1_buf		: unsigned ( 7 downto 0);
	signal reg1_o		: unsigned ( 7 downto 0);
	signal reg_wr_data	: unsigned ( 7 downto 0);
begin

	reg0 			<= reg0_o;
	reg1			<= reg1_o;
	reg_wr_data 	<= spm_read when spm_rd = '1' else value when reg_star = '0' else reg1_buf;
	
	spm_addr		<= spm_addr_ss(spm_addr_width -1 downto 0) when spm_ss = '1' else reg1_buf(spm_addr_width -1 downto 0);
	
	spm_read		<= scratchpad(to_integer(spm_addr));
	reg0_o			<= reg(to_integer(reg_select & reg_address(7 downto 4)));
	reg1_o			<= reg(to_integer(reg_select & reg_address(3 downto 0)));
	
	write_reg : process (clk) begin
		if rising_edge(clk) then
			if (write_en = '1') then
				reg(to_integer(reg_select & reg_address(7 downto 4))) <= reg_wr_data;
			end if;
		end if;
	end process write_reg;
	
	write_spm : process (clk) begin
		if rising_edge(clk) then
			if (spm_we = '1') then
				scratchpad(to_integer(spm_addr)) <=  reg0_buf;
			end if;
		end if;
	end process write_spm;

	buf_reg0_p : process (clk) begin
		if rising_edge(clk) then
			reg0_buf <= reg0_o;
			reg1_buf <= reg1_o;
		end if;
	end process buf_reg0_p;

end Behavioral;

