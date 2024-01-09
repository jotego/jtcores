-- debug_bridge_jtag.vhd
-- Copyright 2022 by Alastair M. Robinson

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

-- This is just a stub to allow compilation against a GHDL testbench.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debug_bridge_jtag is
generic (
	id : natural := 16#832D#
);
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

architecture rtl of debug_bridge_jtag is

signal clk_inv : std_logic;

type states is (IDLE, READADDR,GETRESPONSE,STEP);
signal state : states ;
signal counter : unsigned(15 downto 0);
signal data : std_logic_vector(31 downto 0);

-- JTAG signals

constant TX	: std_logic_vector(1 downto 0) := "00";
constant RX	: std_logic_vector(1 downto 0) := "01";
constant STATUS : std_logic_vector(1 downto 0) := "10";
constant BYPASS : std_logic_vector(1 downto 0) := "11";

signal ir : std_logic_vector(1 downto 0);
signal vstate_cdr : std_logic;
signal vstate_sdr : std_logic;
signal vstate_udr : std_logic;
signal vstate_uir : std_logic;
signal tdo : std_logic;
signal tdi : std_logic;
signal tck : std_logic;

signal cdr_d : std_logic;
signal sdr_d : std_logic;

signal shift : std_logic_vector(31 downto 0);
signal bp : std_logic_vector(1 downto 0);

-- FIFO control signals

signal txmt : std_logic;
signal txfl : std_logic;
signal txdata : std_logic_vector(31 downto 0);
signal txwr_req : std_logic;
signal txrd_req : std_logic;

signal rxmt : std_logic;
signal rxfl : std_logic;
signal rxwr_req : std_logic;
signal rxrd_req : std_logic;

begin

clk_inv <= not clk;

tdo <= bp(0) when ir=BYPASS else shift(0);


virtualjtag : entity work.debug_virtualjtag_sim_ghdl
port map(
	ir_out => ir,
	tdo => tdo,
	tck => tck,
	tdi => tdi,
	virtual_state_cdr => vstate_cdr,
	virtual_state_sdr => vstate_sdr,
	virtual_state_udr => vstate_udr,
	virtual_state_uir => vstate_uir
);


fifotojtag : entity work.debug_fifo
port map (
	din => d,
	wr_clk => clk_inv,
	wr_en => txwr_req,
	full => txfl,

	rd_clk => tck,
	rd_en => txrd_req,
	dout => txdata,
	empty => txmt
);

txrd_req <= vstate_cdr when ir=TX else '0';


fifofromjtag : entity work.debug_fifo
port map (
	din => shift,
	wr_clk => tck,
	wr_en => rxwr_req,
	full => rxfl,

	rd_clk => clk_inv,
	rd_en => rxrd_req,
	dout => q,
	empty => rxmt
);

rxwr_req <= vstate_udr when ir=RX else '0';


process(clk,reset_n)
begin

	if reset_n='0' then

	elsif rising_edge(clk) then
	
		rxrd_req<='0';
		txwr_req<='0';
		ack<='0';
	
		if req='1' and ack='0' then
			if wr='1' and txfl='0' then
				txwr_req<='1';
				ack<='1';
			elsif wr='0' and rxmt='0' then
				rxrd_req<='1';
				ack<='1';
			end if;
		end if;
		
--		if rxrd_req='1' then
--			ack<='1';
--		end if;
	
	end if;

end process;


cdr_d <= vstate_cdr;
sdr_d <= vstate_sdr;

process (tck)
begin
	if rising_edge(tck) then
		case ir is
			when TX =>
				if cdr_d='1' then
					shift <= txdata;
				elsif sdr_d='1' then
					shift <= tdi&shift(31 downto 1);
				end if;

			when RX =>
				if sdr_d='1' then
					shift <= tdi&shift(31 downto 1);
				end if;

			when STATUS =>
				if cdr_d='1' then
					shift <= std_logic_vector(to_unsigned(id,16))
									&X"000"& rxfl & rxmt & txfl & txmt;
				elsif sdr_d='1' then 
					shift <= tdi&shift(31 downto 1);
				end if;

			when others =>
				if sdr_d='1' then
					bp <= tdi&bp(1);
				end if;
		end case;

	end if;

end process;

end architecture;

