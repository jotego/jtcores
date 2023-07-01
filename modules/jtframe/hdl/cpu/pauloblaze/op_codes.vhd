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
use IEEE.NUMERIC_STD.ALL;

package op_codes is

constant OP_LOAD_SX_SY : unsigned(5 downto 0) :=  "000000";
constant OP_LOAD_SX_KK : unsigned(5 downto 0) :=  "000001";
constant OP_STAR_SX_SY : unsigned(5 downto 0) :=  "010110";

constant OP_AND_SX_SY : unsigned(5 downto 0) :=  "000010";
constant OP_AND_SX_KK : unsigned(5 downto 0) :=  "000011";
constant OP_OR_SX_SY : unsigned(5 downto 0) :=  "000100";
constant OP_OR_SX_KK : unsigned(5 downto 0) :=  "000101";
constant OP_XOR_SX_SY : unsigned(5 downto 0) :=  "000110";
constant OP_XOR_SX_KK : unsigned(5 downto 0) :=  "000111";

constant OP_ADD_SX_SY : unsigned(5 downto 0) :=  "010000";
constant OP_ADD_SX_KK : unsigned(5 downto 0) :=  "010001";
constant OP_ADDCY_SX_SY : unsigned(5 downto 0) :=  "010010";
constant OP_ADDCY_SX_KK : unsigned(5 downto 0) :=  "010011";
constant OP_SUB_SX_SY : unsigned(5 downto 0) :=  "011000";
constant OP_SUB_SX_KK : unsigned(5 downto 0) :=  "011001";
constant OP_SUBCY_SX_SY : unsigned(5 downto 0) :=  "011010";
constant OP_SUBCY_SX_KK : unsigned(5 downto 0) :=  "011011";

constant OP_TEST_SX_SY : unsigned(5 downto 0) :=  "001100";
constant OP_TEST_SX_KK : unsigned(5 downto 0) :=  "001101";
constant OP_TESTCY_SX_SY : unsigned(5 downto 0) :=  "001110";
constant OP_TESTCY_SX_KK : unsigned(5 downto 0) :=  "001111";
constant OP_COMPARE_SX_SY : unsigned(5 downto 0) :=  "011100";
constant OP_COMPARE_SX_KK : unsigned(5 downto 0) :=  "011101";
constant OP_COMPARECY_SX_SY : unsigned(5 downto 0) :=  "011110";
constant OP_COMPARECY_SX_KK : unsigned(5 downto 0) :=  "011111";

constant OP_SL0_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SL1_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SLX_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SLA_SX : unsigned(5 downto 0) :=  "010100";
constant OP_RL_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SR0_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SR1_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SRX_SX : unsigned(5 downto 0) :=  "010100";
constant OP_SRA_SX : unsigned(5 downto 0) :=  "010100";
constant OP_RR_SX : unsigned(5 downto 0) :=  "010100";

constant OP_REGBANK_A : unsigned(5 downto 0) :=  "110111";
constant OP_REGBANK_B : unsigned(5 downto 0) :=  "110111";

constant OP_INPUT_SX_SY : unsigned(5 downto 0) :=  "001000";
constant OP_INPUT_SX_PP : unsigned(5 downto 0) :=  "001001";
constant OP_OUTPUT_SX_SY : unsigned(5 downto 0) :=  "101100";
constant OP_OUTPUT_SX_PP : unsigned(5 downto 0) :=  "101101";
constant OP_OUTPUTK_KK_P : unsigned(5 downto 0) :=  "101011";


constant OP_STORE_SX_SY : unsigned(5 downto 0) :=  "101110";
constant OP_STORE_SX_SS : unsigned(5 downto 0) :=  "101111";
constant OP_FETCH_SX_SY : unsigned(5 downto 0) :=  "001010";
constant OP_FETCH_SX_SS : unsigned(5 downto 0) :=  "001011";

constant OP_DISABLE_INTERRUPT : unsigned(5 downto 0) :=  "101000";
constant OP_ENABLE_INTERRUPT : unsigned(5 downto 0) :=  "101000";
constant OP_RETURNI_DISABLE : unsigned(5 downto 0) :=  "101001";
constant OP_RETURNI_ENABLE : unsigned(5 downto 0) :=  "101001";

constant OP_JUMP_AAA : unsigned(5 downto 0) :=  "100010";
constant OP_JUMP_Z_AAA : unsigned(5 downto 0) :=  "110010";
constant OP_JUMP_NZ_AAA : unsigned(5 downto 0) :=  "110110";
constant OP_JUMP_C_AAA : unsigned(5 downto 0) :=  "111010";
constant OP_JUMP_NC_AAA : unsigned(5 downto 0) :=  "111110";
constant OP_JUMP_SX_SY : unsigned(5 downto 0) :=  "100110";

constant OP_CALL_AAA : unsigned(5 downto 0) :=  "100000";
constant OP_CALL_Z_AAA : unsigned(5 downto 0) :=  "110000";
constant OP_CALL_NZ_AAA : unsigned(5 downto 0) :=  "110100";
constant OP_CALL_C_AAA : unsigned(5 downto 0) :=  "111000";
constant OP_CALL_NC_AAA : unsigned(5 downto 0) :=  "111100";
constant OP_CALL_SX_SY : unsigned(5 downto 0) :=  "100100";
constant OP_RETURN : unsigned(5 downto 0) :=  "100101";
constant OP_RETURN_Z : unsigned(5 downto 0) :=  "110001";
constant OP_RETURN_NZ : unsigned(5 downto 0) :=  "110101";
constant OP_RETURN_C : unsigned(5 downto 0) :=  "111001";
constant OP_RETURN_NC : unsigned(5 downto 0) :=  "111101";
constant OP_LOADRETURN_SX_KK : unsigned(5 downto 0) :=  "100001";

constant OP_HWBUILD_SX : unsigned(5 downto 0) :=  "010100";

end op_codes;

package body op_codes is

end op_codes;
