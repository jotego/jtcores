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
-- Based on SP-286 schematic

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity MAIN is
	port(
		I_MCKR      : in  std_logic; -- 7MHz
		I_XCKR      : in  std_logic; -- 14MHz
		I_MD7       : in  std_logic;
		I_4H        : in  std_logic;
		I_8H        : in  std_logic;
		I_RESET     : in  std_logic; -- active high
		I_INT1n     : in  std_logic;
		I_INT3n     : in  std_logic;
		I_WAITn     : in  std_logic;
		I_RD68Kn    : in  std_logic;
		I_WR68Kn    : in  std_logic;
		I_SNDRESn   : in  std_logic;
		I_VBLANKn   : in  std_logic;
		I_VBKINTn   : in  std_logic;
		I_VRAC2     : in  std_logic;

		O_BW_Rn     : out std_logic;
		O_MA18n     : out std_logic;
		O_BLDS      : out std_logic;
		O_ROMn      : out std_logic_vector( 4 downto 0);
		O_CRAMWRn   : out std_logic;
		O_VRAMWR    : out std_logic;
		O_CRAMn     : out std_logic;
		O_CRBUSn    : out std_logic;
		O_SYSRESn   : out std_logic;

		O_VBKACKn   : out std_logic;
		O_SNDINTn   : out std_logic;
		O_VBUSn     : out std_logic;
		O_MISCn     : out std_logic;
		O_PFSPCn    : out std_logic;
		O_VSCRLDn   : out std_logic;
		O_HSCRLDn   : out std_logic;

		O_SNDNMIn   : out std_logic;
		O_SBD       : out std_logic_vector( 7 downto 0);
		I_SBD       : in  std_logic_vector( 7 downto 0);

		-- Push buttons PB5,PB4,PB3,PB2,PB1
		I_PB        : in  std_logic_vector( 5 downto 1);
		I_SELFTESTn : in  std_logic;

		-- interface to extenal ADC0809 chip
		O_ADC_SOC   : out std_logic;                     -- ADC select and start conversion
		O_ADC_CLK   : out std_logic;                     -- ADC clock
		O_ADC_ADDR  : out std_logic_vector( 2 downto 0); -- ADC address
		I_ADC_DATA  : in  std_logic_vector( 7 downto 0); -- ADC data
		I_ADC_EOC   : in  std_logic;                     -- ADC end of conversion

		-- J103 trackball interface
		I_LETA_CLK  : in  std_logic_vector( 3 downto 0); -- trackball clks
		I_LETA_DIR  : in  std_logic_vector( 3 downto 0); -- trackball dirs
		I_LETA_TST  : in  std_logic;
		I_LETA_RES  : in  std_logic;

		-- EEPROM data bus
		I_EEPDATA   : in  std_logic_vector( 7 downto 0);
		O_EEPWR     : out std_logic;

		-- to game cartridge
		O_BASn      : out std_logic;
		O_MEXTn     : out std_logic;
		O_MADDR     : out std_logic_vector(15 downto 1);
		O_MDATA     : out std_logic_vector(15 downto 0);
		I_VBUSD     : in  std_logic_vector(15 downto 0);
		I_MEXTD     : in  std_logic_vector(15 downto 0)
	);
end MAIN;

architecture RTL of MAIN is
	signal
		sl_12F_En,
		sl_68KBUF,
		sl_8H5,
		sl_8H8,
		sl_8J_En,
		sl_AJSINTn,
		sl_ASn,
		sl_CRAMWRn,
		sl_CRAMn,
		sl_CRBUSn,
		sl_DTACKn,
		sl_E2PROMn,
		sl_HSCRLDn,
		sl_IBUSn,
		sl_INPUTn,
		sl_INT1n,
		sl_INT3n,
		sl_LDSn,
		sl_MEXTn,
		sl_MISCn,
		sl_PFSPCn,
		sl_RAJS,
		sl_RAJSn,
		sl_RAJSn_last,
		sl_RAM0,
		sl_RAM1,
		sl_RCO,
		sl_RESETn,
		sl_RLETAn,
		sl_RLn,
		sl_R_Wn,
		sl_RD68Kn,
		sl_SELFTESTn,
