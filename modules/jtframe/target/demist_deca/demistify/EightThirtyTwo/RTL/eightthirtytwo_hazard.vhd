-- eightthirtytwo_hazard.vhd
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

entity eightthirtytwo_hazard is
port(
	valid : in std_logic;
	pause : in std_logic;
	forward_q2tod1 : in std_logic;
	d_read_tmp : in std_logic;
	d_read_reg : in std_logic;
	d_ex_op : in e32_ex;
	d_reg : in e32_reg;
	e_write_tmp : in std_logic;
	e_write_gpr : in std_logic;
	e_write_pc : in std_logic;
	e_write_flags : in std_logic;
	e_loadstore : in std_logic;
	e_load : in std_logic;
	e_store : in std_logic;
	e_reg : in e32_reg;
	m_write_tmp : in std_logic;
	m_write_gpr : in std_logic;
	m_write_pc : in std_logic;
	m_write_flags : in std_logic;
	m_loadstore : in std_logic;
	m_load : in std_logic;
	m_store : in std_logic;
	m_reg : in e32_reg;
	w_write_tmp : in std_logic;
	w_write_flags : in std_logic;
	w_loadstore : in std_logic;
	w_load : in std_logic;
	w_store : in std_logic;
	hazard : out std_logic
);
end entity;

architecture rtl of eightthirtytwo_hazard is

signal hazard_tmp : std_logic;
signal hazard_pc : std_logic;
signal hazard_reg : std_logic;
signal hazard_load : std_logic;
signal hazard_loadwrtmp : std_logic;
signal hazard_flags : std_logic;

begin

-- hazard_tmp:
-- If the instruction being decoded requires tmp as either source we
-- block the transfer from D to E and the advance of PC
-- until any previous instruction writing to tmp has cleared the pipeline.
-- (If we don't implement ltmpinc or ltmp then nothing beyond M will write to the regfile.)

hazard_tmp<='1' when
	d_read_tmp='1' and forward_q2tod1='0' and (e_write_tmp='1' or m_write_tmp='1' or w_write_tmp='1')
	else '0';

-- Load operations write to tmp at some inderminate point in the future.
-- Other operations which write to tmp can't be allowed to run until this is complete)
-- We only filter on q2 since only li and mt can cause issues here - everything else
-- reads tmp before writing to it, so will already be blocked.  I didn't expect
-- to have to worry about this since it can only happen if the result of a load is
-- discarded - but I've already bumped into it when using a load to clear an interrupt
-- status register, so it is necessary after all.

hazard_loadwrtmp<='1' when
	d_ex_op(e32_exb_q2totmp)='1' and (e_load='1' or m_load='1' or w_load='1')
	else '0';

-- hazard_reg:
-- If the instruction being decoded requires a register as source we block
-- the transfer from D to E and the advance of PC until any previous
-- instruction writing to the regfile has cleared the pipeline.

hazard_reg<='1' when
	d_read_reg='1' and
		((e_write_gpr='1' and e_reg=d_reg) or (m_write_gpr='1' and m_reg=d_reg))
	else '0';

hazard_pc<='1' when
		e_write_pc='1' or m_write_pc='1'
	else '0';

	
-- Load hazard - if a load or store is in the pipeline we have to delay further loads/stores

hazard_load<='1' when (d_ex_op(e32_exb_store)='1' or d_ex_op(e32_exb_load)='1') and
		(e_loadstore='1' or m_loadstore='1' or w_loadstore='1')
	else '0';

--hazard_store<='1' when d_ex_op(e32_exb_store)='1' and 
--		(e_loadstore='1' or m_loadstore='1' or w_loadstore='1')
--	else '0';


-- We have a flags hazard with the sgn or cond instructions
-- if anything still in the pipeline is writing to the flags.
-- FIXME - might be able to remove sgn from this by allowing the
-- pipeline to consume the sgn flag earlier.
hazard_flags<='1' when
	(d_ex_op(e32_exb_cond)='1' or d_ex_op(e32_exb_sgn)='1')
		and (e_write_flags='1' or m_write_flags='1' or w_write_flags='1')
	else '0';

hazard<=(not valid)
	or pause
	or hazard_tmp
	or hazard_reg
	or hazard_pc
	or hazard_load
	or hazard_loadwrtmp
	or hazard_flags;

end architecture;
