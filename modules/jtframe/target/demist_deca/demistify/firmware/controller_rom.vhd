-- Control ROM split between two different chunks of memory of different
-- size to reduce demands on block RAM.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.demistify_config_pkg.all;

entity controller_rom is
port (
	clk : in std_logic;
	reset_n : in std_logic := '1';
	addr : in std_logic_vector(demistify_romspace-3 downto 0);
	d : in std_logic_vector(31 downto 0);
	q : out std_logic_vector(31 downto 0);
	we : in std_logic;
	bytesel : in std_logic_vector(3 downto 0)
);
end controller_rom;

architecture arch of controller_rom is

signal romsel_a : std_logic;
signal q1 : std_logic_vector(31 downto 0);
signal q2 : std_logic_vector(31 downto 0);
signal we1 : std_logic;
signal we2 : std_logic;

begin

	-- use high bit of incoming address to switch between two ROMS

	romsel_a<=addr(addr'high);
	we1 <= we when romsel_a='0' else '0';
	we2 <= we when romsel_a='1' else '0';
	q <= q1 when romsel_a='0' else q2;


	rom1 : entity work.controller_rom1
	generic map
	(
		ADDR_WIDTH => demistify_romsize1-2
	)
	port map (
		clk => clk,
		reset_n => reset_n,
		addr => addr(demistify_romsize1-3 downto 0),
		d => d,
		q => q1,
		we => we1,
		bytesel => bytesel
	);

	rom2 : entity work.controller_rom2
	generic map
	(
		ADDR_WIDTH => demistify_romsize2-2
	)
	port map (
		clk => clk,
		reset_n => reset_n,
		addr => addr(demistify_romsize2-3 downto 0),
		d => d,
		q => q2,
		we => we2,
		bytesel => bytesel
	);

end arch;