--		sl_SNDBUFn,
		sl_SNDINTn,
		sl_SNDNMIn,
		sl_SNDRDn,
		sl_SNDRSTn,
		sl_SNDWRn,
		sl_SNDWRn_last,
		sl_SYSRESn,
		sl_UDSn,
		sl_UNLOCKn,
		sl_VBKACKn,
		sl_VBKINTn,
		sl_VBLANKn,
		sl_VBLANKn_last,
		sl_VBUSn,
		sl_VPAn,
		sl_VRAC2,
		sl_VRAC2_last,
--		sl_VRAMRDn,
		sl_VRAMWR,
		sl_VRAMn,
		sl_VRDTACK,
		sl_VRDTACKn,
		sl_VSCRLDn,
		sl_WAITn,
		sl_WDOGn,
		sl_WR68Kn,
		sl_WR68Kn_last,
		sl_WHn,
		sl_WLn,
		sl_WLn_last,
		sl_WRH,
		sl_WRL
								: std_logic := 'U';
	signal
		slv_FC,
		slv_IPL
								: std_logic_vector( 2 downto 0) := (others=>'U');
	signal
		slv_7Ka_Y,
		slv_7Kb_Y,
		ctr_11C,
		ctr_10L
								: std_logic_vector( 3 downto 0) := (others=>'U');
	signal
		slv_ROMn,
		slv_12F_Y
								: std_logic_vector( 4 downto 0) := (others=>'U');
	signal
		slv_PB
								: std_logic_vector( 5 downto 1) := (others=>'U');
	signal
		slv_12K_data,
		slv_12L_data,
		slv_13K_data,
		slv_13L_data,
		slv_SBDI,
		slv_INPUTS,
		slv_LETADB,
		slv_ADC_data
								: std_logic_vector( 7 downto 0) := (others=>'U');
	signal
		slv_14D_Y,
		slv_8J_Y
								: std_logic_vector( 6 downto 0) := (others=>'U');
	signal
		slv_VBUSD,
		slv_MEXTD,
		slv_cpu_di,
		slv_cpu_do
								: std_logic_vector(15 downto 0) := (others=>'U');
	signal
		slv_cpu_ad
								: std_logic_vector(31 downto 0) := (others=>'U');
begin
	O_BW_Rn      <= not sl_R_Wn;
	O_MA18n      <= not slv_cpu_ad(18);
	O_BLDS       <= not sl_LDSn;
	O_ROMn       <= slv_ROMn;
	O_BASn       <= sl_ASn;
	O_VBUSn      <= sl_VBUSn;
	O_MEXTn      <= sl_MEXTn;
	O_VBKACKn    <= sl_VBKACKn;
	O_MISCn      <= sl_MISCn;
	O_PFSPCn     <= sl_PFSPCn;
	O_VSCRLDn    <= sl_VSCRLDn;
	O_HSCRLDn    <= sl_HSCRLDn;
	O_SNDNMIn    <= sl_SNDNMIn;
	O_ADC_SOC    <= sl_RAJS;
	O_ADC_CLK    <= I_4H;
	O_ADC_ADDR   <= slv_cpu_ad(3 downto 1);
	O_CRAMWRn    <= sl_CRAMWRn;
	O_VRAMWR     <= sl_VRAMWR;
	O_CRAMn      <= sl_CRAMn;
	O_CRBUSn     <= sl_CRBUSn;
	O_SNDINTn    <= sl_SNDINTn;
	O_MADDR      <= slv_cpu_ad(15 downto 1);
	O_MDATA      <= slv_cpu_do;
	O_SYSRESn    <= sl_SYSRESn;
	O_EEPWR      <= not (sl_WLn or sl_E2PROMn);

	slv_VBUSD    <= I_VBUSD;
	slv_ADC_data <= I_ADC_DATA;
	sl_AJSINTn   <= not (I_ADC_EOC and sl_8H8); --gate 15J
	sl_RESETn    <= not I_RESET;
	sl_INT1n     <= I_INT1n;
	sl_INT3n     <= I_INT3n;
	sl_WAITn     <= I_WAITn;
	sl_VBLANKn   <= I_VBLANKn;
	sl_VBKINTn   <= I_VBKINTn;
	slv_PB       <= I_PB;
	sl_RD68Kn    <= I_RD68Kn;
	sl_WR68Kn    <= I_WR68Kn;
	sl_SNDRSTn   <= I_SNDRESn;
	sl_SELFTESTn <= I_SELFTESTn;
	sl_68KBUF    <= not sl_SNDNMIn;
