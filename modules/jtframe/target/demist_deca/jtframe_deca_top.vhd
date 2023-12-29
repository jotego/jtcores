library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;

-------------------------------------------------------------------------

entity jtframe_deca_top is
	generic (
		DECA_KEYB: natural := 1  -- 1=PS2 INOUT, 2= USB LOW SPEED (BETA)
	);
	port (
		ADC_CLK_10    : in std_logic;
		MAX10_CLK1_50 : in std_logic;
		MAX10_CLK2_50 : in std_logic;
		KEY           : in std_logic_vector(1 downto 0);
		LED           : out std_logic_vector(3 downto 0) := "1111";
		-- SDRAM
		DRAM_CLK   : out std_logic;
		DRAM_CKE   : out std_logic;
		DRAM_ADDR  : out std_logic_vector(12 downto 0);
		DRAM_BA    : out std_logic_vector(1 downto 0);
		DRAM_DQ    : inout std_logic_vector(15 downto 0);
		DRAM_LDQM  : out std_logic;
		DRAM_UDQM  : out std_logic;
		DRAM_CS_N  : out std_logic;
		DRAM_WE_N  : out std_logic;
		DRAM_CAS_N : out std_logic;
		DRAM_RAS_N : out std_logic;
		-- VGA
		VGA_HS     : out std_logic;
		VGA_VS     : out std_logic;
		VGA_R      : out std_logic_vector(3 downto 0);
		VGA_G      : out std_logic_vector(3 downto 0);
		VGA_B      : out std_logic_vector(3 downto 0);
		-- -- MIDI
		-- SPI_MISO_WSBD         : in    std_logic;
		-- SPI_SCLK_DABD         : in    std_logic;
		-- SPI_CS0_CLKBD         : in    std_logic;
		-- EAR
		EAR 			 : in std_logic;
		-- PS2
		PS2_KEYBOARD_CLK : inout std_logic := '1';
		PS2_KEYBOARD_DAT : inout std_logic := '1';
		PS2_MOUSE_CLK    : inout std_logic;
		PS2_MOUSE_DAT    : inout std_logic;
		-- UART
		UART_RXD : in std_logic;
		UART_TXD : out std_logic;
		--SPI_CS1 : in std_logic;		--CTS
		--SPI_CS2 : out std_logic;		--RTS
		-- JOYSTICK
		JOY1_B2_P9 : in std_logic;
		JOY1_B1_P6 : in std_logic;
		JOY1_UP    : in std_logic;
		JOY1_DOWN  : in std_logic;
		JOY1_LEFT  : in std_logic;
		JOY1_RIGHT : in std_logic;
		JOYX_SEL_O : out std_logic := '1';
		-- SD Card
		SD_CS_N_O   : out std_logic := '1';
		SD_SCLK_O   : out std_logic := '0';
		SD_MOSI_O   : out std_logic := '0';
		SD_MISO_I   : in std_logic;
		SD_SEL      : out std_logic := '0';
		SD_CMD_DIR  : out std_logic := '1';
		SD_D0_DIR   : out std_logic := '0';
		SD_D123_DIR : out std_logic;
		-- PMOD DETO
		DETO1_PMOD2_6 	: inout std_logic;
		DETO2_PMOD2_7 	: inout std_logic;
		DETO3_JOY_MUX 	: inout std_logic;
		DETO4			: inout std_logic;
		-- HDMI-TX  DECA 
		HDMI_I2C_SCL : inout std_logic;
		HDMI_I2C_SDA : inout std_logic;
		HDMI_I2S     : inout std_logic_vector(3 downto 0);
		HDMI_LRCLK   : inout std_logic;
		HDMI_MCLK    : inout std_logic;
		HDMI_SCLK    : inout std_logic;
		HDMI_TX_CLK  : out std_logic;
		HDMI_TX_D    : out std_logic_vector(23 downto 0);
		HDMI_TX_DE   : out std_logic;
		HDMI_TX_HS   : out std_logic;
		HDMI_TX_INT  : in std_logic;
		HDMI_TX_VS   : out std_logic;
		-- AUDIO CODEC  DECA 
		AUDIO_GPIO_MFP5  : inout std_logic;
		AUDIO_MISO_MFP4  : in std_logic;
		AUDIO_RESET_n    : inout std_logic;
		AUDIO_SCLK_MFP3  : out std_logic;
		AUDIO_SCL_SS_n   : out std_logic;
		AUDIO_SDA_MOSI   : inout std_logic;
		AUDIO_SPI_SELECT : out std_logic;
		I2S_MCK          : out std_logic;
		I2S_SCK          : out std_logic;
		I2S_LR           : out std_logic;
		I2S_D            : out std_logic;

		--Switches 
		SW 			: in std_logic_vector(1 downto 0);
		-- Toggle leds in USB keyboard SW[0] LedCaps	SW[1] LedNum

		--TUSB1210
		USB_CLKIN 	: in std_logic;     	--60MHz from ULPI
		USB_FAULT_n	: in std_logic;    		--Overcurrent
		USB_DATA 	: inout std_logic_vector(7 downto 0);
		USB_NXT 	: in std_logic;
		USB_DIR 	: in std_logic;
		USB_STP 	: out std_logic;
		USB_RESET_n : out std_logic;    	--Fixed to High
		USB_CS 		: out std_logic        	--Fixed to High
	);
