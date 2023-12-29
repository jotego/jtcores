-------------------------------------------------------------------[01.11.2014]
-- Encoder
-------------------------------------------------------------------------------
-- Engineer: MVV <mvvproject@gmail.com>

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity encoder is
port (
	CLK     	: in STD_LOGIC;
	DATA    	: in STD_LOGIC_VECTOR (7 downto 0);
	C       	: in STD_LOGIC_VECTOR (1 downto 0);
	VDE	   	: in STD_LOGIC;	-- Video Data Enable (VDE)
	ADE	   	: in STD_LOGIC;	-- Audio/auxiliary Data Enable (ADE)
	AUX		: in STD_LOGIC_VECTOR (3 downto 0);
	ENCODED 	: out STD_LOGIC_VECTOR (9 downto 0));
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
	xored(0) <= DATA(0);
	xored(1) <= DATA(1) xor xored(0);
	xored(2) <= DATA(2) xor xored(1);
	xored(3) <= DATA(3) xor xored(2);
	xored(4) <= DATA(4) xor xored(3);
	xored(5) <= DATA(5) xor xored(4);
	xored(6) <= DATA(6) xor xored(5);
	xored(7) <= DATA(7) xor xored(6);
	xored(8) <= '1';

	xnored(0) <= DATA(0);
	xnored(1) <= DATA(1) xnor xnored(0);
	xnored(2) <= DATA(2) xnor xnored(1);
	xnored(3) <= DATA(3) xnor xnored(2);
	xnored(4) <= DATA(4) xnor xnored(3);
	xnored(5) <= DATA(5) xnor xnored(4);
	xnored(6) <= DATA(6) xnor xnored(5);
	xnored(7) <= DATA(7) xnor xnored(6);
	xnored(8) <= '0';

	-- Count how many ones are set in data
	ones <= "0000" + DATA(0) + DATA(1) + DATA(2) + DATA(3) + DATA(4) + DATA(5) + DATA(6) + DATA(7);
 
	-- Decide which encoding to use
		process (ones, DATA(0), xnored, xored)
		begin
			if ones > 4 or (ones = 4 and DATA(0) = '0') then
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
	process(CLK)
	begin
		if (CLK'event and CLK = '1') then
			-- Video Data Coding
			if VDE = '1' then 
				if dc_bias = "00000" or data_word_disparity = 0 then
					-- dataword has no disparity
					if data_word(8) = '1' then
						ENCODED <= "01" & data_word(7 downto 0);
						dc_bias <= dc_bias + data_word_disparity;
					else
						ENCODED <= "10" & data_word_inv(7 downto 0);
						dc_bias <= dc_bias - data_word_disparity;
					end if;
				elsif (dc_bias(3) = '0' and data_word_disparity(3) = '0') or 
					(dc_bias(3) = '1' and data_word_disparity(3) = '1') then
					ENCODED <= '1' & data_word(8) & data_word_inv(7 downto 0);
					dc_bias <= dc_bias + data_word(8) - data_word_disparity;
				else
					ENCODED <= '0' & data_word;
					dc_bias <= dc_bias - data_word_inv(8) + data_word_disparity;
				end if;
			-- TERC4 Coding
			elsif ADE = '1' then
				case AUX is
					when "0000" => ENCODED <= "1010011100";
					when "0001" => ENCODED <= "1001100011";
					when "0010" => ENCODED <= "1011100100";
					when "0011" => ENCODED <= "1011100010";
					when "0100" => ENCODED <= "0101110001";
					when "0101" => ENCODED <= "0100011110";
					when "0110" => ENCODED <= "0110001110";
					when "0111" => ENCODED <= "0100111100";
					when "1000" => ENCODED <= "1011001100";
					when "1001" => ENCODED <= "0100111001";
					when "1010" => ENCODED <= "0110011100";
					when "1011" => ENCODED <= "1011000110";
					when "1100" => ENCODED <= "1010001110";
					when "1101" => ENCODED <= "1001110001";
					when "1110" => ENCODED <= "0101100011";
					when others => ENCODED <= "1011000011";
				end case;
			else
				-- In the control periods, all values have and have balanced bit count
				case C is            
					when "00"   => ENCODED <= "1101010100";
					when "01"   => ENCODED <= "0010101011";
					when "10"   => ENCODED <= "0101010100";
					when others => ENCODED <= "1010101011";
				end case;
				dc_bias <= (others => '0');
			end if;
		end if;
	end process;      
 
end rtl;
