-- eightthirtytwo_pkg.vhd
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

package eightthirtytwo_pkg is

-- Opcodes in use - most take register 0-7 as a parameter in the low 3 bits.
-- Since not all ops make sense when applied to the program counter,
-- some opcodes are overloaded when the register is 7.
--
-- Opcode 40 is currently unused
-- ldbinc, stdec, shr, shl, ror, stbinc, ld and st are all available
-- for overloading - but st and stdec both offer some interesting
-- if mind-bending possibilities for self-modifying code.

constant e32_op_cond : std_logic_vector(7 downto 0) := X"00";
constant e32_op_exg : std_logic_vector(7 downto 0) := X"08";
constant e32_op_ldbinc : std_logic_vector(7 downto 0) := X"10";
constant e32_op_stdec : std_logic_vector(7 downto 0) := X"18";

constant e32_op_ldinc : std_logic_vector(7 downto 0) := X"20";
constant e32_op_shr : std_logic_vector(7 downto 0) := X"28";
constant e32_op_shl : std_logic_vector(7 downto 0) := X"30";
constant e32_op_ror : std_logic_vector(7 downto 0) := X"38";

constant e32_op_stinc : std_logic_vector(7 downto 0) := X"40"; -- Available for re-use
constant e32_op_mr : std_logic_vector(7 downto 0) := X"48";
constant e32_op_stbinc : std_logic_vector(7 downto 0) := X"50";
constant e32_op_stmpdec : std_logic_vector(7 downto 0) := X"58";

constant e32_op_ldidx : std_logic_vector(7 downto 0) := X"60";
constant e32_op_ld : std_logic_vector(7 downto 0) := X"68";
constant e32_op_mt : std_logic_vector(7 downto 0) := X"70";
constant e32_op_st : std_logic_vector(7 downto 0) := X"78";
 
-- Add's behaviour is different for r7 - perhaps use a different mnemonic?
constant e32_op_add : std_logic_vector(7 downto 0) := X"80";
constant e32_op_sub : std_logic_vector(7 downto 0) := X"88";
constant e32_op_mul : std_logic_vector(7 downto 0) := X"90";
constant e32_op_and : std_logic_vector(7 downto 0) := X"98";

constant e32_op_addt : std_logic_vector(7 downto 0) := X"a0";
constant e32_op_cmp : std_logic_vector(7 downto 0) := X"a8";
constant e32_op_or : std_logic_vector(7 downto 0) := X"b0";
constant e32_op_xor : std_logic_vector(7 downto 0) := X"b8";

constant e32_op_li : std_logic_vector(7 downto 0) := X"c0";

-- Overloaded opcodes.  Mostly ops that make no sense when applied to R7
-- Not actually referred to by name, overloading is handled during decoding
-- constant e32_op_addl : std_logic_vector(7 downto 0) := X"87";  -- add with Link (tmp+r7 -> r7, r7->tmp), overloads add
-- constant e32_op_byt : std_logic_vector(7 downto 0) := X"97";  -- byt, overloads mul
-- constant e32_op_hlf : std_logic_vector(7 downto 0) := X"9f";  -- hlf, overloads and
-- constant e32_op_sig : std_logic_vector(7 downto 0) := X"af";  -- sig, overloads cmp
-- constant e32_op_sgn : std_logic_vector(7 downto 0) := X"b7";  -- sgn, overloads or
-- constant e32_op_ldt : std_logic_vector(7 downto 0) := X"b8";  -- ldt, overloads xor


-- Condional codes

constant e32_cond_nex : std_logic_vector(2 downto 0) := "000";
constant e32_cond_sgt : std_logic_vector(2 downto 0) := "001";
constant e32_cond_eq : std_logic_vector(2 downto 0) := "010";
constant e32_cond_ge : std_logic_vector(2 downto 0) := "011";
constant e32_cond_slt : std_logic_vector(2 downto 0) := "100";
constant e32_cond_neq : std_logic_vector(2 downto 0) := "101";
constant e32_cond_le : std_logic_vector(2 downto 0) := "110";
constant e32_cond_ex : std_logic_vector(2 downto 0) := "111";

-- ALU functions

constant e32_alu_add : std_logic_vector(3 downto 0) := "0000";
constant e32_alu_sub : std_logic_vector(3 downto 0) := "0001";
constant e32_alu_mul : std_logic_vector(3 downto 0) := "0010";
constant e32_alu_and : std_logic_vector(3 downto 0) := "0011";

