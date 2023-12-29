library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;

-------------------------------------------------------------------------

entity jtframe_zxtres_top is
	generic (
		VGA_OUTPUT	: natural   := 1;   -- 1=MIST VIDEO (+DP), 2=ZXTRES WRAPPER (+DP), 3=MIST VIDEO (without DP)
		CLKVIDEO    : natural 	:= 48;  -- 48=most cores, 96=cps1,cps15, cps2
		HSTART 		: natural 	:= 128  -- 128 s16b, 108 kicker, 250 cps1/cps15/cps2
	);	
	port (
		CLK_50      : in std_logic;
		LED5        : out std_logic := '1';
		LED6        : out std_logic := '1';
		-- SDRAM
		DRAM_CLK    : out std_logic;
		DRAM_CKE    : out std_logic;
		DRAM_ADDR   : out std_logic_vector(12 downto 0);
		DRAM_BA     : out std_logic_vector(1 downto 0);
		DRAM_DQ     : inout std_logic_vector(15 downto 0);
		DRAM_LDQM   : out std_logic;
		DRAM_UDQM   : out std_logic;
		DRAM_CS_N   : out std_logic;
		DRAM_WE_N   : out std_logic;
		DRAM_CAS_N  : out std_logic;
		DRAM_RAS_N  : out std_logic;
		-- SRAM
		SRAM_A      : out   std_logic_vector(19 downto 0) := (others => '0');
		SRAM_Q      : inout std_logic_vector(15 downto 0) := (others => 'Z');
		SRAM_WE     : out   std_logic := '1';
		SRAM_OE     : out   std_logic := '1';
		SRAM_UB     : out   std_logic := '1';
		SRAM_LB     : out   std_logic := '1';
		-- VGA
		VGA_HS 		: out std_logic;
		VGA_VS 		: out std_logic;
		VGA_R  		: out std_logic_vector(7 downto 0);
		VGA_G  		: out std_logic_vector(7 downto 0);
		VGA_B  		: out std_logic_vector(7 downto 0);
		-- DISPLAYPORT
		dp_tx_lane_p		: out   std_logic;
		dp_tx_lane_n		: out   std_logic;
		dp_refclk_p			: in	std_logic;
		dp_refclk_n			: in	std_logic;
		dp_tx_hp_detect		: in	std_logic;
		dp_tx_auxch_tx_p	: inout	std_logic;
		dp_tx_auxch_tx_n	: inout	std_logic;
		dp_tx_auxch_rx_p	: inout	std_logic;
		dp_tx_auxch_rx_n	: inout	std_logic;
		-- -- EAR
		-- EAR_I		 : in std_logic;
		-- PS2
		PS2_KEYBOARD_CLK : inout std_logic := '1';
		PS2_KEYBOARD_DAT : inout std_logic := '1';
		PS2_MOUSE_CLK    : inout std_logic;
		PS2_MOUSE_DAT    : inout std_logic;
		-- UART
		PMOD4_D4 	: in std_logic;		--UART_RXD
		PMOD4_D5 	: out std_logic;	--UART_TXD
		-- PMOD4_D6 	: in std_logic;		--UART_CTS
		-- PMOD4_D7 	: out std_logic;	--UART_RTS		
		-- JOYSTICK
        JOY_CLK		: out std_logic;
        JOY_LOAD_N	: out std_logic;
        JOY_DATA	: in std_logic;
        JOY_SEL		: out std_logic := '1';
		-- SD Card
		SD_CS_N_O   : out std_logic := '1';
		SD_SCLK_O   : out std_logic := '0';
		SD_MOSI_O   : out std_logic := '0';
		SD_MISO_I   : in std_logic;
		-- I2S audio		
		I2S_BCLK    : out std_logic := '0';
		I2S_LRCLK   : out std_logic := '0';
		I2S_DATA    : out std_logic := '0';
		-- PWM AUDIO
		PWM_AUDIO_L : out std_logic;
		PWM_AUDIO_R : out std_logic
	);
END entity;

architecture RTL of jtframe_zxtres_top is

	-- System clocks
	signal locked  : std_logic;
	signal reset_n : std_logic;

	-- SPI signals
	signal sd_clk  : std_logic;
	signal sd_cs   : std_logic;
	signal sd_mosi : std_logic;
	signal sd_miso : std_logic;

	-- internal SPI signals
