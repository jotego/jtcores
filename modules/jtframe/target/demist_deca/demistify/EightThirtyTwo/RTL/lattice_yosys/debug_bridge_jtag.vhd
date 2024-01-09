-- Virtual JTAG wrapper for ECP5 JTAGG primitive.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debug_bridge_jtag is
generic (
	id : natural := 16#832d#
);
port(
	clk : in std_logic;
	reset_n : in std_logic;
	-- Design interface
	d : in std_logic_vector(31 downto 0);
	q : out std_logic_vector(31 downto 0);
	req : in std_logic;
	wr : in std_logic;
	ack : out std_logic
);
end entity;

architecture rtl of debug_bridge_jtag is
	-- JTAG signals
	signal capture : std_logic_vector(1 downto 0);
	signal update : std_logic_vector(1 downto 0);
	signal shift : std_logic_vector(1 downto 0);
	signal jtck : std_logic;
	signal jtck_inv : std_logic;

	-- FIFO signals
	-- to JTAG
	signal tjrd,tjwr,tjempty,tjfull : std_logic;
	signal tjd : std_logic_vector(31 downto 0);
	-- from JTAG
	signal fjrd,fjwr,fjempty,fjfull : std_logic;
	signal fjq : std_logic_vector(31 downto 0);	
	
	signal vir : std_logic_vector(31 downto 0);
	signal vir_in : std_logic_vector(31 downto 0);

	signal ack_i : std_logic;

begin

	-- Some glue logic to give us separate capture and update signals for the two user registers

	jtagctrl : block
		signal jtdi : std_logic;
		signal jtdo : std_logic_vector(1 downto 0);
	begin

		vjtag : entity work.debug_virtualjtag
		port map (
			tck => jtck,
			tdi => jtdi,
			tdo => jtdo,
			capture => capture,
			shift => shift,
			update => update
		);
		

		jtck_inv<=not jtck;

		-- Create a pair of registers to be accessed over the JTAG chain

		virtual_ir : entity work.vjtag_register
		generic map (
			bits => 32
		)
		port map (
			tck => jtck,
			tdo => jtdo(0),
			tdi => jtdi,
			cap => capture(0),
			upd => update(0),
			shift => shift(0),
			d => vir_in,
			q => vir
		);

		virtual_dr : entity work.vjtag_register
		generic map (
			bits => 32
		)
		port map (
			tck => jtck,
			tdo => jtdo(1),
			tdi => jtdi,
			cap => capture(1),
			upd => update(1),
			shift => shift(1),
			d => tjd,
			q => fjq
		);
	end block;

	
	-- FIFO to JTAG

	fifotojtag : entity work.debug_fifo
	generic map (
		width => 32,
		depth => 4
	)
	port map(
		reset_n => reset_n,
		rd_clk => jtck_inv,
		rd_en => tjrd,
		dout => tjd,
		empty => tjempty,
		
		wr_clk => clk,
		wr_en => tjwr,
		din => d,
		full => tjfull
	);

	process (jtck) begin
		if falling_edge(jtck) then
			tjrd <= '0';
			fjwr <= '0';
			if vir(1 downto 0) = "00" then
				tjrd <= capture(1) and not tjempty; -- Lag capture by 1 cycle
			end if;
			if vir(1 downto 0) = "01" then
				fjwr <= update(1) and not fjfull; 
			end if;
		end if;
	end process;


	-- FIFO from JTAG

	fifofromjtag : entity work.debug_fifo
	generic map (
		width => 32,
		depth => 4
	)
	port map(
		reset_n => reset_n,
		rd_clk => clk,
		rd_en => fjrd,
		dout => q,
		empty => fjempty,

		wr_clk => jtck_inv,
		wr_en => fjwr,
		din => fjq,
		full => fjfull
	);


	-- Virtual IR, contains fifo state and an ID
	
	vir_in <= std_logic_vector(to_unsigned(id,16)) & req & ack_i & vir(9 downto 0) & fjfull & fjempty & tjfull & tjempty;

	-- Req/ack interface to DR FIFOs

	ack <= ack_i;
	process(clk,reset_n) begin	
		if reset_n='0' then
			tjwr<='0';
			fjrd<='0';
			ack_i<='0';
		elsif rising_edge(clk) then
			tjwr<='0';
			fjrd<='0';
			ack_i<='0';
			if req='1' and ack_i='0' then
				if wr='1' and tjfull='0' then
					tjwr<='1';
					ack_i<='1';
				end if;
				if wr='0' and fjempty='0' then
					fjrd<='1';
					ack_i<='1';
				end if;
			end if;		
		end if;
	end process;

end architecture;