constant e32_alu_addt : std_logic_vector(3 downto 0) := "0100";
constant e32_alu_li : std_logic_vector(3 downto 0) := "0101";
constant e32_alu_or : std_logic_vector(3 downto 0) := "0110";
constant e32_alu_xor : std_logic_vector(3 downto 0) := "0111";

constant e32_alu_nop : std_logic_vector(3 downto 0) := "1000";
constant e32_alu_exg : std_logic_vector(3 downto 0) := "1001";
constant e32_alu_incb : std_logic_vector(3 downto 0) := "1010";
constant e32_alu_decw : std_logic_vector(3 downto 0) := "1011";

constant e32_alu_incw : std_logic_vector(3 downto 0) := "1100";
constant e32_alu_shr : std_logic_vector(3 downto 0) := "1101";
constant e32_alu_shl : std_logic_vector(3 downto 0) := "1110";
constant e32_alu_ror : std_logic_vector(3 downto 0) := "1111";

constant e32_alu_maxbit : integer := 3;


-- Register sources
constant e32_reg_maxbit : integer := 1;
subtype e32_regtype is std_logic_vector(e32_reg_maxbit downto 0);
constant e32_reg_gpr : e32_regtype := "01";
constant e32_regb_gpr : integer := 0;
constant e32_reg_tmp : e32_regtype := "10";
constant e32_regb_tmp : integer := 1;
constant e32_reg_dontcare : e32_regtype := "00";


-- Register number (for GPRs)
subtype e32_reg is std_logic_vector(2 downto 0);


-- Execution operations:
constant e32_exb_cond : integer := 0;
constant e32_exb_postinc : integer := 1;
constant e32_exb_load : integer := 2;
constant e32_exb_store : integer := 3;
constant e32_exb_q1toreg : integer := 4;
constant e32_exb_q1totmp : integer := 5;
constant e32_exb_q2totmp : integer := 6;
constant e32_exb_flags : integer := 7;
constant e32_exb_halfword : integer := 8;
constant e32_exb_byte : integer := 9;
constant e32_exb_waitalu : integer := 10;
constant e32_exb_sgn : integer := 11;

constant e32_ex_maxbit : integer := 11;
subtype e32_ex is std_logic_vector(e32_ex_maxbit downto 0);

constant e32_ex_bubble : std_logic_vector(e32_ex_maxbit downto 0) := "000000000000";
constant e32_ex_cond : std_logic_vector(e32_ex_maxbit downto 0) := "000000000001";
constant e32_ex_postinc : std_logic_vector(e32_ex_maxbit downto 0) := "000000000010";
constant e32_ex_load : std_logic_vector(e32_ex_maxbit downto 0) := "000000000100";
constant e32_ex_store : std_logic_vector(e32_ex_maxbit downto 0) := "000000001000";
constant e32_ex_q1toreg : std_logic_vector(e32_ex_maxbit downto 0) := "000000010000";
constant e32_ex_q1totmp : std_logic_vector(e32_ex_maxbit downto 0) := "000000100000";
constant e32_ex_q2totmp : std_logic_vector(e32_ex_maxbit downto 0) := "000001000000";
constant e32_ex_flags : std_logic_vector(e32_ex_maxbit downto 0) := "000010000000";
constant e32_ex_halfword : std_logic_vector(e32_ex_maxbit downto 0) := "000100000000";
constant e32_ex_byte : std_logic_vector(e32_ex_maxbit downto 0) := "001000000000";
constant e32_ex_waitalu : std_logic_vector(e32_ex_maxbit downto 0) := "010000000000";
constant e32_ex_sgn : std_logic_vector(e32_ex_maxbit downto 0) := "100000000000";

-- Flags are encoded into the upper bits of the program counter.
-- 30 bits of program address space is plenty, and it obviates the need to
-- address flags for context switching.

constant e32_pc_maxbit : integer := 29;

constant e32_fb_zero : integer := 31;
constant e32_fb_carry : integer := 30;
--constant e32_fb_cond : integer := 29;  -- We don't allow interrupts during cond
--constant e32_fb_sgn : integer := 28; -- sgn must immedately precede ALU op, so won't be interrupted.

end package;

