---------------------------------------------------------------------------
-- (c) 2016 Alexey Spirkov
-- I am happy for anyone to use this for non-commercial use.
-- If my verilog/vhdl/c files are used commercially or otherwise sold,
-- please contact me for explicit permission at me _at_ alsp.net.
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
-- Recommended params:
-- N=0x1800 CTS=0x6FD1 (28.625MHz pixel clock -> 48KHz audio clock)
-- N=0x1000 CTS=0x6FD1 (28.625MHz pixel clock -> 32KHz audio clock)
-- N=0x1000 CTS=0x6978 (27MHz pixel clock -> 32KHz audio clock)
-- N=0x1800 CTS=0x6978 (27MHz pixel clock -> 48KHz audio clock)
---------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity hdmi is
	generic (
		FREQ: integer := 27000000;              -- pixel clock frequency
		FS: integer := 48000;                   -- audio sample rate - should be 32000, 44100 or 48000
		CTS: integer := 27000;                  -- CTS = Freq(pixclk) * N / (128 * Fs)
		N: integer := 6144                      -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
						        -- Check HDMI spec 7.2 for details
	);
	port (
		-- clocks
		I_CLK_PIXEL		: in std_logic;
		-- components
		I_R				: in std_logic_vector(7 downto 0);
		I_G				: in std_logic_vector(7 downto 0);
		I_B				: in std_logic_vector(7 downto 0);	
		I_BLANK			: in std_logic;
		I_HSYNC			: in std_logic;
		I_VSYNC			: in std_logic;
		-- PCM audio
		I_AUDIO_ENABLE  : in std_logic;
		I_AUDIO_PCM_L 	: in std_logic_vector(15 downto 0);
		I_AUDIO_PCM_R	: in std_logic_vector(15 downto 0);
		-- TMDS parallel pixel synchronous outputs (serialize LSB first)
		O_RED			: out std_logic_vector(9 downto 0); -- Red
		O_GREEN			: out std_logic_vector(9 downto 0); -- Green
		O_BLUE			: out std_logic_vector(9 downto 0)  -- Blue
);
end entity;

architecture rtl of hdmi is

component hdmidataencoder
generic
(
	FREQ: integer := FREQ;
	FS: integer := FS;
	CTS: integer := CTS;
	N: integer := N
);
port (
	i_pixclk	: in std_logic;
	i_hSync		: in std_logic;
	i_vSync		: in std_logic;
	i_blank		: in std_logic;
	i_audio_enable  : in std_logic;
	i_audioL		: in std_logic_vector(15 downto 0);
	i_audioR		: in std_logic_vector(15 downto 0);
	
	o_d0		: out std_logic_vector(3 downto 0);
	o_d1		: out std_logic_vector(3 downto 0);
	o_d2		: out std_logic_vector(3 downto 0);
	o_data	: out std_logic
);
end component;


	signal red	: std_logic_vector(9 downto 0);
	signal green	: std_logic_vector(9 downto 0);
	signal blue	: std_logic_vector(9 downto 0);		

	signal enc0out	: std_logic_vector(9 downto 0);
	signal enc1out	: std_logic_vector(9 downto 0);
	signal enc2out	: std_logic_vector(9 downto 0);		
	
	
	signal tx_in	: std_logic_vector(29 downto 0);
	signal tmds_d	: std_logic_vector(3 downto 0);

	signal data     : std_logic;
	signal dataPacket0		: std_logic_vector(3 downto 0);	
	signal dataPacket1		: std_logic_vector(3 downto 0);	
	signal dataPacket2		: std_logic_vector(3 downto 0);	

	signal delayLineIn: std_logic_vector(39 downto 0);
	signal delayLineOut: std_logic_vector(39 downto 0);
	
	signal ROut: std_logic_vector(7 downto 0);
	signal GOut: std_logic_vector(7 downto 0);
	signal BOut: std_logic_vector(7 downto 0);
	
	signal hSyncOut: std_logic;
	signal vSyncOut: std_logic;
	signal vdeOut: std_logic;
	signal dataOut: std_logic;
	signal vhSyncOut: std_logic_vector(1 downto 0);
	
	signal prevBlank: std_logic;
	signal prevData: std_logic;

	signal dataPacket0Out		: std_logic_vector(3 downto 0);	
	signal dataPacket1Out		: std_logic_vector(3 downto 0);	
	signal dataPacket2Out		: std_logic_vector(3 downto 0);	
	
	signal ctl0: std_logic;
	signal ctl1: std_logic;
	signal ctl2: std_logic;
	signal ctl3: std_logic;
	
	signal ctl_10: std_logic_vector(1 downto 0);
	signal ctl_32: std_logic_vector(1 downto 0);
	
	-- states
	type count_state is (
			videoData, 
			videoDataPreamble,
			videoDataGuardBand,
			dataIslandPreamble,
			dataIslandPreGuard,
			dataIslandPostGuard,
			dataIsland,
			controlData
	);
	
	signal state: count_state; 

	signal clockCounter: integer range 0 to 2047;
	
	
