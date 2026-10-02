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
-- SLAPSTIC 137412-104 GAUNTLET
--	This SLAPSTIC was translated from MAME "slapstic.cpp" source code pretty much verbatim :)
-- The original MAME C++ code is left in as comments

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;

entity SLAPSTIC is
--	generic (
--		chip_type : integer range 100 to 118 := 104 -- see generate statements below to select correct type
--	);
	port(
		I_CK        : in  std_logic;
		I_ASn       : in  std_logic;
		I_CSn       : in  std_logic;
		I_A         : in  std_logic_vector(13 downto 0);
		O_BS        : out std_logic_vector( 1 downto 0);
		I_SLAP_TYPE : in  integer range 0 to 118 -- slapstic type can be changed dynamically
	);
end SLAPSTIC;

architecture RTL of SLAPSTIC is

	type slap_sm is (DIS, ENA, ALT1, ALT2, ALT3, BIT1, BIT2, BIT3, ADD1, ADD2, ADD3);
	signal state       : slap_sm;
	signal sl_ASn_last : std_logic:='0';
	signal additive    : std_logic:='0';
	signal bitwise     : std_logic:='0';
	signal init_done   : std_logic:='0';
	signal chip_type_last : integer range 0 to 118 := 0;

	signal addr        : std_logic_vector(15 downto 0) := (others=>'0');
	signal ini_bank    : std_logic_vector( 1 downto 0) := (others=>'0');
	signal cur_bank    : std_logic_vector( 1 downto 0) := (others=>'1');
	signal alt_bank    : std_logic_vector( 1 downto 0) := (others=>'0');
	signal bit_bank    : std_logic_vector( 1 downto 0) := (others=>'0');
	signal bit_xor     : std_logic_vector( 1 downto 0) := (others=>'0');
	signal add_bank    : std_logic_vector( 1 downto 0) := (others=>'0');

	signal val_bank0   : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bank1   : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bank2   : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bank3   : std_logic_vector(15 downto 0) := (others=>'0');

	signal mask_alt1   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_alt2   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_alt3   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_alt4   : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_alt1    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_alt2    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_alt3    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_alt4    : std_logic_vector(15 downto 0) := (others=>'0');

	signal altshift    : natural range 0 to 3 := 0;

	signal mask_bit1   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_bit2c0 : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_bit2s0 : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_bit2c1 : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_bit2s1 : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_bit3   : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bit1    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bit2c0  : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bit2s0  : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bit2c1  : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bit2s1  : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_bit3    : std_logic_vector(15 downto 0) := (others=>'0');

	signal mask_add1   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_add2   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_add3   : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_addp1  : std_logic_vector(15 downto 0) := (others=>'0');
	signal mask_addp2  : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_add1    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_add2    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_add3    : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_addp1   : std_logic_vector(15 downto 0) := (others=>'0');
	signal val_addp2   : std_logic_vector(15 downto 0) := (others=>'0');

