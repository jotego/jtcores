library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.HUC6280_PKG.all;

entity HUC6280 is
	port( 
		CLK		: in std_logic;
		RST_N		: in std_logic;
		WAIT_N	: in std_logic;
		SX      : out std_logic;
		  
		A			: out std_logic_vector(20 downto 0);
		DI			: in std_logic_vector(7 downto 0);
		DO			: out std_logic_vector(7 downto 0);
		WR_N  	: out std_logic;
		RD_N  	: out std_logic;
		RDY		: in std_logic;
		NMI_N		: in std_logic;  
		IRQ1_N	: in std_logic;
		IRQ2_N	: in std_logic;
		
		CE			: out std_logic;
		CEK_N		: out std_logic;
		CE7_N		: out std_logic;
		CER_N		: out std_logic;
		PRE_RD	: out std_logic; -- for MiSTer sdram/ddram read
		PRE_WR	: out std_logic;
		
		HSM		: out std_logic;
		
		O			: out std_logic_vector(7 downto 0);
		K			: in std_logic_vector(7 downto 0);
		
		VDCNUM	: in std_logic;
		
		AUD_LDATA: out std_logic_vector(23 downto 0);
		AUD_RDATA: out std_logic_vector(23 downto 0)
	);
end HUC6280;

architecture rtl of HUC6280 is

	signal CPU_CE 			: std_logic;
	signal CPU_CER 		: std_logic;
	signal IO_CE 			: std_logic;
	signal EN 				: std_logic;
	
	signal CPU_DI 			: std_logic_vector(7 downto 0);
	signal CPU_DO 			: std_logic_vector(7 downto 0);
	signal CPU_A 			: std_logic_vector(20 downto 0);
	signal CPU_WE_N 		: std_logic;
	signal CPU_CS 			: std_logic;
	signal CPU_MCYCLE		: std_logic;
	signal CPU_IRQ1_N 	: std_logic;
	signal CPU_IRQ2_N 	: std_logic;
	signal CPU_IRQT_N 	: std_logic;
	signal CPU_RDY 		: std_logic;
	
	signal CPU_CLK_CNT 	: unsigned(4 downto 0);
	signal IO_CLK_CNT 	: unsigned(2 downto 0);
	signal VDC_SEL_OLD	: std_logic;
	
	--IO
	signal IO_BUF 			: std_logic_vector(7 downto 0);
	signal RAM_SEL 		: std_logic;
	signal VDC_SEL 		: std_logic;
	signal VCE_SEL 		: std_logic;
	signal IOP_SEL 		: std_logic;
	signal PSG_SEL 		: std_logic;
	signal TMR_SEL 		: std_logic;
	signal INT_SEL 		: std_logic;
	signal IO_SEL 			: std_logic;
	
	signal INT_MASK 		: std_logic_vector(2 downto 0);
	signal TMR_PRE_CNT 	: unsigned(9 downto 0);
	signal TMR_VALUE 		: std_logic_vector(6 downto 0); 
	signal TMR_LATCH 		: std_logic_vector(6 downto 0);
	signal TMR_EN 			: std_logic;
	signal TMR_RELOAD		: std_logic; 
	signal TMR_IRQ 		: std_logic;
	signal TMR_IRQ_ACK 	: std_logic;

