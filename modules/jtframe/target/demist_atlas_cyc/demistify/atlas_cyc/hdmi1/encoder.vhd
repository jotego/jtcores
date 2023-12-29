-- Adapted By MVV

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity encoder is
port (
	CLK_I		: in  STD_LOGIC;
	DATA_I		: in  STD_LOGIC_VECTOR (7 downto 0);
	C_I		: in  STD_LOGIC_VECTOR (1 downto 0);
	BLANK_I   	: in  STD_LOGIC;
	ENCODED_O 	: out  STD_LOGIC_VECTOR (9 downto 0));
end encoder;

architecture rtl of encoder is
	signal xored  			: STD_LOGIC_VECTOR (8 downto 0);
	signal xnored 			: STD_LOGIC_VECTOR (8 downto 0);
	signal ones			: STD_LOGIC_VECTOR (3 downto 0);
	signal data_word		: STD_LOGIC_VECTOR (8 downto 0);
	signal data_word_inv		: STD_LOGIC_VECTOR (8 downto 0);
	signal data_word_disparity	: STD_LOGIC_VECTOR (3 downto 0);
	signal dc_bias			: STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
	
begin
   -- Work our the two different encodings for the byte
   xored(0) <= DATA_I(0);
   xored(1) <= DATA_I(1) xor xored(0);
   xored(2) <= DATA_I(2) xor xored(1);
   xored(3) <= DATA_I(3) xor xored(2);
   xored(4) <= DATA_I(4) xor xored(3);
   xored(5) <= DATA_I(5) xor xored(4);
   xored(6) <= DATA_I(6) xor xored(5);
   xored(7) <= DATA_I(7) xor xored(6);
   xored(8) <= '1';

   xnored(0) <= DATA_I(0);
   xnored(1) <= DATA_I(1) xnor xnored(0);
   xnored(2) <= DATA_I(2) xnor xnored(1);
   xnored(3) <= DATA_I(3) xnor xnored(2);
   xnored(4) <= DATA_I(4) xnor xnored(3);
   xnored(5) <= DATA_I(5) xnor xnored(4);
   xnored(6) <= DATA_I(6) xnor xnored(5);
   xnored(7) <= DATA_I(7) xnor xnored(6);
   xnored(8) <= '0';
   
   -- Count how many ones are set in DATA_I
   ones <= "0000" + DATA_I(0) + DATA_I(1) + DATA_I(2) + DATA_I(3) + DATA_I(4) + DATA_I(5) + DATA_I(6) + DATA_I(7);
 
   -- Decide which encoding to use
	process (ones, DATA_I(0), xnored, xored)
	begin
		if ones > 4 or (ones = 4 and DATA_I(0) = '0') then
			data_word     <= xnored;
			data_word_inv <= NOT(xnored);
		else
			data_word     <= xored;
			data_word_inv <= NOT(xored);
		end if;
	end process;                                          

	-- Work out the DC bias of the dataword;
	data_word_disparity  <= "1100" + data_word(0) + data_word(1) + data_word(2) + data_word(3) + data_word(4) + data_word(5) + data_word(6) + data_word(7);

	-- Now work out what the output should be
	process(CLK_I)
	begin
		if (CLK_I'event and CLK_I = '1') then
			if BLANK_I = '1' then 
				-- In the control periods, all values have and have balanced bit count
				case C_I is            
					when "00"   => ENCODED_O <= "1101010100";
					when "01"   => ENCODED_O <= "0010101011";
					when "10"   => ENCODED_O <= "0101010100";
					when others => ENCODED_O <= "1010101011";
				end case;
				dc_bias <= (others => '0');
			else
				if dc_bias = "00000" or data_word_disparity = 0 then
					-- dataword has no disparity
					if data_word(8) = '1' then
						ENCODED_O <= "01" & data_word(7 downto 0);
						dc_bias <= dc_bias + data_word_disparity;
					else
						ENCODED_O <= "10" & data_word_inv(7 downto 0);
						dc_bias <= dc_bias - data_word_disparity;
					end if;
				elsif (dc_bias(3) = '0' and data_word_disparity(3) = '0') or 
					(dc_bias(3) = '1' and data_word_disparity(3) = '1') then
					ENCODED_O <= '1' & data_word(8) & data_word_inv(7 downto 0);
					dc_bias <= dc_bias + data_word(8) - data_word_disparity;
				else
					ENCODED_O <= '0' & data_word;
					dc_bias <= dc_bias - data_word_inv(8) + data_word_disparity;
				end if;
			end if;
		end if;
	end process;      
   
end rtl;