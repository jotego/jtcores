-- This is just a stub to allow compilation against a testbench - 
-- there's currently no actual connectivity.
-- TODO - figure out a way to connect to some kind of socket
-- to allow JTAG communication with a running simulation.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debug_virtualjtag_sim_ghdl is
generic (
	irsize : integer := 2;
	drsize : integer := 32
);
port(
	ir_out : out std_logic_vector(irsize-1 downto 0);
	tdo : in std_logic;
	tck : out std_logic;
	tdi : out std_logic;
	virtual_state_cdr : out std_logic;
	virtual_state_sdr : out std_logic;
	virtual_state_udr : out std_logic;
	virtual_state_uir : out std_logic
);
end entity;

architecture rtl of debug_virtualjtag_sim_ghdl is

begin


ir_out <= (others => '0');

tck <= '0';
tdi <= '0';

virtual_state_uir <= '0';
virtual_state_cdr <= '0';
virtual_state_sdr <= '0';
virtual_state_udr <= '0';

end architecture;

