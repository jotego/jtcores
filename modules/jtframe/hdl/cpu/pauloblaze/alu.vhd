-- EMACS settings: -*- tab-width: 4; indent-tabs-mode: t -*-
-- vim: tabstop=4:shiftwidth=4:noexpandtab
-- kate: tab-width 4; replace-tabs off; indent-width 4;
--
-- =============================================================================
-- Authors: Paul Genssler
--
-- Description:
-- ------------------------------------
-- TODO
--
-- License:
-- =============================================================================
-- Copyright 2007-2015 Paul Genssler - Dresden, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS is" BASIS,
-- WITHOUT WARRANTIES or CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.op_codes.all;

entity pauloALU is
	generic (
		debug : boolean := false;
		hwbuild : unsigned(7 downto 0) := X"41"
	);
	port (
		clk             : in STD_LOGIC;
		clk2            : in STD_LOGIC;
		reset           : in STD_LOGIC;
		sleep_int       : in STD_LOGIC;
		opcode          : in unsigned (5 downto 0);
		opB             : in unsigned (7 downto 0);
		preserve_flags  : in std_logic;
		restore_flags   : in std_logic;
		carry           : out STD_LOGIC;
		zero            : out STD_LOGIC;

		reg_value       : out unsigned (7 downto 0);
		reg_we          : out std_logic;
		reg_reg0        : in unsigned (7 downto 0);
		reg_reg1        : in unsigned (7 downto 0)
	);
end pauloALU;

architecture Behavioral of pauloALU is


	signal result : unsigned(7 downto 0);
	signal res_valid : std_logic; -- result should be written to register

	signal inter_flank : std_logic;
	signal carry_c : std_logic;
	signal carry_o : std_logic;
	signal carry_i : std_logic; -- saved during interrupt
	signal zero_i : std_logic; -- same
	signal zero_c : std_logic;
	signal zero_o : std_logic;

	-- signal debug_opA_value : unsigned(7 downto 0);
	-- signal debug_opB_value : unsigned(7 downto 0);

