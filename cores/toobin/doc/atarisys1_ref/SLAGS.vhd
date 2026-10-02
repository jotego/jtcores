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
-- Storage/Logic Array Graphics Shifter (Atari custom chip 137415-101)
--	This SLAGS was derived from Marble Madness SP-276 schematic

library ieee;
	use ieee.std_logic_1164.all;

entity SLAGS is
	port(
		I_MCKR    : in  std_logic; -- RCLOCK
		I_A       : in  std_logic_vector(7 downto 0);
		I_B       : in  std_logic_vector(7 downto 0);
		I_HLDAn   : in  std_logic; -- /HOLDA
		I_HLDBn   : in  std_logic; -- /HOLDB
		I_FLP     : in  std_logic; -- MGHF
		I_MO_PFn  : in  std_logic; -- MO/ /PF
		I_LDn     : in  std_logic; -- /GLD
		O_PFDA    : out std_logic; -- PFSR Play Field Shift Register
		O_PFDB    : out std_logic; -- PFSR Play Field Shift Register
		O_MODA    : out std_logic; -- MOSR Motion Object Shift Register
		O_MODB    : out std_logic  -- MOSR Motion Object Shift Register
	);
end SLAGS;

architecture RTL of SLAGS is
	signal
		sl_MOFDA,
		sl_MOSDA,
		sl_MOFDB,
		sl_MOSDB,
		sl_PFFDA,
		sl_PFSDA,
		sl_PFFDB,
		sl_PFSDB,

		sl_LDMOn,
		sl_LDPFn,
		sl_MOFLP,
		sl_MO_HLDAn,
		sl_MO_HLDBn,
		sl_PFFLP,
		sl_PF_HLDAn,
		sl_PF_HLDBn
								: std_logic := '1';
	signal
		slv_1B_4B,
		slv_1A_5B,
		sel_MOSA,
		sel_MOSB,
		sel_PFSA,
		sel_PFSB,
		slv_2A,
		slv_2B,
		slv_3A,
		slv_3B
								: std_logic_vector(1 downto 0) := (others=>'1');
begin
	-- gates 6B, 12A - shifter controls   MO  /PF
	sl_LDPFn	<= I_LDn or (    I_MO_PFn);
	sl_LDMOn	<= I_LDn or (not I_MO_PFn);

	-- In schema SP-276 when /NOROM signals are asserted they cause the shifters to hold their state and also they
	-- cause /CPAL signals to pull low the D0/D7 lines of the ROMS (which are not fitted to PCB, hence the /NOROM signal)
	-- the final effect of that is to bring low the MOSR lines when FLIP is asserted
	-- In later schemas such as SP-282, SP-298 using LSI chips, the pulldown on D0 line of the ROMs is removed
	-- this causes incorrect SLAGS output when both /HOLD and FLIP are asserted because MOSR is taken from the wrong end
	-- of the shifter, so without detailed knowledge of the internals of the LSI, the best guess is to cancel the FLIP
	-- signal when /HOLD is asserted by logical and-ing them together

	-- latch 8B
	p_8B : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_LDPFn = '0' then
			sl_PFFLP		<= I_FLP and I_HLDAn; -- see note above
			sl_PF_HLDAn	<= I_HLDAn;
			sl_PF_HLDBn	<= I_HLDBn;
		end if;
	end process;

	-- latch 11A
	p_11A : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_LDMOn = '0' then
			sl_MOFLP		<= I_FLP and I_HLDBn; -- see note above
			sl_MO_HLDAn	<= I_HLDAn;
			sl_MO_HLDBn	<= I_HLDBn;
		end if;
	end process;

	-- shift register select signals
	sel_MOSB(0)	<= not (sl_LDMOn and not (sl_MO_HLDBn and (not sl_MOFLP)));
	sel_MOSB(1)	<= not (sl_LDMOn and not (sl_MO_HLDBn and (    sl_MOFLP)));

	sel_MOSA(0)	<= not (sl_LDMOn and not (sl_MO_HLDAn and (not sl_MOFLP)));
	sel_MOSA(1)	<= not (sl_LDMOn and not (sl_MO_HLDAn and (    sl_MOFLP)));

	sel_PFSB(0)	<= not (sl_LDPFn and not (sl_PF_HLDBn and (not sl_PFFLP)));
	sel_PFSB(1)	<= not (sl_LDPFn and not (sl_PF_HLDBn and (    sl_PFFLP)));

	sel_PFSA(0)	<= not (sl_LDPFn and not (sl_PF_HLDAn and (not sl_PFFLP)));
	sel_PFSA(1)	<= not (sl_LDPFn and not (sl_PF_HLDAn and (    sl_PFFLP)));

	-- LS299 shifters
	u_MOSB : entity work.LS299 port map ( I_CK=>I_MCKR, I_DATA=>I_B, I_SL=>'0', I_SR=>'0', I_SEL=>sel_MOSB, O_SL=>sl_MOFDB, O_SR=>sl_MOSDB );
	u_MOSA : entity work.LS299 port map ( I_CK=>I_MCKR, I_DATA=>I_A, I_SL=>'0', I_SR=>'0', I_SEL=>sel_MOSA, O_SL=>sl_MOFDA, O_SR=>sl_MOSDA );
	u_PFSB : entity work.LS299 port map ( I_CK=>I_MCKR, I_DATA=>I_B, I_SL=>'0', I_SR=>'0', I_SEL=>sel_PFSB, O_SL=>sl_PFFDB, O_SR=>sl_PFSDB );
	u_PFSA : entity work.LS299 port map ( I_CK=>I_MCKR, I_DATA=>I_A, I_SL=>'0', I_SR=>'0', I_SEL=>sel_PFSA, O_SL=>sl_PFFDA, O_SR=>sl_PFSDA );

	-- selectors 1A, 1B, 4B, 5B 0=A 1=B
	-- selects left or right shifter outputs based on FLP
	slv_1B_4B <= sl_PFFDB & sl_PFFDA when sl_PFFLP = '1' else sl_PFSDB & sl_PFSDA;
	slv_1A_5B <= sl_MOFDB & sl_MOFDA when sl_MOFLP = '1' else sl_MOSDB & sl_MOSDA;

	-- latches 2A, 2B, 3A, 3B
	-- 2 clock cycle delay line
	p_2A_2B_3A_3B : process
	begin
		wait until rising_edge(I_MCKR);
		slv_3B <= slv_1B_4B;
		slv_3A <= slv_3B;
		slv_2B <= slv_1A_5B;
		slv_2A <= slv_2B;
	end process;

	-- outputs
	O_MODB <= slv_2A(1);
	O_MODA <= slv_2A(0);
	O_PFDB <= slv_3A(1);
	O_PFDA <= slv_3A(0);
end RTL;
