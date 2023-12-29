-- Adapted By MVV

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity hdmi is
port (
	CLK_DVI_I	: in std_logic;
	CLK_PIXEL_I	: in std_logic;
	R_I		: in std_logic_vector(7 downto 0);
	G_I		: in std_logic_vector(7 downto 0);
	B_I		: in std_logic_vector(7 downto 0);
	BLANK_I		: in std_logic;
	HSYNC_I		: in std_logic;
	VSYNC_I		: in std_logic;
	TMDS_D0_O	: out std_logic;
	TMDS_D1_O	: out std_logic;
	TMDS_D2_O	: out std_logic;
	TMDS_CLK_O	: out std_logic);
end entity;

architecture rtl of hdmi is
	signal red	: std_logic_vector(9 downto 0);
	signal green	: std_logic_vector(9 downto 0);
	signal blue	: std_logic_vector(9 downto 0);		
	signal tx_in	: std_logic_vector(29 downto 0);
	signal tmds_d	: std_logic_vector(2 downto 0);
	
begin

enc0: entity work.encoder
port map (
	CLK_I		=> CLK_PIXEL_I,
	DATA_I		=> B_I,
	C_I		=> VSYNC_I & HSYNC_I,
	BLANK_I		=> BLANK_I,
	ENCODED_O	=> blue);

enc1: entity work.encoder
port map (
	CLK_I		=> CLK_PIXEL_I,
	DATA_I		=> G_I,
	C_I		=> "00",
	BLANK_I		=> BLANK_I,
	ENCODED_O	=> green);

enc2: entity work.encoder
port map (
	CLK_I		=> CLK_PIXEL_I,
	DATA_I		=> R_I,
	C_I		=> "00",
	BLANK_I		=> BLANK_I,
	ENCODED_O	=> red);

serializer_inst: entity work.serializer
PORT MAP (
	tx_in	 	=> tx_in,
	tx_inclock	=> CLK_DVI_I,
	tx_syncclock	=> CLK_PIXEL_I,
	tx_out	 	=> tmds_d);
	
tx_in <=	red(0) & red(1) & red(2) & red(3) & red(4) & red(5) & red(6) & red(7) & red(8) & red(9) &
		green(0) & green(1) & green(2) & green(3) & green(4) & green(5) & green(6) & green(7) & green(8) & green(9) &
		blue(0) & blue(1) & blue(2) & blue(3) & blue(4) & blue(5) & blue(6) & blue(7) & blue(8) & blue(9);

TMDS_D0_O	<= tmds_d(0);
TMDS_D1_O	<= tmds_d(1);
TMDS_D2_O	<= tmds_d(2);
TMDS_CLK_O 	<= CLK_PIXEL_I;

end rtl;