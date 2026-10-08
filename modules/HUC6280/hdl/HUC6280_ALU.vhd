library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.HUC6280_PKG.all;

entity ALU is
	port( 
		CLK 	: in std_logic;
		EN 	: in std_logic;
		L   	: in std_logic_vector(7 downto 0); 
		R		: in std_logic_vector(7 downto 0); 
		CTRL	: in ALUCtrl_r;
		BCD	: in std_logic; 
		CI		: in std_logic; 
		VI		: in std_logic; 
		NI		: in std_logic; 
		CO		: out std_logic; 
		VO		: out std_logic; 
		NO		: out std_logic; 
		ZO		: out std_logic; 
		RES	: out std_logic_vector(7 downto 0)
	);
end ALU;

architecture rtl of ALU is

	signal IntL 	: std_logic_vector(7 downto 0);
	signal IntR 	: std_logic_vector(7 downto 0);
	signal CR 		: std_logic;
	signal ADDIn	: std_logic;
	signal BCDIn	: std_logic;
	signal CIIn		: std_logic;
	signal SavedC 	: std_logic;
	
	signal AddS 	: std_logic_vector(7 downto 0);
	signal AddCO 	: std_logic; 
	signal AddVO 	: std_logic; 
	signal Result 	: std_logic_vector(7 downto 0);

begin
	
	process(CTRL, CI, L, R, BCD, SavedC)
	begin
		CR <= CI; 
		BCDIn <= '0';
		case CTRL.fstOp is
			when "000" => 
				CR <= L(7);
				IntL <= L(6 downto 0) & "0";
				IntR <= x"00";
			when "001"=> 
				CR <= L(7);
				IntL <= L(6 downto 0) & CI;
				IntR <= x"00";
			when "010" => 
				CR <= L(0);
				IntL <= "0" & L(7 downto 1);
				IntR <= x"00";
			when "011" => 
				CR <= L(0);
				IntL <= CI & L(7 downto 1);
				IntR <= x"00";
			when "100" => 
				IntL <= L;
				IntR <= R;
				BCDIn <= BCD and CTRL.secOp(1) and CTRL.secOp(0);
			when "101" => 
				IntL <= L;
				IntR <= R;
			when "110" => 	-- INC/DEC LSB
				IntL <= L;
				IntR <= x"01";
				CR <= CTRL.secOp(2);
			when "111" => 	-- INC/DEC MSB
				IntL <= L;
				IntR <= x"00";
				CR <= SavedC;
			when others => null;
		end case;
	end process;
		
	CIIn <= CR or not CTRL.secOp(0);
	ADDIn <= not CTRL.secOp(2);
		
	AddSub: entity work.AddSubBCD
	port map (
		A     	=> IntL,
		B     	=> IntR, 
		CI     	=> CIIn, 
		ADD     	=> ADDIn, 
		BCD     	=> BCDIn,
		S     	=> AddS, 
		CO     	=> AddCO,
		VO     	=> AddVO
	);
	
	process(CLK)
	begin
		if rising_edge(CLK) then
			if EN = '1' then
				SavedC <= AddCO;
			end if;
		end if;
	end process;
	
	process(CTRL, CR, IntL, IntR, AddCO, AddS)
	begin
		case CTRL.secOp is
			when "000" => 
				CO <= CR;
				Result <= IntL or IntR;
			when "001"=> 
				CO <= CR;
				Result <= IntL and IntR;
			when "010" => 
				CO <= CR;
				Result <= IntL xor IntR;
			when "011" | "110" | "111" => 
				CO <= AddCO;
				Result <= AddS;
			when "100" => 
				CO <= CR;
				Result <= IntL;
			when "101" => 			--TRB,TSB
				CO <= CR;
				if CTRL.fc = '0' then
					Result <= IntR and (not IntL);
				else
					Result <= IntR or IntL;
				end if;
			when others => null;
		end case;
	end process;
	
	process(CTRL, VI, NI, IntR, Result, AddVO, BCDIn)
	begin
		VO <= VI; 
		NO <= Result(7); 
		case CTRL.secOp is
			when "001" => 					--AND
				if CTRL.fc = '1' then	--BIT
					VO <= IntR(6);
					NO <= IntR(7);
				end if;
			when "011" => 					-- ADC
				if BCDIn = '0' then
					VO <= AddVO;					
				end if;
			when "101" => 					--TRB,TSB
				VO <= IntR(6);
				NO <= IntR(7); 
			when "111" =>            	-- SBC
				if BCDIn = '0' then
					VO <= AddVO;
				end if;
			when others => null;
		end case;
	end process;
	
	
	ZO <= '1' when Result = x"00" else '0'; 
	
	RES <= Result;
	
end rtl;