begin

-- data should be delayed for 11 clocks to allow preamble and guard band generation

-- delay line inputs
delayLineIn(39 downto 32) <= I_R;
delayLineIn(31 downto 24) <= I_G;
delayLineIn(23 downto 16) <= I_B;
delayLineIn(15) <= I_HSYNC;
delayLineIn(14) <= I_VSYNC;
delayLineIn(13) <= not I_BLANK;
delayLineIn(12) <= data;
delayLineIn(11 downto 8) <= dataPacket0;
delayLineIn(7 downto 4) <= dataPacket1;
delayLineIn(3 downto 0) <= dataPacket2;

-- delay line outputs
ROut <= delayLineOut(39 downto 32);
GOut <= delayLineOut(31 downto 24);
BOut <= delayLineOut(23 downto 16);
hSyncOut <= delayLineOut(15);
vSyncOut <= delayLineOut(14);
vdeOut <= delayLineOut(13);
dataOut <= delayLineOut(12);
dataPacket0Out <= delayLineOut(11 downto 8);
dataPacket1Out <= delayLineOut(7 downto 4);
dataPacket2Out <= delayLineOut(3 downto 0);

vhSyncOut <= vSyncOut & hSyncOut;

ctl_10 <= ctl1&ctl0;
ctl_32 <= ctl3&ctl2;

FSA: process(I_CLK_PIXEL) is 
begin 
	if(rising_edge(I_CLK_PIXEL)) then
		if(prevBlank = '0' and i_BLANK = '1') then
			state <= controlData;
			clockCounter <= 0;
		else
			case state is
				when controlData => 
					if prevData = '0' and data = '1' then 		 -- ok - data stared - needs data preamble
						state <= dataIslandPreamble;
						ctl0 <= '1';
						ctl1 <= '0';
						ctl2 <= '1';
						ctl3 <= '0';
						clockCounter <= 0;
					elsif prevBlank = '1' and I_BLANK = '0' then -- ok blank os out - start generation video preamble
						state <= videoDataPreamble;
						ctl0 <= '1';
						ctl1 <= '0';
						ctl2 <= '0';
						ctl3 <= '0';
						clockCounter <= 0;
					end if;
				when dataIslandPreamble =>							 -- data island preable needed for 8 clocks
					if clockCounter = 8  then
						state <= dataIslandPreGuard;					
						ctl0 <= '0';
						ctl1 <= '0';
						ctl2 <= '0';
						ctl3 <= '0';
						clockCounter <= 0;
					else
						clockCounter <= clockCounter + 1;
					end if;
				when dataIslandPreGuard => 						 -- data island preguard needed for 2 clocks
					if clockCounter = 1 then
						state <= dataIsland;					
						clockCounter <= 0;
					else
						clockCounter <= clockCounter + 1;
					end if;
				when dataIsland => 
					if clockCounter = 11 then						 -- ok we at the end of data island - post guard is needed
						state <= dataIslandPostGuard;					
						clockCounter <= 0;					
					elsif prevBlank = '1' and I_BLANK = '0' then -- something fails - no data were detected but blank os out
						state <= videoDataPreamble;
						ctl0 <= '1';
						ctl1 <= '0';
						ctl2 <= '0';
						ctl3 <= '0';
						clockCounter <= 0;
					elsif data = '0' then								 -- start count and count only when data is over
						clockCounter <= clockCounter + 1;					
					end if;
					
				when dataIslandPostGuard => 						 -- data island postguard needed for 2 clocks
					if clockCounter = 1  then
						state <= controlData;					
						clockCounter <= 0;
					else
						clockCounter <= clockCounter + 1;
					end if;
				when videoDataPreamble => 							 -- video data preable needed for 8 clocks
					if clockCounter = 8  then
						state <= videoDataGuardBand;					
						ctl0 <= '0';
						ctl1 <= '0';
						ctl2 <= '0';
						ctl3 <= '0';
						clockCounter <= 0;
					else
						clockCounter <= clockCounter + 1;
					end if;
				when videoDataGuardBand =>						    -- video data guard needed for 2 clocks
					if clockCounter = 1  then
						state <= videoData;					
						clockCounter <= 0;
					else
						clockCounter <= clockCounter + 1;
					end if;
				when videoData => 					
					if clockCounter = 11  then						 -- ok we at the end of video data - just switch to control
						state <= controlData;					
						clockCounter <= 0;	
					elsif I_BLANK = '1' then								 -- start count and count only when video is over
						clockCounter <= clockCounter + 1;					
					end if;
			end case;
		end if;
		prevBlank <= I_BLANK;
		prevData <= data;
		
	end if;
