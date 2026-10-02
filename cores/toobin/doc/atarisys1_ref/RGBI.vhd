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

-- RGBI to RGB lookup table
-- Implements function (Intensity * Color) / 16 rounded to nearest integer
entity RGBI is
	port(
		ADDR : in  std_logic_vector(7 downto 0);
		DATA : out std_logic_vector(3 downto 0)
	);
end RGBI;

architecture RTL of RGBI is
	type ROM_ARRAY is array (0 to 255) of std_logic_vector(3 downto 0);
	signal ROM : ROM_ARRAY := (
		x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0",
		x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"1", x"1", x"1", x"1", x"1", x"1", x"1", x"1",
		x"0", x"0", x"0", x"0", x"1", x"1", x"1", x"1", x"1", x"1", x"1", x"1", x"2", x"2", x"2", x"2",
		x"0", x"0", x"0", x"1", x"1", x"1", x"1", x"1", x"2", x"2", x"2", x"2", x"2", x"3", x"3", x"3",
		x"0", x"0", x"1", x"1", x"1", x"1", x"2", x"2", x"2", x"2", x"3", x"3", x"3", x"3", x"4", x"4",
		x"0", x"0", x"1", x"1", x"1", x"2", x"2", x"2", x"3", x"3", x"3", x"4", x"4", x"4", x"5", x"5",
		x"0", x"0", x"1", x"1", x"2", x"2", x"2", x"3", x"3", x"4", x"4", x"4", x"5", x"5", x"6", x"6",
		x"0", x"0", x"1", x"1", x"2", x"2", x"3", x"3", x"4", x"4", x"5", x"5", x"6", x"6", x"7", x"7",
		x"0", x"1", x"1", x"2", x"2", x"3", x"3", x"4", x"4", x"5", x"5", x"6", x"6", x"7", x"7", x"8",
		x"0", x"1", x"1", x"2", x"2", x"3", x"4", x"4", x"5", x"5", x"6", x"7", x"7", x"8", x"8", x"9",
		x"0", x"1", x"1", x"2", x"3", x"3", x"4", x"5", x"5", x"6", x"7", x"7", x"8", x"9", x"9", x"A",
		x"0", x"1", x"1", x"2", x"3", x"4", x"4", x"5", x"6", x"7", x"7", x"8", x"9", x"A", x"A", x"B",
		x"0", x"1", x"2", x"2", x"3", x"4", x"5", x"6", x"6", x"7", x"8", x"9", x"A", x"A", x"B", x"C",
		x"0", x"1", x"2", x"3", x"3", x"4", x"5", x"6", x"7", x"8", x"9", x"A", x"A", x"B", x"C", x"D",
		x"0", x"1", x"2", x"3", x"4", x"5", x"6", x"7", x"7", x"8", x"9", x"A", x"B", x"C", x"D", x"E",
		x"0", x"1", x"2", x"3", x"4", x"5", x"6", x"7", x"8", x"9", x"A", x"B", x"C", x"D", x"E", x"F"
	);
	attribute ram_style : string; -- for Xilinx ISE
	attribute ram_style of ROM : signal is "distributed";
	attribute ramstyle : string; -- for Intel Quartus
	attribute ramstyle of ROM : signal is "logic";
begin
--	rgbi_proc : process(ADDR)
--	begin
		DATA <= ROM(to_integer(unsigned(ADDR)));
--	end process;
end RTL;
