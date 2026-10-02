-- (c) 2020 d18c7db(a)hotmail
--
-- This program is free software; you can redistribute it and/or modify it under
-- the terms of the GNU General Public License version 3 or, at your option,
-- any later version as published by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- For full details, see the GNU General Public License at www.gnu.org/licenses

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity AUDIO is
	port(
		I_MCKR      : in  std_logic; -- 7.14MHz
		I_1H        : in  std_logic;
		I_2H        : in  std_logic;
		O_B02       : out std_logic;

		I_SNDNMIn   : in  std_logic;
		I_SNDRSTn   : in  std_logic;
		I_SNDINTn   : in  std_logic;
		O_SNDBW_Rn  : out std_logic;
		O_WR68Kn    : out std_logic;
		O_RD68Kn    : out std_logic;

		I_SELFTESTn : in  std_logic;
		I_COIN_AUX  : in  std_logic;
		I_COIN_L    : in  std_logic;
		I_COIN_R    : in  std_logic;

		O_LED       : out std_logic_vector( 1 downto 0);
		O_CCTRn     : out std_logic_vector( 1 downto 0);
		O_YM_L      : out signed(15 downto 0) := (others=>'1');
		O_YM_R      : out signed(15 downto 0) := (others=>'1');
		O_PKS       : out signed( 5 downto 0) := (others=>'1');

		O_SROMn     : out std_logic_vector( 2 downto 0);
		O_SNDEXTn   : out std_logic;
		O_SBA       : out std_logic_vector(13 downto 0) := (others=>'1');
		I_SBD       : in  std_logic_vector( 7 downto 0);
		O_SBD       : out std_logic_vector( 7 downto 0);
		I_SMD       : in  std_logic_vector( 7 downto 0)
--		O_SMD       : out std_logic_vector( 7 downto 0)
	);
end AUDIO;

architecture RTL of AUDIO is
	component jt51
	port (
		rst     : in  std_logic;
		clk     : in  std_logic;
		cen     : in  std_logic;
		cen_p1  : in  std_logic;
		cs_n    : in  std_logic;
		wr_n    : in  std_logic;
		a0      : in  std_logic;
		din     : in  std_logic_vector(7 downto 0);
		dout    : out std_logic_vector(7 downto 0);
		ct1     : out std_logic;
		ct2     : out std_logic;
		irq_n   : out std_logic;
		sample  : out std_logic;
		left    : out std_logic_vector(15 downto 0);
		right   : out std_logic_vector(15 downto 0);
		xleft   : out signed(15 downto 0);
		xright  : out signed(15 downto 0)
--		dacleft : out std_logic_vector(15 downto 0);
--		dacright: out std_logic_vector(15 downto 0)
	);
	end component;

	signal
		sl_POKEYn,
		sl_14L_CS,
		sl_15L_CS,
		sl_MXTn,
		sl_SNDEXTn,
		sl_SIORDn,
		sl_14Jb_ENn,
		sl_YMHCSn,
		sl_RD02n,
		sl_WR02n,
		sl_WR02,
		sl_SIOWRn,
		sl_YMHRES,
		sl_YMHRESn,
		sl_2H,
		sl_6502IRQn,
		sl_SNDNMIn,
		sl_SNDRSTn,
		sl_SELFTESTn,
		sl_COIN_AUX,
		sl_COIN_L,
		sl_COIN_R,
		sl_MCKF,
		sl_B02,
		sl_SNDBUF,
		sl_68KBUF,
		sl_SNDBW_Rn,
		sl_SNDBR_Wn,
		sl_WR68Kn,
		sl_RD68Kn
								: std_logic := '1';
	signal
		slv_LED,
		slv_CCTRn
								: std_logic_vector( 1 downto 0) := (others => '0');
	signal
		slv_SROMn
								: std_logic_vector( 2 downto 0) := (others => '0');
	signal
		slv_14Ja_Y,
		slv_14Jb_Y
								: std_logic_vector( 3 downto 0) := (others => '0');
	signal
		slv_YM_data,
		slv_POKEY_data,
		slv_14L_RAM_data,
		slv_15L_RAM_data,
		slv_15H_Y,
		slv_SBDI,
		slv_SBDO,
		slv_SMDI,
		slv_SIODATA
								: std_logic_vector( 7 downto 0) := (others => '0');
	signal
		slv_SBA
								: std_logic_vector(23 downto 0) := (others => '0');
