-- Substitute for MiST's MCU
-- Copyright © 2021 by Alastair M. Robinson

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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

library work;
use work.demistify_config_pkg.all;

entity substitute_mcu is
	generic (
		joybits : integer := 8;
		debug : boolean := false;
		jtag_uart : boolean := false;
		spirtc : boolean := false;
		sysclk_frequency : integer := 500; -- Sysclk frequency * 10
		SPI_SLOWBIT : integer := 6;  -- ~384KHz when sysclk is 50MHz
		SPI_FASTBIT : integer := 2 ; -- ~5MHz when sysclk is 50MHz
		SPI_INTERNALBIT : integer := 1; -- Full speed when 0, half speed when 1
		SPI_EXTERNALCLK : boolean := false
	);
	port (
		clk 			: in std_logic;
		reset_in 	: in std_logic;
		reset_out   : out std_logic;

		-- SPI signals
		spi_miso		: in std_logic := '1'; -- Allow the SPI interface not to be plumbed in.
		spi_clk		: out std_logic;
		spi_cs 		: out std_logic;
		spi_mosi    : out std_logic;
		spi_toguest : out std_logic;
		spi_fromguest : in std_logic;
		spi_ss2 : out std_logic;
		spi_ss3 : out std_logic;
		spi_ss4 : out std_logic;
		spi_srtc : out std_logic;
		conf_data0 : out std_logic;
		spi_req : out std_logic;
		spi_ack : in std_logic := '1';
		
		-- PS/2 signals
		ps2k_clk_in : in std_logic := '1';
		ps2k_dat_in : in std_logic := '1';
		ps2k_clk_out : out std_logic;
		ps2k_dat_out : out std_logic;
		ps2m_clk_in : in std_logic := '1';
		ps2m_dat_in : in std_logic := '1';
		ps2m_clk_out : out std_logic;
		ps2m_dat_out : out std_logic;

		-- Joysticks and other inputs
		
		joy1 : in std_logic_vector(joybits-1 downto 0) := (others => '1');
		joy2 : in std_logic_vector(joybits-1 downto 0) := (others => '1');
		joy3 : in std_logic_vector(joybits-1 downto 0) := (others => '1');
		joy4 : in std_logic_vector(joybits-1 downto 0) := (others => '1');
		
		buttons : in std_logic_vector(31 downto 0) := (others => '1');
		
		c64_keys	: in std_logic_vector(63 downto 0) :=X"FFFFFFFFFFFFFFFF";

		-- UART
		rxd	: in std_logic;
		txd	: out std_logic;
		intercept : out std_logic
);
end entity;

architecture rtl of substitute_mcu is

constant sysclk_hz : integer := sysclk_frequency*1000;
constant uart_divisor : integer := sysclk_hz/1152;
constant maxAddrBit : integer := 31;

signal platform : std_logic_vector(7 downto 0);

-- Define speeds for fast and slow SPI clocks.
-- Effective speed is sysclk / (2*(1+2^triggerbit))

signal reset_n : std_logic := '0';
signal reset : std_logic := '1';
signal reset_counter : unsigned(15 downto 0) := X"FFFF";

-- Millisecond counter
signal millisecond_counter : unsigned(31 downto 0) := X"00000000";
signal millisecond_tick : unsigned(19 downto 0);


-- SPI Clock counter
signal spi_ack_d : std_logic;
signal spi_req_out : std_logic;
signal spi_ack_r : std_logic;
signal spi_counter : unsigned(8 downto 0);
signal spi_tick : std_logic;
signal spi_fast_sd : std_logic;
signal spi_fast_int : std_logic;
signal spi_cs_int : std_logic;
signal spi_srtc_int : std_logic;

-- SPI signals
signal host_to_spi : std_logic_vector(7 downto 0);
signal spi_to_host : std_logic_vector(7 downto 0);
signal spi_trigger : std_logic;
signal spi_busy : std_logic;
signal spi_active : std_logic;
-- signal spi_active_d : std_logic_vector(4 downto 0);
signal spi_write : std_logic;
signal spi_setcs : std_logic;

