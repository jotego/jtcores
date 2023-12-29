library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;

-------------------------------------------------------------------------
-- DE10LITE @robinsonb5 hardware top file
-------------------------------------------------------------------------

entity jtframe_de10lite_top is
	port
	(
		ADC_CLK_10		:	 IN STD_LOGIC;
		MAX10_CLK1_50	:	 IN STD_LOGIC;
		MAX10_CLK2_50	:	 IN STD_LOGIC;
		KEY				:	 IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		SW				:	 IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		LEDR			:	 OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
		HEX0			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX1			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX2			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX3			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX4			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		HEX5			:	 OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		DRAM_CLK		:	 OUT STD_LOGIC;
		DRAM_CKE		:	 OUT STD_LOGIC;
		DRAM_ADDR		:	 OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
		DRAM_BA			:	 OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		DRAM_DQ			:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		DRAM_LDQM		:	 OUT STD_LOGIC;
		DRAM_UDQM		:	 OUT STD_LOGIC;
		DRAM_CS_N		:	 OUT STD_LOGIC;
		DRAM_WE_N		:	 OUT STD_LOGIC;
		DRAM_CAS_N		:	 OUT STD_LOGIC;
		DRAM_RAS_N		:	 OUT STD_LOGIC;
		VGA_HS			:	 OUT STD_LOGIC;
		VGA_VS			:	 OUT STD_LOGIC;
		VGA_R			:	 OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		VGA_G			:	 OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		VGA_B			:	 OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
		--CLK_I2C_SCL		:	 OUT STD_LOGIC;
		--CLK_I2C_SDA		:	 INOUT STD_LOGIC;
		GSENSOR_SCLK	:	 OUT STD_LOGIC;
		GSENSOR_SDO		:	 INOUT STD_LOGIC;
		GSENSOR_SDI		:	 INOUT STD_LOGIC;
		GSENSOR_INT		:	 IN STD_LOGIC_VECTOR(2 DOWNTO 1);
		GSENSOR_CS_N	:	 OUT STD_LOGIC;
		GPIO			:	 INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
		ARDUINO_IO		:	 INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		ARDUINO_RESET_N	:	 INOUT STD_LOGIC
	);
END entity;

architecture RTL of jtframe_de10lite_top is
   constant reset_cycles : integer := 131071;
	
-- System clocks
	signal locked  : std_logic;
	signal reset_n : std_logic;

--	signal slowclk : std_logic;
--	signal fastclk : std_logic;
--	signal pll_locked : std_logic;

-- SPI signals
	signal sd_clk : std_logic;
	signal sd_cs : std_logic;
	signal sd_mosi : std_logic;
	signal sd_miso : std_logic;

-- internal SPI signals
	signal spi_do : std_logic;
	signal spi_toguest : std_logic;
	signal spi_fromguest : std_logic;
	signal spi_ss2 : std_logic;
	signal spi_ss3 : std_logic;
	signal spi_ss4 : std_logic;
	signal conf_data0 : std_logic;
	signal spi_clk_int : std_logic;

-- PS/2 Keyboard socket - used for second mouse
	alias ps2_keyboard_clk : std_logic is GPIO(10);
	alias ps2_keyboard_dat : std_logic is GPIO(12);

	signal ps2_keyboard_clk_in : std_logic;
	signal ps2_keyboard_dat_in : std_logic;
	signal ps2_keyboard_clk_out : std_logic;
	signal ps2_keyboard_dat_out : std_logic;

-- PS/2 Mouse
	alias ps2_mouse_clk : std_logic is GPIO(14);
	alias ps2_mouse_dat : std_logic is GPIO(16);

	signal ps2_mouse_clk_in: std_logic;
	signal ps2_mouse_dat_in: std_logic;
	signal ps2_mouse_clk_out: std_logic;
	signal ps2_mouse_dat_out: std_logic;

	signal intercept : std_logic;

-- Video
	signal vga_red: std_logic_vector(7 downto 0);
	signal vga_green: std_logic_vector(7 downto 0);
	signal vga_blue: std_logic_vector(7 downto 0);
	signal vga_hsync : std_logic;
	signal vga_vsync : std_logic;

-- RS232 serial
	signal rs232_rxd : std_logic;
	signal rs232_txd : std_logic;

	alias sigma_l : std_logic is GPIO(18);
	alias sigma_r : std_logic is GPIO(20);

-- IO
	signal joya : std_logic_vector(6 downto 0);
	signal joyb : std_logic_vector(6 downto 0);
	signal joyc : std_logic_vector(6 downto 0);
	signal joyd : std_logic_vector(6 downto 0);

	signal uart_rxd : std_logic;
	signal uart_txd : std_logic;

	signal act_led : std_logic;
	
	-- DE10lite target guest_top template signals
	alias clock_input 		: std_logic is MAX10_CLK1_50;

begin

HEX0<=(others=>'1');
HEX1<=(others=>'1');
HEX2<=(others=>'1');
HEX3<=(others=>'1');
HEX4<=(others=>'1');
HEX5<=(others=>'1');

-- SPI SD card
ARDUINO_IO(10)<=sd_cs;
ARDUINO_IO(11)<=sd_mosi;
ARDUINO_IO(12)<='Z';
sd_miso<=ARDUINO_IO(12);
ARDUINO_IO(13)<=sd_clk;

