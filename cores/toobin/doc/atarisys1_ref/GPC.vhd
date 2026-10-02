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
--	Graphic Priority Control (Atari custom chip 137419-101)
--	This GPC was derived from System I SP-277 schematic

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_arith.all;
	use ieee.std_logic_unsigned.all;

entity GPC is
	port(
		I_CK   : in  std_logic;                    -- MCKR
		I_PFM  : in  std_logic;                    -- PFSC/MO
		I_421H : in  std_logic_vector(2 downto 0); -- 4H 2H 1H
		I_SEL  : in  std_logic;                    -- /CRAM
		I_AL   : in  std_logic_vector(1 downto 0); -- APIX
		I_MA   : in  std_logic_vector(1 downto 0); -- MA9, MA10
		I_D    : in  std_logic_vector(3 downto 0); -- VRD
		I_P    : in  std_logic_vector(7 downto 0); -- PFX
		I_M    : in  std_logic_vector(7 downto 0); -- MPX

		O_CA   : out std_logic_vector(9 downto 0)  -- CRA
	);
end GPC;

architecture RTL of GPC is
	signal
		sl_gate,
		sl_8C6,
		sl_3F2,
		sl_1C12
								: std_logic := '1';
	signal
		PROM_3E_data,
		slv_CRAS
								: std_logic_vector(1 downto 0) := (others=>'1');
	signal
		slv_ALC
								: std_logic_vector(2 downto 0) := (others=>'1');
	signal
		slv_3H
								: std_logic_vector(3 downto 0) := (others=>'1');
	signal
		slv_9D
								: std_logic_vector(7 downto 0) := (others=>'1');
begin
	-- 8D tristate buffers
	O_CA <= I_MA & "00000000" when I_SEL = '0' else slv_CRAS & slv_9D;

	-- gate 8C output  6 (PFX7..3)
	sl_8C6  <= (not (I_P(7) or I_P(6) or I_P(5) or I_P(4) or I_P(3)));

	-- gate 1C output 12 (MPX3..1)
	sl_1C12 <= (not (I_M(3) and I_M(2) and I_M(1)));

	-- when any of these are high, PROM output is all low
	sl_gate <= not (sl_3F2 or I_AL(1) or I_AL(0));

	-- These equations describe the PROM 3E contents,
	-- top 2 data bits are the same as bottom 2 data bits as can be seen in PROM dump
	PROM_3E_data(1)  <= sl_gate and     ((sl_8C6 and I_PFM) or   (not I_M(7)) or (I_M(0)   and (not sl_1C12)) );
	PROM_3E_data(0)  <= sl_gate and not ((sl_8C6 and I_PFM) or (((not I_M(7)) or (I_M(0))) and (not sl_1C12)) );

	-- Graphic Priority Control selection
--	3C9   3C7   4C7   4C9   7C7   7C9   6C7   6C9		case
--	GND   GND   GND   ALC2  ALC1  ALC0  APIX1 APIX0		0
--	GND  /MPX6 /MPX5 /MPX4 /MPX3 /MPX2 /MPX1 /MPX0		1
--	PFX7  PFX6  PFX5  PFX4  PFX3  PFX2  PFX1  PFX0		2
--	PFX3  PFX2  PFX1  PFX0 /MPX3 /MPX2 /MPX1 /MPX0		3

	-- 9D latch
	p_9D : process
	begin
		wait until falling_edge(I_CK);
		if I_SEL = '1' then
			-- 3C, 4C, 7C, 6C dual 4:1 muxes
			case PROM_3E_data is
				when "00" => slv_9D <= "000" & slv_ALC & I_AL;
				when "01" => slv_9D <= '0' & not I_M(6 downto 0);
				when "10" => slv_9D <= I_P;
				when "11" => slv_9D <= I_P(3 downto 0) & not I_M(3 downto 0);
				when others => slv_9D <= (others=>'1');
			end case;
		end if;
	end process;

	-- 3H latch
	p_3H : process
	begin
		wait until rising_edge(I_CK);
		if (I_421H="011") then -- rising edge 4H
			slv_3H <= I_D;
		end if;
	end process;

	-- 3F latch
	p_3F : process
	begin
		wait until falling_edge(I_CK);
		if I_421H(1 downto 0)="11" then -- 3H
			sl_3F2	<= slv_3H(3);
			slv_ALC	<= slv_3H(2 downto 0);
		end if;
	end process;

	-- 1B, 5B latch
	p_1B_5B : process
	begin
		wait until falling_edge(I_CK);
		slv_CRAS <= PROM_3E_data;
	end process;
end RTL;