begin
		sl_SNDNMIn   <= I_SNDNMIn;
		sl_SNDRSTn   <= I_SNDRSTn;
		sl_68KBUF    <= not I_SNDNMIn;
		sl_SNDBUF    <= not I_SNDINTn;
		sl_SELFTESTn <= I_SELFTESTn;
		sl_COIN_AUX  <= I_COIN_AUX;
		sl_COIN_L    <= I_COIN_L;
		sl_COIN_R    <= I_COIN_R;
		slv_SMDI     <= I_SMD;

		O_B02        <= sl_B02;
		O_SNDBW_Rn   <= sl_SNDBW_Rn;
		O_WR68Kn     <= sl_WR68Kn;
		O_RD68Kn     <= sl_RD68Kn;
		O_LED        <= slv_LED;
		O_CCTRn      <= slv_CCTRn;

		O_SROMn      <= slv_SROMn;
		O_SBA        <= slv_SBA(13 downto 0);
		O_SBD        <= slv_SBDO; -- when sl_WR68Kn='0' else (others=>'0');
--		O_SMD        <= slv_SBDO when sl_MXTn='1' and sl_SNDBR_Wn = '0' else (others=>'0');
		O_SNDEXTn    <= sl_SNDEXTn;

	-------------
	-- sheet 5 --
	-------------
-- Atari System 1 TTL motherboard PCB factory modification according to atarisy1.cpp from MAME 
-- Location A2 simply fixes a PCB layout pin swap issue with /COMPSYNC to match the schematic.
-- Location J16 and J17 implements a halt to 6502 for 8 video frames after a /RST or /IRQ
-- A 74LS164 shit register is configured as:
-- 74LS164 inputs A,B tied High, CLK tied to /VBLANK, /RST tied to output of AND gate with inputs /6502IRQ 6502 pin 4, /SNDRST 6502 pin 40
-- 74LS164 output QH and signal /SELFTEST go to inputs of NAND gate whose output goes to 6502 /RDY pin 2.
-- When either /6502IRQ or /SNDRST is asserted, the shift register is cleared so 6502 /RDY pin 2 is asserted halting the processor
-- Also 6502 is simoulatneously reset directly through /SNDRST
-- after 8 /VBLANK pulses a logical high has moved through the shift register outputs QA, QB, ..., QG, QH releasing the 6502 from halt
-- QH is logical-NANDed with /SELFTEST then connected to 6502 /RDY pin 2.
-- This means that when /SELFTEST is asserted the above delay behaviour is cancelled and 6502 runns immediatley after /SNDRST is deasserted

	u_16JK : entity work.T65
	port map (
		MODE    => "00",        -- "00" => 6502, "01" => 65C02, "10" => 65C816
		Enable  => sl_B02,      -- clock enable to run at 1.7MHz

		CLK     => I_MCKR,      -- in, system clock 7MHz
		IRQ_n   => sl_6502IRQn, -- in, active low irq
		NMI_n   => sl_SNDNMIn,  -- in, active low nmi
		RES_n   => sl_SNDRSTn,  -- in, active low reset
		RDY     => '1',         -- in, ready (see above PCB factory mod comment ***)
		SO_n    => '1',         -- in, set overflow
		DI      => slv_SBDI,    -- in, data

		A       => slv_SBA,     -- out, address
		DO      => slv_SBDO,    -- out, data
		R_W_n   => sl_SNDBR_Wn, -- out, read /write
		SYNC    => open         -- out, sync
	);

	sl_MCKF <= not I_MCKR;

	-- 14L, 15L RAMs
	sl_WR02 <= not sl_WR02n;
	p_RAM_14L : entity work.RAM_2K8 port map (I_MCKR => sl_MCKF, I_EN => sl_14L_CS, I_WR => sl_WR02, I_ADDR => slv_SBA(10 downto 0), I_DATA => slv_SBDO, O_DATA => slv_14L_RAM_data );
	p_RAM_15L : entity work.RAM_2K8 port map (I_MCKR => sl_MCKF, I_EN => sl_15L_CS, I_WR => sl_WR02, I_ADDR => slv_SBA(10 downto 0), I_DATA => slv_SBDO, O_DATA => slv_15L_RAM_data );

	slv_SIODATA <= sl_SELFTESTn & "00" & sl_SNDBUF & sl_68KBUF & sl_COIN_AUX & sl_COIN_L & sl_COIN_R;

	-- mux various data sources to CPU input data bus
	slv_SBDI <=
		slv_SMDI         when sl_RD02n = '0' and (sl_SNDEXTn = '0' or slv_SROMn /= "111") else
		I_SBD            when sl_RD02n = '0' and sl_RD68Kn  = '0' else
		slv_14L_RAM_data when sl_RD02n = '0' and sl_14L_CS  = '1' else
		slv_15L_RAM_data when sl_RD02n = '0' and sl_15L_CS  = '1' else
		slv_POKEY_data   when sl_RD02n = '0' and sl_POKEYn  = '0' else
		slv_SIODATA      when sl_RD02n = '0' and sl_SIORDn  = '0' else
		slv_YM_data      when sl_RD02n = '0' and sl_YMHCSn  = '0' else
		(others=>'0');

