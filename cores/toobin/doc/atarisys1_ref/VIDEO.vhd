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
-- From SP-286 schematic

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity VIDEO is
	port(
		I_MCKR     : in  std_logic; -- MCKR  7.159 MHz
		I_XCKR     : in  std_logic; -- XCKR 14.318 MHz
		I_SYSRESn  : in  std_logic;
		I_CRBUSn   : in  std_logic;
		I_CRAMn    : in  std_logic;
		I_VBUSn    : in  std_logic;
		I_BW_Rn    : in  std_logic;
		I_MISCn    : in  std_logic;
		I_CRAMWRn  : in  std_logic;
		I_VRAMWR   : in  std_logic;
		I_PFSPCn   : in  std_logic;
		I_VSCRLDn  : in  std_logic;
		I_HSCRLDn  : in  std_logic;
		I_VBKACKn  : in  std_logic;
		I_MOSR     : in  std_logic_vector( 6 downto 0);
		I_PFSR     : in  std_logic_vector( 7 downto 0);
		I_CPU_A    : in  std_logic_vector(13 downto 1);
		I_CPU_D    : in  std_logic_vector(15 downto 0);
		O_CPU_D    : out std_logic_vector(15 downto 0);

		O_ADDR2B   : out std_logic_vector(13 downto 0);
		I_DATA2B   : in  std_logic_vector( 7 downto 0);

		O_TBTEST   : out std_logic;
		O_TBRESn   : out std_logic;
		O_SNDRESn  : out std_logic;
		O_MGHF     : out std_logic;
		O_GLDn     : out std_logic;
		O_MO_PFn   : out std_logic;
		O_MATCHn   : out std_logic;
		O_VBKINTn  : out std_logic;
		O_HBLANKn  : out std_logic;
		O_VBLANKn  : out std_logic;
		O_VRAC2    : out std_logic;
		O_1H       : out std_logic;
		O_2H       : out std_logic;
		O_4H       : out std_logic;
		O_8H       : out std_logic;
		O_MGRA     : out std_logic_vector(19 downto 1);

		O_I        : out std_logic_vector( 3 downto 0);
		O_R        : out std_logic_vector( 3 downto 0);
		O_G        : out std_logic_vector( 3 downto 0);
		O_B        : out std_logic_vector( 3 downto 0);
		O_HSYNC    : out std_logic;
		O_VSYNC    : out std_logic;
		O_CSYNC    : out std_logic
	);
end VIDEO;

architecture RTL of VIDEO is
	signal
		sl_MISCn_last,
		sl_VBLANKn_last,
		sl_VSCRCLK_last,

--		sl_2HDLn,
		sl_2J_Y9,
		sl_4C_Y,
		sl_4H,
