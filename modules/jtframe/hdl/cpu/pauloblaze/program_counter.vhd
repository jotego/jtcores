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

entity program_counter is
	generic (
		interrupt_vector : unsigned(11 downto 0) := X"3FF";
		stack_depth : positive := 30
	);
	Port (
		clk			: in  STD_LOGIC;
		reset		: in  STD_LOGIC;
		rst_req		: out std_logic;
		bram_pause	: in  STD_LOGIC;
		call		: in  STD_LOGIC;
		ret			: in  std_logic;
		inter_j		: in  std_logic;
		jump		: in  STD_LOGIC;
		jmp_addr	: in  unsigned (11 downto 0);
		address		: out unsigned (11 downto 0));
end program_counter;

architecture Behavioral of program_counter is

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

	type stack_t is array (stack_depth-1 downto 0) of unsigned(11 downto 0);
	signal stack	: stack_t := (others => (others => '0'));
	signal pointer	: unsigned (log2ceil(stack_depth+1)-1 downto 0);
	signal counter	: unsigned (12 downto 0);
	signal jmp_int	: std_logic;
	signal jmp_done	: std_logic;
	signal addr_o	: unsigned (11 downto 0);

begin

	jmp_int <= jump or call or inter_j;
	address	<= interrupt_vector when inter_j = '1' else addr_o ;

	clken : process (clk) 
		variable p : unsigned(pointer'left+1 downto 0);
		variable addr_next : unsigned (11 downto 0);
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				counter <= x"001" & '0';
				addr_o <= (others => '0');
				jmp_done <= '0';
				pointer <= (others => '0');
				rst_req <= '0';
			else
				if (bram_pause = '1') then
					-- counter <= addr_o & '1';
					jmp_done <= jmp_done;
					-- addr_o <= counter(12 downto 1);
				elsif (ret = '1' and jmp_done <= '0') then
					p := ('0' & pointer) - 1;
					if (p = (p'range => '1')) then
						rst_req <= '1';
					else
						pointer <= p(pointer'range);
						addr_next := stack(to_integer(p));
						counter <= addr_next & '1';
						addr_o <= addr_next;
						jmp_done <= '1';
					end if;
				elsif (inter_j = '1') then
					p := ('0' & pointer) + 1;
					if (p > stack_depth) then
						rst_req <= '1';
					else
						stack(to_integer(pointer)) <= addr_o-1;
						pointer <= p(pointer'range);
						counter <= (interrupt_vector & '1') + ("" & '1');
						addr_o <= interrupt_vector;
						jmp_done <= '1';
					end if;
				elsif (jmp_int = '1' and jmp_done <= '0') then
					if (call = '1') then
						p := ('0' & pointer) +1;
						if (p > stack_depth) then
							rst_req <= '1';
						else
							stack(to_integer(pointer)) <= addr_o+1;
							pointer <= p(pointer'range);
						end if;
					end if;
					counter <= jmp_addr & '1';
					addr_o <= jmp_addr;
					jmp_done <= '1';			
				else
					jmp_done <= '0';
					counter <= counter + 1;
					addr_o <= counter(12 downto 1);
				end if;
			end if;
		end if;	
	end process clken;

end Behavioral;