--	sl_SNDBUFn   <= not sl_SNDINTn;
	sl_VRAC2     <= I_VRAC2;
	slv_MEXTD    <= I_MEXTD;

	-- CPU input data bus mux
	slv_cpu_di <=
		slv_12K_data & slv_12L_data   when sl_R_Wn = '1' and sl_RAM0   = '1'                          else
		slv_13K_data & slv_13L_data   when sl_R_Wn = '1' and sl_RAM1   = '1'                          else
							slv_MEXTD when sl_R_Wn = '1' and slv_ROMn /= "11111"                      else
							slv_VBUSD when sl_R_Wn = '1' and sl_VBUSn  = '0'                          else
				 x"FF" & slv_ADC_DATA when sl_R_Wn = '1' and sl_IBUSn  = '0' and sl_RAJS    = '1'     else
				 x"FF" & slv_SBDI     when sl_R_Wn = '1' and sl_IBUSn  = '0' and sl_SNDRDn  = '0'     else
				 x"FF" & slv_LETADB   when sl_R_Wn = '1' and sl_IBUSn  = '0' and sl_RLETAn  = '0'     else
				 x"FF" & I_EEPDATA    when sl_R_Wn = '1' and sl_IBUSn  = '0' and sl_E2PROMn = '0'     else
				 x"FF" & slv_INPUTS   when sl_R_Wn = '1' and sl_IBUSn  = '0' and sl_INPUTn  = '0'     else
		x"FF" & I_MD7 & "1111111"     when sl_R_Wn = '1' and sl_MEXTn  = '0' and slv_cpu_ad(18) = '1' else
		(others=>'0');

	-------------
	-- sheet 2 --
	-------------

	-- 17L priority interrupt encoder
	slv_IPL <=
		"001" when sl_SNDINTn = '0' else -- 6
		"011" when sl_VBKINTn = '0' else -- 4
		"100" when sl_INT3n   = '0' else -- 3
		"101" when sl_AJSINTn = '0' else -- 2
		"110" when sl_INT1n   = '0' else -- 1
		"111";

	-- FIXME pick one
	sl_SYSRESn     <= ctr_10L(3); -- slow reset as per schema
