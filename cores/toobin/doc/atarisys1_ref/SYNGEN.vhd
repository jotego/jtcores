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
--	System Clock and Sync Generator (Atari custom chip 137419-103)
--	This SYNGEN was derived from System I SP-277 schematic

-- H     0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 
-- MCKR  -_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_
-- 1H    __--__--__--__--__--__--__--__--
-- 2H    ____----____----____----____----
-- 2HDL  --____----____----____----____--
--/2HDL  __----____----____----____----__
-- 4H    ________--------________--------
--/4H    --------________--------________
-- 4HDL  --________--------________------
--/4HDL  __--------________--------______
-- 4HDD  ----________--------________----
--/4HDD  ____--------________--------____
-- 4HD3  ------________--------________--
--/4HD3  ______--------________--------__
-- GLDn  __------__------__------__------
-- H03   ------__------__------__------__
--/H03   ______--______--______--______--

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;

entity SYNGEN is
	port(
		I_CK      : in  std_logic; -- 7.159MHz clock

		O_C0      : out std_logic := '0';
		O_C1      : out std_logic := '0';
		O_C2      : out std_logic := '0';
		O_LMPDn   : out std_logic := '0';
		O_VIDBn   : out std_logic; -- VIDBLANK
		O_VRESn   : out std_logic;

		O_HSYNCn  : out std_logic;
		O_VSYNCn  : out std_logic;
		O_PFHSTn  : out std_logic;
		O_BUFCLRn : out std_logic;

		O_HBLKn   : out std_logic;	-- HBLANK
		O_VBLKn   : out std_logic; -- VBLANK
		O_VSCK    : out std_logic;
		O_CK0n    : out std_logic; -- pin  4 RCLOCK
		O_CK0     : out std_logic; -- pin 29 FCLOCK
		O_2HDLn   : out std_logic;
		O_4HDLn   : out std_logic;
		O_4HDDn   : out std_logic;
		O_NXLn    : out std_logic;
		O_V       : out std_logic_vector(7 downto 0);
		O_H       : out std_logic_vector(8 downto 0)
	);
end SYNGEN;

architecture RTL of SYNGEN is
	signal
		sl_2HDLn,
		sl_3A5,
		sl_4HDDn,
		sl_o13
								: std_logic := '0';
	signal
		sl_VBLANKn,
		sl_4HDLn,
		sl_C0,
		sl_C1,
		sl_C2,
		sl_HBLANKn,
		sl_HSYNCn,
		sl_LMPDn,
		sl_NXLn,
		sl_VRESn,
		sl_o11,
		sl_o12,
		sl_o14,
		sl_o15,
		sl_o16,
		sl_o17,
		sl_o18,
		sl_o19
								: std_logic := '1';
	signal
		slv_5E_data
								: std_logic_vector( 3 downto 0) := (others => '1');
	signal
		slv_5E_addr
								: std_logic_vector( 7 downto 0) := (others => '1');
	signal
		slv_vcnt
								: std_logic_vector( 7 downto 0) := x"EF"; --(others => '1');
	signal
		slv_hcnt
								: std_logic_vector( 8 downto 0) := (others => '0');
begin
	O_2HDLn   <= sl_2HDLn;
	O_4HDDn   <= sl_4HDDn;
	O_4HDLn   <= sl_4HDLn;
	O_BUFCLRn <= not sl_o11;
	O_C0      <= sl_C0;
	O_C1      <= sl_C1;
	O_C2      <= sl_C2;
	O_CK0     <=     I_CK;
	O_CK0n    <= not I_CK;
	O_H       <= slv_hcnt;
	O_HSYNCn  <= sl_HSYNCn;
	O_LMPDn   <= sl_LMPDn;
	O_NXLn    <= not sl_o19;
	O_PFHSTn  <= not sl_o12;
	O_V       <= slv_vcnt;
	O_HBLKn   <= sl_HBLANKn; -- From SP-313 this is /HBLANK
	O_VBLKn   <= sl_VBLANKn;
	O_VIDBn   <= sl_VBLANKn and sl_HBLANKn;
	O_VRESn   <= sl_VRESn;
	O_VSCK    <= sl_VBLANKn and sl_o13;
	O_VSYNCn  <= slv_5E_data(1);

	p_7A_7D_7E : process
	begin
		wait until rising_edge(I_CK);

		-- 7D
		sl_2HDLn   <= not slv_hcnt(1); -- 2H delayed x1 inverted
		sl_4HDLn   <= not slv_hcnt(2); -- 4H delayed x1 inverted
		sl_4HDDn   <=     sl_4HDLn;    -- 4H delayed x2

		-- 7E
		sl_NXLn    <= not sl_o19;
		sl_C2      <=     sl_o18;
		sl_C1      <=     sl_o17;
		sl_C0      <=     sl_o16;
		sl_LMPDn   <= not sl_o15;
		sl_HBLANKn <= not sl_o14;
		sl_HSYNCn  <= not sl_o13;
	end process;

	slv_5E_addr <= sl_3A5 & (slv_vcnt(7) and slv_vcnt(6)) & slv_vcnt(5 downto 0);

-- 82S129 256x4 TTL BIPOLAR PROM (Atari chip 136032.102)
	u_PROM_5E : entity work.PROM_5E
	port map (
		CLK  => I_CK,
		ADDR => slv_5E_addr,
		DATA => slv_5E_data
	);

	-- counters 4E, 5D, 6E, 6F
	p_h_v_count : process
	begin
		wait until rising_edge(I_CK);
		if sl_NXLn = '0' then
			slv_hcnt <= (others=>'0');
			if slv_5E_data(0) = '0' then
				slv_vcnt <= (others=>'1');
			else
				slv_vcnt <= slv_vcnt + 1;
			end if;
			sl_VRESn   <=     slv_5E_data(0); -- F/F 3A output 9
			sl_3A5     <=     slv_5E_data(2); -- F/F 3A output 5
			sl_VBLANKn <= not slv_5E_data(3); -- F/F 5B output 5
		else
			slv_hcnt <= slv_hcnt + 1;
		end if;
	end process;

