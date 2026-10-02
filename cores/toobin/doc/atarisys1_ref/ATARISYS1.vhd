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

--	Developer: Atari Games
--	Platform:  Arcade
--	Release:   1984
--	CPU:       Motorola 68010 @ 7.15909 MHz, MOS Technology 6502 @ 1.789772 MHz
--	Sound:     Yamaha YM2151 @ 3.579545, Atari POKEY @ 1.789772 MHz, Texas Instruments TMS5220@ 650.826 kHz
--	Display:   Raster, 336x240 resolution

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity FPGA_ATARISYS1 is
	port(
		I_SLAP_TYPE: in  integer range 0 to 118; -- slapstic type can be changed dynamically
		-- System Clock
		I_CLK_7M   : in  std_logic;
		I_CLK_14M  : in  std_logic;

		-- Active high reset
		I_RESET    : in  std_logic;

		O_ADC_ADDR : out std_logic_vector( 2 downto 0);
		I_ADC_DATA : in  std_logic_vector( 7 downto 0);
		-- Trackball inputs active low:
		I_CLK      : in  std_logic_vector(3 downto 0); -- HCLK2,VCLK2,HCLK1,VCLK1
		I_DIR      : in  std_logic_vector(3 downto 0); -- HDIR2,VDIR2,HDIR1,VDIR1
		-- System inputs active low
		I_SELFTESTn: in  std_logic;                    -- SELFTEST
		I_SW       : in  std_logic_vector(5 downto 1); -- SW[5:1]
		I_COIN     : in  std_logic_vector(2 downto 0); -- COIN_AUX, COIN_R, COIN_L

		O_LEDS     : out std_logic_vector(2 downto 1);

		-- Audio out
		O_AUDIO_L  : out std_logic_vector(15 downto 0) := (others=>'0');
		O_AUDIO_R  : out std_logic_vector(15 downto 0) := (others=>'0');

		-- Monitor output
		O_VIDEO_I  : out std_logic_vector(3 downto 0);
		O_VIDEO_R  : out std_logic_vector(3 downto 0);
		O_VIDEO_G  : out std_logic_vector(3 downto 0);
		O_VIDEO_B  : out std_logic_vector(3 downto 0);
		O_HSYNC    : out std_logic;
		O_VSYNC    : out std_logic;
		O_CSYNC    : out std_logic;

		O_HBLANK   : out std_logic;
		O_VBLANK   : out std_logic;

		O_ADDR2B   : out std_logic_vector(13 downto 0);
		I_DATA2B   : in  std_logic_vector( 7 downto 0);

		-- EEPROM data bus
		O_EEPDATA  : out std_logic_vector( 7 downto 0);
		I_EEPDATA  : in  std_logic_vector( 7 downto 0);
		O_EEPWR    : out std_logic;

		-- CART interface
		O_ROMn     : out std_logic_vector( 4 downto 0);
		O_MA18n    : out std_logic;
		O_MADEC    : out std_logic_vector(15 downto 1);
		I_MDATA    : in  std_logic_vector(15 downto 0);

		O_SROMn    : out std_logic_vector( 2 downto 0);
		O_SBA      : out std_logic_vector(13 downto 0);

		O_PADDR    : out std_logic_vector( 8 downto 0);
		I_PD4A     : in  std_logic_vector( 7 downto 0);
		I_PD7A     : in  std_logic_vector( 7 downto 0);
		I_SDATA    : in  std_logic_vector( 7 downto 0);

		O_VADDR    : out std_logic_vector(18 downto 0);
		I_VDATA    : in  std_logic_vector(63 downto 0)
	);
end FPGA_ATARISYS1;