--	sl_SYSRESn     <= sl_RESETn;  -- fast reset for simulation

	-- VRDTACK signal generation
	p_10Da : process
	begin
		wait until rising_edge(I_XCKR);
		sl_VRAC2_last <= sl_VRAC2;
		if sl_ASn = '1' then
			sl_VRDTACKn <= '1';
		elsif sl_VRAC2_last = '0' and sl_VRAC2 = '1' then
			sl_VRDTACKn <= sl_VRAMn;
		end if;
	end process;

	sl_VRDTACK <= not sl_VRDTACKn;

	--	12E gate
	sl_VPAn    <= not ((not sl_ASn) and slv_FC(2) and slv_FC(1) and slv_FC(0) );

	-- 10C gate
	sl_DTACKn  <= not (sl_VRDTACK or sl_RCO);

	sl_RCO <= ctr_11C(3) and ctr_11C(2) and ctr_11C(1) and ctr_11C(0);

	-- busk ACK delay
	p_11C : process
	begin
		wait until rising_edge(I_MCKR);
		-- clear
		if sl_ASn = '1' or sl_VRAMn = '0' or sl_WAITn = '0' then
			ctr_11C <= (others=>'0');
		-- load
		elsif ctr_11C(3) = '0' then
			ctr_11C <= '1' & '1' & sl_IBUSn & sl_MEXTn;
		-- count
		elsif sl_DTACKn = '1' then
			ctr_11C <= ctr_11C + 1;
		end if;
	end process;

	-- Wrapper around 68010 soft core
	u_12H : entity work.TG68K
	generic map (
		CPU        => "01"           -- 00->68000  01->68010  11->68020
	)
	port map (
		CLK        => I_MCKR,        -- CLK 7.1591MHz
		RESET      => sl_SYSRESn,    -- RESET active low
		HALT       => sl_SYSRESn,    -- HALT  in sync with reset

		BERR       => '0',           -- BERR tied high (inverse logic)
		IPL        => slv_IPL,       -- IPL
		ADDR       => slv_cpu_ad,    -- ADDR
		FC         => slv_FC,        -- FC2..0
		DATAI      => slv_cpu_di,    -- DATA in
		DATAO      => slv_cpu_do,    -- DATA out
---- bus control
--		BG         => open,
--		BR         => '1',           -- BR    tied high
--		BGACK      => '1',           -- BGACK tied high
-- async interface
		AS         => sl_ASn,        -- AS
		UDS        => sl_UDSn,       -- UDS
		LDS        => sl_LDSn,       -- LDS
		RW         => sl_R_Wn,       -- R/W
		DTACK      => sl_DTACKn,     -- DTACK active low
-- sync interface
		E          => open,          -- E   not connected
		VPA        => sl_VPAn,       -- VPA   active low
		VMA        => open           -- VMA not connected
	);

	-- reset circuit
	-- counter counts VBLANK intervals from 8 up to 15 and the system
	-- resets if it reaches 0 without being preset by watchdog back to 8
	p_10L : process(sl_RESETn, I_MCKR)
	begin
		if sl_RESETn = '0' then
			ctr_10L <= (others=>'0');
		elsif rising_edge(I_MCKR) then
			sl_VBLANKn_last <= I_VBLANKn;
			if sl_WDOGn = '0' then
				ctr_10L <= "1000";
			elsif sl_VBLANKn_last='1' and I_VBLANKn='0' then
				ctr_10L <= ctr_10L + 1;
			end if;
		end if;
	end process;

	-- 7Ka 2:4 decoder
	slv_7Ka_Y(3) <= sl_ASn    or ( not slv_cpu_ad(23) ) or ( not slv_cpu_ad(22) );
	slv_7Ka_Y(2) <= sl_ASn    or ( not slv_cpu_ad(23) ) or (     slv_cpu_ad(22) );
	slv_7Ka_Y(1) <= sl_ASn    or (     slv_cpu_ad(23) ) or ( not slv_cpu_ad(22) );
	slv_7Ka_Y(0) <= sl_ASn    or (     slv_cpu_ad(23) ) or (     slv_cpu_ad(22) );

	-- 7Kb 2:4 decoder
	slv_7Kb_Y(3) <= sl_VBUSn  or ( not slv_cpu_ad(21) ) or ( not slv_cpu_ad(20) );
	slv_7Kb_Y(2) <= sl_VBUSn  or ( not slv_cpu_ad(21) ) or (     slv_cpu_ad(20) );
	slv_7Kb_Y(1) <= sl_VBUSn  or (     slv_cpu_ad(21) ) or ( not slv_cpu_ad(20) );
	slv_7Kb_Y(0) <= sl_VBUSn  or (     slv_cpu_ad(21) ) or (     slv_cpu_ad(20) );

	-- 14D 3:8 decoder
--	slv_14D_Y(7) <= sl_IBUSn  or ( not slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) ); -- unused
	slv_14D_Y(6) <= sl_IBUSn  or ( not slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );
	slv_14D_Y(5) <= sl_IBUSn  or ( not slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) ); -- unused
	slv_14D_Y(4) <= sl_IBUSn  or ( not slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );
	slv_14D_Y(3) <= sl_IBUSn  or (     slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) );
	slv_14D_Y(2) <= sl_IBUSn  or (     slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );
	slv_14D_Y(1) <= sl_IBUSn  or (     slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) );
	slv_14D_Y(0) <= sl_IBUSn  or (     slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );

	-- 8J 3:8 decoder