-- Equations for PLA chip 7F Signetics 82S153 aka PLS153A (Atari custom chip 136032.103)
-- /o19 = /i1 &  i2 & i3 & i7 & i8 & i9
--  o18 =  i1 & /i2
--  o17 =  i1 & /i2 & /i3 +
--        /i1 &  i2 & /i3 +
--         i1 & /i2 &  i3
--  o16 = /i2 +
--         i1 &  i2 & /i3 +
--        /i1 &  i2 &  i3
-- /o15 =  i3 & /i4 & /i5 & /i6 & /i7 & /i8 & /i9 +
--         i2 & /i3 & /i4 & /i5 & /i6 & /i7 & /i8 & /i9 +
--        /i2 & /i3 &  i4 & /i5 & /i6 & /i7 & /i8 & /i9
-- /o14 = /i4 & /i5 & /i6 & /i7 & /i8 & /i9 +
--         i4 &  i5 & /i6 &  i7 & /i8 &  i9 +
--         i6 &  i7 & /i8 &  i9 +
--         i8 &  i9
--  o13 = /i4 &  i5 & /i6 & /i7 &  i8 &  i9 +
--        /i5 & /i6 & /i7 &  i8 &  i9 +
--         i4 &  i5 &  i6 &  i7 & /i8 &  i9
-- /o12 =  i4 &  i5 &  i6 & /i7 &  i8 &  i9
-- /o11 = /i1 &  i2 &  i3 & /i4 & /i5 & /i6 & /i7 & /i8 & /i9

	sl_o19 <=  ( (not slv_hcnt(0)) and      slv_hcnt(1)  and      slv_hcnt(2)                                                                    and      slv_hcnt(6)  and      slv_hcnt(7)  and      slv_hcnt(8));

	sl_o18 <=         slv_hcnt(0)  and (not slv_hcnt(1)) ;

	sl_o17 <=  (      slv_hcnt(0)  and (not slv_hcnt(1)) and (not slv_hcnt(2))) or
              ( (not slv_hcnt(0)) and      slv_hcnt(1)  and (not slv_hcnt(2))) or
              (      slv_hcnt(0)  and (not slv_hcnt(1)) and      slv_hcnt(2));

	sl_o16 <=                          (not slv_hcnt(1)) or
              (      slv_hcnt(0)  and      slv_hcnt(1)  and (not slv_hcnt(2))) or
              ( (not slv_hcnt(0)) and      slv_hcnt(1)  and      slv_hcnt(2));

	sl_o15 <=                       ( (                           slv_hcnt(2)  and (not slv_hcnt(3)) and (not slv_hcnt(4)) and (not slv_hcnt(5)) and (not slv_hcnt(6)) and (not slv_hcnt(7)) and (not slv_hcnt(8))) or
                                   (       slv_hcnt(1)  and (not slv_hcnt(2)) and (not slv_hcnt(3)) and (not slv_hcnt(4)) and (not slv_hcnt(5)) and (not slv_hcnt(6)) and (not slv_hcnt(7)) and (not slv_hcnt(8))) or
                                   ( ( not slv_hcnt(1)) and (not slv_hcnt(2)) and      slv_hcnt(3)  and (not slv_hcnt(4)) and (not slv_hcnt(5)) and (not slv_hcnt(6)) and (not slv_hcnt(7)) and (not slv_hcnt(8))));

	sl_o14 <=                                                                    (((not slv_hcnt(3)) and (not slv_hcnt(4)) and (not slv_hcnt(5)) and (not slv_hcnt(6)) and (not slv_hcnt(7)) and (not slv_hcnt(8))) or
                                                                                (      slv_hcnt(3)  and      slv_hcnt(4)  and (not slv_hcnt(5)) and      slv_hcnt(6)  and (not slv_hcnt(7)) and      slv_hcnt(8))  or
                                                                                (                                                  slv_hcnt(5)  and      slv_hcnt(6)  and (not slv_hcnt(7)) and      slv_hcnt(8))  or
                                                                                (                                                                                              slv_hcnt(7)  and      slv_hcnt(8)));

	sl_o13 <=                                                                    ( (not slv_hcnt(3)) and      slv_hcnt(4)  and (not slv_hcnt(5)) and (not slv_hcnt(6)) and      slv_hcnt(7)  and      slv_hcnt(8))  or
                                                                                (                       (not slv_hcnt(4)) and (not slv_hcnt(5)) and (not slv_hcnt(6)) and      slv_hcnt(7)  and      slv_hcnt(8))  or
                                                                                (      slv_hcnt(3)  and      slv_hcnt(4)  and      slv_hcnt(5)  and      slv_hcnt(6)  and (not slv_hcnt(7)) and      slv_hcnt(8));

	sl_o12 <=                                                                    (      slv_hcnt(3)  and      slv_hcnt(4)  and      slv_hcnt(5)  and (not slv_hcnt(6)) and      slv_hcnt(7)  and      slv_hcnt(8));

	sl_o11 <=  ( (not slv_hcnt(0)) and      slv_hcnt(1) and       slv_hcnt(2)  and (not slv_hcnt(3)) and (not slv_hcnt(4)) and (not slv_hcnt(5)) and (not slv_hcnt(6)) and (not slv_hcnt(7)) and (not slv_hcnt(8)));
end RTL;
