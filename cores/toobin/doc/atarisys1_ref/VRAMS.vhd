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

entity VRAMS is
	port(
		I_MCKR  : in  std_logic;
		I_WEn   : in  std_logic;
		I_VRA   : in  std_logic_vector(12 downto 0);
		I_VRD   : in  std_logic_vector(15 downto 0);
		O_VRD   : out std_logic_vector(15 downto 0)
	);
end VRAMS;

architecture RTL of VRAMS is
	type RAM_ARRAY_8Kx16 is array (0 to 8191) of std_logic_vector(15 downto 0);
	signal RAM : RAM_ARRAY_8Kx16:=(others=>(others=>'0'));

	-- Ask Xilinx synthesis to use block RAMs if possible
	attribute ram_style : string;
	attribute ram_style of RAM : signal is "block";
	-- Ask Quartus synthesis to use block RAMs if possible
	attribute ramstyle : string;
	attribute ramstyle of RAM : signal is "M10K";

begin
	p_VRAM : process
	begin
		wait until rising_edge(I_MCKR);
		if I_WEn = '0' then
			RAM(to_integer(unsigned(I_VRA))) <= I_VRD;
		else
			O_VRD <= RAM(to_integer(unsigned(I_VRA)));
		end if;
	end process;
end RTL;
