-- eightthirtytwo_aligner_le.vhd
-- Copyright 2020 by Alastair M. Robinson

-- This file is part of the EightThirtyTwo CPU project.

-- EightThirtyTwo is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- EightThirtyTwo is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with EightThirtyTwo.  If not, see <https://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Little endian variant

entity eightthirtytwo_aligner_le is
port(
	d : in std_logic_vector(31 downto 0);
	q : out std_logic_vector(31 downto 0);
	addr : in std_logic_vector(1 downto 0);
	load_store : in std_logic; -- 1 for load, 0 for store
	mask : out std_logic_vector(3 downto 0);
	mask2 : out std_logic_vector(3 downto 0);
	byteop : in std_logic;
	halfwordop : in std_logic
);
end entity;

architecture rtl of eightthirtytwo_aligner_le is

signal shift : std_logic_vector(1 downto 0);
signal key : std_logic_vector(4 downto 0);

begin

	key<=load_store&halfwordop&byteop&addr; -- Just a convenient alias; will be optmised out.

	-- First figure out the shift amount and masks from the lower two address bits.

	with key select shift <=
		-- full word load:
		"00" when "10000",
		"11" when "10001",
		"10" when "10010",
		"01" when "10011",
		-- byte load:
		"00" when "10100",
		"11" when "10101",
		"10" when "10110",
		"01" when "10111",
		-- halfword load:
		"00" when "11000",
		"11" when "11001",
		"10" when "11010",
		"01" when "11011",
		
		-- full word store:
		"00" when "00000",
		"01" when "00001",
		"10" when "00010",
		"11" when "00011",
		-- byte store:
		"00" when "00100",
		"01" when "00101",
		"10" when "00110",
		"11" when "00111",
		-- halfword store:
		"00" when "01000",
		"01" when "01001",
		"10" when "01010",
		"11" when "01011",

		"--" when others;

		
	-- First word's mask

	with key select mask <=
		-- Full word load:
		"1111" when "10000",
		"0111" when "10001",
		"0011" when "10010",
		"0001" when "10011",
		-- byte load:
		"0001" when "10100",
		"0001" when "10101",
		"0001" when "10110",
		"0001" when "10111",
		-- halfword load:
		"0011" when "11000",
		"0011" when "11001",
		"0011" when "11010",
		"0001" when "11011",
		
		-- Full word store:
		"1111" when "00000",
		"1110" when "00001",
		"1100" when "00010",
		"1000" when "00011",
		-- byte store:
		"0001" when "00100",
		"0010" when "00101",
		"0100" when "00110",
		"1000" when "00111",
		-- halfword store:
		"0011" when "01000",
		"0110" when "01001",
		"1100" when "01010",
		"1000" when "01011",

		"----" when others;


	-- Second word's mask
		
	with key select mask2 <= 
		-- Full word load:
		"0000" when "10000",
		"1000" when "10001",
		"1100" when "10010",
		"1110" when "10011",
		-- byte load:
		"0000" when "10100",
		"0000" when "10101",
		"0000" when "10110",
		"0000" when "10111",
		-- halfword accesses:
		"0000" when "11000",
		"0000" when "11001",
		"0000" when "11010",
		"0010" when "11011",
		
		-- Full word store:
		"0000" when "00000",
		"0001" when "00001",
		"0011" when "00010",
		"0111" when "00011",
		-- byte store:
		"0000" when "00100",
		"0000" when "00101",
		"0000" when "00110",
		"0000" when "00111",
		-- halfword store:
		"0000" when "01000",
		"0000" when "01001",
		"0000" when "01010",
		"0001" when "01011",

		"----" when others;

	-- Now do the actual shifting...
	
	with shift select q(31 downto 24) <= 
		d(31 downto 24) when "00",
		d(23 downto 16) when "01",
		d(15 downto 8) when "10",
		d(7 downto 0) when "11",
		(others=>'-') when others;
		

	with shift select q(23 downto 16) <= 
		d(23 downto 16) when "00",
		d(15 downto 8) when "01",
		d(7 downto 0) when "10",
		d(31 downto 24) when "11",
		(others => '-') when others;

	with shift select q(15 downto 8) <= 
		d(15 downto 8) when "00",
		d(7 downto 0) when "01",
		d(31 downto 24) when "10",
		d(23 downto 16) when "11",
		(others => '-') when others;

	with shift select q(7 downto 0) <= 
		d(7 downto 0) when "00",
		d(31 downto 24) when "01",
		d(23 downto 16) when "10",
		d(15 downto 8) when "11",
		(others => '-') when others;
		
end architecture;