begin

	process (clk)
	begin
		if rising_edge(clk) then
			reg_value <= result;
			reg_we <= not clk2 and res_valid and not sleep_int;
		end if;
	end process;

	carry <= carry_o;
	zero <= zero_o;

	op : process (reset, opcode, opB, carry_o, zero_o, reg_reg0, reg_reg1, clk2)
		variable opB_value : unsigned(7 downto 0);
		variable opA_value : unsigned(7 downto 0);
		variable result_v : unsigned(8 downto 0);
		variable parity_v : std_logic;
		variable padding : std_logic;
		variable tmp : std_logic;
	begin
		opA_value := reg_reg0;
		if (opcode (0) = '0') then -- LSB 0 = op_x sx, sy
			opB_value := reg_reg1;
		else -- LSB 1 = op_x sx, kk
			opB_value := opB;
		end if;

		if (debug) then
			padding := '0'; --looks better during simulation
			-- debug_opA_value <= opA_value;
			-- debug_opB_value <= opB_value;
		else
			padding := '-';
		end if;
		res_valid <= '0';
		carry_c <= carry_o;
		zero_c <= zero_o;
		result_v := (others => padding);
		parity_v := '0';

		if (reset = '0') then
			case opcode is
				--register loading
				when OP_LOAD_SX_SY | OP_LOAD_SX_KK | OP_LOADRETURN_SX_KK =>
					result_v := padding & opB_value;
					res_valid <= '1';
				when OP_STAR_SX_SY =>
					--Logical
				when OP_AND_SX_SY | OP_AND_SX_KK =>
					result_v := padding & (opA_value and opB_value);
					res_valid <= '1';
					if (result_v(7 downto 0) = "00000000") then
						zero_c <= '1';
					else
						zero_c <= '0';
					end if;
					carry_c <= '0';
				when OP_OR_SX_SY | OP_OR_SX_KK =>
					result_v := padding & (opA_value or opB_value);
					res_valid <= '1';
					if (result_v(7 downto 0) = "00000000") then
						zero_c <= '1';
					else
						zero_c <= '0';
					end if;
					carry_c <= '0';
				when OP_XOR_SX_SY | OP_XOR_SX_KK =>
					result_v := padding & (opA_value xor opB_value);
					res_valid <= '1';
					if (result_v(7 downto 0) = "00000000") then
						zero_c <= '1';
					else
						zero_c <= '0';
					end if;
					carry_c <= '0';
					--Arithmetic
				when OP_ADD_SX_SY | OP_ADD_SX_KK | OP_SUB_SX_SY | OP_SUB_SX_KK |
					OP_ADDCY_SX_SY | OP_ADDCY_SX_KK | OP_SUBCY_SX_SY | OP_SUBCY_SX_KK =>
					if (opcode(3) = '0') then
						result_v := ('0' & opA_value) + ('0' & opB_value) + ("" & (carry_o and opCode(1)));
					else
						result_v := ('0' & opA_value) - ('0' & opB_value) - ("" & (carry_o and opCode(1)));
					end if;

					if (result_v(7 downto 0) = "00000000") then
						if (opcode = OP_ADDCY_SX_SY or opcode = OP_ADDCY_SX_KK or opcode = OP_SUBCY_SX_SY or opcode = OP_SUBCY_SX_KK) then
							zero_c <= zero_o;
						else
							zero_c <= '1';
						end if;
					else
						zero_c <= '0';
					end if;
					carry_c <= result_v(8);
					res_valid <= '1';
					--Test and Compare
				when OP_TEST_SX_SY | OP_TEST_SX_KK | OP_TESTCY_SX_SY | OP_TESTCY_SX_KK =>
					result_v := (padding & (opA_value and opB_value));
					-- opCode(1) == 0 : TEST
					-- opCode(1) == 1 : TESTCY
					if (result_v(7 downto 0) = "00000000") then
						if (opCode(1) = '0') then
							zero_c <= '1';
						else
							zero_c <= zero_o;
						end if;
					else
						zero_c <= '0';
					end if;

					for i in 0 to 7 loop
						parity_v := parity_v xor result_v(i);
					end loop;
					if (opCode(1) = '0') then
						-- TEST
						carry_c <= parity_v;
					else
						-- TESTCY
						carry_c <= parity_v xor carry_o;
					end if;
				when OP_COMPARE_SX_SY | OP_COMPARE_SX_KK | OP_COMPARECY_SX_SY | OP_COMPARECY_SX_KK =>
					-- opCode(1) == 0 : COMPARE
					-- opCode(1) == 1 : COMPARECY
					-- mask carry with it
					result_v := ('0' & opA_value) - ('0' & opB_value) - ("" & (opCode(1) and carry_o));

					if (result_v(7 downto 0) = "00000000") then
						if (opCode(1) = '0') then
							zero_c <= '1';
						else
							zero_c <= zero_o;
						end if;
					else
						zero_c <= '0';
					end if;

					carry_c <= result_v(8);
					--Shift and Rotate ... and hwbuild OP_HWBUILD_SX
				when OP_SL0_SX =>
					if (opB(7) = '1') then -- hw build op
						result_v := padding & hwbuild;
						res_valid <= '1';
						carry_c <= '1';
						if (result_v(7 downto 0) = "00000000") then
							zero_c <= '1';
						else
							zero_c <= '0';
						end if;
					else
						-- shift and rotate
						case opB(2 downto 0) is
							when "110" | "111" =>
								tmp := opB(0);
							when "010" => -- RL
								tmp := opA_value(7);
							when "100" => -- RR
								tmp := opA_value(0);
							when "000" =>
								tmp := carry_o;
							when others =>
								tmp := '0';
						end case;

						if (opB(3) = '1') then
							result_v := opA_value(0) & tmp & opA_value(7 downto 1);
						else -- concat the carry value into the result and shift
							result_v := opA_value(7) & opA_value(6 downto 0) & tmp;
						end if;

						carry_c <= result_v(8);
						if (result_v(7 downto 0) = "00000000") then
							zero_c <= '1';
						else
							zero_c <= '0';
						end if;
						res_valid <= '1';
					end if;
				when others =>
					result_v := (others => padding);
			end case;
		end if;
		result <= result_v(7 downto 0);
	end process;

	flags : process (clk) begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				carry_o <= '0';
				zero_o <= '0';
				carry_i <= '0';
				zero_i <= '0';
			else
				if (preserve_flags = '1') then
					-- preserve flags
					carry_i <= carry_o;
					zero_i <= zero_o;
				end if;
				if (restore_flags = '1') then
					-- restore flags
					carry_o <= carry_i;
					zero_o <= zero_i;
				elsif (clk2 = '1') then
					carry_o <= carry_c;
					zero_o <= zero_c;
				else
					carry_o <= carry_o;
					zero_o <= zero_o;
				end if;
			end if;
		end if;
	end process flags;

end Behavioral;