--		sl_4HDDn,
		sl_4HDL,
		sl_4HDLn,
		sl_4Hn,
		sl_ALBNK_CTF,
		sl_BR_Wn,
		sl_COMPSYNCn,
		sl_CRAMWRn,
		sl_CRAMn,
		sl_CRBUSn,
		sl_GLDn,
		sl_HSCRLDn,
		sl_HSYNCn,
		sl_LMPDn,
		sl_MATCHn,
		sl_MGHF,
		sl_MISCn,
		sl_MM19,
		sl_MM18,
		sl_MM8,
		sl_MOHFLIP,
		sl_MO_PFn,
		sl_NXLn,
		sl_NXLn_star,
		sl_PFHFLIP,
		sl_PFHSTn,
		sl_PFSC_MOn,
		sl_PFSPCn,
		sl_PP19,
		sl_PP18,
		sl_SNDRSTn,
		sl_SYSRESn,
		sl_TBRESn,
		sl_TBTEST,
		sl_VBKACKn,
		sl_VBKINTn,
		sl_HBLANKn,
		sl_VBLANKn,
		sl_VBUSn,
		sl_VIDBLANKn,
		sl_VRAMWEn,
		sl_VRAMWR,
		sl_VRD13,
		sl_VRESETn,
		sl_VSCRCLK,
		sl_VSCRLDn,
		sl_VSYNCn
								: std_logic := '1';
	signal
		slv_2J_sel
								: std_logic_vector( 1 downto 0) := (others=>'0');
	signal
		slv_MPBS,
		slv_VRAC
								: std_logic_vector( 2 downto 0) := (others=>'0');
	signal
		slv_INT,
		slv_RED,
		slv_GRN,
		slv_BLU,
		slv_1H_A,
		slv_1H_B,
		slv_2H_A,
		slv_2H_B,
		slv_3H_A,
		slv_3H_B,
		slv_4H_A,
		slv_4H_B,
		slv_SHIFT_1B,
		slv_SHIFT_2B
								: std_logic_vector( 3 downto 0) := (others=>'0');
	signal
		slv_1H_S,
		slv_2H_S,
		slv_3H_S,
		slv_4H_S
								: std_logic_vector( 4 downto 0) := (others=>'0');
	signal
		slv_MN
								: std_logic_vector( 5 downto 0) := (others=>'0');
	signal
		slv_V,
		slv_PFSR,
		slv_PFX,
		slv_MPX,
		slv_ROM_2B_data
								: std_logic_vector( 7 downto 0) := (others=>'0');
	signal
		slv_H,
		slv_PFH,
		slv_PFV
								: std_logic_vector( 8 downto 0) := (others=>'0');
	signal
		slv_CRA,
		slv_CRA_GPC
								: std_logic_vector( 9 downto 0) := (others=>'0');
	signal
		slv_MM,
		slv_PP
								: std_logic_vector( 9 downto 1) := (others=>'0');
	signal
		slv_VRA
								: std_logic_vector(11 downto 0) := (others=>'0');
	signal
		slv_ROM_2B_addr
								: std_logic_vector(13 downto 0) := (others=>'0');
	signal
		slv_MA
								: std_logic_vector(13 downto 1) := (others=>'0');
	signal
		slv_MDI,
		slv_MDO,
		slv_VBD,
		slv_VRD,
		slv_VRAM,
		slv_CRAM,
		slv_7F_7H
								: std_logic_vector(15 downto 0) := (others=>'0');
	signal
		slv_MGRA
								: std_logic_vector(19 downto 1) := (others=>'0');

