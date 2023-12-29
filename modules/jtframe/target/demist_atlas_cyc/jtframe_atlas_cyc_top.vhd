library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;

-------------------------------------------------------------------------

entity jtframe_atlas_top is
	generic (
		ATLAS_CYC_EAR : natural := 0; -- 0 = JOY SEL pin,	1 = EAR pin,  2 = MIDI_WSBD
		ATLAS_CYC_VGA : natural := 1; -- 0 = HDMI,  		1 = VGA
		ATLAS_CYC_KEYB: natural := 0  -- 0=PS2 NO AT1, 1=PS2 AT1, 2=USB NO AT1, 3=USB AT1, 
	);
	port (
		CLK12M : in std_logic;
		CLK_X  : in std_logic;
		KEY0   : in std_logic;
		LED    : out std_logic_vector(7 downto 0);
		-- PS2
		PS2_KEYBOARD_1 	 : inout std_logic;
		PS2_KEYBOARD_2 	 : inout std_logic;
		PDP_4k7			 : out   std_logic;		--USB2PS2
    	PDM_4k7			 : out   std_logic;
		PS2_MOUSE_CLK    : inout std_logic;
		PS2_MOUSE_DAT    : inout std_logic;
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
		-- HDMI TDMS [or VGA if ATLAS_CYC_VGA = 1]
		TMDS : out std_logic_vector(7 downto 0) := (others => '0');
		-- AUDIO
		SIGMA_R : out std_logic;
		SIGMA_L : out std_logic;
		-- -- I2S audio		
		PI_MISO_I2S_BCLK		: 	 out std_logic	:= '0';
		PI_MOSI_I2S_LRCLK		: 	 out std_logic	:= '0';
		PI_CLK_I2S_DATA			: 	 out std_logic	:= '0';	
		-- UART / MIDI
		UART_TXD_MIDI_OUT 		: 	out std_logic;
		UART_RXD_MIDI_WSBD 		: 	in std_logic;
		PI_CS_MIDI_CLKBD		: 	in std_logic;

		--PI_CLK_I2S_DATA		: 	 out std_logic;	  	-- Composite output 0
		--PI_CS_MIDI_CLKBD		: 	 out std_logic;	  	-- Composite output 1

		--PI_MISO_I2S_BCLK		: 	 in  std_logic;   			-- UART_CTS
		--PI_MOSI_I2S_LRCLK		: 	 out std_logic	:= '0';	  	-- UART_RTS

		-- SHARED PIN_P11: JOY SELECT Output / EAR Input / MIDI
		JOYX_SEL_EAR_MIDI_DABD  : 	inout std_logic := '0';
		-- JOYSTICK 
		JOY1_B2_P9 : in std_logic;
		JOY1_B1_P6 : in std_logic;
		JOY1_UP    : in std_logic;
		JOY1_DOWN  : in std_logic;
		JOY1_LEFT  : in std_logic;
		JOY1_RIGHT : in std_logic;
		-- SD Card
		SD_CS_N_O : out std_logic := '1';
		SD_SCLK_O : out std_logic := '0';
		SD_MOSI_O : out std_logic := '0';
		SD_MISO_I : in std_logic
	);
END entity;

architecture RTL of jtframe_atlas_top is

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


	-- HDMI TDMS signals
	signal clock_vga_s    : std_logic;
	signal clock_dvi_s    : std_logic;
	signal sound_hdmi_l_s : signed(15 downto 0);
	signal sound_hdmi_r_s : signed(15 downto 0);
	signal tdms_r_s       : std_logic_vector(9 downto 0);
	signal tdms_g_s       : std_logic_vector(9 downto 0);
	signal tdms_b_s       : std_logic_vector(9 downto 0);
	signal tdms_p_s       : std_logic_vector(3 downto 0);
	signal tdms_n_s       : std_logic_vector(3 downto 0);

	-- VGA signals  [ ATLAS_CYC_VGA = 1]
	signal VGA_HS : std_logic;
	signal VGA_VS : std_logic;
	signal VGA_R  : std_logic_vector(1 downto 0);
	signal VGA_G  : std_logic_vector(1 downto 0);
	signal VGA_B  : std_logic_vector(1 downto 0);

	-- VIDEO signals
	signal vga_clk   : std_logic;
	signal hdmi_clk  : std_logic;
	signal vga_de 	 : std_logic;
	signal vga_x_r   : std_logic_vector(5 downto 0);
	signal vga_x_g   : std_logic_vector(5 downto 0);
	signal vga_x_b   : std_logic_vector(5 downto 0);
	signal vga_x_hs  : std_logic;
	signal vga_x_vs  : std_logic;


	signal CLK50M : std_logic;
	signal CLK48M : std_logic;

	component pll2 is			-- for hdmi output & 50 MHz clock
	    port (
		--  areset : in std_logic;
			inclk0 : in std_logic;
			c0 : out std_logic;		--   50 MHz
			c1 : out std_logic;		--   48 MHz
		    c2 : out std_logic;		--   x5
		--	c3 : out std_logic;		--	 x
			locked : out std_logic
	  );
	end component;

	-- SHARE PIN P11 EAR IN / JOY SEL OUT  
	signal EAR        : std_logic;
	signal JOYX_SEL_O : std_logic;
	signal MIDI_DABD  : std_logic;

	-- USB2PS2
	component USB_PS2
		port (
			clk : in std_logic;
			LedNum : in std_logic;
			LedCaps : in std_logic;
			LedScroll : in std_logic;
			dp : inout std_logic;
			dm : inout std_logic;
			PS2data : out std_logic;
			PS2clock : out std_logic
	);
	end component;

	signal PS2data 		:  std_logic; 
	signal PS2clock 	:  std_logic; 
	signal clk48	    :  std_logic; 

	signal act_led : std_logic;

	signal osd_en   : std_logic;

	-- ATLAS CYC1000 target guest_top template signals
	signal clock_input 			: std_logic;
	alias uart_txd		 		: std_logic is UART_TXD_MIDI_OUT;
	alias uart_rxd		 		: std_logic is UART_RXD_MIDI_WSBD;
	alias audio_input 			: std_logic is EAR;
	
