-- eightthirtytwo_debug.vhd
-- Copyright 2020 by Alastair M. Robinson

-- This file is part of the EightThirtyTwo CPU project.

-- EightThirtyTwo is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.

-- EightThirtyTwo is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.

-- You should have received a copy of the GNU General Public License
-- along with EightThirtyTwo.  If not, see <https://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.eightthirtytwo_pkg.all;

entity eightthirtytwo_debug is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	
	-- Connections to debug data transport
	debug_d : in std_logic_vector(31 downto 0);
	debug_q : out std_logic_vector(31 downto 0);
	debug_req : out std_logic;
	debug_wr : out std_logic;
	debug_ack : in std_logic;
	
	-- Control signals for CPU
	addr : out std_logic_vector(31 downto 0);
	d : in std_logic_vector(31 downto 0);
	q : out std_logic_vector(31 downto 0);
	req : out std_logic;
	ack : in std_logic;
	wr : out std_logic;
	rdreg : out std_logic;
	setbrk : out std_logic;
	run : out std_logic;
	stop : out std_logic;
	step : out std_logic
);
end entity;

architecture rtl of eightthirtytwo_debug is

-- Command from the TCL bridge script
constant DBG832_RUN : std_logic_vector(7 downto 0) := X"02";
constant DBG832_SINGLESTEP : std_logic_vector(7 downto 0) := X"03";
constant DBG832_STEPOVER : std_logic_vector(7 downto 0) := X"04";
constant DBG832_READREG : std_logic_vector(7 downto 0) := X"05";
constant DBG832_READFLAGS : std_logic_vector(7 downto 0) := X"06";
constant DBG832_READ : std_logic_vector(7 downto 0) := X"07";
constant DBG832_WRITE : std_logic_vector(7 downto 0) := X"08";
constant DBG832_BREAKPOINT : std_logic_vector(7 downto 0) := X"09";
constant DBG832_STOP : std_logic_vector(7 downto 0) := X"0A";

-- State machine definitions

type debugstate_t is (IDLE,SINGLESTEP,READADDR,READDATA,WRITEDATA,EXECUTE,RESPOND,FINISH);
signal debugstate : debugstate_t := IDLE;

-- Storage for parameters

signal debug_cmd : std_logic_vector(7 downto 0);
signal debug_parambytes : std_logic_vector(7 downto 0);
signal debug_responsebytes : std_logic_vector(7 downto 0);
signal debug_param : std_logic_vector(7 downto 0);

signal debug_req_r : std_logic;

begin

debug_req <= debug_req_r;

process(clk,reset_n)
begin
	if reset_n='0' then
		req<='0';
		wr<='0';
		rdreg<='0';
		setbrk<='0';
		step<='0';
		run<='0';
		addr<=X"00000000";
		debug_wr<='0';
		debugstate<=IDLE;
	elsif rising_edge(clk) then

		rdreg<='0';
		setbrk<='0';
		run<='0';
		stop<='0';
		step<='0';
		debug_req_r<='0';

		case debugstate is
			when IDLE =>
				wr<='0';
				if debug_req_r='1' and debug_ack='1' then
					debug_cmd<=debug_d(31 downto 24);
					debug_parambytes<=debug_d(23 downto 16);
					debug_responsebytes<=debug_d(15 downto 8);
					debug_param<=debug_d(7 downto 0);
					q(7 downto 0)<=debug_d(7 downto 0);

					case debug_d(23 downto 16) is
						when X"00" =>
							debugstate<=EXECUTE;
						when X"04" =>
							debugstate<=READADDR;
						when X"08" =>
							debugstate<=READADDR;
						when others =>
							null;
					end case;
				else
					debug_req_r<='1';
				end if;

			when READADDR =>
				if debug_req_r='1' and debug_ack='1' then
					addr<=debug_d;
					if debug_parambytes=X"08" then
						debugstate<=READDATA;
					else
						debugstate<=EXECUTE;
					end if;
				else
					debug_req_r<='1';
				end if;

			when READDATA =>
				if debug_req_r='1' and debug_ack='1' then
					q<=debug_d;
					debugstate<=EXECUTE;
				else
					debug_req_r<='1';
				end if;

			when EXECUTE =>
				debugstate<=IDLE;
				case debug_cmd is
					when DBG832_RUN =>
						run<='1';
					when DBG832_STOP =>
						stop<='1';
					when DBG832_BREAKPOINT =>
						setbrk<='1';
					when DBG832_SINGLESTEP =>
						step<='1';
					when DBG832_STEPOVER =>
						-- FIXME - set breakpoint to PC + 1, then run.
					when DBG832_READREG =>
						rdreg<='1';
						debugstate<=RESPOND;
					when DBG832_READ =>
						req<='1';
						wr<='0';
						debugstate<=RESPOND;
					when DBG832_WRITE =>
						req<='1';
						wr<='1';
						debugstate<=WRITEDATA;
					when others =>
						null;
				end case;

			when WRITEDATA =>
				if ack='1' then
					req<='0';
					wr<='0';
					debugstate<=IDLE;
				end if;
				
			-- Wait for the CPU to supply the requested data
			-- then send the response to the debug channel
			when RESPOND =>
				if ack='1' then
					-- FIXME - this can probably be done directly.	
					debug_q<=d;
					debug_req_r<='1';
					debug_wr<='1';
					wr<='0';
					req<='0';
					debugstate<=FINISH;
				end if;

			-- Wait for the debug channel to acknowledge the data
			when FINISH =>
				if debug_req_r='1' and debug_ack='1' then
					debug_wr<='0';
					debugstate<=IDLE;
				else
					debug_req_r<='1';
				end if;
				
			when others =>
				null;

		end case;

	end if;
end process;

end architecture;