signal spi_fromguest_sd : std_logic;
signal spi_mosi_int : std_logic;

-- UART signals

signal ser_txdata : std_logic_vector(7 downto 0);
signal ser_txready : std_logic;
signal ser_rxdata : std_logic_vector(7 downto 0);
signal ser_rxrecv : std_logic;
signal ser_txgo : std_logic;
signal ser_rxint : std_logic;


-- Interrupt signals

constant int_max : integer := 2;
signal int_triggers : std_logic_vector(int_max downto 0);
signal int_status : std_logic_vector(int_max downto 0);
signal int_ack : std_logic;
signal int_req : std_logic;
signal int_enabled : std_logic :='0'; -- Disabled by default
signal int_trigger : std_logic;


-- Timer register block signals

signal timer_reg_req : std_logic;
signal timer_tick : std_logic;


-- PS2 signals
signal ps2_int : std_logic;

signal kbdidle : std_logic;
signal kbdrecv : std_logic;
signal kbdrecvreg : std_logic;
signal kbdsendbusy : std_logic;
signal kbdsendtrigger : std_logic;
signal kbdsenddone : std_logic;
signal kbdsendbyte : std_logic_vector(7 downto 0);
signal kbdrecvbyte : std_logic_vector(10 downto 0);

signal mouseidle : std_logic;
signal mouserecv : std_logic;
signal mouserecvreg : std_logic;
signal mousesendbusy : std_logic;
signal mousesenddone : std_logic;
signal mousesendtrigger : std_logic;
signal mousesendbyte : std_logic_vector(7 downto 0);
signal mouserecvbyte : std_logic_vector(10 downto 0);


-- CPU signals
signal cpureset_n : std_logic;
signal soft_reset_n : std_logic;
signal mem_busy : std_logic;
signal mem_rom : std_logic;
signal rom_ack : std_logic;
signal from_mem : std_logic_vector(31 downto 0);
signal cpu_addr : std_logic_vector(31 downto 0);
signal to_cpu : std_logic_vector(31 downto 0);
signal from_cpu : std_logic_vector(31 downto 0);
signal from_rom : std_logic_vector(31 downto 0);
signal cpu_req : std_logic; 
signal cpu_ack : std_logic; 
signal cpu_wr : std_logic; 
signal cpu_bytesel : std_logic_vector(3 downto 0);
signal mem_rd : std_logic; 
signal mem_wr : std_logic; 
signal rom_wr : std_logic;
signal mem_rd_d : std_logic; 
signal mem_wr_d : std_logic; 
signal cache_valid : std_logic;
signal flushcaches : std_logic;
signal cpu_int : std_logic;

-- CPU Debug signals
signal debug_req : std_logic;
signal debug_ack : std_logic;
signal debug_fromcpu : std_logic_vector(31 downto 0);
signal debug_tocpu : std_logic_vector(31 downto 0);
signal debug_wr : std_logic;

-- Remapped joystick data
signal joy1_r : std_logic_vector(joybits-1 downto 0);
signal joy2_r : std_logic_vector(joybits-1 downto 0);
signal joy3_r : std_logic_vector(joybits-1 downto 0);
signal joy4_r : std_logic_vector(joybits-1 downto 0);

signal peripheral_block : std_logic_vector(3 downto 0);

begin

reset <= not reset_n;
cpureset_n <= reset_n and soft_reset_n;

platform(7 downto 1) <= (others=>'0');
platform(0) <= '1' when spirtc=true else '0';

-- Remap joystick data;
joy1_r(joybits-1 downto 4) <= not joy1(joybits-1 downto 4);
joy2_r(joybits-1 downto 4) <= not joy2(joybits-1 downto 4);
joy3_r(joybits-1 downto 4) <= not joy3(joybits-1 downto 4);
joy4_r(joybits-1 downto 4) <= not joy4(joybits-1 downto 4);
joy1_r(3 downto 0) <= not (joy1(0)&joy1(1)&joy1(2)&joy1(3));
joy2_r(3 downto 0) <= not (joy2(0)&joy2(1)&joy2(2)&joy2(3));
joy3_r(3 downto 0) <= not (joy3(0)&joy3(1)&joy3(2)&joy3(3));
joy4_r(3 downto 0) <= not (joy4(0)&joy4(1)&joy4(2)&joy4(3));

