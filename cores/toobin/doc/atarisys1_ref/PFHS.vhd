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
-- Play Field Horizontal Scroll (Atari custom chip 137419-104)
--	This PFHS was derived from System I SP-277 schematic

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity PFHS is
	port(
		I_CK     : in  std_logic;                    -- MCKR
		I_ST     : in  std_logic;                    -- PFHST
		I_CTF    : in  std_logic;                    -- CTF (when '1' inverts O_PFH)
		I_421H   : in  std_logic_vector(2 downto 0); -- 4H 2H 1H
		I_HS     : in  std_logic;                    -- HSCRLD
		I_SPC    : in  std_logic;                    -- PFSPC
		I_D      : in  std_logic_vector(8 downto 0); -- VBD
		I_PS     : in  std_logic_vector(7 downto 0); -- PFSR

		O_PFM    : out std_logic;                    -- PFSC/MO
		O_PFH    : out std_logic_vector(5 downto 0); -- PF8H..PH256H
		O_XP     : out std_logic_vector(7 downto 0)  -- PFX
	);
end PFHS;

architecture RTL of PFHS is
	type RAM_ARRAY is array (0 to 7) of std_logic_vector(7 downto 0);
	signal
		RAM_4M_5M_addr
								: std_logic_vector(2 downto 0) := (others=>'1');
	signal
		slv_8E_9B
								: std_logic_vector(5 downto 0) := (others=>'1');
	signal
		slv_4D
								: std_logic_vector(7 downto 0) := (others=>'1');
	signal
		slv_10F,
		slv_11E
								: std_logic_vector(8 downto 0) := (others=>'1');
begin
	O_PFH <= slv_8E_9B when I_CTF = '0' else not slv_8E_9B;
	O_XP	<= slv_4D;

	-- 10F and 1B latches
	p_10F_1B : process
	begin
		-- until rising edge I_HS in schema
		wait until rising_edge(I_CK);
		if (I_HS = '0') then
			slv_10F	<= I_D;
		end if;
	end process;

	-- 11E latch
	p_11E : process
	begin
		-- until rising edge I_SPC in schema
		wait until rising_edge(I_CK);
		if (I_SPC = '0') then
			slv_11E <= I_D;
		end if;
	end process;

	-- 12E 8:1 mux
	O_PFM <= slv_11E(to_integer(unsigned(slv_4D(2 downto 0))));

	-- two 74LS189 16x4 bit RAMs, arranged as one 16x8 RAM
	-- but only 3 address lines used, so really one 8x8 RAM
	-- IMPORTANT: data out is the COMPLEMENT of data in!!!
	p_4M_5M : process
	variable RAM : RAM_ARRAY;
	-- Ask Xilinx synthesis to use distributed logic RAMs if possible
	attribute ram_style : string;
	attribute ram_style of RAM : variable is "distributed";
	-- Ask Quartus synthesis to use distributed logic RAMs if possible
	attribute ramstyle : string;
	attribute ramstyle of RAM : variable is "logic";
	begin
		wait until falling_edge(I_CK);
		slv_4D <= RAM(to_integer(unsigned(RAM_4M_5M_addr))); -- 4D latch
		RAM(to_integer(unsigned(RAM_4M_5M_addr))) := not I_PS;
	end process;

	-- 6D counter
	p_6D : process
	begin
		wait until rising_edge(I_CK);
		if I_ST = '0' or RAM_4M_5M_addr = "111" then
			RAM_4M_5M_addr <= slv_10F(2 downto 0);
		else
			RAM_4M_5M_addr <= RAM_4M_5M_addr + 1;
		end if;
	end process;

	-- 8E, 9B counters
	p_8E_9B : process
	begin
		wait until rising_edge(I_CK);
		if I_421H = "011" then -- rising edge 4H
			if I_ST = '0' then
				slv_8E_9B <= slv_10F(8 downto 3);
			else
				slv_8E_9B <= slv_8E_9B  + 1;
			end if;
		end if;
	end process;
end RTL;