ARDUINO_IO(1) <= uart_txd;
ARDUINO_IO(0) <= 'Z';
uart_rxd <= ARDUINO_IO(0);


-- External devices tied to GPIOs

ps2_mouse_dat_in<=ps2_mouse_dat;
ps2_mouse_dat <= '0' when ps2_mouse_dat_out='0' else 'Z';
ps2_mouse_clk_in<=ps2_mouse_clk;
ps2_mouse_clk <= '0' when ps2_mouse_clk_out='0' else 'Z';

ps2_keyboard_dat_in<=ps2_keyboard_dat;
ps2_keyboard_dat <= '0' when ps2_keyboard_dat_out='0' else 'Z';
ps2_keyboard_clk_in<=ps2_keyboard_clk;
ps2_keyboard_clk <= '0' when ps2_keyboard_clk_out='0' else 'Z';
	
GPIO(0)<=rs232_txd;
rs232_rxd<=GPIO(1);

joya<=(others=>'1');
joyb<=(others=>'1');
joyc<=(others=>'1');
joyd<=(others=>'1');

VGA_R<=vga_red(7 downto 4);
VGA_G<=vga_green(7 downto 4);
VGA_B<=vga_blue(7 downto 4);
VGA_HS<=vga_hsync;
VGA_VS<=vga_vsync;




guest : component mist_top
	port map
	(
		CLOCK_27   => clock_input&clock_input, -- Comment out one of these lines to match the guest core.
		LED 	   => act_led,

		--SDRAM
		SDRAM_DQ   => DRAM_DQ,
		SDRAM_A    => DRAM_ADDR,
		SDRAM_DQML => DRAM_LDQM,
		SDRAM_DQMH => DRAM_UDQM,
		SDRAM_nWE  => DRAM_WE_N,
		SDRAM_nCAS => DRAM_CAS_N,
		SDRAM_nRAS => DRAM_RAS_N,
		SDRAM_nCS  => DRAM_CS_N,
		SDRAM_BA   => DRAM_BA,
		SDRAM_CLK  => DRAM_CLK,
		SDRAM_CKE  => DRAM_CKE,

		--UART
		UART_TX    => UART_TXD,
		UART_RX    => UART_RXD,

		--SPI
		SPI_DO     => spi_do,
		SPI_DI     => spi_toguest,
		SPI_SCK    => spi_clk_int,
		SPI_SS2    => spi_ss2,
		SPI_SS3    => spi_ss3,
		SPI_SS4    => spi_ss4,
		CONF_DATA0 => conf_data0,

		--VGA
		VGA_HS     => vga_hsync,
		VGA_VS     => vga_vsync,
		VGA_R      => vga_red(7 downto 2),
		VGA_G      => vga_green(7 downto 2),
		VGA_B      => vga_blue(7 downto 2),

		--AUDIO
		--DAC_L   => dac_l,
		--DAC_R   => dac_r,
		AUDIO_L => sigma_l,
		AUDIO_R => sigma_r

		--PS2
		-- PS2K_CLK => ps2_keyboard_clk_in or intercept, -- Block keyboard when OSD is active
		-- PS2K_DAT => ps2_keyboard_dat_in,
		-- PS2M_CLK => ps2_mouse_clk_in,
		-- PS2M_DAT => ps2_mouse_dat_in
	);


-- Pass internal signals to external SPI interface
sd_clk <= spi_clk_int;
spi_do <= sd_miso when spi_ss4='0' else 'Z';
spi_fromguest <= spi_do;

controller : entity work.substitute_mcu
	generic map (
		sysclk_frequency => 500,
		debug 		=> false,
		jtag_uart 	=> false
	)
	port map (
		clk 		=> MAX10_CLK1_50,
		reset_in 	=> KEY(0),
		reset_out 	=> reset_n,

		-- SPI signals
		spi_miso      => sd_miso,
		spi_mosi      => sd_mosi,
		spi_clk       => spi_clk_int,
		spi_cs        => sd_cs,
		spi_fromguest => spi_fromguest,
		spi_toguest   => spi_toguest,
		spi_ss2       => spi_ss2,
		spi_ss3       => spi_ss3,
		spi_ss4       => spi_ss4,
		conf_data0    => conf_data0,

		-- PS/2 signals
		ps2k_clk_in  => ps2_keyboard_clk_in,
		ps2k_dat_in  => ps2_keyboard_dat_in,
		ps2k_clk_out => ps2_keyboard_clk_out,
		ps2k_dat_out => ps2_keyboard_dat_out,
		ps2m_clk_in  => ps2_mouse_clk_in,
		ps2m_dat_in  => ps2_mouse_dat_in,
		ps2m_clk_out => ps2_mouse_clk_out,
		ps2m_dat_out => ps2_mouse_dat_out,

		-- Buttons
		buttons => (0=>KEY(1), others=>'1'),    -- 0=>OSD_button

		-- Joysticks
		-- joy1 => joya,

		-- UART
		rxd => rs232_rxd,
		txd => rs232_txd,
		--
		intercept => intercept
);

LEDR <= (0=>(not act_led), others=>'0');

--CLK_I2C_SCL <= '1';
--CLK_I2C_SDA	<='Z';
GSENSOR_SCLK <= '0';
GSENSOR_CS_N <= '0';

end rtl;
