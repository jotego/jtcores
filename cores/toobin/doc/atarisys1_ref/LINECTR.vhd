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
-- Custom chip LBC 137419-102

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity LINECTR is
	port(
		I_MCKR   : in  std_logic;
		I_VRD    : in  std_logic_vector(15 downto 5);
		I_NXLn   : in  std_logic;
		I_421H   : in  std_logic_vector( 2 downto 0); -- 4H 2H 1H

		O_BQ     : out std_logic_vector(8 downto 0);
		O_PA     : out std_logic;
		O_PAn    : out std_logic;
		O_GLDn   : out std_logic;
		O_MOn    : out std_logic
	);
end LINECTR;

architecture RTL of LINECTR is
	signal
		sl_LDn,
		sl_PAD,
		sl_NXLn,
		sl_CLRn,
		sl_MOSR7D,
		sl_BUFCLRn,
		sl_MOn
								: std_logic := '1';
	signal
		slv_NXL_delay
								: std_logic_vector( 7 downto 0) := (others=>'1');
	signal
		slv_LB,
		slv_3J
								: std_logic_vector( 8 downto 0) := (others=>'1');
begin
	O_GLDn     <= (I_421H(1) or I_421H(0));
	O_PAn      <= not sl_PAD;
	O_PA       <=     sl_PAD;
	O_BQ       <= slv_LB;
	O_MOn      <= sl_MOn;
	sl_NXLn    <= I_NXLn;
	sl_BUFCLRn <= slv_NXL_delay(7);
	sl_CLRn    <= sl_PAD or sl_BUFCLRn;

	-- generate some internal signals
	p_nxl : process
	begin
		wait until rising_edge(I_MCKR);
		-- /BUFCLR signal is just /NXL delayed 8 clocks
		slv_NXL_delay <= slv_NXL_delay(6 downto 0) & sl_NXLn;
		-- create PADB signal from recovered /BUFCLRN
		sl_PAD   <= (not sl_PAD) xor sl_BUFCLRn;
	end process;

	-- 4J, 3D on SP-277 schema sheet 8
	sl_LDn  <= I_421H(2) or ((not I_421H(1)) or (I_421H(0))) or sl_PAD;

	-- 3T, 3R, 3W, 3U, 3S, 3X counters
	p_ctrs : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_CLRn = '0' then
			slv_LB <= (others=>'0');
		elsif sl_LDn = '0' then
			slv_LB <= slv_3J;
		else
			slv_LB <= slv_LB + 1;
		end if;
	end process;

	p_MOSR7 : process
	begin
		wait until rising_edge(I_MCKR);
		if (I_421H = "101") then -- rising 4HDD
			sl_MOSR7D  <= I_VRD(15);
			slv_3J     <= I_VRD(13 downto 5); -- latch 3J
		end if;
		if (I_421H = "010") then -- rising /4HD3
			sl_MOn <= sl_MOSR7D; -- VRD15 delayed by 4HDD and then by /4HD3
		end if;
	end process;
end RTL;