--	signal spi_do 		 : std_logic;
	signal spi_toguest   : std_logic;
	signal spi_fromguest : std_logic;
	signal spi_ss2       : std_logic;
	signal spi_ss3       : std_logic;
	signal spi_ss4       : std_logic;
	signal conf_data0    : std_logic;
	signal spi_clk_int   : std_logic;

	-- PS/2 Keyboard socket - used for second mouse
	signal ps2_keyboard_clk_in  : std_logic;
	signal ps2_keyboard_dat_in  : std_logic;
	signal ps2_keyboard_clk_out : std_logic;
	signal ps2_keyboard_dat_out : std_logic;

	-- PS/2 Mouse
	signal ps2_mouse_clk_in  : std_logic;
	signal ps2_mouse_dat_in  : std_logic;
	signal ps2_mouse_clk_out : std_logic;
	signal ps2_mouse_dat_out : std_logic;

	signal intercept : std_logic;

	-- Video
	signal vga_red   : std_logic_vector(7 downto 0);
	signal vga_green : std_logic_vector(7 downto 0);
	signal vga_blue  : std_logic_vector(7 downto 0);
	signal vga_hsync : std_logic;
	signal vga_vsync : std_logic;

	signal vga_red_w   : std_logic_vector(7 downto 0);
	signal vga_green_w : std_logic_vector(7 downto 0);
	signal vga_blue_w  : std_logic_vector(7 downto 0);
	signal vga_hsync_w : std_logic;
	signal vga_vsync_w : std_logic;	

	signal vga_clk   : std_logic;
	signal vga_ce 	 : std_logic;
	signal vga_x_r   : std_logic_vector(5 downto 0);
	signal vga_x_g   : std_logic_vector(5 downto 0);
	signal vga_x_b   : std_logic_vector(5 downto 0);
	signal vga_x_hs  : std_logic;
	signal vga_x_vs  : std_logic;

	signal scan2x_enb: std_logic;
	signal scan2x_toggle : std_logic;

	-- RS232 serial
	signal rs232_rxd : std_logic;
	signal rs232_txd : std_logic;

	-- JOYSTICK
	signal joya : std_logic_vector(7 downto 0);
	signal joyb : std_logic_vector(7 downto 0);

	signal joy1_bus : std_logic_vector(5 downto 0);
	signal joy2_bus : std_logic_vector(5 downto 0);
	signal intercept_joy : std_logic_vector(5 downto 0);
	signal joy_select_o  : std_logic;

	signal joy1up      : std_logic;
	signal joy1down    : std_logic;
	signal joy1left    : std_logic;
	signal joy1right   : std_logic;
	signal joy1fire1   : std_logic;
	signal joy1fire2   : std_logic;
	signal joy2up      : std_logic;
	signal joy2down    : std_logic;
	signal joy2left    : std_logic;
	signal joy2right   : std_logic;
	signal joy2fire1   : std_logic;
	signal joy2fire2   : std_logic;

	-- DAC AUDIO
	signal dac_l 	: signed(15 downto 0);
	signal dac_r 	: signed(15 downto 0);
	signal dac_l_s  : signed(15 downto 0);
	signal dac_r_s  : signed(15 downto 0);

	-- I2S 
	signal i2s_mclk : std_logic;

	component audio_top is
		port (
			clk_50MHz : in std_logic;  -- system clock
			dac_MCLK  : out std_logic; -- outputs to I2S DAC
			dac_LRCK  : out std_logic;
			dac_SCLK  : out std_logic;
			dac_SDIN  : out std_logic;
			L_data    : in std_logic_vector(15 downto 0); -- LEFT data (15-bit signed)
			R_data    : in std_logic_vector(15 downto 0)  -- RIGHT data (15-bit signed) 
		);
	end component;

	signal act_led 	  : std_logic;
	signal osd_en  	  : std_logic;
	signal lf_sram 	  : std_logic;

	signal CLK_50_buf : std_logic;
	
	alias clock_input : std_logic is CLK_50;
	alias sigma_l 	  : std_logic is PWM_AUDIO_L;
	alias sigma_r 	  : std_logic is PWM_AUDIO_R;

begin


-- SPI
SD_CS_N_O <= sd_cs;
SD_MOSI_O <= sd_mosi;
sd_miso   <= SD_MISO_I;
SD_SCLK_O <= sd_clk;

-- External devices tied to GPIOs
ps2_mouse_dat_in <= PS2_MOUSE_DAT;
PS2_MOUSE_DAT    <= '0' when ps2_mouse_dat_out = '0' else 'Z';
ps2_mouse_clk_in <= PS2_MOUSE_CLK;
PS2_MOUSE_CLK    <= '0' when ps2_mouse_clk_out = '0' else 'Z';

ps2_keyboard_dat_in <= PS2_KEYBOARD_DAT;
PS2_KEYBOARD_DAT    <= '0' when ps2_keyboard_dat_out = '0' else 'Z';
ps2_keyboard_clk_in <= PS2_KEYBOARD_CLK;
PS2_KEYBOARD_CLK    <= '0' when ps2_keyboard_clk_out = '0' else 'Z';