begin
	O_I        <= slv_int;
	O_R        <= slv_red;
	O_G        <= slv_grn;
	O_B        <= slv_blu;
	O_VSYNC    <= sl_VSYNCn;
	O_HSYNC    <= sl_HSYNCn;
	O_CSYNC    <= sl_COMPSYNCn;
	O_VBLANKn  <= sl_VBLANKn;
	O_HBLANKn  <= sl_HBLANKn;

	O_TBTEST   <= sl_TBTEST;
	O_TBRESn   <= sl_TBRESn;
	O_GLDn     <= sl_GLDn;
	O_MGHF     <= sl_MGHF;
	O_MATCHn   <= sl_MATCHn;
	O_MO_PFn   <= sl_MO_PFn;
	O_MGRA     <= slv_MGRA;
	O_VBKINTn  <= sl_VBKINTn;
	O_SNDRESn  <= sl_SNDRSTn;
	O_VRAC2    <= slv_VRAC(2);
	O_1H       <= slv_H(0);
	O_2H       <= slv_H(1);
	O_4H       <= slv_H(2);
	O_8H       <= slv_H(3);
	O_CPU_D    <= slv_MDO;
	O_ADDR2B   <= slv_ROM_2B_addr;

	sl_SYSRESn <= I_SYSRESn;
	sl_CRAMWRn <= I_CRAMWRn;
	sl_VRAMWR  <= I_VRAMWR;
	slv_MDI    <= I_CPU_D;
	slv_MA     <= I_CPU_A;
	sl_VBUSn   <= I_VBUSn;
	sl_BR_Wn   <= not I_BW_Rn;
	slv_PFSR   <= I_PFSR;
	sl_CRAMn   <= I_CRAMN;
	sl_CRBUSn  <= I_CRBUSn;
	sl_VBKACKn <= I_VBKACKn;
	sl_MISCn   <= I_MISCn;
	sl_PFSPCn  <= I_PFSPCn;
	sl_VSCRLDn <= I_VSCRLDn;
	sl_HSCRLDn <= I_HSCRLDn;

	-------------
	-- sheet 7 --
	-------------

	u_9E : entity work.SYNGEN
	port map (
		I_CK      => I_MCKR,

		O_C0      => slv_VRAC(0),
		O_C1      => slv_VRAC(1),
		O_C2      => slv_VRAC(2),
		O_LMPDn   => sl_LMPDn,
		O_VIDBn   => sl_VIDBLANKn,
		O_VRESn   => sl_VRESETn,

		O_HSYNCn  => sl_HSYNCn,
		O_VSYNCn  => sl_VSYNCn,
		O_PFHSTn  => sl_PFHSTn,
		O_BUFCLRn => open,

		O_HBLKn   => sl_HBLANKn,
		O_VBLKn   => sl_VBLANKn,
		O_VSCK    => sl_VSCRCLK,
		O_CK0n    => open, -- same as MCKF
		O_CK0     => open, -- same as MCKR
--		O_2HDLn   => sl_2HDLn,
		O_4HDLn   => sl_4HDLn,
--		O_4HDDn   => sl_4HDDn,
		O_NXLn    => sl_NXLn,
		O_V       => slv_V,
		O_H       => slv_H
	);

	-- gates 13D, 10C
	sl_COMPSYNCn <= sl_HSYNCn and sl_VSYNCn;

	-- gate 8F
	sl_MO_PFn <= not sl_4HDLn;

	-- gates 10E
	sl_4H     <= slv_H(2);
	sl_4Hn    <= not sl_4H;
	sl_4HDL   <= not sl_4HDLn;

	-- 9Da latch
	p_9Da : process
	begin
		wait until rising_edge(I_XCKR);
		sl_VBLANKn_last <= sl_VBLANKn;
		if sl_VBKACKn = '0' then
			sl_VBKINTn <= '1'; -- preset
		elsif sl_VBLANKn_last = '1' and sl_VBLANKn = '0' then
			sl_VBKINTn <= '0'; -- set
		end if;
	end process;

	-- 9Db latch
	p_9Db : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_NXLn = '0' then
			sl_NXLn_star <= '0'; -- preset
		elsif slv_H(2 downto 0) = "011" then -- rising edge 4H
			sl_NXLn_star <= '1'; -- set
		end if;
	end process;

	-- 1J/K Play Field Horizontal Scroll
	u_1J_K : entity work.PFHS
	port map (
		I_CK    => I_MCKR,
		I_ST    => sl_PFHSTn,
		I_CTF   => sl_ALBNK_CTF,
		I_421H  => slv_H(2 downto 0),
		I_HS    => sl_HSCRLDn,
		I_SPC   => sl_PFSPCn,
		I_D     => slv_VBD(8 downto 0),
		I_PS    => slv_PFSR,

		O_PFM   => sl_PFSC_MOn,
		O_PFH   => slv_PFH(8 downto 3),
		O_XP    => slv_PFX
	);

	u_MOHLBLSI : entity work.MOHLB_LSI
	port map (
		I_MCKR   => I_MCKR,
		I_NXLn   => sl_NXLn,
		I_421H   => slv_H(2 downto 0),
		I_VRD    => slv_VRD,
		I_LMPDn  => sl_LMPDn,
		I_MOSR   => I_MOSR,

		O_MPX    => slv_MPX,
		O_GLDn   => sl_GLDn
	);

	-------------
	-- sheet 8 --
	-------------

	-- 6E, 7E, 8E, 6D, 7D, 8D selectors create video RAM address
	slv_VRA <=
		slv_PFV(8 downto 3) & slv_PFH(8 downto 3)                        when slv_VRAC(1 downto 0) = "00" else -- c0
		'0' & slv_MPBS & sl_4HDL & (slv_H(1) or (not slv_H(0))) & slv_MN when slv_VRAC(1 downto 0) = "01" else -- c1
		'1' & slv_V(7 downto 3) & slv_H(8 downto 3)                      when slv_VRAC(1 downto 0) = "10" else -- c2
		slv_MA(12 downto 1);                                          -- when slv_VRAC(1 downto 0) = "11" else -- c3

	-- chip 4C 8:1 encoder
	sl_4C_Y   <=
		'0'            when slv_VRAC(1 downto 0) = "00" else
		'1'            when slv_VRAC(1 downto 0) = "01" else
		'1'            when slv_VRAC(1 downto 0) = "10" else
		slv_MA(13); -- when slv_VRAC(1 downto 0) = "11" else

	-- gate 12E
	sl_VRAMWEn <= not (slv_VRAC(2) and sl_VRAMWR); -- and (not I_MCKR)); -- MCKR is VRAM clock

	u_VRAMS : entity work.VRAMS
	port map (
		I_MCKR             => I_XCKR,
		I_WEn              => sl_VRAMWEn,
		I_VRA(12)          => sl_4C_Y,
		I_VRA(11 downto 0) => slv_VRA,
		I_VRD              => slv_VBD,
		O_VRD              => slv_VRAM
	);

	-- 6F, 6H buffers
	slv_VRD <= slv_VBD when sl_VRAMWEn = '0' else slv_VRAM;

	-- 7F, 7H / 10F, 11F bus latches
	-- VRAC(2) 0=latched, 1=transparent
	p_7F_7H : process
		begin
		wait until rising_edge(I_XCKR);
		if slv_VRAC(2) = '1' then
			slv_7F_7H <= slv_VRAM;
		end if;
	end process;

	slv_VBD <= slv_MDI when sl_VBUSn = '0' and sl_BR_Wn = '0' else slv_7F_7H;

	-- 9C latch
	p_9C : process
	begin
		wait until rising_edge(I_XCKR);
		sl_MISCn_last   <= sl_MISCn;
		if sl_SYSRESn = '0' then
			sl_SNDRSTn  <= '0';
			sl_TBTEST   <= '0';
			slv_MPBS(2) <= '0';
			slv_MPBS(1) <= '0';
			slv_MPBS(0) <= '0';
			sl_PP19     <= '0';
			sl_TBRESn   <= '0';
			sl_ALBNK_CTF<= '0';
		elsif (sl_MISCn_last = '1' and sl_MISCn = '0') then
			sl_SNDRSTn  <= slv_VBD(7); -- Sound CPU reset
			sl_TBTEST   <= slv_VBD(6); -- Trackball test
			slv_MPBS(2) <= slv_VBD(5); -- MO bank select
			slv_MPBS(1) <= slv_VBD(4); -- MO bank select
			slv_MPBS(0) <= slv_VBD(3); -- MO bank select
			sl_PP19     <= slv_VBD(2); -- PF bank select
			sl_TBRESn   <= slv_VBD(1); -- Trackball resolution
			sl_ALBNK_CTF<= slv_VBD(0); -- AL bank select
		end if;
	end process;

	-- 2C latch
	p_2C : process
	begin
		wait until rising_edge(I_MCKR);
		if sl_NXLn_star = '0' then
			slv_MN <= (others=>'0');
		elsif slv_H(2 downto 0) = "111" then -- rising edge /4H
			slv_MN <= slv_VRD(5 downto 0);
		end if;
	end process;

	-- 5F latch
	p_5F : process
	begin
		wait until rising_edge(I_MCKR);
		if slv_H(2 downto 0) = "000" then -- rising edge /4HDL
			sl_PFHFLIP         <= slv_VRD(15); -- PF H flip
			sl_PP18            <= slv_VRD(14); -- PF tile+palette select
			slv_PP(9 downto 4) <= slv_VRD( 5 downto 0);
		end if;
	end process;

	-- 6C, 7C, 8C counters
	p_6C_7C_8C : process
	begin
		wait until rising_edge(I_XCKR);
		sl_VSCRCLK_last <= sl_VSCRCLK;
		if sl_VSCRLDn = '0' then
			slv_PFV <= slv_VBD( 8 downto 0);
		elsif sl_VSCRCLK_last = '0' and sl_VSCRCLK = '1' then
			-- ALBNK is CTF in SP-299
			if sl_ALBNK_CTF = '1' then
				slv_PFV <= slv_PFV - 1;
			else
				slv_PFV <= slv_PFV + 1;
			end if;
		end if;
	end process;

	slv_PP(3 downto 1) <= slv_PFV(2 downto 0);

	-------------
	-- sheet 9 --
	-------------

	p_7L : process
	begin
		-- FIXME timing on /2HDL may cause sdram setup/hold errors
		wait until rising_edge(I_MCKR);
		if slv_H(1 downto 0) = "00" then -- rising edge /2HDL
			slv_MGRA(17 downto 10) <= slv_VRD(13 downto 6);
		end if;
	end process;

	-- muxes 6J, 6K, 6L
	sl_MGHF                <= sl_MOHFLIP        when sl_4HDLn = '0' else sl_PFHFLIP;
	slv_MGRA(19 downto 18) <= sl_MM19 & sl_MM18 when sl_4HDLn = '0' else sl_PP19 & sl_PP18;
	slv_MGRA( 9 downto  1) <= slv_MM            when sl_4HDLn = '0' else slv_PP;

	-- gates 1F, 4L, 5L
