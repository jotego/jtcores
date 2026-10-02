--	(c) 2020 d18c7db(a)hotmail
--
--	This program is free software; you can redistribute it and/or modify it under
--	the terms of the GNU General Public License version 3 or, at your option,
--	any later version as published by the Free Software Foundation.
--
--	This program is distributed in the hope that it will be useful,
--	but WITHOUT ANY WARRANTY; without even the implied warranty of
--	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- For full details, see the GNU General Public License at www.gnu.org/licenses
--

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity CRAMS is
	port(
		I_MCKR  : in  std_logic;
		I_WEn   : in  std_logic;
		I_CRA   : in  std_logic_vector( 9 downto 0);
		I_CRD   : in  std_logic_vector(15 downto 0);
		O_CRD   : out std_logic_vector(15 downto 0)
	);
end CRAMS;

architecture RTL of CRAMS is
	type RAM_ARRAY_1Kx16 is array (0 to 1023) of std_logic_vector(15 downto 0);
	signal RAM : RAM_ARRAY_1Kx16:=(others=>(others=>'0'));
	-- Ask Xilinx synthesis to use block RAMs if possible
	attribute ram_style : string;
	attribute ram_style of RAM : signal is "block";
	-- Ask Quartus synthesis to use block RAMs if possible
	attribute ramstyle : string;
	attribute ramstyle of RAM : signal is "M10K";

begin
	p_CRAM : process
	begin
		wait until rising_edge(I_MCKR);
		if I_WEn = '0' then
			RAM(to_integer(unsigned(I_CRA))) <= I_CRD;
		else
			O_CRD <= RAM(to_integer(unsigned(I_CRA)));
		end if;
	end process;
end RTL;
