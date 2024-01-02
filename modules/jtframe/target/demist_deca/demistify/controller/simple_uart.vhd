library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

-- Simplistic UART, handles 8N1 RS232 Rx/Tx with baud rate specified by a signal.


entity simple_uart is
	generic(
		counter_bits : natural := 16;
		enable_rx : boolean := true;
		enable_tx : boolean := true
	);
	port(
		clk : in std_logic;
		reset : in std_logic;
		txdata : in std_logic_vector(7 downto 0);
		txgo : in std_logic;			-- trigger transmission
		txready : out std_logic;	-- ready to transmit
		rxdata : out std_logic_vector(7 downto 0);
		rxready : in std_logic :='1';	-- ready to receive

		rxint : out std_logic;	-- Interrupt, momentary pulse when character received
		txint : out std_logic;	-- Interrupt, momentary pulse when data has finished sending

		-- clock_divisor divides the system clock into the width of a single serial bit, so
		-- for a 50MHz clock, 19,200 baud, we'd use 50,000,000 / 19,200 = 2604 decimal, X"0A2C" hex
		clock_divisor : unsigned(15 downto 0) := X"0A2C";

		-- physical ports

		rxd : in std_logic;
		txd : out std_logic
	);
end simple_uart;

architecture rtl of simple_uart is

signal rxd_sync : std_logic;
signal rxd_sync2 : std_logic;

signal rxcounter : unsigned(counter_bits-1 downto 0);
signal rxclock : std_logic;
signal rxbuffer : std_logic_vector(8 downto 0);

type rxstates is (idle, start, bits, stop);
signal rxstate : rxstates := idle;

signal txcounter : unsigned(counter_bits-1 downto 0);
signal txclock : std_logic;
signal txbuffer : std_logic_vector(17 downto 0);

type txstates is (idle, bits);
signal txstate : txstates := idle;

begin

	-- Signal synchronisation for rxd.
	-- Without this, the state machine can get messed up.  The change from one state
	-- to another is not an atomic operation; leaving one state and entering the next
	-- are distinct, and it's possible (and, in fact, common) for one 
	-- to happen without the other if inputs aren't properly synchronised.
genrx : if enable_rx generate	
	process(clk,rxd)
	begin
		if rising_edge(clk) then
			rxd_sync2<=rxd;
			rxd_sync<=rxd_sync2;
		end if;
	end process;

	-- Rx Clock generation
	-- The Rx clock is slightly more complicated.  When idle we detect the leading edge of the
	-- start bit, and set the counter to half a bit width.  When it reaches zero, the counter is
	-- set to a full bit width, so clock ticks should land in the centre of each bit.

	process(clk,reset,rxd_sync,rxcounter,rxstate)
	begin
		if rising_edge(clk) then
			rxclock<='0';

			if rxstate=idle then
				if rxd_sync='0' then	-- Start bit?  Set counter to half a bit width
					rxcounter<='0' & clock_divisor(counter_bits-1 downto 1);
				end if;
			else
				rxcounter<=rxcounter-1;
				if rxcounter=0 then
					rxclock<='1';
					rxcounter<=clock_divisor;
				end if;
			end if;
		end if;
	end process;


	-- Data Rx
	-- We use a 9-bit shift register here.  Upon detection of the start bit, we
	-- load the shift register with "100000000".
	-- As each bit is received we shift the register one bit to the right, and load new data
	-- into bit 8.
	-- When the 1 initially in bit 8 reaches bit zero we know we've received the entire word.
	process(clk,reset,rxd_sync,rxcounter,rxstate)
	begin
		if reset='0' then
			rxstate<=idle;
			rxint<='0';
		elsif rising_edge(clk) then
			rxint<='0';
			case rxstate is
				when idle =>
					if rxd_sync='0' then
						rxstate<=start;
					end if;
				when start =>
					if rxclock='1' then
						if rxd_sync='0' then
							rxbuffer<="100000000"; -- Set marker bit.
							rxstate<=bits;
						else
							rxstate<=idle;
						end if;
					end if;
				when bits =>
					if rxclock='1' then
						rxbuffer<=rxd_sync & rxbuffer(8 downto 1);
					end if;
					if rxbuffer(0)='1' then	-- Marker bit has reached bit 0
						rxstate<=stop;
					end if;
				when stop =>
					if rxclock='1' then
						if rxd_sync='1' then -- valid stop bit?
							rxdata<=rxbuffer(8 downto 1);
							rxint<='1';
						end if;
						rxstate<=idle;
					end if;
				when others =>
					rxstate<=idle;
			end case;
		end if;
	end process;
end generate;

gennorx: if not enable_rx generate
	rxint<='0';	
end generate;
	-- Clock generators.
	-- We have independent Rx and Tx clocks, generated from counters
	-- which count down from clock_divisor to zero.
	-- At zero, we generate a momentary high pulse which is used as the serial clock signal.

	-- Tx Clock generation
	-- Very simple - the counter is reset when either it reaches zero or
	-- the Tx is idle, and counts down once per system clock tick.
gentx: if enable_tx generate
	process(clk)
	begin
		if rising_edge(clk) then
			txclock<='0';

			if txstate=idle then
				txcounter<=clock_divisor;
			else
				txcounter<=txcounter-1;
				if txcounter=0 then
					txclock<='1';
					txcounter<=clock_divisor;
				end if;
			end if;
		end if;
	end process;


	-- Data Tx
	-- Similarly to the Rx routine, we use a shift register larger than the word,
	-- which also includes a marker bit.  This time the marker bit is a zero, and when
	-- the zero reaches bit 8, we know we've transmitted the entire word plus one stop bit.
	process(clk,reset,txgo,txcounter,txstate)
	begin
		if reset='0' then
			txstate<=idle;
			txready<='1';
			txd<='1';
			txint<='0';
		elsif rising_edge(clk) then
			txint <='0';
			case txstate is
				when idle =>
					if txgo='1' then
						txbuffer<="0111111111" & txdata;	-- marker bit + data
						txstate<=bits;
						txready<='0';
						txd<='0'; -- Start bit
					end if;
				when bits =>
					if txclock='1' then
						txd<=txbuffer(0);
						txbuffer<='0' & txbuffer(17 downto 1);

						if txbuffer(8)='0' then	-- Marker bit has reached bit 8
							txstate<=idle;
							txready<='1';
							txint<='1';
						end if;

					end if;
				when others =>
					txstate<=idle;
			end case;
		end if;
	end process;
end generate;

gennotx: if not enable_tx generate
	txready<='0';
	txint<='0';	
	txd<='1';
end generate;

end architecture;