-- VGA_OUTPUT   1=MIST VIDEO (+DP), 2=ZXTRES WRAPPER (+DP), 3=MIST VIDEO (without DP)
VIDEO_1 : if (VGA_OUTPUT = 1 or VGA_OUTPUT = 3) generate --  1=MIST VIDEO (+DP), 3=MIST VIDEO (without DP)
	-- Video signals from guest mist_top 
	VGA_R  <= vga_red(7 downto 2)   & vga_red(7 downto 6);
	VGA_G  <= vga_green(7 downto 2) & vga_green(7 downto 6);
	VGA_B  <= vga_blue(7 downto 2)  & vga_blue(7 downto 6);
	VGA_HS <= vga_hsync;
	VGA_VS <= vga_vsync;
end generate VIDEO_1;

VIDEO_2 : if VGA_OUTPUT = 2 generate -- 2=ZXTRES WRAPPER (+DP )
	-- Video signals from zxtres_wrapper
	VGA_R  <= vga_red_w;
	VGA_G  <= vga_green_w;
	VGA_B  <= vga_blue_w;
	VGA_HS <= vga_hsync_w;
	VGA_VS <= vga_vsync_w;
end generate VIDEO_2;


-- Buffered input clock
clkin_buff : component IBUF 
	port map (
		I => (clock_input),
		O => (CLK_50_buf)
	);

-- JOYSTICKS
joystick_serial_inst : entity work.joydecoder_neptuno	-- neogeo joy controller
--joystick_serial_inst : entity work.joystick_serial	-- jtframe neptuno target joy controller
	port map (
		clk_i 		  => vga_clk,		-- vga_clk = clk_sys
		joy_data_i 	  => JOY_DATA,
		joy_clk_o 	  => JOY_CLK,
		joy_load_o 	  => JOY_LOAD_N,

		joy1_up_o     => joy1up,
		joy1_down_o   => joy1down,
		joy1_left_o   => joy1left,
		joy1_right_o  => joy1right,
		joy1_fire1_o  => joy1fire1,
		joy1_fire2_o  => joy1fire2,

		joy2_up_o     => joy2up,
		joy2_down_o   => joy2down,
		joy2_left_o   => joy2left,
		joy2_right_o  => joy2right,
		joy2_fire1_o  => joy2fire1,
		joy2_fire2_o  => joy2fire2
	);

-- osd joystick
joya <= "11" & joy1fire2 & joy1fire1 & joy1right & joy1left & joy1down & joy1up;
joyb <= "11" & joy2fire2 & joy2fire1 & joy2right & joy2left & joy2down & joy2up;

-- Core direct joystick
joy1_bus <= joy1fire2 & joy1fire1 & joy1up & joy1down & joy1left & joy1right;
joy2_bus <= joy2fire2 & joy2fire1 & joy2up & joy2down & joy2left & joy2right;

--  Joystick intercept signal
intercept_joy <= "111111"   when intercept = '1' else "000000";
JOY_SEL       <= '1' 		when intercept = '1' else joy_select_o;

-- I2S audio
audio_i2s : entity work.audio_top
	port map (
		clk_50MHz => CLK_50_buf,
		dac_MCLK  => i2s_mclk,
		dac_SCLK  => I2S_BCLK,
		dac_SDIN  => I2S_DATA,
		dac_LRCK  => I2S_LRCLK,
		L_data    => std_logic_vector(dac_l_s),
		R_data    => std_logic_vector(dac_r_s)
		);

dac_l_s <= (dac_l(15) & dac_l(15 downto 1));
dac_r_s <= (dac_r(15) & dac_r(15 downto 1));


guest : component mist_top
	port map (
		CLOCK_27 	=> clock_input & clock_input,
		LED 		=> act_led,

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

		--SRAM
		SRAM_A	   => SRAM_A,
		SRAM_Q	   => SRAM_Q,
		SRAM_WE	   => SRAM_WE,
		SRAM_OE	   => SRAM_OE,
		SRAM_UB	   => SRAM_UB,
		SRAM_LB	   => SRAM_LB,			

		--UART
		UART_TX    => PMOD4_D5,
		UART_RX    => PMOD4_D4,

		--SPI
		--SPI_DO   => spi_do,
		SPI_DO     => spi_fromguest,
		SPI_DO_IN  => sd_miso,
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

		--DISPLAYPORT
		RED_x      => vga_x_r,
		GREEN_x    => vga_x_g,
		BLUE_x     => vga_x_b,
		HS_x       => vga_x_hs,
		VS_x       => vga_x_vs,
		VGA_CE     => vga_ce,
		VGA_CLK    => vga_clk,		-- vga_clk = clk_sys

		--JOYSTICKS
		JOY1_BUS   => joy1_bus or intercept_joy,   -- Block joystick when OSD is active
		JOY2_BUS   => joy2_bus or intercept_joy,   -- Block joystick when OSD is active
		JOY_SELECT => joy_select_o,

		--AUDIO
		DAC_L      => dac_l,
		DAC_R      => dac_r,
		AUDIO_L    => sigma_l,
		AUDIO_R    => sigma_r,

		SCAN2x_ENB => scan2x_enb,
		SCAN2x_TOGGLE => scan2x_toggle,
		OSD_EN	   => osd_en
	);