architecture RTL of FPGA_ATARISYS1 is
	signal
		sl_BASn,
		sl_INT1n,
		sl_INT3n,
		sl_WAITn,
		sl_MA18n,
		sl_MATCHn,
		sl_MGHF,
		sl_GLDn,
		sl_MD7,
		sl_MO_PFn,
		sl_SNDEXTn,
		sl_SNDBW_Rn,
		sl_B02,

		sl_adc_eoc,
		sl_adc_soc,
		sl_adc_soc_last,
		sl_TBTEST,
		sl_TBRESn,
		sl_1H,
		sl_2H,
		sl_4H,
		sl_8H,
		sl_BW_Rn,
		sl_WR68Kn,
		sl_RD68Kn,
		sl_SNDNMIn,
		sl_SNDRESn,
		sl_SNDINTn,
		sl_SYSRESn,

		sl_CRAMn,
		sl_CRBUSn,
		sl_CRAMWRn,
		sl_VRAMWR,
		sl_VBUSn,
		sl_VRAC2,
		sl_HBLANKn,
		sl_VBLANKn,
		sl_VBKACKn,
		sl_VBKINTn,
		sl_MEXTn,
		sl_MISCn,
		sl_PFSPCn,
		sl_VSCRLDn,
		sl_HSCRLDn
								: std_logic := '1';
	signal
		slv_adc_addr
								: std_logic_vector( 2 downto 0) := (others=>'0');
	signal
		slv_ROMn
								: std_logic_vector( 4 downto 0) := (others=>'0');
	signal
		s_POK_out
								:           signed( 5 downto 0) := (others=>'0');
	signal
		slv_MOSR
								: std_logic_vector( 6 downto 0) := (others=>'0');
	signal
		slv_SBDI,
		slv_SBDO,
		slv_PFSR,
		slv_SMD,
		slv_adc_data
								: std_logic_vector( 7 downto 0) := (others=>'0');
	signal
		slv_adc_ctr
								: std_logic_vector( 9 downto 0) := (others=>'0');
	signal
		slv_SBA
								: std_logic_vector(13 downto 0) := (others=>'0');
	signal
		s_snd
								:           signed(13 downto 0) := (others=>'0');
	signal
		slv_VBUSD,
		slv_MDO
								: std_logic_vector(15 downto 0) := (others=>'0');
	signal
		slv_MADDR
								: std_logic_vector(15 downto 1) := (others=>'0');
	signal
		s_chan_l,
		s_chan_r,
		s_audio_YML,
		s_audio_YMR
								:           signed(15 downto 0) := (others=>'0');
	signal
		slv_MGRA
								: std_logic_vector(19 downto 1) := (others=>'0');