end process; 


blueout: blue <= 
	"1010001110" when (state = dataIslandPreGuard or state = dataIslandPostGuard) and vhSyncOut = "00" else
	"1001110001" when (state = dataIslandPreGuard or state = dataIslandPostGuard) and vhSyncOut = "01" else
	"0101100011" when (state = dataIslandPreGuard or state = dataIslandPostGuard) and vhSyncOut = "10" else
	"1011000011" when (state = dataIslandPreGuard or state = dataIslandPostGuard) and vhSyncOut = "11" else
	"1011001100" when state = videoDataGuardBand else
	enc0out;

greenout: green <= 
	"0100110011" when state = videoDataGuardBand else
	"0100110011" when state = dataIslandPreGuard or state = dataIslandPostGuard else
	enc1out;

redout: red <= 
	"1011001100" when state = videoDataGuardBand else
	"0100110011" when state = dataIslandPreGuard or state = dataIslandPostGuard else
	enc2out;

delay_line: entity work.hdmi_delay_line
port map (
	i_clk => I_CLK_PIXEL,
	i_d => delayLineIn,
	o_q => delayLineOut
);

dataenc: hdmidataencoder
generic map (
	FREQ => FREQ,
	FS => FS,
	CTS => CTS,
	N => N
)
port map(
	i_pixclk		=> I_CLK_PIXEL,
	i_blank 		=> I_BLANK,
	i_hSync		=> I_HSYNC,
	i_vSync		=> I_VSYNC,
	i_audio_enable  => I_AUDIO_ENABLE,
	i_audioL		=>	I_AUDIO_PCM_L,
	i_audioR		=>	I_AUDIO_PCM_R,
	o_d0 			=> dataPacket0,
	o_d1 			=> dataPacket1,
	o_d2 			=> dataPacket2,
	o_data		=> data
);


enc0: entity work.encoder
port map (
	CLK	=> I_CLK_PIXEL,
	DATA	=> BOut,
	C	=> vhSyncOut,
	VDE	=> vdeOut,
	ADE	=> dataOut,
	AUX	=> dataPacket0Out,
	ENCODED	=> enc0out);

enc1: entity work.encoder
port map (
	CLK	=> I_CLK_PIXEL,
	DATA	=> GOut,
	C	=> ctl_10,
	VDE	=> vdeOut,
	ADE	=> dataOut,
	AUX	=> dataPacket1Out,
	ENCODED	=> enc1out);

enc2: entity work.encoder
port map (
	CLK	=> I_CLK_PIXEL,
	DATA	=> ROut,
	C	=> ctl_32,
	VDE	=> vdeOut,
	ADE	=> dataOut,
	AUX	=> dataPacket2Out,
	ENCODED	=> enc2out);
	
O_RED	<= red;
O_GREEN	<= green;
O_BLUE	<= blue;

end rtl;