-- Pass internal signals to external SPI interface
sd_clk <= spi_clk_int;
-- spi_do <= sd_miso when spi_ss4='0' else 'Z'; -- to guest
-- spi_fromguest <= spi_do;  -- to control CPU

controller : entity work.substitute_mcu
	generic map (
		sysclk_frequency => 500,
--		SPI_FASTBIT=>3,
--		SPI_INTERNALBIT=>2,		--needed if OSD hungs
--		SPI_FASTBIT => 0, 		-- Reducing this will make SPI comms faster, for cores which are clocked fast enough.
--		SPI_INTERNALBIT => 0, 	-- This will make SPI comms faster, for cores which are clocked fast enough.
		debug     => false,
		jtag_uart => false
	)
	port map (
		clk       => CLK_50_buf,	--50 MHz
		reset_in  => '1',			--reset_in  when 0
		reset_out => reset_n,		--reset_out when 0

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
		buttons => (0 => (not osd_en), others => '1'),	-- 0 => OSD_button

		-- Joysticks
		joy1 => joya,
		joy2 => joyb,

		-- UART
		rxd  => rs232_rxd,
		txd  => rs232_txd,
		--
		intercept => intercept
	);

LED5 <= not act_led;

VIDEO_3 : if (VGA_OUTPUT = 1 or VGA_OUTPUT = 2) generate --1=MIST VIDEO (+DP), 2=ZXTRES WRAPPER (+DP), 3=MIST VIDEO (without DP)

zxtres_wrapper_inst : zxtres_wrapper
  generic map (
	HSTART => HSTART,  --128 s16b, kicker(48right,108cent)  --250 cps1/cps15/cps2
	VSTART => 15,
	CLKVIDEO => CLKVIDEO,	--48 most cores		--96 cps1/cps15/cps2
	INITIAL_FIELD => 0
  )
  port map (
    clkvideo => vga_clk,
    enclkvideo => vga_ce,	--'1'
    clkpalntsc => '0',
    reset_n => 	reset_n,     --'1',
    reboot_fpga => '0',
	----
    video_output_sel => not scan2x_enb,	-- 0: RGB 15kHz + DP   1: VGA + DP pantalla azul
    disable_scanlines => '1',  	-- 1: sin scanlines  0: emular scanlines (cuidado con el policía del retro!)  
    monochrome_sel => '0',  	-- 0 : RGB, 1: fósforo verde, 2: fósforo ámbar, 3: escala de grises
    interlaced_image => '0', 	-- 1: Indico que la fuente de video es una señal entrelazada, no progresiva.
    -- ad724_modo => '0',		-- Reloj de color. 0 : PAL, 1: NTSC
    -- ad724_clken => '0',		-- 0 = AD724 usa su propio cristal. 1 = AD724 usa reloj de FPGA.
	----
    ri => vga_x_r & vga_x_r(5 downto 4),
    gi => vga_x_g & vga_x_g(5 downto 4),
    bi => vga_x_b & vga_x_b(5 downto 4),
    hsync_ext_n => vga_x_hs,
    vsync_ext_n => vga_x_vs,
    csync_ext_n => vga_x_hs & vga_x_vs,
	----
    ro => vga_red_w,
    go => vga_green_w,
    bo => vga_blue_w,
    hsync => vga_hsync_w,
    vsync => vga_vsync_w,
	----
    dp_tx_lane_p => dp_tx_lane_p,
    dp_tx_lane_n => dp_tx_lane_n,
    dp_refclk_p => dp_refclk_p,
    dp_refclk_n => dp_refclk_n,
    dp_tx_hp_detect => dp_tx_hp_detect,
    dp_tx_auxch_tx_p => dp_tx_auxch_tx_p,
    dp_tx_auxch_tx_n => dp_tx_auxch_tx_n,
    dp_tx_auxch_rx_p => dp_tx_auxch_rx_p,
    dp_tx_auxch_rx_n => dp_tx_auxch_rx_n
  );

end generate VIDEO_3;

end rtl;