--	sl_MATCHn <= (not (((sl_VRD13 xor sl_VRESETn) xor slv_1H_S(4)) and slv_1H_S(3) and slv_3H_S(4)) ) and sl_4HDL;
	sl_MATCHn <=
		sl_4HDL and
		not ( sl_2J_Y9 and
			( (sl_VRD13 xor sl_VRESETn) xor slv_1H_S(4))
		);

	slv_2J_sel <= slv_3H_S(4) & slv_1H_S(3);

	sl_2J_Y9 <=	    sl_ALBNK_CTF		when slv_2J_sel="00" else
					'0'		when slv_2J_sel="01" else
					'0'		when slv_2J_sel="10" else
			not sl_ALBNK_CTF;	--	when slv_2J_sel="11"

--	slv_MM(8) <= (sl_MM8 or slv_4H_S(4));
	slv_MM(8) <= 	(sl_MM8 xor slv_4H_S(4))					when slv_2J_sel="00" else
						(sl_MM8 xor slv_4H_S(4)) xor sl_ALBNK_CTF		when slv_2J_sel="01" else
						(sl_MM8 xor slv_4H_S(4)) xor sl_ALBNK_CTF		when slv_2J_sel="10" else
						(sl_MM8 xor slv_4H_S(4));				--	when slv_2J_sel="11"

	slv_MM(7 downto 4) <= slv_4H_S(3 downto 0);
	slv_MM(3 downto 1) <= slv_2H_S(2 downto 0) when sl_ALBNK_CTF = '0' else not slv_2H_S(2 downto 0); -- as per SP-299


	-- latches 2F, 3F
	p_2F_3F : process
	begin
		wait until rising_edge(I_MCKR);
		if slv_H(2 downto 0) = "001" then -- rising edge /4HDD
			sl_MOHFLIP <= slv_VRD(15);          -- MO X flip
			sl_VRD13   <= slv_VRD(13);          -- MO Y pos 8
			slv_1H_B   <= slv_VRD(12 downto 9); -- MO Y pos 7..4
			slv_2H_B   <= slv_VRD( 8 downto 5); -- MO Y pos 3..0
			slv_3H_A   <= slv_VRD( 3 downto 0); -- MO tiles-1
		end if;
	end process;

	slv_1H_A <= slv_V(7 downto 4);
	slv_2H_A <= slv_V(3 downto 0);
	slv_3H_B <= slv_1H_S(2 downto 0) & slv_2H_S(3);
	slv_4H_B <= slv_3H_S(3 downto 0) when sl_ALBNK_CTF = '0' else not slv_3H_S(3 downto 0); -- as per SP-299

	-- adders 1H, 2H, 3H, 4H
	slv_1H_S <= ('0' & slv_1H_A + slv_1H_B) + ("000" & slv_2H_S(4));
	slv_2H_S <= ('0' & slv_2H_A + slv_2H_B) + "0001";
	slv_3H_S <= ('0' & slv_3H_A + slv_3H_B) + ("000" & not sl_ALBNK_CTF); -- as per SP-299
	slv_4H_S <= ('0' & slv_4H_A + slv_4H_B);

	-- latch 4F
	p_4F : process
	begin
		wait until rising_edge(I_MCKR);
		if slv_H(2 downto 0) = "100" then -- rising edge 4HDL
			sl_MM19   <= slv_VRD(15);
			sl_MM18   <= slv_VRD(14);
			slv_MM(9) <= slv_VRD( 5);
			sl_MM8    <= slv_VRD( 4);
			slv_4H_A  <= slv_VRD( 3 downto 0);
		end if;
	end process;

	p_3C : process
	begin
		wait until rising_edge(I_MCKR);
		if slv_H(2 downto 0) = "011" then -- rising edge 4H
			-- 1/2A, 3C latch
			-- on SP-299 addr bit 13 is taken from VRD9 but on SP-286 it is connected to ALBNK selector
			-- the only games that uses a 16K ALPHA ROM are indytempc and roadblstcg
			slv_ROM_2B_addr(13 downto 4) <= slv_VRD(9 downto 0);
		end if;
	end process;

	-- unlatched part of address bus
	slv_ROM_2B_addr(3 downto 0) <= slv_V(2 downto 0) & sl_4Hn;