END entity;

architecture RTL of jtframe_deca_top is

	-- System clocks
	signal locked  : std_logic;
	signal reset_n : std_logic;

	-- SPI signals
	signal sd_clk  : std_logic;
	signal sd_cs   : std_logic;
	signal sd_mosi : std_logic;
	signal sd_miso : std_logic;

	-- internal SPI signals
	signal spi_do 	     : std_logic;
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

	-- RS232 serial
	signal rs232_rxd : std_logic;
	signal rs232_txd : std_logic;

	-- IO
	signal joya : std_logic_vector(7 downto 0);
	signal joyb : std_logic_vector(7 downto 0);
	signal joyc : std_logic_vector(7 downto 0);
	signal joyd : std_logic_vector(7 downto 0);

	signal joy1 : std_logic_vector(5 downto 0);
	signal joy2 : std_logic_vector(5 downto 0);
	signal intercept_joy : std_logic_vector(5 downto 0);
	signal joy_select_o  : std_logic;

	-- DAC AUDIO
	signal dac_l : signed(15 downto 0);
	signal dac_r : signed(15 downto 0);

	component AUDIO_SPI_CTL_RD
		port (
			iRESET_n : in std_logic;
			iCLK_50  : in std_logic;
			oCS_n    : out std_logic;
			oSCLK    : out std_logic;
			oDIN     : out std_logic;
			iDOUT    : in std_logic
		);
	end component;

	signal RESET_DELAY_n : std_logic;

	-- I2S
	signal i2s_Mck_o : std_logic;
	signal i2s_Sck_o : std_logic;
	signal i2s_Lr_o  : std_logic;
	signal i2s_D_o   : std_logic;

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

	-- HDMI

	component I2C_HDMI_Config
		port (
			iCLK        : in std_logic;
			iRST_N      : in std_logic;
			I2C_SCLK    : out std_logic;
			I2C_SDAT    : inout std_logic;
			HDMI_TX_INT : in std_logic
		);
	end component;

	-- component pll2
	-- 	port (
	-- 		inclk0 : in std_logic;
	-- 		c0     : out std_logic;
	-- 		c1     : out std_logic;
	-- 		locked : out std_logic
	-- 	);
	-- end component;

	-- VIDEO signals
	signal vga_clk   : std_logic;
	signal vga_de 	 : std_logic;
	signal vga_x_r   : std_logic_vector(5 downto 0);
	signal vga_x_g   : std_logic_vector(5 downto 0);
	signal vga_x_b   : std_logic_vector(5 downto 0);
	signal vga_x_hs  : std_logic;
	signal vga_x_vs  : std_logic;

	-- USB ULPI KEYBOARD
	signal USB_CLK_PHASE  : std_logic;
	signal USB_PLL_LOCKED : std_logic;
	signal PS2_KEYBOARD_CLK_USB : std_logic := '1';
	signal PS2_KEYBOARD_DAT_USB : std_logic := '1';

	component PLL_PHASE90
		port (
			inclk0 : in std_logic;
			c0     : out std_logic;
			locked : out std_logic
		);
	end component;

	-- https://github.com/TheSonders/USBKeyboard/blob/main/ULPI_PS2_PUBLIC.v
	component ULPI_PS2
		port (
			clk 		: in std_logic;
			LedNum 		: in std_logic;
			LedCaps 	: in std_logic;
			LedScroll 	: in std_logic;
			PS2data 	: out std_logic;
			PS2clock 	: out std_logic;
			FAULT_n 	: in std_logic;
			DATA 		: inout std_logic_vector  (7 downto 0);
			NXT 		: in std_logic;
			DIR 		: in std_logic;
			STP 		: out std_logic;
			RESET_n 	: out std_logic;
			CS 			: out std_logic
		);
	end component;


	--
	
	signal act_led  : std_logic;
	signal osd_en   : std_logic;

	-- DECA target guest_top template signals
	alias clock_input 	: std_logic is MAX10_CLK1_50;
	alias audio_input	: std_logic is EAR;	
	alias sigma_l : std_logic is DETO1_PMOD2_6;
	alias sigma_r : std_logic is DETO2_PMOD2_7;

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

	-- DECA_KEYB:  1=PS2 INOUT, 2= PS2 & USB LOW SPEED
	KEYBOARD_1 : if DECA_KEYB = 1 generate -- KEYB PS2 INOUT
		ps2_keyboard_dat_in <= PS2_KEYBOARD_DAT;
		PS2_KEYBOARD_DAT    <= '0' when ps2_keyboard_dat_out = '0' else 'Z';
		ps2_keyboard_clk_in <= PS2_KEYBOARD_CLK;
		PS2_KEYBOARD_CLK    <= '0' when ps2_keyboard_clk_out = '0' else 'Z';
		USB_PLL_LOCKED      <= '1';
	end generate KEYBOARD_1;

	KEYBOARD_2 : if DECA_KEYB = 2 generate -- KEYB USB LOW SPEED 
		ps2_keyboard_dat_in <= PS2_KEYBOARD_DAT_USB;
