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
-- Motion Object Horizontal Line Buffer based on SP-286 schematic sheet 7

library ieee;
	use ieee.std_logic_1164.all;

entity MOHLB_LSI is
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
end MOHLB_LSI;

architecture RTL of MOHLB_LSI is
	signal
		sl_NXL_B,
		sl_LMPDn,
		sl_PA,
		sl_PADBn,
		sl_PADB,
		sl_ACSn,
		sl_BCSn,
		sl_MOn,
		sl_NXLn,
		sl_GLDn
								: std_logic := '0';

	signal
		slv_MPX,
		slv_MOSR,
		slv_MPXA,
		slv_MPXB
								: std_logic_vector( 7 downto 0) := (others=>'0');
	signal
		slv_BQA,
		slv_BQB
								: std_logic_vector( 8 downto 0) := (others=>'0');
	signal
		slv_VRD
								: std_logic_vector(15 downto 0) := (others=>'0');
begin
	sl_NXLn  <= I_NXLn;
	slv_VRD  <= I_VRD;
	sl_LMPDn <= I_LMPDn;

	O_MPX    <= slv_MPX;
	O_GLDn   <= sl_GLDn;

	-------------
	-- sheet 7 --
	-------------

	-- Custom chip 5/6 J/K (LBC 137419-102)
	u_LINECTRA : entity work.LINECTR
	port map (
		I_MCKR        => I_MCKR,
		I_VRD         => slv_VRD(15 downto 5),
		I_NXLn        => sl_NXLn,
		I_421H        => I_421H,

		O_BQ          => slv_BQA,
		O_PA          => sl_PADBn,
		O_PAn         => sl_PADB,
		O_GLDn        => sl_GLDn,
		O_MOn         => sl_MOn
	);

	-- Line Buffer A
	u_LINBUFA : entity work.LINEBUF
	port map (
		I_MCKR        => I_MCKR,
		I_FLBn        => sl_PADBn,
		I_CSn         => sl_ACSn,
		I_HPOS        => slv_BQA,
		I_MOSR        => slv_MOSR,
		O_MPX         => slv_MPXA
	);

	-- Custom chip 5 J/K (LBC 137419-102)
	u_LINECTRB : entity work.LINECTR
	port map (
		I_MCKR        => I_MCKR,
		I_VRD         => slv_VRD(15 downto 5),
		I_NXLn        => sl_NXL_B,
		I_421H        => I_421H,

		O_BQ          => slv_BQB,
		O_PA          => open,
		O_PAn         => sl_PA,
		O_GLDn        => open,
		O_MOn         => open
	);

	-- Line Buffer B
	u_LINBUFB : entity work.LINEBUF
	port map (
		I_MCKR        => I_MCKR,
		I_FLBn        => sl_PADB,
		I_CSn         => sl_BCSn,
		I_HPOS        => slv_BQB,
		I_MOSR        => slv_MOSR,
		O_MPX         => slv_MPXB
	);

	-- gate 1L generates top bit of MOSR
	slv_MOSR   <= (not sl_MOn) & I_MOSR;

	-- gates 5J/K - the function of this circuit is to ensure that if the two LBC chips start synchronized
	-- a single NXL pulse is skipped to one of them and they become unsynced, so they capture alternate lines
	sl_NXL_B <= (sl_PADB xnor sl_PA) or sl_NXLn;

	-- gates 4L, 5L, 1L (and MCKR goes to the RAM clock)
	sl_ACSn <= (    sl_PADB ) and not (sl_LMPDn and (not (slv_MOSR(3) and slv_MOSR(2) and slv_MOSR(1) and slv_MOSR(0))));
	sl_BCSn <= (    sl_PADBn) and not (sl_LMPDn and (not (slv_MOSR(3) and slv_MOSR(2) and slv_MOSR(1) and slv_MOSR(0))));

	-- selectors 2K, 2J
	p_2K_2J : process
	begin
		wait until falling_edge(I_MCKR);
		if sl_PADB = '0' then
			slv_MPX <= slv_MPXA;
		else
			slv_MPX <= slv_MPXB;
		end if;
	end process;
end RTL;