-- Create a PHI2 clock enable, PHI1 is not used
	p_cpuena : process
	begin
		wait until rising_edge(I_MCKR);
		-- use 1H and 2H to create a short clock enable for the 7MHz master clock
		sl_B02 <= I_1H and I_2H;
	end process;

	-- 14Ja 2:4 decoder
	slv_14Ja_Y(3) <= ( not slv_SBA(15) ) or ( not slv_SBA(14) );
	slv_14Ja_Y(2) <= ( not slv_SBA(15) ) or (     slv_SBA(14) );
	slv_14Ja_Y(1) <= (     slv_SBA(15) ) or ( not slv_SBA(14) );
	slv_14Ja_Y(0) <= (     slv_SBA(15) ) or (     slv_SBA(14) );

	slv_SROMn(2) <= slv_14Ja_Y(3);
	slv_SROMn(1) <= slv_14Ja_Y(2);
	slv_SROMn(0) <= slv_14Ja_Y(1);
	sl_14Jb_ENn  <= slv_14Ja_Y(0);

	-- 14Jb 2:4 decoder
	slv_14Jb_Y(3) <= sl_14Jb_ENn  or ( not slv_SBA(12) ) or ( not slv_SBA(11) );
	slv_14Jb_Y(2) <= sl_14Jb_ENn  or ( not slv_SBA(12) ) or (     slv_SBA(11) );
	slv_14Jb_Y(1) <= sl_14Jb_ENn  or (     slv_SBA(12) ) or ( not slv_SBA(11) );
	slv_14Jb_Y(0) <= sl_14Jb_ENn  or (     slv_SBA(12) ) or (     slv_SBA(11) );

	sl_MXTn    <=     slv_14Jb_Y(3);
	sl_SNDEXTn <=     slv_14Jb_Y(2);
	sl_14L_CS  <= not slv_14Jb_Y(1);
	sl_15L_CS  <= not slv_14Jb_Y(0);

	-- 15H 3:8 decoder
	slv_15H_Y(7) <= sl_MXTn  or ( not slv_SBA(6) ) or ( not slv_SBA(5) ) or ( not slv_SBA(4) );