--	slv_8J_Y(7)  <= sl_8J_En  or ( not slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) ); -- unused
	slv_8J_Y(6)  <= sl_8J_En  or ( not slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );
	slv_8J_Y(5)  <= sl_8J_En  or ( not slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) );
	slv_8J_Y(4)  <= sl_8J_En  or ( not slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );
	slv_8J_Y(3)  <= sl_8J_En  or (     slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) );
	slv_8J_Y(2)  <= sl_8J_En  or (     slv_cpu_ad(19) ) or ( not slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );
	slv_8J_Y(1)  <= sl_8J_En  or (     slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or ( not slv_cpu_ad(17) );
	slv_8J_Y(0)  <= sl_8J_En  or (     slv_cpu_ad(19) ) or (     slv_cpu_ad(18) ) or (     slv_cpu_ad(17) );

	-- 12F 3:8 decoder
--	slv_12F_Y(7) <= sl_12F_En or ( not slv_cpu_ad(19) ) or ( not slv_cpu_ad(17) ) or ( not slv_cpu_ad(16) ); -- unused
--	slv_12F_Y(6) <= sl_12F_En or ( not slv_cpu_ad(19) ) or ( not slv_cpu_ad(17) ) or (     slv_cpu_ad(16) ); -- unused
--	slv_12F_Y(5) <= sl_12F_En or ( not slv_cpu_ad(19) ) or (     slv_cpu_ad(17) ) or ( not slv_cpu_ad(16) ); -- unused
	slv_12F_Y(4) <= sl_12F_En or ( not slv_cpu_ad(19) ) or (     slv_cpu_ad(17) ) or (     slv_cpu_ad(16) );
	slv_12F_Y(3) <= sl_12F_En or (     slv_cpu_ad(19) ) or ( not slv_cpu_ad(17) ) or ( not slv_cpu_ad(16) );
	slv_12F_Y(2) <= sl_12F_En or (     slv_cpu_ad(19) ) or ( not slv_cpu_ad(17) ) or (     slv_cpu_ad(16) );
	slv_12F_Y(1) <= sl_12F_En or (     slv_cpu_ad(19) ) or (     slv_cpu_ad(17) ) or ( not slv_cpu_ad(16) );
	slv_12F_Y(0) <= sl_12F_En or (     slv_cpu_ad(19) ) or (     slv_cpu_ad(17) ) or (     slv_cpu_ad(16) );

	sl_IBUSn     <= slv_7Ka_Y(3);
	sl_VBUSn     <= slv_7Ka_Y(2);
	sl_8J_En     <= slv_7Kb_Y(0);
	sl_12F_En    <= slv_cpu_ad(23) or slv_cpu_ad(22) or slv_cpu_ad(21);

	-- gates 9H, 10K
	sl_RAM1      <= not (slv_7Ka_Y(1) or (     slv_cpu_ad(12) ));
	sl_RAM0      <= not (slv_7Ka_Y(1) or ( not slv_cpu_ad(12) ));
	sl_MEXTn     <= slv_7Ka_Y(0) or ( not slv_cpu_ad(21) );

	sl_CRAMn     <= slv_7Kb_Y(3);
	sl_VRAMn     <= slv_7Kb_Y(2);

	-- gates 5H
--	sl_VRAMRDn   <= sl_VRAMn or sl_RLn;

	-- gates 8K, 8F, 10K
	sl_WHn       <= sl_UDSn or sl_R_Wn;
	sl_WLn       <= sl_LDSn or sl_R_Wn;
	sl_RLn       <= sl_LDSn or (not sl_R_Wn);

	-- gates 7J
	sl_SNDRDn    <= slv_14D_Y(6);
	sl_SNDWRn    <= slv_14D_Y(4) or sl_WLn;
	sl_INPUTn    <= slv_14D_Y(3);
	sl_RAJSn     <= slv_14D_Y(2);
	sl_RLETAn    <= slv_14D_Y(1);
	sl_E2PROMn   <= slv_14D_Y(0);
	sl_CRBUSn    <= sl_LDSn or sl_CRAMn;
	sl_CRAMWRn   <= sl_LDSn or (sl_CRAMn or sl_R_Wn);

	-- gates 5H, 10C
	sl_RAJS      <= (not (sl_RAJSn or sl_RLn));
	sl_VRAMWR    <= not (sl_VRAMn or sl_WLn or sl_VRDTACKn);

	sl_UNLOCKn   <= slv_8J_Y(6);
	sl_VBKACKn   <= slv_8J_Y(5);
	sl_WDOGn     <= slv_8J_Y(4);
	sl_MISCn     <= slv_8J_Y(3);
	sl_PFSPCn    <= slv_8J_Y(2);
	sl_VSCRLDn   <= slv_8J_Y(1);
	sl_HSCRLDn   <= slv_8J_Y(0);

	slv_ROMn     <= slv_12F_Y(4 downto 0);

	-------------
	-- sheet 3 --
	-------------

	-- RAM at address 400000-401FFF
	sl_WRH <= not sl_WHn;
	sl_WRL <= not sl_WLn;
	p_RAM_12K : entity work.RAM_2K8 port map (I_MCKR => I_XCKR, I_EN => sl_RAM0, I_WR => sl_WRH, I_ADDR => slv_cpu_ad(11 downto 1), I_DATA => slv_cpu_do(15 downto 8), O_DATA => slv_12K_data );
	p_RAM_12L : entity work.RAM_2K8 port map (I_MCKR => I_XCKR, I_EN => sl_RAM0, I_WR => sl_WRL, I_ADDR => slv_cpu_ad(11 downto 1), I_DATA => slv_cpu_do( 7 downto 0), O_DATA => slv_12L_data );
	p_RAM_13K : entity work.RAM_2K8 port map (I_MCKR => I_XCKR, I_EN => sl_RAM1, I_WR => sl_WRH, I_ADDR => slv_cpu_ad(11 downto 1), I_DATA => slv_cpu_do(15 downto 8), O_DATA => slv_13K_data );
	p_RAM_13L : entity work.RAM_2K8 port map (I_MCKR => I_XCKR, I_EN => sl_RAM1, I_WR => sl_WRL, I_ADDR => slv_cpu_ad(11 downto 1), I_DATA => slv_cpu_do( 7 downto 0), O_DATA => slv_13L_data );

	-- FIXME check if F/F 8L is necessary for data mux, disconnects CPU data bus from cart port for any address = ROM0 or higher than 800000

	-------------
	-- sheet 4 --
	-------------

	-- 14C buffer
	slv_INPUTS <= sl_68KBUF & sl_SELFTESTn & slv_PB(5) & sl_VBLANKn & slv_PB(4 downto 1);

	p_8Ha : process
	begin
		wait until rising_edge(I_MCKR);
		sl_RAJSn_last <= sl_RAJSn;
		if sl_SYSRESn = '0' then
			sl_8H8 <= '0';
		elsif sl_RAJSn_last = '0' and sl_RAJSn = '1' then
			sl_8H8 <= not slv_cpu_ad(4);
		end if;
	end process;

	p_8Hb : process(I_MCKR, sl_UNLOCKn)
	begin
		if sl_UNLOCKn = '0' then
			sl_8H5 <= '1';
		elsif rising_edge(I_MCKR) then
			sl_WLn_last <= sl_WLn;
			if sl_SYSRESn = '0' then
				sl_8H5 <= '0';
			elsif sl_WLn_last = '0' and sl_WLn = '1' then
				sl_8H5 <= '0';
			end if;
		end if;
	end process;

	p_16Ha : process(I_XCKR, sl_RD68Kn, sl_SNDWRn)
	begin
		if sl_RD68Kn = '0' then
			sl_SNDNMIn <= '1';
		elsif rising_edge(I_XCKR) then
			if sl_SNDWRn_last = '0' and sl_SNDWRn = '1' then
				sl_SNDNMIn <= '0';
			end if;
		end if;
	end process;

	p_16Hb : process(I_XCKR, sl_SNDRSTn, sl_SNDRDn, sl_WR68Kn)
	begin
		if sl_SNDRDn = '0' or sl_SNDRSTn = '0' then
			sl_SNDINTn <= '1';
		elsif rising_edge(I_XCKR) then
			if sl_WR68Kn_last = '0' and sl_WR68Kn = '1' then
				sl_SNDINTn <= '0';
			end if;
		end if;
	end process;

	-- 14E latch sound data out
	p_14E : process
	begin
		wait until rising_edge(I_XCKR);
		sl_SNDWRn_last <= sl_SNDWRn;
		if sl_SNDWRn_last = '0' and sl_SNDWRn = '1' then
			O_SBD <= slv_cpu_do(7 downto 0);
		end if;
	end process;

	-- 15E latch sound data in
	p_15E : process
	begin
		wait until rising_edge(I_XCKR);
		sl_WR68Kn_last <= sl_WR68Kn;
		if sl_WR68Kn_last = '0' and sl_WR68Kn = '1' then
			slv_SBDI <= I_SBD;
		end if;
	end process;

-- 13E EEPROM loaded by top level
--	sl_EEP_OEn <= sl_8H5 and sl_SYSRESn;

	-- 12C LETA trackball controller
	p_LETA	: entity work.LETA_REP
	port map (
		clk     => I_MCKR,
		ck      => I_8H,
		resoln  => I_LETA_RES,
		cs      => sl_RLETAn,
		test    => I_LETA_TST,
		ad      => slv_cpu_ad( 2 downto 1),
		clks    => I_LETA_CLK,
		dirs    => I_LETA_DIR,
		db      => slv_LETADB
	);

end RTL;