-- Reset counter.

process(clk, reset_in)
begin
	if reset_in='0' then -- or sdr_ready='0' then
		reset_counter<=X"FFFF";
		reset_n<='0';
	elsif rising_edge(clk) then
		reset_counter<=reset_counter-1;
		if reset_counter=X"0000" then
			reset_n<='1';
		end if;
	end if;
end process;

reset_out<=reset_n;

-- Timer
process(clk)
begin
	if rising_edge(clk) then
		timer_tick<='0';
		millisecond_tick<=millisecond_tick+1;
		if millisecond_tick=sysclk_frequency*100 then
			if millisecond_counter(3 downto 0)=X"0" then
				timer_tick<='1';
			end if;
			millisecond_counter<=millisecond_counter+1;
			millisecond_tick<=X"00000";
		end if;
	end if;
end process;


-- UART

genjtaguart:
if jtag_uart=true generate

myuart : entity work.jtag_uart
	generic map(
		enable_tx=>true,
		enable_rx=>true
	)
	port map(
		clk => clk,
		reset => reset_n, -- active low
		txdata => ser_txdata,
		txready => ser_txready,
		txgo => ser_txgo,
		rxdata => ser_rxdata,
		rxint => ser_rxint,
		txint => open,
		clock_divisor => to_unsigned(uart_divisor,16), -- 42MHz / 115,200 bps
		rxd => rxd,
		txd => txd
	);
end generate;

genuart:
if jtag_uart=false generate

myuart : entity work.simple_uart
	generic map(
		enable_tx=>true,
		enable_rx=>true
	)
	port map(
		clk => clk,
		reset => reset_n, -- active low
		txdata => ser_txdata,
		txready => ser_txready,
		txgo => ser_txgo,
		rxdata => ser_rxdata,
		rxint => ser_rxint,
		txint => open,
		clock_divisor => to_unsigned(uart_divisor,16), -- 42MHz / 115,200 bps
		rxd => rxd,
		txd => txd
	);
end generate;


-- PS2 devices

	mykeyboard : entity work.io_ps2_com
		generic map (
			clockFilter => 15,
			ticksPerUsec => sysclk_frequency/10
		)
		port map (
			clk => clk,
			reset => reset, -- active high!
			ps2_clk_in => ps2k_clk_in,
			ps2_dat_in => ps2k_dat_in,
			ps2_clk_out => ps2k_clk_out,
			ps2_dat_out => ps2k_dat_out,
			
			inIdle => open,	-- Probably don't need this
			sendTrigger => kbdsendtrigger,
			sendByte => kbdsendbyte,
			sendBusy => kbdsendbusy,
			sendDone => kbdsenddone,
			recvTrigger => kbdrecv,
			recvByte => kbdrecvbyte
		);


	mymouse : entity work.io_ps2_com
		generic map (
			clockFilter => 15,
			ticksPerUsec => sysclk_frequency/10
		)
		port map (
			clk => clk,
			reset => reset, -- active high!
			ps2_clk_in => ps2m_clk_in,
			ps2_dat_in => ps2m_dat_in,
			ps2_clk_out => ps2m_clk_out,
			ps2_dat_out => ps2m_dat_out,
			
			inIdle => open,	-- Probably don't need this
			sendTrigger => mousesendtrigger,
			sendByte => mousesendbyte,
			sendBusy => mousesendbusy,
			sendDone => mousesenddone,
			recvTrigger => mouserecv,
			recvByte => mouserecvbyte
		);

spi_req<=spi_req_out;

