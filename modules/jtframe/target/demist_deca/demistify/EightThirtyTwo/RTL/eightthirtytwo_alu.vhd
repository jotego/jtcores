-- eightthirtytwo_alu.vhd
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


entity eightthirtytwo_alu is
generic(
	multiplier : boolean := true
);
port(
	clk : in std_logic;
	reset_n : in std_logic;

	imm : in std_logic_vector(5 downto 0);
	d1 : in std_logic_vector(31 downto 0);
	d2 : in std_logic_vector(31 downto 0);
	op : in std_logic_vector(3 downto 0);
	sgn : in std_logic;
	req : in std_logic;

	q1 : out std_logic_vector(31 downto 0);
	q2 : buffer std_logic_vector(31 downto 0);
	carry : out std_logic;
	ack : out std_logic;
	forward_q2tod1 : in std_logic := '0'
);
end entity;

architecture rtl of eightthirtytwo_alu is

signal sgn_mod : std_logic;
signal d1_sgn : std_logic;
signal d2_sgn : std_logic;
signal d1_2 : std_logic_vector(31 downto 0);
signal d2_2 : std_logic_vector(31 downto 0);
signal busyflag : std_logic;
signal addresult : unsigned(33 downto 0);
signal mulresult : signed(65 downto 0);
signal immresult : std_logic_vector(31 downto 0);

signal shiftresult : std_logic_vector(31 downto 0);
signal shiftcarry : std_logic;
signal shiftack : std_logic;
signal shiftrl : std_logic;
signal shiftrot : std_logic;
signal shiftreq : std_logic;

signal sublsb : std_logic;

signal immediatestreak : std_logic;

begin


sgn_mod<=(not sgn) and (d1(31) xor d2(31)) and op(0); -- op(0) differentiates add from sub.

with op select shiftreq <=
	req when e32_alu_shr,
	req when e32_alu_shl,
	req when e32_alu_ror,
	'0' when others;

with op select shiftrl <=
	'1' when e32_alu_shr,
	'1' when e32_alu_ror,
	'0' when others;

with op select shiftrot <=
	'1' when e32_alu_ror,
	'0' when others;

with op select d2_2 <=
	X"00000001" when e32_alu_incb,
	X"00000004" when e32_alu_incw,
	X"FFFFFFFC" when e32_alu_decw,
	d2 xor X"FFFFFFFF" when e32_alu_sub,
	d2 when others;

d1_2 <= q2 when forward_q2tod1='1' else d1;

sublsb<='1' when op=e32_alu_sub else '0';

ack <= shiftack or busyflag;

-- FIXME - signed/unsigned comparisons aren't working correctly
d1_sgn<=d1_2(31) when op=e32_alu_sub else '0';
d2_sgn<=d2_2(31) when op=e32_alu_sub else '0';

addresult <= unsigned(d1_sgn&d1_2&sublsb) + unsigned(d2_sgn&d2_2&sublsb);

genmult : if multiplier=true generate
	signal mulclk : std_logic;
begin
	mulclk <= clk;
	
	process(mulclk) begin
		if rising_edge(mulclk) then
			mulresult <= signed((d1(31) and sgn)&d1) * signed((d2(31) and sgn)&d2);
		end if;
	end process;
end generate;

process(clk,reset_n)
begin
	if reset_n='0' then
		busyflag<='0';
		carry<='0';
		immediatestreak<='0';
	elsif rising_edge(clk) then

		immediatestreak<='0';
		busyflag<='0';

		case op is
			when e32_alu_and =>
				q1<=d1_2 and d2;
--				carry<='-';
				q2 <= d2;
			
			when e32_alu_or =>
				q1<=d1_2 or d2;
--				carry<='-';
				q2 <= d2;
					
			when e32_alu_xor =>
				q1<=d1_2 xor d2;
--				carry<='-';
				q2 <= d2;
					
			when e32_alu_shl =>
				q1<=shiftresult; -- fixme - unnecessary delay here
				carry<=shiftcarry;
				q2 <= d2;

			when e32_alu_shr =>
				q1<=shiftresult; -- fixme - unnecessary delay here
				carry<=shiftcarry;
				q2 <= d2;

			when e32_alu_ror =>
				q1<=shiftresult; -- fixme - unnecessary delay here
				carry<=shiftcarry;
				q2 <= d2;

			when e32_alu_incb =>
				busyflag<=req;
				if req='1' then
					q1<=d1_2;
				else
					q1<=std_logic_vector(addresult(32 downto 1));
				end if;
--				carry<='-';
				q2 <= d2;

			when e32_alu_incw =>
				busyflag<=req;
				if req='1' then
					q1<=d1_2;
				else
					q1<=std_logic_vector(addresult(32 downto 1));
				end if;
--				carry<='-';
				q2 <= d2;
				
			when e32_alu_decw =>
				q1<=std_logic_vector(addresult(32 downto 1));
--				carry<='-';
				q2 <= d2;

			when e32_alu_addt =>
				q1 <=std_logic_vector(addresult(32 downto 1));
				q2 <= d2;
				carry<=addresult(33) xor sgn_mod;
			
			when e32_alu_add =>
				q1 <=std_logic_vector(addresult(32 downto 1));
				q2 <= d2;
				carry<=addresult(33) xor sgn_mod;
			
			when e32_alu_sub =>
				q1 <=std_logic_vector(addresult(32 downto 1));
				q2 <= d2;
				carry<=addresult(33) xor sgn_mod;

			when e32_alu_mul =>
				busyflag<=req;
				carry<=mulresult(64); -- FIXME - check carry semantics for MUL
				q1 <= std_logic_vector(mulresult(31 downto 0));
				q2 <= std_logic_vector(mulresult(63 downto 32));

			when e32_alu_li =>
				if immediatestreak='1' then	-- Keep the streak alive during bubbles
					immediatestreak<='1';
				end if;
				if req='1' then
					immediatestreak<='1';
					if immediatestreak='0' then
						q2(31 downto 6)<=(others=>imm(5));
					else
						q2(31 downto 6)<=q2(25 downto 0);
					end if;
					q2(5 downto 0)<=imm(5 downto 0);
				end if;

			when others =>
--				carry<='-';
				q1<=d1_2;
				q2<=d2;

		end case;
		
	end if;
	
end process;

shifter : entity work.eightthirtytwo_shifter
port map(
	clk => clk,
	reset_n => reset_n,
	d => d1_2,
	q => shiftresult,
	carry => shiftcarry,
	shift => d2(4 downto 0),
--	immediate : in std_logic_vector(5 downto 0);
	right_left => shiftrl,
	sgn => sgn,
	rotate => shiftrot,
	req => shiftreq,
	ack => shiftack
);

end architecture;