--	slv_ROM_2B_addr(13) <= sl_ALBNK_CTF; -- not used because 2/3B ROM is only 8K

	-- 2/3B ROM (same as 5F)
	slv_ROM_2B_data <= I_DATA2B;

	-- 1B, 2B shifters S1 S0 11=load 10=shift left 01=shift right 00=inhibit
	p_1B_2B : process
	begin
		wait until falling_edge(I_MCKR);
		if slv_H(1 downto 0) = "11" then -- load on H3
			slv_shift_2B <= slv_ROM_2B_data(7 downto 4);
			slv_shift_1B <= slv_ROM_2B_data(3 downto 0);
		else -- shift msb
			slv_shift_2B <= slv_shift_2B(2 downto 0) & '0'; --msb is APIX1
			slv_shift_1B <= slv_shift_1B(2 downto 0) & '0'; --msb is APIX0
		-- else inhibit
		end if;
	end process;

	--------------
	-- sheet 10 --
	--------------

	-- Graphic Priority Control
	u_1C : entity work.GPC
	port map (
		I_CK     => I_MCKR,
		I_PFM    => sl_PFSC_MOn,
		I_421H   => slv_H(2 downto 0),
		I_SEL    => sl_CRAMn,

		-- AL serialised data
		I_AL(1)  => slv_shift_2B(3),
		I_AL(0)  => slv_shift_1B(3),
		I_MA     => slv_MA(10 downto 9),

		-- I_D controls color for alphanumerics
		I_D(3)   => slv_VRD(13), -- SP286 schema has D3<-VRD13
		I_D(2)   => slv_VRD(12), -- SP286 schema has D2<-VRD10
		I_D(1)   => slv_VRD(11), -- SP286 schema has D1<-VRD11
		I_D(0)   => slv_VRD(10), -- SP286 schema has D0<-VRD12

		-- PF data
		I_P      => slv_PFX,

		-- MO data
		I_M      => slv_MPX,

		O_CA     => slv_CRA_GPC
	);

	u_CRAMS : entity work.CRAMS
	port map (
		I_MCKR   => I_MCKR,
		I_WEn    => sl_CRAMWRn,
		I_CRA    => slv_CRA,
		I_CRD    => slv_VBD,
		O_CRD    => slv_CRAM
	);

	slv_CRA <= slv_CRA_GPC(9 downto 8) & slv_MA(8 downto 1) when sl_CRAMn = '0' else slv_CRA_GPC;

	-- 6A, 6B latch color palette output
	p_6A_6B : process
	begin
		wait until falling_edge(I_MCKR);
		if sl_VIDBLANKn = '0' then
			slv_INT <= (others=>'0');
			slv_RED <= (others=>'0');
			slv_GRN <= (others=>'0');
			slv_BLU <= (others=>'0');
		elsif sl_CRBUSn = '1' then
			-- UDS
			slv_INT <= slv_CRAM(15 downto 12); -- INT
			slv_RED <= slv_CRAM(11 downto  8); -- RED
			-- LDS
			slv_GRN <= slv_CRAM( 7 downto  4); -- GRN
			slv_BLU <= slv_CRAM( 3 downto  0); -- BLU
		end if;
	end process;

	slv_MDO <=
		slv_CRAM when sl_CRBUSn = '0' else
		slv_VBD;
end RTL;