-- SPI Timer
process(clk)
begin
	if rising_edge(clk) then
		spi_counter<=spi_counter+1;
		spi_ack_d<=spi_ack;
		spi_tick<='0';
		if (spi_fast_sd='1' and SPI_EXTERNALCLK=true) then
			spi_tick<='1';
			spi_ack_r<=spi_ack_d;
			spi_counter<=(others=>'0');
		elsif (spi_fast_sd='1' and spi_counter(SPI_FASTBIT)='1')
--				or (spi_fast_int='1' and spi_counter(0)='1')
				or (spi_fast_int='1' and (spi_counter(SPI_INTERNALBIT)='1' or SPI_INTERNALBIT=0))
				or spi_counter(SPI_SLOWBIT)='1' then
			spi_ack_r<=spi_req_out;
			spi_tick<='1';
			spi_counter<=(others=>'0');
		end if;
	end if;
end process;


-- SPI host
spi : entity work.spi_controller
	port map(
		sysclk => clk,
		reset => reset_n,

		-- Host interface
		host_to_spi => host_to_spi,
		spi_to_host => spi_to_host,
		trigger => spi_trigger,
		busy => spi_busy,

		-- Hardware interface
		spi_req => spi_req_out,
		spi_ack => spi_ack_r,
		miso => spi_fromguest_sd,
		mosi => spi_mosi_int,
		spiclk_out => spi_clk
	);

-- SPI input will be SD card MISO when SPI_CD is low, otherwise the MISO signal from the guest
spi_srtc <= spi_srtc_int;
spi_cs <= spi_cs_int;
spi_mosi <= spi_mosi_int;
spi_fromguest_sd <= spi_miso when (spi_cs_int='0' or spi_srtc_int='0') else spi_fromguest;
spi_toguest <= spi_mosi_int;


-- Interrupt controller

intcontroller: entity work.interrupt_controller
generic map (
	max_int => int_max
)
port map (
	clk => clk,
	reset_n => cpureset_n,
	trigger => int_triggers,
	ack => int_ack,
	int => int_req,
	status => int_status
);

int_triggers<=(
	0=>'0',--timer_tick,
	1=>ps2_int,
	others => '0'
);


-- ROM

	rom : entity work.controller_rom
	port map(
		clk => clk,
		addr => cpu_addr(demistify_romspace-1 downto 2),
		d => from_cpu,
		q => from_rom,
		we => rom_wr,
		bytesel => cpu_bytesel
	);


-- Main CPU

	mem_rom <='1' when cpu_addr(31 downto 26)=X"0"&"00" else '0';
	mem_rd<='1' when cpu_req='1' and cpu_wr='0' and mem_rom='0' else '0';
	mem_wr<='1' when cpu_req='1' and cpu_wr='1' and mem_rom='0' else '0';
		
	process(clk)
	begin
		if rising_edge(clk) then
			rom_ack<=cpu_req and mem_rom;

			if mem_rom='1' and cpu_req='1' then
				to_cpu<=from_rom;
			else
				to_cpu<=from_mem;
			end if;

			if (mem_busy='0' or rom_ack='1') and cpu_ack='0' then
				cpu_ack<='1';
			else
				cpu_ack<='0';
			end if;

			if mem_rom='1' then
				rom_wr<=(cpu_wr and cpu_req);
			else
				rom_wr<='0';
			end if;
	
		end if;	
	end process;
	
	cpu_int <= int_req and int_enabled;
	
	cpu : entity work.eightthirtytwo_cpu
	generic map
	(
		littleendian => true,
		dualthread => false,
		prefetch => true,
		interrupts => true,
		debug => debug
	)
	port map
	(
		clk => clk,
		reset_n => cpureset_n,
		interrupt => cpu_int,

		-- cpu fetch interface

		addr => cpu_addr(31 downto 2),
		d => to_cpu,
		q => from_cpu,
		bytesel => cpu_bytesel,
		wr => cpu_wr,
		req => cpu_req,
		ack => cpu_ack,
		-- Debug signals
		debug_d=>debug_tocpu,
		debug_q=>debug_fromcpu,
		debug_req=>debug_req,
		debug_wr=>debug_wr,
		debug_ack=>debug_ack		
	);

	cpu_addr(1 downto 0)<="00";
	