begin

	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			CPU_CLK_CNT <= (others=>'0');
			CPU_CE <= '0';
			CPU_CER <= '0';
			IO_CLK_CNT <= (others=>'0');
			IO_CE <= '0';
			SX    <= '0';
		elsif rising_edge(CLK) then
			CPU_CE <= '0';
			if (CPU_CLK_CNT = 2 and CPU_CS = '1') or (CPU_CLK_CNT = 11 and CPU_CS = '0') then
				SX <= '1';
			else
				SX <= '0';
			end if;
			if (CPU_CLK_CNT = 5 and CPU_CS = '1') or (CPU_CLK_CNT = 23 and CPU_CS = '0') then
				if WAIT_N = '1' then
					CPU_CLK_CNT <= (others=>'0');
					CPU_CE <= '1';
				end if; 
			else
				CPU_CLK_CNT <= CPU_CLK_CNT + 1;
			end if; 
			
			CPU_CER <= '0';
			if CPU_CLK_CNT = 1 then
				CPU_CER <= '1';
			end if; 
			
			IO_CE <= '0';
			IO_CLK_CNT <= IO_CLK_CNT + 1;
			if IO_CLK_CNT = 5 then
				IO_CLK_CNT <= (others=>'0');
				IO_CE <= '1';
			end if; 
		end if;
	end process;
	
	CE <= CPU_CE and CPU_RDY;
	
	EN <= CPU_CE and CPU_RDY;
	
	
	CORE : entity work.HUC6280_CPU
	port map (
		CLK 		=> CLK,
		RST_N 	=> RST_N,
		CE 		=> CPU_CE,
		
		A_OUT 	=> CPU_A,
		DI 		=> CPU_DI,
		DO 		=> CPU_DO,
		WE_N 		=> CPU_WE_N,
		RDY 		=> CPU_RDY,
		IRQ1_N 	=> CPU_IRQ1_N,
		IRQ2_N 	=> CPU_IRQ2_N,
		IRQT_N 	=> CPU_IRQT_N,
		NMI_N 	=> NMI_N,
		MCYCLE	=> CPU_MCYCLE,
		CS 		=> CPU_CS,
		VDCNUM   => VDCNUM
	);
	
	CPU_IRQ1_N <= IRQ1_N or INT_MASK(1);
	CPU_IRQ2_N <= IRQ2_N or INT_MASK(0);
	CPU_IRQT_N <= not TMR_IRQ or INT_MASK(2);
	
	RAM_SEL <= '1' when CPU_A(20 downto 15) = "111110" else '0'; -- RAM : Page $F8 - $FB
	VDC_SEL <= '1' when CPU_A(20 downto 13) = x"FF" and CPU_A(12 downto 10) = "000" else '0'; -- VDC : $0000 - $03FF
	VCE_SEL <= '1' when CPU_A(20 downto 13) = x"FF" and CPU_A(12 downto 10) = "001" else '0'; -- VCE : $0400 - $07FF
	
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			WR_N <= '1';
			RD_N <= '1';
			CPU_RDY <= '1';
			VDC_SEL_OLD <= '0';
		elsif rising_edge(CLK) then
			if CPU_CER = '1' then
				if CPU_MCYCLE = '1' then
					WR_N <= CPU_WE_N;
					RD_N <= not CPU_WE_N;
				end if; 
				
				VDC_SEL_OLD <= VDC_SEL or VCE_SEL;
				if (VDC_SEL = '1' or VCE_SEL = '1') and VDC_SEL_OLD = '0' then
					CPU_RDY <= '0';
				end if;
			elsif CPU_CE = '1' then
				if CPU_RDY = '1' then
					WR_N <= '1';
					RD_N <= '1';
				end if; 
				CPU_RDY <= RDY;
			end if; 
		end if;
	end process;
	
	PRE_RD <= CPU_WE_N and CPU_MCYCLE and RST_N;
	PRE_WR <= not CPU_WE_N and CPU_MCYCLE and RST_N;
	
	A <= CPU_A;
	DO <= CPU_DO;
	CER_N <= not RAM_SEL;
	CE7_N <= not VDC_SEL;
	CEK_N <= not VCE_SEL;
	HSM <= CPU_CS;
	
	
	
	--KO port
	IOP_SEL <= '1' when CPU_A(20 downto 13) = x"FF" and CPU_A(12 downto 10) = "100" else '0'; -- IOP : $1000 - $13FF
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			O <= (others=>'0');
		elsif rising_edge(CLK) then
			if EN = '1' then
				if IOP_SEL = '1' and CPU_WE_N = '0' then
					O <= CPU_DO;
				end if; 
			end if; 
		end if;
	end process;
	
	--Interrupts register
	INT_SEL <= '1' when CPU_A(20 downto 13) = x"FF" and CPU_A(12 downto 10) = "101" else '0'; -- INT : $1400 - $17FF
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			INT_MASK <= (others=>'0');
			TMR_IRQ_ACK <= '0';
		elsif rising_edge(CLK) then
			TMR_IRQ_ACK <= '0';
			if INT_SEL = '1' and CPU_CER = '1' then 
				if CPU_WE_N = '0' then
					case CPU_A(1 downto 0) is
						when "10" =>
							INT_MASK <= CPU_DO(2 downto 0);
						when "11" =>
							TMR_IRQ_ACK <= '1';
						when others => null;
					end case;
				else
					case CPU_A(1 downto 0) is
						when "10" =>
							TMR_IRQ_ACK <= '1';
						when others => null;
					end case;
				end if; 
			end if; 
		end if;
	end process;


	-- Timer
	TMR_SEL <= '1' when CPU_A(20 downto 13) = x"FF" and CPU_A(12 downto 10) = "011" else '0'; -- TMR : $0C00 - $0FFF
	process( CLK, RST_N )
	begin
		if RST_N = '0' then
			TMR_VALUE <= (others => '0');			
			TMR_PRE_CNT <= (others => '1'); 
			TMR_LATCH <= (others => '0');
			TMR_EN <= '0';
			TMR_RELOAD <= '0'; 
			TMR_IRQ <= '0';
		elsif rising_edge(CLK) then
			if TMR_SEL = '1' and CPU_WE_N = '0' and CPU_CER = '1' then
				if CPU_A(0) = '0' then
					-- Timer latch
					TMR_LATCH <= CPU_DO(6 downto 0);
				else
					-- Timer enable
					TMR_EN <= CPU_DO(0);
					if TMR_EN = '0' and CPU_DO(0) = '1' then
						TMR_VALUE <= TMR_LATCH;
						TMR_PRE_CNT <= (others => '1'); 
					end if;
				end if;	
			end if; 
			
			if TMR_IRQ_ACK = '1' then
				TMR_IRQ <= '0';
			end if;
			
			if IO_CE = '1' then
				TMR_RELOAD <= '0';
				if TMR_EN = '1' then
					TMR_PRE_CNT <= TMR_PRE_CNT - 1;
					if TMR_PRE_CNT = 0 then
						TMR_VALUE <= std_logic_vector( unsigned(TMR_VALUE) - 1 );
						if TMR_VALUE = "0000000" then
							TMR_RELOAD <= '1';
							TMR_IRQ <= '1';
						end if;
					end if;
				end if; 
				
				if TMR_RELOAD = '1' then
					TMR_VALUE <= TMR_LATCH;
				end if; 
			end if;
		end if;
	end process;
	
	-- PSG
	PSG_SEL <= '1' when CPU_A(20 downto 13) = x"FF" and CPU_A(12 downto 10) = "010" else '0'; -- PSG : $0800 - $0BFF
	-- PSG unused in Robocop, I remove it so I don't have to deal
	-- with the dpram module, which is mapped to an Altera primitive
