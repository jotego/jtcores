-- Timer Controller
-- Copyright © 2015 by Alastair M. Robinson

-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
use IEEE.numeric_std.ALL;

library work;

-- Timer controller module

entity timer_controller is
  generic(
		prescale : integer := 1; -- Prescale incoming clock
		timers : integer := 0 -- This is a power of 2, so zero means 1 counter, 4 means 16 counters...
	);
  port (
		clk : in std_logic;
		reset : in std_logic; -- active low

		reg_addr_in : in std_logic_vector(7 downto 0); -- from host CPU
		reg_data_in: in std_logic_vector(31 downto 0);
		reg_rw : in std_logic;
		reg_req : in std_logic;

		ticks : out std_logic_vector(2**timers-1 downto 0)
	);
end entity;
	
architecture rtl of timer_controller is
	constant prescale_adj : integer := prescale-1;
	signal prescale_counter : unsigned(15 downto 0);
	signal prescaled_tick : std_logic;
	type timer_counters is array (2**timers-1 downto 0) of unsigned(23 downto 0);
	signal timer_counter : timer_counters;
	signal timer_limit : timer_counters;
	signal timer_enabled : std_logic_vector(2**timers-1 downto 0);
	signal timer_index : unsigned(7 downto 0);
begin

	-- Prescaled tick
	process(clk,reset)
	begin
		if reset='0' then
			prescale_counter<=(others=>'0');
		elsif rising_edge(clk) then
			prescaled_tick<='0';
			prescale_counter<=prescale_counter-1;
			if prescale_counter=X"0000" then
				prescaled_tick<='1';
				prescale_counter<=to_unsigned(prescale_adj,16);
			end if;
		end if;
	end process;

	-- The timers proper;
	process(clk,reset)
	begin
		if reset='0' then
			for I in 0 to (2**timers-1) loop
				timer_counter(I)<=(others => '0');
			end loop;
		elsif rising_edge(clk) then
			ticks<=(others => '0');
			if prescaled_tick='1' then
				for I in 0 to (2**timers-1) loop
					if timer_enabled(I)='1' then
						timer_counter(I)<=timer_counter(I)-1;
						if timer_counter(I)=X"000000" then
							timer_counter(I)<=timer_limit(I);
							ticks(I)<='1';
						end if;
					end if;
				end loop;
			end if;
		end if;
	end process;

	-- Handle CPU access to hardware registers
	
	process(clk,reset)
	begin
		if reset='0' then
			timer_enabled<=(others => '0');
		elsif rising_edge(clk) then
			if reg_req='1' and reg_rw='0' then -- Write access
				case reg_addr_in is
					when X"00" =>
						timer_enabled<=reg_data_in(2**timers-1 downto 0);
					when X"04" =>
						timer_index<=unsigned(reg_data_in(7 downto 0));
					when X"08" =>
						timer_limit(to_integer(timer_index(timers downto 0)))<=
							unsigned(reg_data_in(23 downto 0));					
					when others =>
						null;
				end case;
			end if;
		end if;
	end process;
		
end architecture;