gendebugbridge:
if debug=true generate
	debugbridge : entity work.debug_bridge_jtag
	port map
	(
		clk => clk,
		reset_n => reset_n,
		d => debug_fromcpu,
		q => debug_tocpu,
		req => debug_req,
		ack => debug_ack,
		wr => debug_wr
	);
end generate;

gennodebug:
if debug=false generate
	debug_ack<='0';
	debug_tocpu<=(others=>'0');
end generate;

peripheral_block <= cpu_addr(31)&cpu_addr(10 downto 8);

process(clk, reset_n)
begin
	if reset_n='0' then
		intercept<='0';
		spi_active<='0';
		int_enabled<='0';
		kbdrecvreg <='0';
		mouserecvreg <='0';
		spi_cs_int <= '1';
		spi_srtc_int <= '1';
		spi_ss2 <= '1';
		spi_ss3 <= '1';
		spi_ss4 <= '1';
		conf_data0 <= '1';
		spi_setcs <= '0';
		spi_write <= '0';
	elsif rising_edge(clk) then
		mem_busy<='1';
		ser_txgo<='0';
		int_ack<='0';
		timer_reg_req<='0';
		spi_trigger<='0';
		kbdsendtrigger<='0';
		mousesendtrigger<='0';
		flushcaches<='0';
		soft_reset_n<='1';
		
		mem_rd_d<=mem_rd;
		mem_wr_d<=mem_wr;

		-- Write from CPU?
		if mem_wr='1' and mem_wr_d='0' and mem_busy='1' then
			case peripheral_block is

--				when X"C" =>	-- Timer controller at 0xFFFFFC00
--					timer_reg_req<='1';
--					mem_busy<='0';	-- Timer controller never blocks the CPU

				when X"F" =>	-- Peripherals
					case cpu_addr(7 downto 0) is

						when X"B0" => -- Interrupts
							int_enabled<=from_cpu(0);
							mem_busy<='0';
							
						when X"B4" => -- Cache control
							flushcaches<=from_cpu(0);
							mem_busy<='0';

						when X"C0" => -- UART
							ser_txdata<=from_cpu(7 downto 0);
							ser_txgo<='1';
							mem_busy<='0';

						when X"D0" => -- SPI CS
							spi_setcs<='1';

						when X"D4" => -- SPI Data
							spi_write<='1';
							spi_active<='1';
						
--						when X"D8" => -- SPI Pump
--							spi_trigger<='1';
--							host_to_spi<=from_cpu(7 downto 0);
--							spi_active<='1';

						-- Write to PS/2 registers
						when X"e0" =>
							kbdsendbyte<=from_cpu(7 downto 0);
							kbdsendtrigger<='1';
							mem_busy<='0';

						when X"e4" =>
							mousesendbyte<=from_cpu(7 downto 0);
							mousesendtrigger<='1';
							mem_busy<='0';
							
						when X"fc" =>
							intercept <= from_cpu(0);
							mem_busy<='0';
							
						when others =>
							mem_busy<='0';
							null;
					end case;
				when others =>
					mem_busy<='0';
			end case;

		elsif mem_rd='1' and mem_rd_d='0' and mem_busy='1' then -- Read from CPU?
			case cpu_addr(31 downto 28) is

				when X"F" =>	-- Peripherals
					case cpu_addr(7 downto 0) is

						when X"90" => -- c64 keyboard
							from_mem<=c64_keys(63 downto 32);
							mem_busy<='0';

						when X"94" => -- c64 keyboard
							from_mem<=c64_keys(31 downto 0);
							mem_busy<='0';
					
						when X"B0" => -- Interrupt
							from_mem<=(others=>'X');
							from_mem(int_max downto 0)<=int_status;
							int_ack<='1';
							mem_busy<='0';

						when X"C0" => -- UART
							from_mem<=(others=>'X');
							from_mem(9 downto 0)<=ser_rxrecv&ser_txready&ser_rxdata;
							ser_rxrecv<='0';	-- Clear rx flag.
							mem_busy<='0';
							
						when X"C8" => -- Millisecond counter
							from_mem<=std_logic_vector(millisecond_counter);
							mem_busy<='0';

