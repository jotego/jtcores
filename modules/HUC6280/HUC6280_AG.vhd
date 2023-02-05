library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

entity HUC6280_AG is
    port( 
        CLK 			: in std_logic;
		  RST_N 			: in std_logic;
		  CE 				: in std_logic;
		  PC_CTRL		: in std_logic_vector(2 downto 0); 
        ADDR_CTRL		: in std_logic_vector(5 downto 0); 
		  GOT_INT		: in std_logic;  
        DI   			: in std_logic_vector(7 downto 0);
		  X   			: in std_logic_vector(7 downto 0);
		  Y   			: in std_logic_vector(7 downto 0);
		  DR   			: in std_logic_vector(7 downto 0);

		  PC				: out std_logic_vector(15 downto 0);
        AA     		: out std_logic_vector(15 downto 0)
    );
end HUC6280_AG;

architecture rtl of HUC6280_AG is

	signal AAL, AAH : std_logic_vector(7 downto 0);
	signal SavedCarry : std_logic;
	
	signal NewAAL : std_logic_vector(8 downto 0);
	signal NewAAH : std_logic_vector(7 downto 0);
	
	signal PCr: std_logic_vector(15 downto 0);
	signal NextPC, NewPCWithOffset: std_logic_vector(15 downto 0);

begin

	NewPCWithOffset <= std_logic_vector(unsigned(PCr) + unsigned((7 downto 0 => AAL(7)) & AAL)); 
	
	process(CLK, RST_N, PC_CTRL, PCr, DI, DR, GOT_INT, NewPCWithOffset, AAH, AAL )
	begin
		case PC_CTRL is
			when "000" => 
				NextPC <= PCr;
			when "001" => 
				if GOT_INT = '0' then
					NextPC <= std_logic_vector(unsigned(PCr) + 1); 
				else
					NextPC <= PCr;
				end if;
			when "010"=> 
				NextPC <= PCr(15 downto 8) & DI;
			when "011" => 
				NextPC <= DI & PCr(7 downto 0); 
			when "100" => 
				NextPC <= NewPCWithOffset; 
			when "110" => 
				NextPC <= AAH & AAL; 
			when others => 
				NextPC <= PCr;
		end case;
		
		if RST_N = '0' then
			PCr <= (others=>'0');
		elsif rising_edge(CLK) then
			if CE = '1' then
				PCr <= NextPC;
			end if;
		end if;
	end process;
	
	process(ADDR_CTRL, AAL, AAH, X, Y, DI, DR, SavedCarry)
	begin
		case ADDR_CTRL(5 downto 3) is
			when "000"=> 
				NewAAL <= "0" & AAL;
			when "001"=> 
				NewAAL <= "0" & DI;
			when "010" => 
				NewAAL <= std_logic_vector(unsigned("0" & AAL) + 1);
			when "011" => 
				NewAAL <= std_logic_vector(unsigned("0" & AAL) + unsigned("0" & X));
			when "100" => 
				NewAAL <= std_logic_vector(unsigned("0" & AAL) + unsigned("0" & Y));
			when "101" => 
				NewAAL <= "0" & DR;
			when "110" => 
				NewAAL <= std_logic_vector(unsigned("0" & DR) + unsigned("0" & Y));
			when others =>
				NewAAL <= "0" & X;
		end case;
		
		case ADDR_CTRL(2 downto 0) is
			when "000"=> 
				NewAAH <= AAH;
			when "001"=> 
				NewAAH <= DI;
			when "010" => 
				NewAAH <= std_logic_vector(unsigned(AAH) + 1);
			when "011" => 
				NewAAH <= std_logic_vector(unsigned(AAH) + ("0000000"&SavedCarry));
			when others =>
				NewAAH <= AAH;
		end case;
	end process;

	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			AAL <= (others=>'0');
			AAH <= (others=>'0');
			SavedCarry <= '0';
		elsif rising_edge(CLK) then
			if CE = '1' then
				AAL <= NewAAL(7 downto 0); 
				SavedCarry <= NewAAL(8); 
				AAH <= NewAAH(7 downto 0); 
			end if;
		end if;
	end process;

	AA <= AAH & AAL; 
	PC <= PCr;
	
end rtl;