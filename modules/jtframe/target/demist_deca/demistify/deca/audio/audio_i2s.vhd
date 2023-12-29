----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    23:18:31 08/04/2019 
-- Design Name: 
-- Module Name:    dac_if - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac_if is
	Port ( 	
				SCLK : 		in STD_LOGIC; 					-- serial clock (1.56 MHz)
				L_start: 	in STD_LOGIC; 					-- strobe to load LEFT data
				R_start: 	in STD_LOGIC; 					-- strobe to load RIGHT data
				L_data : 	in SIGNED(15 downto 0);  	-- LEFT data (15-bit signed)
				R_data : 	in SIGNED(15 downto 0);  	-- RIGHT data (15-bit signed)
				SDATA : 		out STD_LOGIC); 				-- serial data stream to DAC
end dac_if;

architecture Behavioral of dac_if is

signal sreg: STD_LOGIC_VECTOR (15 downto 0); -- 16-bit shift register to do
															-- parallel to serial conversion
begin
	
	-- SREG is used to serially shift data out to DAC, MSBit first.
	-- Left data is loaded into SREG on falling edge of SCLK when L_start is active.
	-- Right data is loaded into SREG on falling edge of SCLK when R_start is active.
	-- At other times, falling edge of SCLK causes REG to logically shift one bit left
	-- Serial data to DAC is MSBit of SREG

	dac_proc: process
	begin
			wait until falling_edge(SCLK);
			if 	L_start = '1' then
						sreg <= std_logic_vector(L_data); 	-- load LEFT data into SREG
			elsif	R_start = '1' then
						sreg <= std_logic_vector(R_data); 	-- load RIGHT data into SREG
			else 	sreg <= sreg(14 downto 0) & '0'; 		-- logically shift SREG one bit left
			end if;
end process;

	SDATA <= sreg(15); 	-- serial data to DAC is MSBit of SREG

end Behavioral;


----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    00:11:41 08/05/2019 
-- Design Name: 
-- Module Name:    siren - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity audio_top is
	Port ( 	
				clk_50MHz : in STD_LOGIC; -- system clock (50 MHz)
				dac_MCLK : out STD_LOGIC; -- outputs to PMODI2L DAC
				dac_LRCK : out STD_LOGIC;
				dac_SCLK : out STD_LOGIC;
				dac_SDIN : out STD_LOGIC;
				L_data : 	in std_logic_vector(15 downto 0);  	-- LEFT data (15-bit signed)
				R_data : 	in std_logic_vector(15 downto 0)  	-- RIGHT data (15-bit signed) 
	);
end audio_top;

architecture Behavioral of audio_top is

--constant lo_tone: UNSIGNED (13 downto 0) := to_unsigned (344, 14); 	-- lower limit of siren = 256 Hz
--constant hi_tone: UNSIGNED (13 downto 0) := to_unsigned (687, 14); 	-- upper limit of siren = 512 Hz
--constant wail_speed: UNSIGNED (7 downto 0) := to_unsigned (8, 8); 	-- sets wailing speed

component dac_if is
	Port ( 	
				SCLK : in STD_LOGIC;
				L_start: in STD_LOGIC;
				R_start: in STD_LOGIC;
				L_data : in SIGNED(15 downto 0); 
				R_data : in SIGNED(15 downto 0); 
				SDATA : out STD_LOGIC
	);
end component;


signal tcount: UNSIGNED (19 downto 0) := (others=>'0'); 	-- timing counter
--signal data_L, data_R: SIGNED (15 downto 0); 				-- 16-bit signed audio data
signal dac_load_L, dac_load_R: STD_LOGIC; 					-- timing pulses to load DAC shift reg.
signal slo_clk, sclk, audio_CLK: STD_LOGIC;

begin
		
		-- this process sets up a 20 bit binary counter clocked at 50MHz. This is used
		-- to generate all necessary timing signals. dac_load_L and dac_load_R are pulses
		-- sent to dac_if to load parallel data into shift register for serial clocking
		-- out to DAC

tim_pr: 	process
			begin
					wait until rising_edge(clk_50MHz);
					if (tcount(9 downto 0) >= X"00F") and (tcount(9 downto 0) < X"02E") then
						dac_load_L <= '1'; else dac_load_L <= '0';
					end if;
					if (tcount(9 downto 0) >= X"20F") and (tcount(9 downto 0) < X"22E") then
						dac_load_R <= '1'; else dac_load_R <= '0';
					end if;
					tcount <= tcount+1;
end process;

dac_MCLK <= not tcount(1);	-- DAC master clock (12.5 MHz)
--dac_MCLK <= clk_50MHz;
audio_CLK <= tcount(9); 	-- audio sampling rate (48.8 kHz)
dac_LRCK <= audio_CLK; 		-- also sent to DAC as left/right clock
sclk <= tcount(4); 			-- serial data clock (1.56 MHz)
dac_SCLK <= sclk; 			-- also sent to DAC as SCLK
--slo_clk <= tcount(19); 		-- clock to control wailing of tone (47.6 Hz)

dac: dac_if port map ( 		-- instantiate parallel to serial DAC interface	
			SCLK => sclk, 		
			L_start => dac_load_L,
			R_start => dac_load_R,
			L_data => SIGNED(L_data),
			R_data => SIGNED(R_data),
			SDATA => dac_SDIN
);



end Behavioral;