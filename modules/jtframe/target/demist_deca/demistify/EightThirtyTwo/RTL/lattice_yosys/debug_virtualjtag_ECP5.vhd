library ieee;
use ieee.std_logic_1164.all;

entity debug_virtualjtag is
port (
	tck : out std_logic;
	tdi : out std_logic;
	tdo : in std_logic_vector(1 downto 0);
	capture : out std_logic_vector(1 downto 0);
	shift : out std_logic_vector(1 downto 0);
	update : out std_logic_vector(1 downto 0)
);
end entity;

architecture rtl of debug_virtualjtag is
	signal jtck : std_logic;
	signal jtdi,jshift,jupdate,jrstn,jce1,jce2 : std_logic;
	signal jtdi_mux : std_logic;
	signal jtdi_latched : std_logic;
	signal jshift_d : std_logic;
	signal selectedreg : std_logic;

	component JTAGG
	port (
		JTCK : out std_logic;
		JTDI : out std_logic;
		JSHIFT : out std_logic;
		JUPDATE : out std_logic;
		JRSTN : out std_logic;
		JCE1 : out std_logic;
		JCE2 : out std_logic;
		JRTI1 : out std_logic;
		JRTI2 : out std_logic;
		JTDO1 : in std_logic;
		JTDO2 : in std_logic
	);
	end component;

begin

	-- The JTAGG instance
	jtg : component JTAGG
	port map(
		JTCK => jtck,
		JTDI => jtdi,
		JSHIFT => jshift,
		JUPDATE => jupdate,
		JRSTN => jrstn,
		JCE1 => jce1,
		JCE2 => jce2,
		JRTI1 => open,
		JRTI2 => open,
		JTDO1 => tdo(0),
		JTDO2 => tdo(1)
	);
	tck <= jtck;
	tdi <= jtdi when jshift_d='1' else jtdi_latched;

	process(jtck) begin
		if rising_edge(jtck) then
			jshift_d <= jshift;
			if jshift_d='1' then
				jtdi_latched <= jtdi;
			end if;
		end if;
	end process;

	capture(0) <= jce1 and not jshift;
	capture(1) <= jce2 and not jshift;
	shift(0) <= jce1 and jshift;
	shift(1) <= jce2 and jshift;

	-- Record which register is being accessed, and filter jupdate accordingly.
	process(jtck) begin
		if rising_edge(jtck) then
			if (jce1 and jshift) = '1' then
				selectedreg<='0';
			end if;
			if (jce2 and jshift) = '1' then
				selectedreg<='1';
			end if;
		end if;
	end process;
	update(0) <= jupdate and not selectedreg;
	update(1) <= jupdate and selectedreg;

end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity vjtag_register is
generic (
	bits : integer := 32
);
port (
	-- JTAG clock domain
	tck : in std_logic;
	tdo : out std_logic;
	tdi : in std_logic;
	cap : in std_logic;
	upd : in std_logic;
	shift : in std_logic;
	d : in std_logic_vector(bits-1 downto 0);
	q : out std_logic_vector(bits-1 downto 0)
);
end entity;

architecture rtl of vjtag_register is
	signal shift_next : std_logic_vector(bits-1 downto 0);
	signal shiftreg : std_logic_vector(bits-1 downto 0);
	signal tck_inv : std_logic;
begin
	tdo <= shiftreg(0);

	shift_next <= tdi & shiftreg(bits-1 downto 1);

	process(tck) begin
		if falling_edge(tck) then
			if shift='1' then
				shiftreg<=shift_next;
			end if;

			if cap='1' then
				shiftreg<=d;
			end if;
		end if;
	end process;

	process(tck) begin
		if falling_edge(tck) then
			if upd='1' then
				q<=shift_next;
			end if;
		end if;
	end	process;

end architecture;

