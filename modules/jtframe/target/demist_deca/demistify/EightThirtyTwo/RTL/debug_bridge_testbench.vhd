library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debug_bridge_testbench is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	d : in std_logic_vector(31 downto 0);
	q : out std_logic_vector(31 downto 0);
	req : in std_logic;
	wr : in std_logic;
	ack : buffer std_logic
);
end entity;

architecture rtl of debug_bridge_testbench is

type states is (IDLE, READADDR,GETRESPONSE,STEP);
signal state : states ;
signal counter : unsigned(15 downto 0);
signal data : std_logic_vector(31 downto 0);

begin

process(clk,reset_n)
begin

	if reset_n='0' then
		counter<=X"0000";
		state<=IDLE;
	elsif rising_edge(clk) then

		counter<=counter+1;
		ack<='0';

		case state is
			when IDLE =>
			
				if req='1' and ack='0' and counter=X"FFFF" then
					q<=X"03000000"; -- Single step command, no parameters or response
					ack<='1';
					
				elsif counter(5 downto 0)="00"&X"0" then
					q<=X"07040400"; -- Read, 4 byte param, 4 byte response
					ack<='1';
					state<=READADDR;
					
				elsif counter(5 downto 0)="10"&X"0" then
					q<=X"05000407"; -- Read reg, 0 byte param, 4 byte respons, reg r7
					ack<='1';
					state<=GETRESPONSE;
					
				end if;
				

			when READADDR =>
				if req='1' and ack='0' then
					q<=X"00000"&"00"&std_logic_vector(counter(15 downto 6));
					ack<='1';
					state<=GETRESPONSE;
				end if;

			when GETRESPONSE =>
				if req='1' and ack='0' then
					data<=d;
					ack<='1';
					state<=IDLE;
				end if;
			
			when STEP =>
				state<=IDLE;

			when others =>
				null;

		end case;
	
	end if;

end process;


end architecture;