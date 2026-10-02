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

-- simplified 74LS299 shifter as used in SLAGS
entity LS299 is
	port(
		I_CK   : in  std_logic;                    -- Clock
		I_DATA : in  std_logic_vector(7 downto 0); -- parallel input
		I_SEL  : in  std_logic_vector(1 downto 0); -- S1 S0
		I_SL   : in  std_logic;                    -- SL shift left input
		I_SR   : in  std_logic;                    -- SR shift right input
		O_SL   : out std_logic;                    -- QA shift left output
		O_SR   : out std_logic                     -- QH shift right output
	);
end LS299;

architecture RTL of LS299 is
	signal slv_shifter : std_logic_vector(7 downto 0) := (others=>'0');
begin
	O_SR <= slv_shifter(7);
	O_SL <= slv_shifter(0);

	-- LS299 shifter, datasheet "right" means shift lsb towards msb, "left" is the reverse
	p_shift : process
	begin
		wait until rising_edge(I_CK);
		case I_SEL is
			when "11" => slv_shifter <= I_DATA;                                 -- load
			when "10" => slv_shifter <= I_SL & slv_shifter(7 downto 1);         -- left
			when "01" => slv_shifter <=        slv_shifter(6 downto 0) & I_SR ; -- right
			when "00" =>                                                        -- hold
			when others => null;
		end case;
	end process;
end RTL;