begin
	-- ADC0809 converts analog player control inputs with a 100uS conversion delay
	-- the channel data already comes to us digitised so here we just route it to the data bus
	p_adc0809 : process
	begin
		wait until rising_edge(I_CLK_7M);
		sl_adc_soc_last <= sl_adc_soc;
		if sl_adc_soc_last = '0' and sl_adc_soc = '1' then
			slv_adc_ctr <=  (others=>'0');
			sl_adc_eoc <= '0';
			slv_adc_data <= I_ADC_DATA;

		-- fake a 100uS conversion delay, may not be needed but it's as per datasheet
		elsif slv_adc_ctr > "1011001011" then -- after 715 cycles of 140ns = 100uS
			sl_adc_eoc <= '1';
		else
			slv_adc_ctr <= slv_adc_ctr + 1;
		end if;
	end process;

	O_LEDS    <= (others=>'0');
	O_HBLANK  <= sl_HBLANKn;
	O_VBLANK  <= sl_VBLANKn;
	O_SBA     <= slv_SBA;
	O_MA18n   <= sl_MA18n;
	O_ROMn    <= slv_ROMn;
	O_EEPDATA <= slv_MDO(7 downto 0);
	O_ADC_ADDR<= slv_adc_addr;

	u_main : entity work.MAIN
	port map (
		I_MCKR      => I_CLK_7M,
		I_XCKR      => I_CLK_14M,
		I_RESET     => I_RESET,
		I_VBLANKn   => sl_VBLANKn,
		I_VBKINTn   => sl_VBKINTn,

		I_MD7       => sl_MD7,
		I_4H        => sl_4H,
		I_8H        => sl_8H,
		I_INT1n     => sl_INT1n,
		I_INT3n     => sl_INT3n,
		I_WAITn     => sl_WAITn,
		I_VRAC2     => sl_VRAC2,
		I_WR68Kn    => sl_WR68Kn,
		I_RD68Kn    => sl_RD68Kn,

		I_SNDRESn   => sl_SNDRESn,

		O_BW_Rn     => sl_BW_Rn,
		O_CRAMn     => sl_CRAMn,
		O_CRAMWRn   => sl_CRAMWRn,
		O_VRAMWR    => sl_VRAMWR,
		O_CRBUSn    => sl_CRBUSn,
		O_SYSRESn   => sl_SYSRESn,

		O_HSCRLDn   => sl_HSCRLDn,
		O_SNDNMIn   => sl_SNDNMIn,
		O_SNDINTn   => sl_SNDINTn,
		O_VBKACKn   => sl_VBKACKn,
		O_VBUSn     => sl_VBUSn,
		O_MISCn     => sl_MISCn,
		O_PFSPCn    => sl_PFSPCn,
		O_VSCRLDn   => sl_VSCRLDn,
		O_SBD       => slv_SBDI,
		I_SBD       => slv_SBDO,

		-- J106 (+5 N/C LED2 LED1 KEY PB5 PB2 PB4 PB1 PB3 GND) push buttons 5-1 and SELFTEST
		-- PB5=N/C, PB4=N/C, PB3=Jump (not used for Indiana Jones cart), PB2 = Start2/Whip/Throw, PB1=Start1/Whip/Throw
		I_PB        => I_SW(5 downto 1),
		I_SELFTESTn => I_SELFTESTn,

		-- interface to extenal ADC0809 chip
		O_ADC_SOC   => sl_adc_soc, -- active high start of conversion
		O_ADC_CLK   => open,
		O_ADC_ADDR  => slv_adc_addr,
		I_ADC_DATA  => slv_adc_data,
		I_ADC_EOC   => sl_adc_eoc, -- active high end of conversion

		-- trackball interface
		I_LETA_CLK  => I_CLK,
		I_LETA_DIR  => I_DIR,
		I_LETA_TST  => sl_TBTEST,
		I_LETA_RES  => sl_TBRESn,

		I_EEPDATA   => I_EEPDATA,
		O_EEPWR     => O_EEPWR,

		-- to game cartridge
		O_MA18n     => sl_MA18n,
		O_BLDS      => open,
		O_ROMn      => slv_ROMn,
		O_BASn      => sl_BASn,
		O_MEXTn     => sl_MEXTn,
		O_MADDR     => slv_MADDR,
		O_MDATA     => slv_MDO,
		I_VBUSD     => slv_VBUSD,
		I_MEXTD     => I_MDATA
	);

	u_video : entity work.VIDEO
	port map (
		I_MCKR      => I_CLK_7M,
		I_XCKR      => I_CLK_14M,
		I_SYSRESn   => sl_SYSRESn,
		I_CRBUSn    => sl_CRBUSn,
		I_CRAMn     => sl_CRAMn,
		I_CRAMWRn   => sl_CRAMWRn,
		I_VRAMWR    => sl_VRAMWR,

		I_BW_Rn     => sl_BW_Rn,
		I_VBUSn     => sl_VBUSn,
		I_MISCn     => sl_MISCn,
		I_PFSPCn    => sl_PFSPCn,
		I_VSCRLDn   => sl_VSCRLDn,
		I_HSCRLDn   => sl_HSCRLDn,
		I_VBKACKn   => sl_VBKACKn,
		I_MOSR      => slv_MOSR,
		I_PFSR      => slv_PFSR,
		I_CPU_A     => slv_MADDR(13 downto 1),
		I_CPU_D     => slv_MDO,
		O_CPU_D     => slv_VBUSD,

		O_ADDR2B    => O_ADDR2B,
		I_DATA2B    => I_DATA2B,

		O_SNDRESn   => sl_SNDRESn,
		O_MGHF      => sl_MGHF,
		O_GLDn      => sl_GLDn,
		O_MO_PFn    => sl_MO_PFn,
		O_MATCHn    => sl_MATCHn,
		O_VBKINTn   => sl_VBKINTn,
		O_MGRA      => slv_MGRA,
		O_VRAC2     => sl_VRAC2,
		O_1H        => sl_1H,
		O_2H        => sl_2H,
		O_4H        => sl_4H,
		O_8H        => sl_8H,
		O_TBTEST    => sl_TBTEST,
		O_TBRESn    => sl_TBRESn,

		O_VBLANKn   => sl_VBLANKn,
		O_HBLANKn   => sl_HBLANKn,
		O_I         => O_VIDEO_I,
		O_R         => O_VIDEO_R,
		O_G         => O_VIDEO_G,
		O_B         => O_VIDEO_B,
		O_HSYNC     => O_HSYNC,
		O_VSYNC     => O_VSYNC,
		O_CSYNC     => O_CSYNC
	);

	u_audio : entity work.AUDIO
	port map (
		I_MCKR      => I_CLK_7M,
		I_1H        => sl_1H,
		I_2H        => sl_2H,
		O_B02       => sl_B02,

		I_SNDNMIn   => sl_SNDNMIn,
		I_SNDRSTn   => sl_SNDRESn,
		I_SNDINTn   => sl_SNDINTn,
		O_SNDBW_Rn  => sl_SNDBW_Rn,
		O_WR68Kn    => sl_WR68Kn,
		O_RD68Kn    => sl_RD68Kn,

		I_SELFTESTn => I_SELFTESTn,
		I_COIN_AUX  => I_COIN(2),
		I_COIN_R    => I_COIN(1),
		I_COIN_L    => I_COIN(0),

		O_LED       => open,	-- LED indicators
		O_CCTRn     => open,	-- coin counters open collector active low
		O_YM_L      => s_audio_YML,
		O_YM_R      => s_audio_YMR,
		O_PKS       => s_POK_out,

		O_SROMn     => O_SROMn,
		O_SNDEXTn   => sl_SNDEXTn,
		O_SBA       => slv_SBA,
		O_SBD       => slv_SBDO,
		I_SMD       => slv_SMD,
--		O_SMD       => slv_SMDO,
		I_SBD       => slv_SBDI
	);

	u_cart : entity work.ATARI_CART
	port map (
		I_SLAP_TYPE => I_SLAP_TYPE,
		I_MCKR      => I_CLK_7M,
		I_XCKR      => I_CLK_14M,

		I_BASn      => sl_BASn,
		O_INT1n     => sl_INT1n,
		O_INT3n     => sl_INT3n,
		O_WAITn     => sl_WAITn,
		O_MD7       => sl_MD7,
		I_SLAPn     => slv_ROMn(4),
		I_MA18n     => sl_MA18n,
		I_MADDR     => slv_MADDR, -- raw addr from CPU

		I_SMD       => slv_SBDO, -- to VIA in
		O_SMD       => slv_SMD,  -- sound ROM data out
		I_SBA       => slv_SBA,

		I_MGRA      => slv_MGRA,
		I_MATCHn    => sl_MATCHn,
		I_MGHF      => sl_MGHF,
		I_MEXTn     => sl_MEXTn,
		I_BW_Rn     => sl_BW_Rn,
		I_GLDn      => sl_GLDn,
		I_MO_PFn    => sl_MO_PFn,
		I_SNDEXTn   => sl_SNDEXTn,
		I_SNDRSTn   => sl_SNDRESn,
		I_SNDBW_Rn  => sl_SNDBW_Rn,
		I_B02       => sl_B02,

		-- video shifters
		O_MOSR      => slv_MOSR,
		O_PFSR      => slv_PFSR,

		-- sound L and R are the same
		O_SND       => s_snd,

		O_MADEC     => O_MADEC, -- addr decoded by slapstic

		-- PROMs to outside
		O_PADDR     => O_PADDR,
		I_PD4A      => I_PD4A,
		I_PD7A      => I_PD7A,

		-- sound ROMs to outside
		I_SDATA     => I_SDATA,

		-- video ROMs to outside
		O_VADDR     => O_VADDR,
		I_VDATA     => I_VDATA
);

	p_volmux : process
	begin
		wait until rising_edge(I_CLK_7M);
		-- add signed outputs together, already have extra spare bits for overflow
		s_chan_l <= ( ((s_snd & "00") + s_audio_YML) + (s_POK_out(s_POK_out'left) & s_POK_out & "000000000") );
		s_chan_r <= ( ((s_snd & "00") + s_audio_YMR) + (s_POK_out(s_POK_out'left) & s_POK_out & "000000000") );

		-- convert to unsigned slv for DAC usage
		O_AUDIO_L <= std_logic_vector(s_chan_l + 16383);
		O_AUDIO_R <= std_logic_vector(s_chan_r + 16383);
	end process;

end RTL;