begin

	clock_input <= CLK12M;		-- from board

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

	-- ATLAS_CYC_KEYB -- 0 = PS2 NON AT1, 1 = PS2 AT1,  2 = USB NON AT1, 3 = USB AT1, 

	KEYBOARD_0 : if ATLAS_CYC_KEYB = 0 generate -- Keyboard PS2 previous AT1
		ps2_keyboard_dat_in <= PS2_KEYBOARD_1;
		PS2_KEYBOARD_1    <= '0' when ps2_keyboard_dat_out = '0' else 'Z';
		ps2_keyboard_clk_in <= PS2_KEYBOARD_2;
		PS2_KEYBOARD_2    <= '0' when ps2_keyboard_clk_out = '0' else 'Z';
	end generate KEYBOARD_0;

	KEYBOARD_1 : if ATLAS_CYC_KEYB = 1 generate -- Keyboard PS2 AT1 
		ps2_keyboard_dat_in <= PS2_KEYBOARD_2;
		PS2_KEYBOARD_2    <= '0' when ps2_keyboard_dat_out = '0' else 'Z';
		ps2_keyboard_clk_in <= PS2_KEYBOARD_1;
		PS2_KEYBOARD_1    <= '0' when ps2_keyboard_clk_out = '0' else 'Z';
	end generate KEYBOARD_1;

	KEYBOARD_2 : if ATLAS_CYC_KEYB = 2 generate -- Keyboard USB previous AT1
		-- USB2PS2
		PDP_4k7	<= '0';
		PDM_4k7	<= '0';

		USB_PS2_inst : USB_PS2
			port map (
				clk => CLK48M,
				LedNum =>  '0',
				LedCaps =>  '0',
				LedScroll =>  '0',
				dp => PS2_KEYBOARD_2,
				dm => PS2_KEYBOARD_1,
				PS2data => PS2data,
				PS2clock => PS2clock
			);

		ps2_keyboard_dat_in <= PS2data;
		ps2_keyboard_clk_in <= PS2clock;
	end generate KEYBOARD_2;

	KEYBOARD_3 : if ATLAS_CYC_KEYB = 3 generate -- Keyboard USB AT1 
		-- USB2PS2
		PDP_4k7	<= '0';
		PDM_4k7	<= '0';

		USB_PS2_inst : USB_PS2
			port map (
				clk => CLK48M,
				LedNum =>  '0',
				LedCaps =>  '0',
				LedScroll =>  '0',
				dp => PS2_KEYBOARD_1,
				dm => PS2_KEYBOARD_2,
				PS2data => PS2data,
				PS2clock => PS2clock
			);

		ps2_keyboard_dat_in <= PS2data;
		ps2_keyboard_clk_in <= PS2clock;
	end generate KEYBOARD_3;


	PIN_P11_JOYSEL_0 : if ATLAS_CYC_EAR = 0 generate -- JOY Select Output
		-- JOYX_SEL_O   <= '1';
		JOYX_SEL_EAR_MIDI_DABD <= JOYX_SEL_O;
		EAR          <= '0';
	end generate PIN_P11_JOYSEL_0;

	PIN_P11_JOYSEL_1 : if ATLAS_CYC_EAR = 1 generate -- EAR Input
		EAR 		<= JOYX_SEL_EAR_MIDI_DABD;
	end generate PIN_P11_JOYSEL_1;

	PIN_P11_JOYSEL_2 : if ATLAS_CYC_EAR = 2 generate -- MIDI WSBD input
		MIDI_DABD 	<= JOYX_SEL_EAR_MIDI_DABD;
		EAR         <= '0';
	end generate PIN_P11_JOYSEL_2;


	joya <= "11" & JOY1_B2_P9 & JOY1_B1_P6 & JOY1_RIGHT & JOY1_LEFT & JOY1_DOWN & JOY1_UP;
	joyb <= (others => '1');
	joyc <= (others => '1');
	joyd <= (others => '1');

	-- Core direct joystick
	joy1                <= JOY1_B2_P9 & JOY1_B1_P6 & JOY1_UP & JOY1_DOWN & JOY1_LEFT & JOY1_RIGHT;
	joy2                <= (others => '1');
	
	-- I2S audio
	audio_i2s: audio_top
		port map(
			clk_50MHz => CLK50M,
			dac_MCLK  => I2S_MCLK,
			dac_LRCK  => PI_MOSI_I2S_LRCLK,
			dac_SCLK  => PI_MISO_I2S_BCLK,
			dac_SDIN  => PI_CLK_I2S_DATA,
			L_data    => std_logic_vector(dac_l),
			R_data    => std_logic_vector(dac_r)
		);


	-- BEGIN VGA ATLAS -------------------  
	VGA_R  <= vga_red(7 downto 6);
	VGA_G  <= vga_green(7 downto 6);
	VGA_B  <= vga_blue(7 downto 6);
	VGA_HS <= vga_hsync;
	VGA_VS <= vga_vsync;

	PINS_HDMI_VGA_1 : if ATLAS_CYC_VGA = 1 generate -- VGA
		TMDS(7) <= VGA_R(1);
		TMDS(6) <= VGA_R(0);
		TMDS(5) <= VGA_G(1);
		TMDS(4) <= VGA_G(0);
		TMDS(3) <= VGA_B(1);
		TMDS(2) <= VGA_B(0);
		TMDS(1) <= VGA_VS;
		TMDS(0) <= VGA_HS;
	end generate PINS_HDMI_VGA_1;
	-- END VGA ATLAS -------------------  


	-- PLL 50 MHz / 48 USB / VIDEO
	pll_50_48 : pll2
	port map (
		inclk0		=> CLK12M,				--      
		c0			=> CLK50M,				-- 50 MHz
		c1			=> CLK48M,				-- 48 MHz
		c2			=> clock_dvi_s,			-- x5	    
--		c3			=> clock_vga_s,			-- x 	   
		locked		=> locked
	);


	-- BEGIN HDMI ATLAS -------------------   
	PINS_HDMI_VGA_2 : if ATLAS_CYC_VGA = 0 generate -- HDMI TDMS

		clock_vga_s <= vga_clk;
		--clock_dvi_s <= hdmi_clk;

		-- HDMI AUDIO
		sound_hdmi_l_s <= dac_l;
		sound_hdmi_r_s <= dac_r;
		-- sound_hdmi_l_s <= std_logic_vector(dac_l);
		-- sound_hdmi_r_s <= std_logic_vector(dac_r);

		------------------------------------------------------------------------------------------------------
		-- JUST LEAVE ONE HDMI WRAPPER (1/2/3) UNCOMMENTED                                                  --
		-- SELECT PROJECT FILES FOR HDMI WRAPPER (1/2/3) AT DeMiSTify/Board/atlas_cyc/atlas_cyc_support.tcl --
		------------------------------------------------------------------------------------------------------



		---- BEGIN HDMI 1 NO SOUND (MULTICPM / Next186) 

		TMDS(6) <= '0';
		TMDS(4) <= '0';
		TMDS(2) <= '0';
		TMDS(0) <= '0';

		inst_hdmi : entity work.hdmi
			port map(
				-- clocks
				CLK_PIXEL_I => clock_vga_s,
				CLK_DVI_I   => clock_dvi_s,
				--components
				R_I        => vga_x_r & vga_x_r(4 downto 3),
				G_I        => vga_x_g & vga_x_g(4 downto 3),
				B_I        => vga_x_b & vga_x_b(4 downto 3),
				BLANK_I    => not vga_de,
				HSYNC_I    => vga_x_hs,
				VSYNC_I    => vga_x_vs,
				TMDS_D0_O  => TMDS(3),
				TMDS_D1_O  => TMDS(5),
				TMDS_D2_O  => TMDS(7),
				TMDS_CLK_O => TMDS(1)
			);

		---- END HDMI 1 


		----  BEGIN HDMI 2 (MSX)  

		-- hdmi: entity work.hdmi
		-- generic map (
		-- 	FREQ	=> 35480000,	-- pixel clock frequency 
		-- 	CTS		=> 35480,		-- CTS = Freq(pixclk) * N / (128 * Fs)
		-- 	-- FREQ	=> 28630000,	-- pixel clock frequency 
		-- 	-- CTS	=> 28630,		-- CTS = Freq(pixclk) * N / (128 * Fs)
		-- 	FS		=> 48000,		-- audio sample rate - should be 32000, 41000 or 48000 = 48KHz
		-- 	N		=> 6144			-- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300 (Check HDMI spec 7.2 for details)
		-- ) 
		-- port map (
		-- 	I_CLK_PIXEL		=> clock_vga_s,
		-- 	I_R				=> vga_x_r & vga_x_r(4 downto 3),
		-- 	I_G				=> vga_x_g & vga_x_g(4 downto 3),
		-- 	I_B				=> vga_x_b & vga_x_b(4 downto 3),
		-- 	I_BLANK			=> vga_blank,
		-- 	I_HSYNC			=> vga_x_hs,
		-- 	I_VSYNC			=> vga_x_vs,
		-- 	-- PCM audio
		-- 	I_AUDIO_ENABLE	=> '1',
		-- 	I_AUDIO_PCM_L 	=> sound_hdmi_l_s,
		-- 	I_AUDIO_PCM_R	=> sound_hdmi_r_s,
		-- 	-- TMDS parallel pixel synchronous outputs (serialize LSB first)
		-- 	O_RED			=> tdms_r_s,
		-- 	O_GREEN			=> tdms_g_s,
		-- 	O_BLUE			=> tdms_b_s
		-- );

		-- hdmio: entity work.hdmi_out_altera
		-- port map (
		-- 	clock_pixel_i		=> clock_vga_s,
		-- 	clock_tdms_i		=> clock_dvi_s,
		-- 	red_i				=> tdms_r_s,
		-- 	green_i				=> tdms_g_s,
		-- 	blue_i				=> tdms_b_s,
		-- 	tmds_out_p			=> tdms_p_s,
		-- 	tmds_out_n			=> tdms_n_s
		-- );

		-- TMDS(7)	<= tdms_p_s(2);	-- 2+		
		-- TMDS(6)	<= tdms_n_s(2);	-- 2-		
		-- TMDS(5)	<= tdms_p_s(1);	-- 1+			
		-- TMDS(4)	<= tdms_n_s(1);	-- 1-		
		-- TMDS(3)	<= tdms_p_s(0);	-- 0+		
		-- TMDS(2)	<= tdms_n_s(0);	-- 0-	
		-- TMDS(1)	<= tdms_p_s(3);	-- CLK+	
		-- TMDS(0)	<= tdms_n_s(3);	-- CLK-

		---- END HDMI 2 


		---- BEGIN HDMI 3 (ATARI)    ok PAL, AUDIO 32k, 41k, 48k IS NOT GOOD, NTSC NOT TESTED

		-- inst_dvid: entity work.hdmi
		-- generic map (
		-- 	FREQ	=> 35480000,	-- pixel clock frequency 
		-- 	CTS		=> 35480,		-- CTS = Freq(pixclk) * N / (128 * Fs)
		-- 	FS		=> 41000,		-- audio sample rate - should be 32000, 41000 or 48000 = 48KHz
		-- 	N		=> 6144			-- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300 (Check HDMI spec 7.2 for details)
		-- ) 
		-- port map(
		-- 	I_CLK_VGA	=> clock_vga_s,
		-- 	I_CLK_TMDS	=> clock_dvi_s,
		-- 	I_HSYNC		=> vga_x_hs,
		-- 	I_VSYNC		=> vga_x_vs,
		-- 	I_BLANK		=> vga_blank,
		-- 	I_RED		=> vga_x_r & vga_x_r(4 downto 3),
		-- 	I_GREEN		=> vga_x_g & vga_x_g(4 downto 3),
		-- 	I_BLUE		=> vga_x_b & vga_x_b(4 downto 3),
		-- 	I_AUDIO_PCM_L 	=> sound_hdmi_l_s,
		-- 	I_AUDIO_PCM_R	=> sound_hdmi_r_s,
		-- 	O_TMDS			=> TMDS
		-- );

		---- END HDMI 3 


		---- END HDMI PAL ATLAS 

	end generate PINS_HDMI_VGA_2;
	
	-- END HDMI ATLAS -------------------


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
			DAC_L   => dac_l,
			DAC_R   => dac_r,
			AUDIO_L => sigma_l,
			AUDIO_R => sigma_r,

			OSD_EN	=> osd_en

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
			clk       => CLK50M,	
			reset_in  => KEY0,			--reset_in  when 0
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

	LED <= (0 => not act_led, others => '0');

end rtl;