--		PS2_KEYBOARD_DAT    <= '0' when ps2_keyboard_dat_out = '0' else 'Z';
		ps2_keyboard_clk_in <= PS2_KEYBOARD_CLK_USB;
--		PS2_KEYBOARD_CLK    <= '0' when ps2_keyboard_clk_out = '0' else 'Z';
	
		-- PLL ULPI_PS2
		PLL_PHASE90_inst : PLL_PHASE90
		port map (
			inclk0		=> USB_CLKIN,
			c0			=> USB_CLK_PHASE,		
			locked		=> USB_PLL_LOCKED
		);

		-- ULPI_PS2
		ULPI_PS2_inst : ULPI_PS2
		port map (
			clk 		=> USB_CLK_PHASE,
			LedNum 		=> SW(1),
			LedCaps 	=> SW(0),
			LedScroll 	=> '0',
			PS2data 	=> PS2_KEYBOARD_DAT_USB,
			PS2clock 	=> PS2_KEYBOARD_CLK_USB,
			FAULT_n 	=> USB_FAULT_n,
			DATA 		=> USB_DATA,
			NXT 		=> USB_NXT,
			DIR 		=> USB_DIR,
			STP 		=> USB_STP,
			RESET_n 	=> USB_RESET_n,
			CS 			=> USB_CS
		);
	end generate KEYBOARD_2;

	
	-- OSD joystick
	-- JOYX_SEL_O          <= '1';
	joya                <= "11" & JOY1_B2_P9 & JOY1_B1_P6 & JOY1_RIGHT & JOY1_LEFT & JOY1_DOWN & JOY1_UP;
	joyb                <= (others => '1');
	joyc                <= (others => '1');
	joyd                <= (others => '1');

	-- Core direct joystick
	joy1                <= JOY1_B2_P9 & JOY1_B1_P6 & JOY1_UP & JOY1_DOWN & JOY1_LEFT & JOY1_RIGHT;
	joy2                <= (others => '1');

	SD_SEL      <= '0'; -- 0 = 3.3V at sdcard   
	SD_CMD_DIR  <= '1'; -- MOSI FPGA output
	SD_D0_DIR   <= '0'; -- MISO FPGA input     
	SD_D123_DIR <= '1'; -- CS FPGA output  

	VGA_R       <= vga_red(7 downto 4);
	VGA_G       <= vga_green(7 downto 4);
	VGA_B       <= vga_blue(7 downto 4);
	VGA_HS      <= vga_hsync;
	VGA_VS      <= vga_vsync;


	-- DECA AUDIO CODEC
	RESET_DELAY_n <= reset_n;
	-- Audio DAC DECA Output assignments
	AUDIO_GPIO_MFP5  <= '1'; -- GPIO
	AUDIO_SPI_SELECT <= '1'; -- SPI mode
	AUDIO_RESET_n    <= RESET_DELAY_n;

	-- DECA AUDIO CODEC SPI CONFIG
	AUDIO_SPI_CTL_RD_inst : AUDIO_SPI_CTL_RD
		port map (
			iRESET_n => RESET_DELAY_n,
			iCLK_50  => MAX10_CLK1_50,
			oCS_n    => AUDIO_SCL_SS_n,
			oSCLK    => AUDIO_SCLK_MFP3,
			oDIN     => AUDIO_SDA_MOSI,
			iDOUT    => AUDIO_MISO_MFP4
		);

	-- AUDIO CODEC
	audio_i2s : entity work.audio_top
		port map (
			clk_50MHz => MAX10_CLK1_50,
			dac_MCLK  => i2s_Mck_o,
			dac_SCLK  => i2s_Sck_o,
			dac_SDIN  => i2s_D_o,
			dac_LRCK  => i2s_Lr_o,
			L_data    => std_logic_vector(dac_l),
			R_data    => std_logic_vector(dac_r)
		);

	I2S_MCK <= i2s_Mck_o;
	I2S_SCK <= i2s_Sck_o;
	I2S_LR  <= i2s_Lr_o;
	I2S_D   <= i2s_D_o;


	-- DECA HDMI

	-- HDMI CONFIG    
	I2C_HDMI_Config_inst : I2C_HDMI_Config
	port map(
		iCLK        => MAX10_CLK1_50,
		iRST_N      => reset_n, --reset_n, KEY(0)
		I2C_SCLK    => HDMI_I2C_SCL,
		I2C_SDAT    => HDMI_I2C_SDA,
		HDMI_TX_INT => HDMI_TX_INT
	);

	-- -- PLL2
	-- pll2_inst : pll2
	-- port map (
	-- 	inclk0		=> MAX10_CLK1_50,
	-- 	c0			=> vga_clk,		
	-- 	--c1			=> vga_clk,		
	-- 	locked		=> open
	-- );

	--  HDMI VIDEO   
	HDMI_TX_CLK <= vga_clk;
	HDMI_TX_DE  <= vga_de;

	HDMI_TX_HS  <= vga_x_hs;
	HDMI_TX_VS  <= vga_x_vs;
	HDMI_TX_D   <= vga_x_r & vga_x_r(4 downto 3) & vga_x_g & vga_x_g(4 downto 3) & vga_x_b & vga_x_b(4 downto 3);

	-- HDMI_TX_HS  <= vga_hsync;					
	-- HDMI_TX_VS  <= vga_vsync;
	-- HDMI_TX_D   <= vga_red(7 downto 2) & vga_red(7 downto 6) & vga_green(7 downto 2)  & vga_green(7 downto 6) & vga_blue(7 downto 2)  & vga_blue(7 downto 6);

	--  HDMI AUDIO   
	HDMI_MCLK   <= i2s_Mck_o;
	HDMI_SCLK   <= i2s_Sck_o; -- lr*2*16
	HDMI_LRCLK  <= i2s_Lr_o;
	HDMI_I2S(0) <= i2s_D_o;


	--  Joystick intercept signal
	process(clock_input)
	begin
		if (intercept = '1') then
			intercept_joy <= "111111";
	 		JOYX_SEL_O    <= '1';
		else
			intercept_joy <= "000000";
			JOYX_SEL_O    <= joy_select_o;
		end if;
	end process;


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

			--HDMI
			RED_x      => vga_x_r,
			GREEN_x    => vga_x_g,
			BLUE_x     => vga_x_b,
			HS_x       => vga_x_hs,
			VS_x       => vga_x_vs,
			VGA_DE     => vga_de,
			VGA_CLK    => vga_clk,

			--JOYSTICKS
			JOY1 	   => joy1 or intercept_joy,   -- Block joystick when OSD is active
			JOY2 	   => joy2 or intercept_joy,   -- Block joystick when OSD is active
			JOY_SELECT => joy_select_o,

			--AUDIO
			DAC_L      => dac_l,
			DAC_R      => dac_r,
			AUDIO_L    => sigma_l,
			AUDIO_R    => sigma_r,

			OSD_EN	   => osd_en

			--PS2
			-- PS2K_CLK => ps2_keyboard_clk_in or intercept, -- Block keyboard when OSD is active
			-- PS2K_DAT => ps2_keyboard_dat_in,
			-- PS2M_CLK => ps2_mouse_clk_in,
			-- PS2M_DAT => ps2_mouse_dat_in
		);


	-- Pass internal signals to external SPI interface
	sd_clk <= spi_clk_int;
	spi_do <= sd_miso when spi_ss4='0' else 'Z'; -- to guest
	spi_fromguest <= spi_do;  -- to control CPU

	controller : entity work.substitute_mcu
		generic map (
			sysclk_frequency => 500,
	--		SPI_FASTBIT=>3,
	--		SPI_INTERNALBIT=>2,		--needed if OSD hungs
			debug     => false,
			jtag_uart => false
		)
		port map (
			clk       => MAX10_CLK1_50,
			reset_in  => KEY(0) and USB_PLL_LOCKED,		--reset_in  when 0
			reset_out => reset_n,						--reset_out when 0

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
			buttons => (0 => KEY(1) and (not osd_en), others => '1'),	-- 0 => OSD_button

			-- Joysticks
			joy1 => joya,
			joy2 => joyb,

			-- UART
			rxd  => rs232_rxd,
			txd  => rs232_txd,
			--
			intercept => intercept
		);

	LED <= (0 => not act_led, others => '1');

end rtl;
