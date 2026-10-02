----------------------------------------------------------------------------------
-- Create Date:    22:38:01 1/11/2007
-- Design Name:
-- Module Name:    LETA_REP - Behavioral
-- Project Name:   LETA on a CPLD
-- Target Devices: XC95108
-- Tool versions:  webpack ise 9.1.03i
-- Description:    Atari Leta replacement *Freeware* !!
--
-- Additional Comments:
-- 	another fun project from JROK
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity LETA_REP is
port (
	clk		: in  std_logic;  -- system wide clock
	ck		: in  std_logic;  -- LETA clock
	resoln	: in  std_logic;
	cs		: in  std_logic;
	test	: in  std_logic;
	ad		: in  std_logic_vector (1 downto 0);
	clks	: in  std_logic_vector (3 downto 0);
	dirs	: in  std_logic_vector (3 downto 0);
	db		: out std_logic_vector (7 downto 0)
);
end LETA_REP;

architecture Behavioral of LETA_REP is

-- 8 bit counter register
type   cnt_reg is  array( 0 to 3 ) of   std_logic_vector( 7 downto 0 );
signal count_register : cnt_reg := (others=>(others=>'0'));

-- 3 bit temp storage
type tmp_inputs is array( 0 to 3 ) of std_logic_vector( 2 downto 0 );
signal clks_tmp: tmp_inputs := (others=>(others=>'0'));
signal dirs_tmp: tmp_inputs := (others=>(others=>'0'));

signal clks_last_bit : std_logic_vector( 3 downto 0 ) := (others=>'0');
signal dirs_last_bit : std_logic_vector( 3 downto 0 ) := (others=>'0');
signal ck_last       : std_logic := '0';

begin
-- 0 1 1 0 count up   0 1 1 0 count down
-- 0 0 1 1            1 1 0 0
----------------------------------------------------------
process( clk)
begin
if ( rising_edge( clk ) ) then
	ck_last <= ck;
	if ck_last = '0' and ck = '1' then
		for cntr in 3 downto 0 loop
			if ( test = '1' ) then
				-- test mode clear the states of DIR and CLK and ALL the counts
				clks_tmp( cntr ) <= (others=>'0');
				dirs_tmp( cntr ) <= (others=>'0');
				count_register( cntr ) <= (others=>'0');
				clks_last_bit( cntr )  <= '0';
				dirs_last_bit( cntr )  <= '0';
			else
				-- shift the bits left and store the current state in bit '0'
				clks_tmp( cntr ) <= clks_tmp( cntr )( 1 downto 0 ) & clks( cntr );
				dirs_tmp( cntr ) <= dirs_tmp( cntr )( 1 downto 0 ) & dirs( cntr );
				-- test mode = '0' so normal counting operation
				-- 3 bits of CLK or DIR have to be the same
				if ( clks_tmp( cntr ) = "000" ) then
					clks_last_bit( cntr ) <= '0';
				elsif ( clks_tmp( cntr ) = "111" ) then
					clks_last_bit( cntr ) <= '1';
				end if;
				if ( dirs_tmp( cntr ) = "000" ) then
					dirs_last_bit( cntr ) <= '0';
				elsif ( dirs_tmp( cntr ) = "111" ) then
					dirs_last_bit( cntr ) <= '1';
				end if;
				--  check for a new state of DIR & CLK then take a counting action depending on the previous state
				-- state 10
				if  ( clks_tmp( cntr ) = "111" and  dirs_tmp( cntr ) = "000"   ) then
					if ( clks_last_bit( cntr ) ='1' and dirs_last_bit( cntr ) ='1' ) then
						count_register(cntr) <= count_register(cntr)-1;
					end if;
					if  ( clks_last_bit( cntr ) ='0' and dirs_last_bit( cntr ) ='0' and resoln = '1' ) then
						count_register(cntr) <= count_register(cntr)+1;
					end if;
				end if;
				-- state 11
				if  ( clks_tmp( cntr ) = "111" and  dirs_tmp( cntr ) = "111"   ) then
					if  ( clks_last_bit( cntr ) ='1' and dirs_last_bit( cntr ) ='0' ) then
						count_register(cntr) <= count_register(cntr)+1;
					end if;
					if  ( clks_last_bit( cntr ) ='0' and dirs_last_bit( cntr ) ='1'  and resoln = '1' ) then
						count_register(cntr) <= count_register(cntr)-1;
					end if;
				end if;
				-- state 01
				if  ( clks_tmp( cntr ) = "000" and  dirs_tmp( cntr ) = "111"  ) then
					if  ( clks_last_bit( cntr ) ='0' and dirs_last_bit( cntr ) ='0' ) then
						count_register(cntr) <= count_register(cntr)-1;
					end if;
					if  ( clks_last_bit( cntr ) ='1' and dirs_last_bit( cntr ) ='1'  and resoln = '1' ) then
						count_register(cntr) <= count_register(cntr)+1;
					end if;
				end if;
				-- state 00
				if  ( clks_tmp( cntr ) = "000" and  dirs_tmp( cntr ) = "000"   ) then
					if  ( clks_last_bit( cntr ) ='0' and dirs_last_bit( cntr ) ='1'  ) then
						count_register(cntr) <= count_register(cntr)+1;
					end if;
					if  ( clks_last_bit( cntr ) ='1' and dirs_last_bit( cntr ) ='0'  and resoln = '1') then
						count_register(cntr) <= count_register(cntr)-1;
					end if;
				end if;
			end if;
		end loop;
	end if;
end if;
end process;
----------------------------------------------------------
process( cs, count_register, ad, test,dirs, clks )
begin
	if ( cs = '1' ) then
		db <= "ZZZZZZZZ";
	else
		if ( test = '0' ) then
			-- put the register pointed to by A0 & A1 onto the databus
			db   <= count_register( conv_integer( ad ) ) ;
		else
			-- test mode so just pass thru' the INVERTED states of the dir and clk inputs
			-- A0/A1 are irrelevant
			db <= not (clks(3) & dirs(3) & clks(2) & dirs(2) & clks(1) & dirs(1) & clks(0) & dirs(0));
		end if;
	end if;
end process;

end Behavioral;