begin
	process
	begin
		wait until rising_edge(I_CK);
		if I_SLAP_TYPE /= chip_type_last then
			chip_type_last <= I_SLAP_TYPE;
			case I_SLAP_TYPE is
                                                          --/* slapstic 137412-101: Empire Strikes Back/Tetris (NOT confirmed) */
                                                          --static const struct slapstic_data slapstic101 =
                                                          --{
				when 101 =>
--	gen_101 : if chip_type = 101 generate                  --	/* basic banking */
		ini_bank     <= "11";                               --	3,                              /* starting bank */
		val_bank0    <= x"0080";                            --	{ 0x0080,0x0090,0x00a0,0x00b0 },/* bank select values */
		val_bank1    <= x"0090";
		val_bank2    <= x"00A0";
		val_bank3    <= x"00B0";
                                                          --	/* alternate banking */
		mask_alt1    <= x"007F";    val_alt1    <= x"FFFF"; --	{ 0x007f,UNKNOWN },             /* 1st mask/value in sequence */
		mask_alt2    <= x"1FFF";    val_alt2    <= x"1DFF"; --	{ 0x1fff,0x1dff },              /* 2nd mask/value in sequence */
		mask_alt3    <= x"1FFC";    val_alt3    <= x"1B5C"; --	{ 0x1ffc,0x1b5c },              /* 3rd mask/value in sequence */
		mask_alt4    <= x"1FCF";    val_alt4    <= x"0080"; --	{ 0x1fcf,0x0080 },              /* 4th mask/value in sequence */
		altshift     <= 0;                                  --	0,                              /* shift to get bank from 3rd */

		bitwise      <= '1';                                --	/* bitwise banking */
		mask_bit1    <= x"1FF0";    val_bit1    <= x"1540"; --	{ 0x1ff0,0x1540 },              /* 1st mask/value in sequence */
		mask_bit2c0  <= x"1FF3";    val_bit2c0  <= x"1540"; --	{ 0x1ff3,0x1540 },              /* clear bit 0 value */
		mask_bit2s0  <= x"1FF3";    val_bit2s0  <= x"1541"; --	{ 0x1ff3,0x1541 },              /*   set bit 0 value */
		mask_bit2c1  <= x"1FF3";    val_bit2c1  <= x"1542"; --	{ 0x1ff3,0x1542 },              /* clear bit 1 value */
		mask_bit2s1  <= x"1FF3";    val_bit2s1  <= x"1543"; --	{ 0x1ff3,0x1543 },              /*   set bit 1 value */
		mask_bit3    <= x"1FF8";    val_bit3    <= x"1550"; --	{ 0x1ff8,0x1550 },              /* final mask/value in sequence */
                                                          --	/* additive banking */
		additive     <= '0';                                --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-103: Marble Madness (confirmed) */
                                                          --static const struct slapstic_data slapstic103 =
                                                          --{
				when 103 =>
--	gen_103 : if chip_type = 103 generate                  --	/* basic banking */
		ini_bank     <= "11";                               --	3,                              /* starting bank */
		val_bank0    <= x"0040";                            --	{ 0x0040,0x0050,0x0060,0x0070 },/* bank select values */
		val_bank1    <= x"0050";
		val_bank2    <= x"0060";
		val_bank3    <= x"0070";
																			 --	/* alternate banking */
		mask_alt1    <= x"007F";    val_alt1    <= x"002D"; --	{ 0x007f,0x002d },              /* 1st mask/value in sequence */
		mask_alt2    <= x"3FFF";    val_alt2    <= x"3D14"; --	{ 0x3fff,0x3d14 },              /* 2nd mask/value in sequence */
		mask_alt3    <= x"3FFC";    val_alt3    <= x"3D24"; --	{ 0x3ffc,0x3d24 },              /* 3rd mask/value in sequence */
		mask_alt4    <= x"3FCF";    val_alt4    <= x"0040"; --	{ 0x3fcf,0x0040 },              /* 4th mask/value in sequence */
		altshift     <= 0;                                  --	0,                              /* shift to get bank from 3rd */

		bitwise      <= '1';                                --	/* bitwise banking */
		mask_bit1    <= x"3FF0";    val_bit1    <= x"34C0"; --	{ 0x3ff0,0x34c0 },              /* 1st mask/value in sequence */
		mask_bit2c0  <= x"3FF3";    val_bit2c0  <= x"34C0"; --	{ 0x3ff3,0x34c0 },              /* clear bit 0 value */
		mask_bit2s0  <= x"3FF3";    val_bit2s0  <= x"34C1"; --	{ 0x3ff3,0x34c1 },              /*   set bit 0 value */
		mask_bit2c1  <= x"3FF3";    val_bit2c1  <= x"34C2"; --	{ 0x3ff3,0x34c2 },              /* clear bit 1 value */
		mask_bit2s1  <= x"3FF3";    val_bit2s1  <= x"34C3"; --	{ 0x3ff3,0x34c3 },              /*   set bit 1 value */
		mask_bit3    <= x"3FF8";    val_bit3    <= x"34D0"; --	{ 0x3ff8,0x34d0 },              /* final mask/value in sequence */
																			 --	/* additive banking */
		additive     <= '0';                                --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-104: Gauntlet (confirmed) */
                                                          --static const struct slapstic_data slapstic104 =
                                                          --{
				when 104 =>
--	gen_104 : if chip_type = 104 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0020";                             --	{ 0x0020,0x0028,0x0030,0x0038 },/* bank select values */
		val_bank1   <= x"0028";
		val_bank2   <= x"0030";
		val_bank3   <= x"0038";
																			 --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0069"; --	{ 0x007f,0x0069 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"3735"; --	{ 0x3fff,0x3735 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"3764"; --	{ 0x3ffc,0x3764 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FE7";     val_alt4    <= x"0020"; --	{ 0x3fe7,0x0020 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"3D90"; --	{ 0x3ff0,0x3d90 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"3D90"; --	{ 0x3ff3,0x3d90 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"3D91"; --	{ 0x3ff3,0x3d91 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"3D92"; --	{ 0x3ff3,0x3d92 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"3D93"; --	{ 0x3ff3,0x3d93 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"3DA0"; --	{ 0x3ff8,0x3da0 },              /* final mask/value in sequence */
																			 --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-105: Indiana Jones/Paperboy (confirmed) */
                                                          --static const struct slapstic_data slapstic105 =
                                                          --{
				when 105 =>
--	gen_105 : if chip_type = 105 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0010";                             --	{ 0x0010,0x0014,0x0018,0x001c },/* bank select values */
		val_bank1   <= x"0014";
		val_bank2   <= x"0018";
		val_bank3   <= x"001C";
																			 --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"003D"; --	{ 0x007f,0x003d },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"0092"; --	{ 0x3fff,0x0092 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"00A4"; --	{ 0x3ffc,0x00a4 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FF3";     val_alt4    <= x"0010"; --	{ 0x3ff3,0x0010 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"35B0"; --	{ 0x3ff0,0x35b0 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"35B0"; --	{ 0x3ff3,0x35b0 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"35B1"; --	{ 0x3ff3,0x35b1 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"35B2"; --	{ 0x3ff3,0x35b2 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"35B3"; --	{ 0x3ff3,0x35b3 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"35C0"; --	{ 0x3ff8,0x35c0 },              /* final mask/value in sequence */
																			 --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-106: Gauntlet II (confirmed) */
                                                          --static const struct slapstic_data slapstic106 =
                                                          --{
				when 106 =>
--	gen_106 : if chip_type = 106 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0008";                             --	{ 0x0008,0x000a,0x000c,0x000e },/* bank select values */
		val_bank1   <= x"000A";
		val_bank2   <= x"000C";
		val_bank3   <= x"000E";
																			 --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"002B"; --	{ 0x007f,0x002b },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"0052"; --	{ 0x3fff,0x0052 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"0064"; --	{ 0x3ffc,0x0064 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FF9";     val_alt4    <= x"0008"; --	{ 0x3ff9,0x0008 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"3DA0"; --	{ 0x3ff0,0x3da0 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"3DA0"; --	{ 0x3ff3,0x3da0 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"3DA1"; --	{ 0x3ff3,0x3da1 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"3DA2"; --	{ 0x3ff3,0x3da2 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"3DA3"; --	{ 0x3ff3,0x3da3 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"3DB0"; --	{ 0x3ff8,0x3db0 },              /* final mask/value in sequence */
                                                          --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-107: Peter Packrat/Xybots/2p Gauntlet/720 (confirmed) */
                                                          --static const struct slapstic_data slapstic107 =
                                                          --{
				when 107 =>
--	gen_107 : if chip_type = 107 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0018";                             --	{ 0x0018,0x001a,0x001c,0x001e },/* bank select values */
		val_bank1   <= x"001A";
		val_bank2   <= x"001C";
		val_bank3   <= x"001E";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"006B"; --	{ 0x007f,0x006b },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"3D52"; --	{ 0x3fff,0x3d52 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"3D64"; --	{ 0x3ffc,0x3d64 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FF9";     val_alt4    <= x"0018"; --	{ 0x3ff9,0x0018 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"00A0"; --	{ 0x3ff0,0x00a0 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"00A0"; --	{ 0x3ff3,0x00a0 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"00A1"; --	{ 0x3ff3,0x00a1 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"00A2"; --	{ 0x3ff3,0x00a2 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"00A3"; --	{ 0x3ff3,0x00a3 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"00B0"; --	{ 0x3ff8,0x00b0 },              /* final mask/value in sequence */
																			 --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-108: Road Runner/Super Sprint (confirmed) */
                                                          --static const struct slapstic_data slapstic108 =
                                                          --{
				when 108 =>
--	gen_108 : if chip_type = 108 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0028";                             --	{ 0x0028,0x002a,0x002c,0x002e },/* bank select values */
		val_bank1   <= x"002A";
		val_bank2   <= x"002C";
		val_bank3   <= x"002E";
																			 --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"001F"; --	{ 0x007f,0x001f },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"3772"; --	{ 0x3fff,0x3772 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"3764"; --	{ 0x3ffc,0x3764 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FF9";     val_alt4    <= x"0028"; --	{ 0x3ff9,0x0028 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"0060"; --	{ 0x3ff0,0x0060 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"0060"; --	{ 0x3ff3,0x0060 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"0061"; --	{ 0x3ff3,0x0061 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"0062"; --	{ 0x3ff3,0x0062 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"0063"; --	{ 0x3ff3,0x0063 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"0070"; --	{ 0x3ff8,0x0070 },              /* final mask/value in sequence */
                                                          --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-109: Championship Sprint/Road Blasters (confirmed) */
                                                          --static const struct slapstic_data slapstic109 =
                                                          --{
				when 109 =>
--	gen_109 : if chip_type = 109 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0008";                             --	{ 0x0008,0x000a,0x000c,0x000e },/* bank select values */
		val_bank1   <= x"000A";
		val_bank2   <= x"000C";
		val_bank3   <= x"000E";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"002B"; --	{ 0x007f,0x002b },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"0052"; --	{ 0x3fff,0x0052 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"0064"; --	{ 0x3ffc,0x0064 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FF9";     val_alt4    <= x"0008"; --	{ 0x3ff9,0x0008 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"3DA0"; --	{ 0x3ff0,0x3da0 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"3DA0"; --	{ 0x3ff3,0x3da0 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"3DA1"; --	{ 0x3ff3,0x3da1 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"3DA2"; --	{ 0x3ff3,0x3da2 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"3DA3"; --	{ 0x3ff3,0x3da3 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"3DB0"; --	{ 0x3ff8,0x3db0 },              /* final mask/value in sequence */
                                                          --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

                                                          --/* slapstic 137412-110: Road Blasters/APB (confirmed) */
                                                          --static const struct slapstic_data slapstic110 =
                                                          --{
				when 110 =>
--	gen_110 : if chip_type = 110 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	3,                              /* starting bank */
		val_bank0   <= x"0040";                             --	{ 0x0040,0x0050,0x0060,0x0070 },/* bank select values */
		val_bank1   <= x"0050";
		val_bank2   <= x"0060";
		val_bank3   <= x"0070";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"002D"; --	{ 0x007f,0x002d },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"3D14"; --	{ 0x3fff,0x3d14 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3FFC";     val_alt3    <= x"3D24"; --	{ 0x3ffc,0x3d24 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FCF";     val_alt4    <= x"0040"; --	{ 0x3fcf,0x0040 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */

		bitwise     <= '1';                                 --	/* bitwise banking */
		mask_bit1   <= x"3FF0";     val_bit1    <= x"34C0"; --	{ 0x3ff0,0x34c0 },              /* 1st mask/value in sequence */
		mask_bit2c0 <= x"3FF3";     val_bit2c0  <= x"34C0"; --	{ 0x3ff3,0x34c0 },              /* clear bit 0 value */
		mask_bit2s0 <= x"3FF3";     val_bit2s0  <= x"34C1"; --	{ 0x3ff3,0x34c1 },              /*   set bit 0 value */
		mask_bit2c1 <= x"3FF3";     val_bit2c1  <= x"34C2"; --	{ 0x3ff3,0x34c2 },              /* clear bit 1 value */
		mask_bit2s1 <= x"3FF3";     val_bit2s1  <= x"34C3"; --	{ 0x3ff3,0x34c3 },              /*   set bit 1 value */
		mask_bit3   <= x"3FF8";     val_bit3    <= x"34D0"; --	{ 0x3ff8,0x34d0 },              /* final mask/value in sequence */
                                                          --	/* additive banking */
		additive    <= '0';                                 --	NO_ADDITIVE
--	end generate;                                          --};

--/*************************************
-- *
-- *  Slapstic-2 definitions
-- *
-- *************************************/

                                                          --/* slapstic 137412-111: Pit Fighter (confirmed) */
                                                          --static const struct slapstic_data slapstic111 =
                                                          --{
				when 111 =>
--	gen_111 : if chip_type = 111 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0042";                             --	{ 0x0042,0x0052,0x0062,0x0072 },/* bank select values */
		val_bank1   <= x"0052";
		val_bank2   <= x"0062";
		val_bank3   <= x"0072";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"000A"; --	{ 0x007f,0x000a },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"28A4"; --	{ 0x3fff,0x28a4 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"0784";     val_alt3    <= x"0080"; --	{ 0x0784,0x0080 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FCF";     val_alt4    <= x"0042"; --	{ 0x3fcf,0x0042 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"00A1"; --	{ 0x3fff,0x00a1 },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"00A2"; --	{ 0x3fff,0x00a2 },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3C4F";     val_addp1   <= x"284D"; --	{ 0x3c4f,0x284d },              /* +1 mask/value */
		mask_addp2  <= x"3A5F";     val_addp2   <= x"285D"; --	{ 0x3a5f,0x285d },              /* +2 mask/value */
		mask_add3   <= x"3FF8";     val_add3    <= x"2800"; --	{ 0x3ff8,0x2800 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-112: Pit Fighter (Japan) (confirmed) */
                                                          --static const struct slapstic_data slapstic112 =
                                                          --{
				when 112 =>
--	gen_112 : if chip_type = 112 generate                  --	/* basic banking */
		ini_bank    <= "11";                                --	0,                              /* starting bank */
		val_bank0   <= x"002C";                             --	{ 0x002c,0x003c,0x006c,0x007c },/* bank select values */
		val_bank1   <= x"003C";
		val_bank2   <= x"006C";
		val_bank3   <= x"007C";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0014"; --	{ 0x007f,0x0014 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"29A0"; --	{ 0x3fff,0x29a0 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"0073";     val_alt3    <= x"0010"; --	{ 0x0073,0x0010 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FAF";     val_alt4    <= x"002C"; --	{ 0x3faf,0x002c },              /* 4th mask/value in sequence */
		altshift    <= 2;                                   --	2,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"2DCE"; --	{ 0x3fff,0x2dce },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"2DCF"; --	{ 0x3fff,0x2dcf },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3DEF";     val_addp1   <= x"15E2"; --	{ 0x3def,0x15e2 },              /* +1 mask/value */
		mask_addp2  <= x"3FBF";     val_addp2   <= x"15A2"; --	{ 0x3fbf,0x15a2 },              /* +2 mask/value */
		mask_add3   <= x"3FFC";     val_add3    <= x"1450"; --	{ 0x3ffc,0x1450 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-113: Unknown (Europe) (confirmed) */
                                                          --static const struct slapstic_data slapstic113 =
                                                          --{
				when 113 =>
--	gen_113 : if chip_type = 113 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0008";                             --	{ 0x0008,0x0018,0x0028,0x0038 },/* bank select values */
		val_bank1   <= x"0018";
		val_bank2   <= x"0028";
		val_bank3   <= x"0038";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0059"; --	{ 0x007f,0x0059 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"11A5"; --	{ 0x3fff,0x11a5 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"0860";     val_alt3    <= x"0800"; --	{ 0x0860,0x0800 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FCF";     val_alt4    <= x"0008"; --	{ 0x3fcf,0x0008 },              /* 4th mask/value in sequence */
		altshift    <= 3;                                   --	3,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"049B"; --	{ 0x3fff,0x049b },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"049C"; --	{ 0x3fff,0x049c },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3FCF";     val_addp1   <= x"3EC7"; --	{ 0x3fcf,0x3ec7 },              /* +1 mask/value */
		mask_addp2  <= x"3EDF";     val_addp2   <= x"3ED7"; --	{ 0x3edf,0x3ed7 },              /* +2 mask/value */
		mask_add3   <= x"3FFF";     val_add3    <= x"3FB2"; --	{ 0x3fff,0x3fb2 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-114: Pit Fighter (rev 9) (confirmed) */
                                                          --static const struct slapstic_data slapstic114 =
                                                          --{
				when 114 =>
--	gen_114 : if chip_type = 114 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0040";                             --	{ 0x0040,0x0048,0x0050,0x0058 },/* bank select values */
		val_bank1   <= x"0048";
		val_bank2   <= x"0050";
		val_bank3   <= x"0058";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0016"; --	{ 0x007f,0x0016 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"24DE"; --	{ 0x3fff,0x24de },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3871";     val_alt3    <= x"0000"; --	{ 0x3871,0x0000 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FE7";     val_alt4    <= x"0040"; --	{ 0x3fe7,0x0040 },              /* 4th mask/value in sequence */
		altshift    <= 1;                                   --	1,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"0AB7"; --	{ 0x3fff,0x0ab7 },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"0AB8"; --	{ 0x3fff,0x0ab8 },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3F63";     val_addp1   <= x"0D40"; --	{ 0x3f63,0x0d40 },              /* +1 mask/value */
		mask_addp2  <= x"3FD9";     val_addp2   <= x"0DC8"; --	{ 0x3fd9,0x0dc8 },              /* +2 mask/value */
		mask_add3   <= x"3FFF";     val_add3    <= x"0AB0"; --	{ 0x3fff,0x0ab0 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-115: Race Drivin' DSK board (confirmed) */
                                                          --static const struct slapstic_data slapstic115 =
                                                          --{
				when 115 =>
--	gen_115 : if chip_type = 115 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0020";                             --	{ 0x0020,0x0022,0x0024,0x0026 },/* bank select values */
		val_bank1   <= x"0022";
		val_bank2   <= x"0024";
		val_bank3   <= x"0026";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0054"; --	{ 0x007f,0x0054 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"3E01"; --	{ 0x3fff,0x3e01 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"3879";     val_alt3    <= x"0029"; --	{ 0x3879,0x0029 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FF9";     val_alt4    <= x"0020"; --	{ 0x3ff9,0x0020 },              /* 4th mask/value in sequence */
		altshift    <= 1;                                   --	1,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"2591"; --	{ 0x3fff,0x2591 },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"2592"; --	{ 0x3fff,0x2592 },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3FE6";     val_addp1   <= x"3402"; --	{ 0x3fe6,0x3402 },              /* +1 mask/value */
		mask_addp2  <= x"3FB4";     val_addp2   <= x"3410"; --	{ 0x3fb4,0x3410 },              /* +2 mask/value */
		mask_add3   <= x"3FFF";     val_add3    <= x"34A2"; --	{ 0x3fff,0x34a2 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-116: Hydra (confirmed) */
                                                          --static const struct slapstic_data slapstic116 =
                                                          --{
				when 116 =>
--	gen_116 : if chip_type = 116 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0044";                             --	{ 0x0044,0x004c,0x0054,0x005c },/* bank select values */
		val_bank1   <= x"004C";
		val_bank2   <= x"0054";
		val_bank3   <= x"005C";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0069"; --	{ 0x007f,0x0069 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"2BAB"; --	{ 0x3fff,0x2bab },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"387C";     val_alt3    <= x"0808"; --	{ 0x387c,0x0808 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FE7";     val_alt4    <= x"0044"; --	{ 0x3fe7,0x0044 },              /* 4th mask/value in sequence */
		altshift    <= 0;                                   --	0,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"3F7C"; --	{ 0x3fff,0x3f7c },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"3F7D"; --	{ 0x3fff,0x3f7d },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3DB2";     val_addp1   <= x"3C12"; --	{ 0x3db2,0x3c12 },              /* +1 mask/value */
		mask_addp2  <= x"3FE3";     val_addp2   <= x"3E43"; --	{ 0x3fe3,0x3e43 },              /* +2 mask/value */
		mask_add3   <= x"3FFF";     val_add3    <= x"2BA8"; --	{ 0x3fff,0x2ba8 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-117: Race Drivin' main board (confirmed) */
                                                          --static const struct slapstic_data slapstic117 =
                                                          --{
				when 117 =>
--	gen_117 : if chip_type = 117 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0008";                             --	{ 0x0008,0x001a,0x002c,0x003e },/* bank select values */
		val_bank1   <= x"001A";
		val_bank2   <= x"002C";
		val_bank3   <= x"003E";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"007D"; --	{ 0x007f,0x007d },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"3580"; --	{ 0x3fff,0x3580 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"0079";     val_alt3    <= x"0020"; --	{ 0x0079,0x0020 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3FC9";     val_alt4    <= x"0008"; --	{ 0x3fc9,0x0008 },              /* 4th mask/value in sequence */
		altshift    <= 1;                                   --	1,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"0676"; --	{ 0x3fff,0x0676 },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"0677"; --	{ 0x3fff,0x0677 },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3E62";     val_addp1   <= x"1A42"; --	{ 0x3e62,0x1a42 },              /* +1 mask/value */
		mask_addp2  <= x"3E35";     val_addp2   <= x"1A11"; --	{ 0x3e35,0x1a11 },              /* +2 mask/value */
		mask_add3   <= x"3FFF";     val_add3    <= x"1A42"; --	{ 0x3fff,0x1a42 }               /* final mask/value in sequence */
--	end generate;                                          --};

                                                          --/* slapstic 137412-118: Rampart/Vindicators II (confirmed) */
                                                          --static const struct slapstic_data slapstic118 =
                                                          --{
				when 118 =>
--	gen_118 : if chip_type = 118 generate                  --	/* basic banking */
		ini_bank    <= "00";                                --	0,                              /* starting bank */
		val_bank0   <= x"0014";                             --	{ 0x0014,0x0034,0x0054,0x0074 },/* bank select values */
		val_bank1   <= x"0034";
		val_bank2   <= x"0054";
		val_bank3   <= x"0074";
                                                          --	/* alternate banking */
		mask_alt1   <= x"007F";     val_alt1    <= x"0002"; --	{ 0x007f,0x0002 },              /* 1st mask/value in sequence */
		mask_alt2   <= x"3FFF";     val_alt2    <= x"1950"; --	{ 0x3fff,0x1950 },              /* 2nd mask/value in sequence */
		mask_alt3   <= x"0067";     val_alt3    <= x"0020"; --	{ 0x0067,0x0020 },              /* 3rd mask/value in sequence */
		mask_alt4   <= x"3F9F";     val_alt4    <= x"0014"; --	{ 0x3f9f,0x0014 },              /* 4th mask/value in sequence */
		altshift    <= 3;                                   --	3,                              /* shift to get bank from 3rd */
                                                          --	/* bitwise banking */
		bitwise     <= '0';                                 --	NO_BITWISE,

		additive    <= '1';                                 --	/* additive banking */
		mask_add1   <= x"3FFF";     val_add1    <= x"1958"; --	{ 0x3fff,0x1958 },              /* 1st mask/value in sequence */
		mask_add2   <= x"3FFF";     val_add2    <= x"1959"; --	{ 0x3fff,0x1959 },              /* 2nd mask/value in sequence */
		mask_addp1  <= x"3F73";     val_addp1   <= x"3052"; --	{ 0x3f73,0x3052 },              /* +1 mask/value */
		mask_addp2  <= x"3F67";     val_addp2   <= x"3042"; --	{ 0x3f67,0x3042 },              /* +2 mask/value */
		mask_add3   <= x"3FF8";     val_add3    <= x"30E0"; --	{ 0x3ff8,0x30e0 }               /* final mask/value in sequence */
--	end generate;                                          --};

				when others => null;
			end case;
		end if;
	end process;

	O_BS <= cur_bank;

	-- expand address to 16 bits for easier representation in hex
	addr <= "00" & I_A;

	p_slap : process
	begin
		wait until rising_edge(I_CK);
		sl_ASn_last <= I_ASn; -- detect /AS transition
		if I_SLAP_TYPE /= chip_type_last then
			init_done <= '0';
		elsif init_done = '0' then
			init_done <= '1';
			cur_bank <= ini_bank;
		end if;

		if I_CSn = '0' then
			if sl_ASn_last = '0' and I_ASn = '1' then
                                                                                    --	/* reset is universal */
				if addr = x"0000" then                                                  --	if (offset == 0x0000)
                                                                                    --	{
					state <= ENA;                                                        --		state = ENABLED;
                                                                                    --	}
                                                                                    --	/* otherwise, use the state machine */
				else                                                                    --	else
                                                                                    --	{
					case state is                                                        --		switch (state)
                                                                                    --		{
                                                                                    --			/* DISABLED state: everything is ignored except a reset */
						when DIS  => null;                                                --			case DISABLED:
                                                                                    --				break;
                                                                                    --			/* ENABLED state: the chip has been activated and is ready for a bankswitch */
						when ENA  =>                                                      --			case ENABLED:
                                                                                    --				/* check for request to enter bitwise state */
							if ((addr and mask_bit1) = val_bit1) and (bitwise = '1') then	--				if (MATCHES_MASK_VALUE(offset, slapstic.bit1))
                                                                                    --				{
								state <= BIT1;                                              --					state = BITWISE1;
                                                                                    --				}
                                                                                    --				/* check for request to enter additive state */
							elsif ((addr and mask_add1) = val_add1) and (additive = '1') then	--				else if (MATCHES_MASK_VALUE(offset, slapstic.add1))
                                                                                    --				{
								state <= ADD1;                                              --					state = ADDITIVE1;
                                                                                    --				}
                                                                                    --				/* check for request to enter alternate state */
							elsif ((addr and mask_alt1) = val_alt1) then                   --				else if (MATCHES_MASK_VALUE(offset, slapstic.alt1))
                                                                                    --				{
								state <= ALT1;                                              --					state = ALTERNATE1;
                                                                                    --				}
                                                                                    --				/* special kludge for catching the second alternate address if */
                                                                                    --				/* the first one was missed (since it's usually an opcode fetch) */
							elsif ((addr and mask_alt2) = val_alt2) then                   --				else if (MATCHES_MASK_VALUE(offset, slapstic.alt2))
                                                                                    --				{
								state <= ALT2;                                              --					state = alt2_kludge(space, offset);
                                                                                    --				}
                                                                                    --				/* check for standard bankswitches */
							elsif addr = val_bank0 then                                    --				else if (offset == slapstic.bank[0])
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= "00";                                           --					current_bank = 0;
                                                                                    --				}
							elsif addr = val_bank1 then                                    --				else if (offset == slapstic.bank[1])
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= "01";                                           --					current_bank = 1;
                                                                                    --				}
							elsif addr = val_bank2 then                                    --				else if (offset == slapstic.bank[2])
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= "10";                                           --					current_bank = 2;
                                                                                    --				}
							elsif addr = val_bank3 then                                    --				else if (offset == slapstic.bank[3])
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= "11";                                           --					current_bank = 3;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* ALTERNATE1 state: look for alternate2 offset, or else fall back to ENABLED */
						when ALT1 =>                                                      --			case ALTERNATE1:
							if    (addr and mask_alt2) = val_alt2 then                     --				if (MATCHES_MASK_VALUE(offset, slapstic.alt2))
                                                                                    --				{
								state <= ALT2;                                              --					state = ALTERNATE2;
                                                                                    --				}
							else                                                           --				else
                                                                                    --				{
								state <= ENA;                                               --					state = ENABLED;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* ALTERNATE2 state: look for altbank offset, or else fall back to ENABLED */
						when ALT2 =>                                                      --			case ALTERNATE2:
							if    (addr and mask_alt3) = val_alt3 then                     --				if (MATCHES_MASK_VALUE(offset, slapstic.alt3))
                                                                                    --				{
								state <= ALT3;                                              --					state = ALTERNATE3;
								alt_bank <= addr(altshift+1) & addr(altshift);              --					alt_bank = (offset >> slapstic.altshift) & 3;
                                                                                    --				}
							else                                                           --				else
                                                                                    --				{
								state <= ENA;                                               --					state = ENABLED;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* ALTERNATE3 state: wait for the final value to finish the transaction */
						when ALT3 =>                                                      --			case ALTERNATE3:
							if    (addr and mask_alt4) = val_alt4 then                     --				if (MATCHES_MASK_VALUE(offset, slapstic.alt4))
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= alt_bank;                                       --					current_bank = alt_bank;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* BITWISE1 state: waiting for a bank to enter the BITWISE state */
						when BIT1 =>                                                      --			case BITWISE1:
                                                                                    --				if (offset == slapstic.bank[0] || offset == slapstic.bank[1] ||
							if (addr = val_bank0) or (addr = val_bank1) or                 --					offset == slapstic.bank[2] || offset == slapstic.bank[3])
								(addr = val_bank2) or (addr = val_bank3) then
                                                                                    --				{
								state <= BIT2;                                              --					state = BITWISE2;
								bit_bank <= cur_bank;                                       --					bit_bank = current_bank;
								bit_xor <= "00";                                            --					bit_xor = 0;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* BITWISE2 state: watch for twiddling and the escape mechanism */
						when BIT2 =>                                                      --			case BITWISE2:
                                                                                    --				/* check for clear bit 0 case */
							if ( (addr(15 downto 2) & (addr(1 downto 0) xor bit_xor) )		--				if (MATCHES_MASK_VALUE(offset ^ bit_xor, slapstic.bit2c0))
								and mask_bit2c0) = val_bit2c0 then
                                                                                    --				{
								bit_bank <= bit_bank and "10";                              --					bit_bank &= ~1;
								bit_xor <= bit_xor xor "11";                                --					bit_xor ^= 3;
                                                                                    --				}
                                                                                    --
                                                                                    --				/* check for set bit 0 case */
							elsif ( (addr(15 downto 2) & (addr(1 downto 0) xor bit_xor) )	--				else if (MATCHES_MASK_VALUE(offset ^ bit_xor, slapstic.bit2s0))
								and mask_bit2s0) = val_bit2s0 then
                                                                                    --				{
								bit_bank <= bit_bank or "01";                               --					bit_bank |= 1;
								bit_xor <= bit_xor xor "11";                                --					bit_xor ^= 3;
                                                                                    --				}
                                                                                    --				/* check for clear bit 1 case */
							elsif ( (addr(15 downto 2) & (addr(1 downto 0) xor bit_xor) )	--				else if (MATCHES_MASK_VALUE(offset ^ bit_xor, slapstic.bit2c1))
								and mask_bit2c1) = val_bit2c1 then
                                                                                    --				{
								bit_bank <= bit_bank and "01";                              --					bit_bank &= ~2;
								bit_xor <= bit_xor xor "11";                                --					bit_xor ^= 3;
                                                                                    --				}
                                                                                    --				/* check for set bit 1 case */
							elsif ( (addr(15 downto 2) & (addr(1 downto 0) xor bit_xor) )	--				else if (MATCHES_MASK_VALUE(offset ^ bit_xor, slapstic.bit2s1))
								and mask_bit2s1) = val_bit2s1 then
                                                                                    --				{
								bit_bank <= bit_bank or "10";                               --					bit_bank |= 2;
								bit_xor <= bit_xor xor "11";                                --					bit_xor ^= 3;
                                                                                    --				}
                                                                                    --				/* check for escape case */
							elsif (addr and mask_bit3) = val_bit3 then                     --				else if (MATCHES_MASK_VALUE(offset, slapstic.bit3))
                                                                                    --				{
								state <= BIT3;                                              --					state = BITWISE3;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* BITWISE3 state: waiting for a bank to seal the deal */
						when BIT3 =>                                                      --			case BITWISE3:
                                                                                    --				if (offset == slapstic.bank[0] || offset == slapstic.bank[1] ||
							if (addr = val_bank0) or (addr = val_bank1) or                 --					offset == slapstic.bank[2] || offset == slapstic.bank[3])
								(addr = val_bank2) or (addr = val_bank3) then
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= bit_bank;                                       --					current_bank = bit_bank;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* ADDITIVE1 state: look for add2 offset, or else fall back to ENABLED */
						when ADD1 =>                                                      --			case ADDITIVE1:
							if    (addr and mask_add2) = val_add2 then                     --				if (MATCHES_MASK_VALUE(offset, slapstic.add2))
                                                                                    --				{
								state <= ADD2;                                              --					state = ADDITIVE2;
								add_bank <= cur_bank;                                       --					add_bank = current_bank;
                                                                                    --				}
							else                                                           --				else
                                                                                    --				{
								state <= ENA;                                               --					state = ENABLED;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* ADDITIVE2 state: watch for twiddling and the escape mechanism */
						when ADD2 =>                                                      --			case ADDITIVE2:
							if    ((addr and mask_addp1) = val_addp1) and  --	there is a case where we add 3 (both +1 and +2 cases matched) so since we don't execute sequentially
									((addr and mask_addp2) = val_addp2) then --  like a CPU runing a C program but in parallel, we have to add one more test for that specific case
								add_bank <= add_bank + 3;
                                                                                    --				/* check for add 1 case 												-- can intermix */
							elsif (addr and mask_addp1) = val_addp1 then                   --				if (MATCHES_MASK_VALUE(offset, slapstic.addplus1))
                                                                                    --				{
								add_bank <= add_bank + 1;                                   --					add_bank = (add_bank + 1) & 3;
                                                                                    --				}
                                                                                    --				/* check for add 2 case 												-- can intermix */
							elsif (addr and mask_addp2) = val_addp2 then                   --				if (MATCHES_MASK_VALUE(offset, slapstic.addplus2))
                                                                                    --				{
								add_bank <= add_bank + 2;                                   --					add_bank = (add_bank + 2) & 3;
                                                                                    --				}
                                                                                    --				/* check for escape case 												-- can intermix with the above */
							elsif (addr and mask_add3) = val_add3 then                     --				if (MATCHES_MASK_VALUE(offset, slapstic.add3))
                                                                                    --				{
								state <= ADD3;                                              --					state = ADDITIVE3;
							end if;                                                        --				}
                                                                                    --				break;
                                                                                    --			/* ADDITIVE3 state: waiting for a bank to seal the deal */
						when ADD3 =>                                                      --			case ADDITIVE3:
                                                                                    --				if (offset == slapstic.bank[0] || offset == slapstic.bank[1] ||
							if (addr = val_bank0) or (addr = val_bank1) or                 --					offset == slapstic.bank[2] || offset == slapstic.bank[3])
							   (addr = val_bank2) or (addr = val_bank3) then
                                                                                    --				{
								state <= DIS;                                               --					state = DISABLED;
								cur_bank <= add_bank;                                       --					current_bank = add_bank;
							end if;                                                        --				}
						when others => null;                                              --				break;
					end case;                                                            --		}
				end if;                                                                 --	}
			end if;
		end if;
	end process;

end RTL;