-- 	PSG : entity work.psg port map (
-- 		CLK		=> CLK,
-- 		CLKEN		=> IO_CE,	-- 7.16 Mhz clock
-- 		RESET_N	=> RST_N,
--
-- 		DI			=> CPU_DO,
-- 		A			=> CPU_A(3 downto 0),
-- 		WE			=> not CPU_WE_N and EN and PSG_SEL,
--
-- 		DAC_LATCH=> '1',
-- 		LDATA		=> AUD_LDATA,
-- 		RDATA		=> AUD_RDATA
-- 	);
		
	IO_SEL <= IOP_SEL or INT_SEL or TMR_SEL or PSG_SEL;
	process(CLK, RST_N)
	begin
		if RST_N = '0' then
			IO_BUF <= (others=>'1');
		elsif rising_edge(CLK) then
			if EN = '1' then
				if IO_SEL = '1' then 
					if CPU_WE_N = '0' then
						IO_BUF <= CPU_DO;
					else
						IO_BUF <= CPU_DI;
					end if; 
				end if; 
			end if; 
		end if;
	end process;
	
	process(CLK)
	begin
		if rising_edge(CLK) then
			if IO_SEL = '0' then
				CPU_DI <= DI;
			elsif PSG_SEL = '1' then
				CPU_DI <= x"00";
			elsif IOP_SEL = '1' then
				CPU_DI <= K;
			elsif INT_SEL = '1' then
				case CPU_A(1 downto 0) is
					when "10" =>
						CPU_DI <= IO_BUF(7 downto 3) & INT_MASK;
					when "11" =>
						CPU_DI <= IO_BUF(7 downto 3) & TMR_IRQ & not IRQ1_N & not IRQ2_N;
					when others =>
						CPU_DI <= IO_BUF;
				end case;
			elsif TMR_SEL = '1' then
				CPU_DI <= IO_BUF(7) & TMR_VALUE;
			else
				CPU_DI <= IO_BUF;
			end if;
		end if;
	end process;

end rtl;
	