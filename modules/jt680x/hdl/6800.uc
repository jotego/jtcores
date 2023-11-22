#    This file is part of JTCORES.
#    JTCORES program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    JTCORES program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.
#
#    Author: Jose Tejada Gomez. Twitter: @topapate
#    Version: 1.0
#    Date: 22-11-2023

# Reset starts here too
control:
	# all bus names get _ctrl attached to them
	# all value names get the bus name attached, like ADD_EA_PC
	- name: pc
		values: [ "0", ADD_EA, INC, LOAD_EA, PULL_LO, PULL_HI ]
	- name: bus
		values: [ "0", FETCH, READ, WRITE, PUSH, PULL, INT_HI, INT_LO ]
	- name: op
		values: [ "0", FETCH ]
	- name: op0
		values: [ "0", ACCA, ACCB, ACCD, IX, SP ]
	- name: op1
		values: [ "0", ZERO, ONE, ACCB, MDHI ]
	- name: acca
		values: [ "0", LOAD, LOAD_HI, XCG, PULL ]
	# entries with no values key are considered 1-bit signals
	- name: dec_en
	- name: load_sp
sequence:
	# The sequence must use the value full name
	-	id: serve_int
		seq:
			- PULL_HI_PC, INT_HI_BUS, PC_HI_DOUT
			- PULL_LO_PC, INT_LO_BUS, PC_LO_DOUT
	- id: fetch
		seq:
			- FETCH_OP, INC_PC, FETCH_LO_MD, DEC_EN
	- id: alu_imm8a
		seq:
			- ACCA_OP0, LOAD_ACCA, INC_PC
	- id: alu_imm8b
		seq:
			- ACCB_OP0, LOAD_ACCB, INC_PC
	- id: ldd
		seq:
			- LOAD_ACCB, FETCH_LO_MD, INC_PC
			- LOAD_HI_ACCA, INC_PC
	- id: ldx
		seq:
			- FETCH_HI_MD, INC_PC
			- LOAD_IX, INC_PC
	- id: lds
		seq:
			- FETCH_HI_MD, INC_PC
			- LOAD_SP, INC_PC