--	slv_15H_Y(6) <= sl_MXTn  or ( not slv_SBA(6) ) or ( not slv_SBA(5) ) or (     slv_SBA(4) ); -- unused
--	slv_15H_Y(5) <= sl_MXTn  or ( not slv_SBA(6) ) or (     slv_SBA(5) ) or ( not slv_SBA(4) ); -- unused
--	slv_15H_Y(4) <= sl_MXTn  or ( not slv_SBA(6) ) or (     slv_SBA(5) ) or (     slv_SBA(4) ); -- unused
--	slv_15H_Y(3) <= sl_MXTn  or (     slv_SBA(6) ) or ( not slv_SBA(5) ) or ( not slv_SBA(4) ); -- unused
	slv_15H_Y(2) <= sl_MXTn  or (     slv_SBA(6) ) or ( not slv_SBA(5) ) or (     slv_SBA(4) );
	slv_15H_Y(1) <= sl_MXTn  or (     slv_SBA(6) ) or (     slv_SBA(5) ) or ( not slv_SBA(4) );
	slv_15H_Y(0) <= sl_MXTn  or (     slv_SBA(6) ) or (     slv_SBA(5) ) or (     slv_SBA(4) );

	-- gates 13F
	sl_POKEYn <= slv_15H_Y(7);
	sl_SIOWRn <= slv_15H_Y(2) or sl_WR02n;
	sl_WR68Kn <= slv_15H_Y(1) or sl_WR02n;
	sl_SIORDn <= slv_15H_Y(2) or sl_RD02n;
	sl_RD68Kn <= slv_15H_Y(1) or sl_RD02n;
	sl_YMHCSn <= slv_15H_Y(0);

	-- gate 8F
	sl_SNDBW_Rn <= not sl_SNDBR_Wn;

	-- gates 15J
	sl_RD02n <= not (sl_B02 and sl_SNDBR_Wn);
	sl_WR02n <= not (sl_B02 and sl_SNDBW_Rn);

	--	POKEY sound (Atari custom chip 137430-001)
	u_17J : entity work.POKEY
	port map (
		ADDR      => slv_SBA(3 downto 0),
		DIN       => slv_SBDO,
		DOUT      => slv_POKEY_data,
		DOUT_OE_L => open,
		CS        => '1',
		CS_L      => sl_POKEYn,
		RW_L      => sl_SNDBR_Wn,

		PIN       => x"00",
		ENA       => sl_B02,
		CLK       => I_MCKR,

		AUDIO_OUT => O_PKS
	);

	-------------
	-- sheet 6 --
	-------------

	sl_YMHRES <= not sl_YMHRESn;
	sl_2H <= I_1H and I_2H;

	-- YM2151 sound
	u_15R : jt51
	port map(
		-- inputs
		rst      => sl_YMHRES,
		clk      => I_MCKR,
		cen      => I_1H,
		cen_p1   => sl_2H,
		a0       => slv_SBA(0),
		wr_n     => sl_WR02n,
		cs_n     => sl_YMHCSn,
		din      => slv_SBDO,

		-- outputs
		dout     => slv_YM_data,
		irq_n    => sl_6502IRQn,

		ct1      => open,
		ct2      => open,

		--	 Low resolution outputs (same as real chip)
		sample   => open,
		left     => open,
		right    => open,

		--	 Full resolution outputs
		xleft    => O_YM_L,
		xright   => O_YM_R
--		dacleft  => open,
--		dacright => open
	);

	-- YM3012 DAC - not used becase YM2151 core outputs parallel sound data

	-- 14F simplified addressable latch
	p_14F : process
	begin
		wait until falling_edge(I_MCKR);
		if sl_SNDRSTn = '0' then
			sl_YMHRESn <= '0';
			slv_LED    <= (others=>'0');
			slv_CCTRn  <= (others=>'0');
		else
			if sl_SIOWRn = '0' then
				case slv_SBA(2 downto 0) is
					when "000" => sl_YMHRESn   <= slv_SBDO(0);
					when "100" => slv_LED(0)   <= slv_SBDO(0);
					when "101" => slv_LED(1)   <= slv_SBDO(0);
					when "110" => slv_CCTRn(0) <= slv_SBDO(0);
					when "111" => slv_CCTRn(1) <= slv_SBDO(0);
					when others => null;
				end case;
			end if;
		end if;
	end process;
end RTL;
