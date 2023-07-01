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

entity io_module is
    Port (
		clk				: in  STD_LOGIC;
		clk2			: in  STD_LOGIC;
		reset			: in  std_logic;
		reg_value		: out unsigned (7 downto 0);
		reg_we			: out std_logic;
		reg_reg0		: in  unsigned (7 downto 0);
		reg_reg1		: in  unsigned (7 downto 0);
		out_data		: in  unsigned (7 downto 0);
		io_op_in		: in  std_logic;
		io_op_out		: in  std_logic;
		io_op_out_pp	: in  std_logic;
		io_kk_en		: in  std_logic;
		io_kk_port		: in  unsigned (3 downto 0);
		io_kk_data		: in  unsigned (7 downto 0);
		-- actual i/o module ports
		in_port			: in  unsigned (7 downto 0);
		port_id			: out unsigned (7 downto 0);
		out_port		: out unsigned (7 downto 0);
		read_strobe		: out STD_LOGIC;
		write_strobe	: out STD_LOGIC;
		k_write_strobe	: out STD_LOGIC
	);
end io_module;

architecture Behavioral of io_module is

	signal strobe_o : std_logic;

begin

	reg_value		<= in_port;
	read_strobe		<= io_op_in and not clk2;
	write_strobe	<= io_op_out and strobe_o and clk2;
	k_write_strobe	<= io_kk_en and strobe_o and clk2;
	reg_we			<= io_op_in and clk2;

	out_proc : process (reset, out_data, reg_reg0, reg_reg1, io_kk_en, io_kk_port, io_kk_data, io_op_out_pp) begin
		if (reset = '1') then
			port_id <= (others => '0');
			out_port <= (others => '0');
		else
			if (io_kk_en = '1') then
				port_id <= x"0" & io_kk_port;
				out_port <= io_kk_data;
			else
				out_port <= reg_reg0;
				if (io_op_out_pp = '1') then			-- intermediate value pp
					port_id <= out_data;
				else
					port_id <= reg_reg1;
				end if;
			end if;
		end if;
	end process out_proc;

	process (clk) begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				strobe_o <= '0';
			else
				if ((io_op_in or io_op_out or io_kk_en) = '1') then
					strobe_o <= '1';
				else
					strobe_o <= '0';
				end if;
			end if;
		end if;
	end process;

end Behavioral;