--						when X"D0" => -- SPI Status
--							from_mem<=(others=>'X');
--							from_mem(15)<=spi_busy;
--							mem_busy<='0';

						when X"D4" => -- SPI read (blocking)
							spi_active<='1';

--						when X"D8" => -- SPI pump (blocking)
--							spi_trigger<='1';
--							host_to_spi<=X"FF";
--							spi_active<='1';

						-- Read from PS/2 regs
						when X"E0" =>
							from_mem<=(others =>'0');
							from_mem(11 downto 0)<=kbdrecvreg & not kbdsendbusy & kbdrecvbyte(10 downto 1);
							kbdrecvreg<='0';
							mem_busy<='0';
							
						when X"E4" =>
							from_mem<=(others =>'0');
							from_mem(11 downto 0)<=mouserecvreg & not mousesendbusy & mouserecvbyte(10 downto 1);
							mouserecvreg<='0';
							mem_busy<='0';

						when X"E8" => -- joysticks - ports 1 and 2;
							-- Pack the joystick bits right-aligned, so that if joybits=8 the layout is the same as before for ports 1 and 2
							from_mem <= (others => '0');
							from_mem(joybits*2-1 downto joybits) <= joy2_r;
							from_mem(joybits-1 downto 0) <= joy1_r;
							mem_busy<='0';

						when X"EC" => -- Misc inputs;
							from_mem(31 downto 0)<=not buttons;
							mem_busy<='0';

						when X"F0" => -- joysticks - ports 3 and 4;
							from_mem <= (others => '0');
							from_mem(joybits*2-1 downto joybits) <= joy4_r;
							from_mem(joybits-1 downto 0) <= joy3_r;
							mem_busy<='0';

						when X"FC" => -- Platform capabilities;
							from_mem<=(others => '0');
							from_mem(7 downto 0)<=platform;
							mem_busy<='0';

						when others =>
							mem_busy<='0';
					end case;

				when others =>
					mem_busy<='0';
			end case;
		end if;
	
		-- SPI cycles

		if spi_active='1' and spi_busy='0' and spi_tick='1' then
			if spi_write='1' then
				spi_trigger<='1';
				host_to_spi<=from_cpu(7 downto 0);
				spi_write<='0';
			end if;
			from_mem<=X"000000"&spi_to_host;
			spi_active<='0';
			mem_busy<='0';
		end if;

		if spi_setcs='1' and spi_busy='0' and spi_tick='1' then
			if from_cpu(1)='1' then
				spi_cs_int <= not from_cpu(0);
			end if;
			if from_cpu(2)='1' then
				spi_ss2 <= not from_cpu(0);
			end if;
			if from_cpu(3)='1' then
				spi_ss3 <= not from_cpu(0);
			end if;
			if from_cpu(4)='1' then
				spi_ss4 <= not from_cpu(0);
			end if;
			if from_cpu(5)='1' then
				conf_data0 <= not from_cpu(0);
			end if;
			if from_cpu(6)='1' then
				spi_srtc_int <= not from_cpu(0);
			end if;
			if from_cpu(0)='1' then
				spi_fast_sd<=from_cpu(8);
				spi_fast_int<=from_cpu(9);
			end if;
			spi_setcs<='0';
			mem_busy<='0';
		end if;

		-- Set this after the read operation has potentially cleared it.
		if ser_rxint='1' then
			ser_rxrecv<='1';
		end if;

		-- PS2 interrupt
		ps2_int <= kbdrecv or kbdsenddone
			or mouserecv or mousesenddone;
		if kbdrecv='1' then
			kbdrecvreg <= '1'; -- remains high until cleared by a read
		end if;
		if mouserecv='1' then
			mouserecvreg <= '1'; -- remains high until cleared by a read
		end if;	

	end if; -- rising-edge(clk)

end process;

end architecture;

