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
-- Motion Object Horizontal Line Buffer based on SP-277 schematic sheet 9A

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity MOHLB_TTL is
	port(
		I_MCKR      : in  std_logic;
		I_NXLn      : in  std_logic;
		I_LMPDn     : in  std_logic;
		I_421H      : in  std_logic_vector( 2 downto 0); -- 4H 2H 1H
		I_VRD       : in  std_logic_vector(15 downto 0);
		I_MOSR      : in  std_logic_vector( 6 downto 0);
		O_MPX       : out std_logic_vector( 7 downto 0);
		O_GLDn      : out std_logic
	);
end MOHLB_TTL;

architecture RTL of MOHLB_TTL is
	signal
		sl_T1,
		sl_MOn,
		sl_LMPDn,
		sl_BUFCLRn,
		sl_PADB,
		sl_ACSn,
		sl_BCSn,
		sl_NXLn,
		sl_LDAn,
		sl_LDBn,
		sl_1H,
		sl_2H,
		sl_4H,
		sl_4HD3n,
		sl_4HD,
		sl_4HDD,
		sl_CLRAn,
		sl_CLRBn
								: std_logic := '0';

	signal
		slv_MPX,
		slv_MOSR,
		slv_RAMAI,
		slv_MPXA,
		slv_RAMBI,
		slv_MPXB,
		slv_NXLD
								: std_logic_vector( 7 downto 0) := (others=>'0');
	signal
		slv_BQA,
		slv_BQB,
		slv_3J
								: std_logic_vector( 8 downto 0) := (others=>'0');
	signal
		slv_VRD
								: std_logic_vector(15 downto 0) := (others=>'0');

	type RAM_ARRAY is array (0 to 511) of std_logic_vector(7 downto 0);
	signal RAMA : RAM_ARRAY := ((others=>(others=>'1')));
	signal RAMB : RAM_ARRAY := ((others=>(others=>'1')));
	attribute ram_style : string;
	attribute ram_style of RAMA : signal is "block";
	attribute ram_style of RAMB : signal is "block";

begin
	sl_NXLn  <= I_NXLn;
	slv_VRD  <= I_VRD;
	sl_LMPDn <= I_LMPDn;
	sl_4H    <= I_421H(2);
	sl_2H    <= I_421H(1);
	sl_1H    <= I_421H(0);

	O_MPX    <= slv_MPX;
	O_GLDn   <= sl_2H or sl_1H;

	slv_MOSR <= (not sl_MOn) & I_MOSR;

	sl_LDAn  <= sl_4H or (not sl_2H) or sl_1H or (not sl_PADB) ;
	sl_LDBn  <= sl_4H or (not sl_2H) or sl_1H or (    sl_PADB) ;

	sl_ACSn  <= (    sl_PADB ) and not (sl_LMPDn and ( not ( slv_MOSR(3) and slv_MOSR(2) and slv_MOSR(1) and slv_MOSR(0) ) ) );
	sl_BCSn  <= (not sl_PADB ) and not (sl_LMPDn and ( not ( slv_MOSR(3) and slv_MOSR(2) and slv_MOSR(1) and slv_MOSR(0) ) ) );

	sl_BUFCLRn <= slv_NXLD(7);
	sl_CLRAn   <= (not sl_PADB) or sl_BUFCLRn;
	sl_CLRBn   <= (    sl_PADB) or sl_BUFCLRn;

	p_hcnt : process
	begin
		wait until rising_edge(I_MCKR);
		sl_4HD   <= sl_4H;
		sl_4HDD  <= sl_4HD;
		sl_4HD3n <= not sl_4HDD;
		slv_NXLD <= slv_NXLD(6 downto 0) & sl_NXLn;
		sl_PADB  <= (not sl_PADB) xor sl_BUFCLRn;
	end process;

	p_3J : process
	begin
		wait until rising_edge(sl_4HDD);
		slv_3J <= slv_VRD(13 downto 5);
		sl_T1  <= slv_VRD(15);
	end process;

	p_1K : process
	begin
		wait until rising_edge(sl_4HD3n);
		sl_MOn <= sl_T1;
	end process;

	p_2J_2H_2F : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_CLRAn = '0' then
			slv_BQA <= (others=>'0');
		elsif sl_LDAn = '0' then
			slv_BQA <= slv_3J;
		else
			slv_BQA <= slv_BQA + 1;
		end if;
	end process;

	p_1J_1H_1F : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_CLRBn = '0' then
			slv_BQB <= (others=>'0');
		elsif sl_LDBn = '0' then
			slv_BQB <= slv_3J;
		else
			slv_BQB <= slv_BQB + 1;
		end if;
	end process;

	p_RAMA : process
	begin
		wait until falling_edge(I_MCKR);
		if sl_ACSn = '0' then
			RAMA(to_integer(unsigned(slv_BQA))) <= slv_RAMAI;
			slv_MPXA <= RAMA(to_integer(unsigned(slv_BQA)));
		else
			slv_MPXA <= (others=>'1');
		end if;
	end process;

	p_RAMB : process
	begin
		wait until falling_edge(I_MCKR);
		if sl_BCSn = '0' then
			RAMB(to_integer(unsigned(slv_BQB))) <= slv_RAMBI;
			slv_MPXB <= RAMB(to_integer(unsigned(slv_BQB)));
		else
			slv_MPXB <= (others=>'1');
		end if;
	end process;

	slv_RAMAI <= slv_MOSR when sl_PADB = '1' else (others=>'1');
	slv_RAMBI <= slv_MOSR when sl_PADB = '0' else (others=>'1');

	p_2K_3K : process
	begin
		wait until falling_edge(I_MCKR);
		if sl_PADB = '0' then
			slv_MPX <= slv_MPXA;
		else
			slv_MPX <= slv_MPXB;
		end if;
	end process;
end RTL;
