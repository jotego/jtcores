-- eightthirtytwo_fetchloadstore.vhd
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

-- FIXME - add sign extension and zeroing of upper bits for byte or halfword loads

entity eightthirtytwo_fetchloadstore is
generic
(
	littleendian : in boolean := true;
	storealign : in boolean := true;
	dualthread : in boolean := true;
	prefetch : in boolean := true
);
port
(
	clk : in std_logic;
	reset_n : in std_logic;
	freeze : in std_logic := '0';

	-- cpu fetch interface

	pc : in std_logic_vector(e32_pc_maxbit downto 0);
	pc_req : in std_logic;
	opcode : out std_logic_vector(7 downto 0);
	opcode_valid : out std_logic;

	-- fetch interface for second thread

	pc2 : in std_logic_vector(e32_pc_maxbit downto 0) := (others=>'0');
	pc2_req : in std_logic := '0';
	opcode2 : out std_logic_vector(7 downto 0);
	opcode2_valid : out std_logic;

	-- cpu load/store interface

	ls_addr : in std_logic_vector(31 downto 0);
	ls_d : in std_logic_vector(31 downto 0);
	ls_q : out std_logic_vector(31 downto 0);
	ls_wr : in std_logic;
	ls_byte : in std_logic;
	ls_halfword : in std_logic;
	ls_req : in std_logic;
	ls_ack : out std_logic;

	-- external RAM interface:

	ram_addr : out std_logic_vector(31 downto 2); -- Transfer 32-bit words.
	ram_d : in std_logic_vector(31 downto 0);
	ram_q : out std_logic_vector(31 downto 0);
	ram_bytesel : out std_logic_vector(3 downto 0); -- Select which bytes of the word should be written.  (Always "1111" for reads.)
	ram_wr : out std_logic; -- 0 for reads, 1 for writes.
	ram_req : out std_logic;
	ram_ack : in std_logic
);
end entity;

architecture behavioural of eightthirtytwo_fetchloadstore is

-- Fetch signals

signal opcodebuffer : std_logic_vector(63 downto 0);
signal opcodebuffer_valid : std_logic_vector(1 downto 0);
signal opcode_valid_i : std_logic;

signal fetch_ram_req : std_logic;
signal fetch_addr : std_logic_vector(31 downto 2);
signal fetch_abort : std_logic;
signal fetch_prevpc : std_logic_vector(1 downto 0);
signal fetch_word : std_logic_vector(2 downto 0);

signal opcodebuffer2 : std_logic_vector(63 downto 0);
signal opcodebuffer2_valid : std_logic_vector(1 downto 0);
signal opcode2_valid_i : std_logic;

signal fetch2_ram_req : std_logic;
signal fetch2_addr : std_logic_vector(31 downto 2);
signal fetch2_abort : std_logic;
signal fetch2_prevpc : std_logic_vector(1 downto 0);
signal fetch2_word : std_logic_vector(2 downto 0);

-- Load store signals

signal load_store : std_logic; -- 1 for load, 0 for store.
type ls_states is (LS_WAIT, LS_LOAD, LS_LOAD2, LS_FETCH, LS_FETCH2);
signal ls_state : ls_states;
signal ls_mask : std_logic_vector(3 downto 0);
signal ls_mask2 : std_logic_vector(3 downto 0);
signal ls_addrplus4 : unsigned(31 downto 0);

-- aligner signals
signal aligner_mask : std_logic_vector(3 downto 0);
signal aligner_shift : std_logic_vector(1 downto 0);
signal from_aligner : std_logic_vector(31 downto 0);
signal to_aligner : std_logic_vector(31 downto 0);

signal ram_req_r : std_logic;
signal ram_addr_r : std_logic_vector(31 downto 2);

begin


-- Fetch 1

opcode_valid_i<=opcodebuffer_valid(1) when pc(2)='0' else opcodebuffer_valid(0);
opcode_valid<=opcode_valid_i and not (pc_req or freeze);

process(clk,reset_n)
begin

--	if reset_n='0' then
--		opcodebuffer_valid<="00";
--		fetch_ram_req<='0';
--		fetch_abort<='0';
--	elsif rising_edge(clk) then
	if rising_edge(clk) then

		fetch_prevpc<=pc(1 downto 0);
	 	-- We double-buffer the opcodes; as program flow enters one word we invalidate the other.
		if fetch_prevpc="11" and pc(1 downto 0)="00" then
			if pc(2)='1' then
				opcodebuffer_valid(1)<='0';
			else
				opcodebuffer_valid(0)<='0';
			end if;
			fetch_ram_req<='1';
		end if;

		-- If an operation is in progress when we set the PC, we must wait for it to complete.
		if fetch_abort='1' and ram_ack='1' then
			fetch_abort<='0';
			fetch_ram_req<='1';
		end if;

		-- Do we have prefetch?
		
		if fetch_abort='0' and ram_ack='1' and ls_state=LS_FETCH and prefetch=true then
			fetch_addr<=std_logic_vector(unsigned(fetch_addr)+1);
			if opcodebuffer_valid="00" then
				fetch_ram_req<='1';
			else
				fetch_ram_req<='0';
			end if;

			if fetch_addr(2)='0' then
				opcodebuffer(63 downto 32)<=ram_d;
			else
				opcodebuffer(31 downto 0)<=ram_d;
			end if;
			if fetch_addr(2)='0' then
				opcodebuffer_valid(1)<='1';
			else
				opcodebuffer_valid(0)<='1';
			end if;
		end if;

		-- If no prefetch we use simpler logic...
		
		if fetch_abort='0' and ram_ack='1' and ls_state=LS_FETCH and prefetch=false then
			fetch_ram_req<='0';
			opcodebuffer(31 downto 0)<=ram_d;
			if pc(2)='0' then
				opcodebuffer_valid(1)<='1';
			else
				opcodebuffer_valid(0)<='1';
			end if;
		end if;

--		if fetch_abort='0' and fetch_ram_req='0' and opcodebuffer_valid/="11" then
--			fetch_ram_req<='1';
--		end if;

		if pc_req='1' then	-- PC has changed - could happen while fetching...
			fetch_ram_req<='1';
			if prefetch=true then
				fetch_addr(31 downto e32_pc_maxbit+1)<=(others=>'0');
				fetch_addr(e32_pc_maxbit downto 2)<=pc(e32_pc_maxbit downto 2);
			end if;
			opcodebuffer_valid<="00"; -- Invalidate both halves of the buffer.
			if fetch_ram_req='1' then -- and ram_ack='0' then
				fetch_abort<='1';
			end if;
		end if;

	end if;
end process;


-- Fetch 2
genthread2:
if dualthread=true generate
opcode2_valid_i<=opcodebuffer2_valid(1) when pc2(2)='0' else opcodebuffer2_valid(0);
opcode2_valid<=opcode2_valid_i and not (pc2_req or freeze);

process(clk,reset_n)
begin

	if reset_n='0' then
		opcodebuffer2_valid<="00";
		fetch2_ram_req<='0';
		fetch2_abort<='0';
	elsif rising_edge(clk) and dualthread=true then

		fetch2_prevpc<=pc2(1 downto 0);
	 	-- We double-buffer the opcodes; as program flow enters one word we invalidate the other.
		if fetch2_prevpc="11" and pc2(1 downto 0)="00" then
			if pc2(2)='1' then
				opcodebuffer2_valid(1)<='0';
			else
				opcodebuffer2_valid(0)<='0';
			end if;
			fetch2_ram_req<='1';
		end if;

		-- If an operation is in progress when we set the PC, we must wait for it to complete.
		if fetch2_abort='1' and ram_ack='1' then
			fetch2_abort<='0';
			fetch2_ram_req<='1';
		end if;

		-- Do we have prefetch?
		
		if fetch2_abort='0' and ram_ack='1' and ls_state=LS_FETCH2 and prefetch=true then
			fetch2_addr<=std_logic_vector(unsigned(fetch2_addr)+1);
			if opcodebuffer2_valid="00" then
				fetch2_ram_req<='1';
			else
				fetch2_ram_req<='0';
			end if;

			if fetch2_addr(2)='0' then
				opcodebuffer2(63 downto 32)<=ram_d;
			else
				opcodebuffer2(31 downto 0)<=ram_d;
			end if;
			if fetch2_addr(2)='0' then
				opcodebuffer2_valid(1)<='1';
			else
				opcodebuffer2_valid(0)<='1';
			end if;
		end if;

		-- If no prefetch we use simpler logic...
		
		if fetch2_abort='0' and ram_ack='1' and ls_state=LS_FETCH2 and prefetch=false then
			fetch2_ram_req<='0';
			opcodebuffer2(31 downto 0)<=ram_d;
			if pc2(2)='0' then
				opcodebuffer2_valid(1)<='1';
			else
				opcodebuffer2_valid(0)<='1';
			end if;
		end if;

--		if fetch2_abort='0' and fetch2_ram_req='0' and opcodebuffer2_valid/="11" then
--			fetch2_ram_req<='1';
--		end if;

		if pc2_req='1' then	-- PC has changed - could happen while fetching...
			fetch2_ram_req<='1';
			fetch2_addr(31 downto e32_pc_maxbit+1)<=(others=>'0');
			fetch2_addr(e32_pc_maxbit downto 2)<=pc2(e32_pc_maxbit downto 2);
			opcodebuffer2_valid<="00"; -- Invalidate both halves of the buffer.
			if fetch2_ram_req='1' then -- and ram_ack='0' then
				fetch2_abort<='1';
			end if;
		end if;

	end if;
end process;

-- Memory interface - dual thread

-- With prefetch enabled we want to assert ram_req immediately if we can:
-- Careful - priorities here must match priorities in state machine!
ram_req<='0' when reset_n='0'
	else (fetch_ram_req or fetch2_ram_req) and not ram_ack when ls_state=LS_WAIT and prefetch=true
	else ram_req_r and not ram_ack;

ram_addr<=fetch_addr(31 downto 2) when ls_state=LS_WAIT and fetch_ram_req='1' and prefetch=true
	else fetch2_addr(31 downto 2) when ls_state=LS_WAIT and fetch2_ram_req='1' and prefetch=true and dualthread=true
	else ram_addr_r;

end generate;

gennothread2:
if dualthread=false generate
	fetch2_ram_req<='0';
	opcodebuffer2_valid<="00";
	fetch2_addr<=(others=>'0');

-- Memory interface - single threaded

-- With prefetch enabled we want to assert ram_req immediately if we can:
-- Careful - priorities here must match priorities in state machine!
ram_req<='0' when reset_n='0'
	else fetch_ram_req and not ram_ack when ls_state=LS_WAIT and prefetch=true
	else ram_req_r and not ram_ack;

ram_addr<=fetch_addr(31 downto 2) when ls_state=LS_WAIT and fetch_ram_req='1' and prefetch=true
	else ram_addr_r;
	
end generate;

	
process(clk, reset_n)
begin
	if reset_n='0' then
		ls_state<=LS_WAIT;
		ram_req_r<='0';
		ram_wr<='0';
	elsif rising_edge(clk) then

		ls_addrplus4<=unsigned(ls_addr)+4;
		ls_ack<='0';

		case ls_state is
			when LS_WAIT =>
					ram_bytesel<="1111";
					if fetch_ram_req='1' and prefetch=true then
						ram_addr_r<=std_logic_vector(fetch_addr(31 downto 2));
						ram_req_r<='1';
						ls_state<=LS_FETCH;
					elsif fetch_ram_req='1' and prefetch=false then
						ram_addr_r(31 downto e32_pc_maxbit+1)<=(others=>'0');
						ram_addr_r(e32_pc_maxbit downto 2)<=pc(e32_pc_maxbit downto 2);
						ram_req_r<='1';
						ls_state<=LS_FETCH;
					elsif fetch2_ram_req='1' and dualthread=true and prefetch=true then
						ram_addr_r<=std_logic_vector(fetch2_addr(31 downto 2));
						ram_req_r<='1';
						ls_state<=LS_FETCH2;
					elsif fetch2_ram_req='1' and dualthread=true and prefetch=false then
						ram_addr_r(31 downto e32_pc_maxbit+1)<=(others=>'0');
						ram_addr_r(e32_pc_maxbit downto 2)<=pc2(e32_pc_maxbit downto 2);
						ram_req_r<='1';
						ls_state<=LS_FETCH2;
					elsif ls_req='1' then
						ram_addr_r<=ls_addr(31 downto 2);
						ram_req_r<='1';
						ram_bytesel(3)<=ls_mask(0);
						ram_bytesel(2)<=ls_mask(1);
						ram_bytesel(1)<=ls_mask(2);
						ram_bytesel(0)<=ls_mask(3);
						ram_wr<=ls_wr;
						ls_state<=LS_LOAD;
					end if;

			when LS_FETCH =>
				if ram_ack='1' then
					ram_req_r<='0';
					ls_state<=LS_WAIT;
					if ls_req='1' then
						ram_addr_r<=ls_addr(31 downto 2);
						ram_req_r<='1';
						ram_bytesel(3)<=ls_mask(0);
						ram_bytesel(2)<=ls_mask(1);
						ram_bytesel(1)<=ls_mask(2);
						ram_bytesel(0)<=ls_mask(3);
						ram_wr<=ls_wr;
						ls_state<=LS_LOAD;
					end if;
				end if;

			when LS_FETCH2 =>
				if ram_ack='1' then
					ram_req_r<='0';
					ls_state<=LS_WAIT;
					if ls_req='1' then
						ram_addr_r<=ls_addr(31 downto 2);
						ram_req_r<='1';
						ram_bytesel(3)<=ls_mask(0);
						ram_bytesel(2)<=ls_mask(1);
						ram_bytesel(1)<=ls_mask(2);
						ram_bytesel(0)<=ls_mask(3);
						ram_wr<=ls_wr;
						ls_state<=LS_LOAD;
					end if;
				end if;

			when LS_LOAD =>
				if ram_ack='1' then

					if ls_mask(3)='1' then
						ls_q(31 downto 24)<=from_aligner(31 downto 24);
					else
						ls_q(31 downto 24)<=(others=>'0');
					end if;
					
					if ls_mask(2)='1' then
						ls_q(23 downto 16)<=from_aligner(23 downto 16);
					else
						ls_q(23 downto 16)<=(others=>'0');
					end if;
					
					if ls_mask(1)='1' then
						ls_q(15 downto 8)<=from_aligner(15 downto 8);
					else
						ls_q(15 downto 8)<=(others=>'0');
					end if;
					
					if ls_mask(0)='1' then
						ls_q(7 downto 0)<=from_aligner(7 downto 0);
					else
						ls_q(7 downto 0)<=(others=>'0');
					end if;
					
					if ls_mask2="0000" then
						ram_req_r<='0';
						ram_wr<='0';
						ls_ack<='1';
						ls_state<=LS_WAIT;
					else
						ram_addr_r<=std_logic_vector(ls_addrplus4(31 downto 2));
						ram_bytesel(3)<=ls_mask2(0);
						ram_bytesel(2)<=ls_mask2(1);
						ram_bytesel(1)<=ls_mask2(2);
						ram_bytesel(0)<=ls_mask2(3);
						ram_req_r<='1';
						ls_state<=LS_LOAD2;
					end if;
				end if;

			when LS_LOAD2 =>
				if ram_ack='1' then

					if ls_mask2(3)='1' then
						ls_q(31 downto 24)<=from_aligner(31 downto 24);
					end if;
					
					if ls_mask2(2)='1' then
						ls_q(23 downto 16)<=from_aligner(23 downto 16);
					end if;
					
					if ls_mask2(1)='1' then
						ls_q(15 downto 8)<=from_aligner(15 downto 8);
					end if;
					
					if ls_mask2(0)='1' then
						ls_q(7 downto 0)<=from_aligner(7 downto 0);
					end if;

					ram_req_r<='0';
					ram_wr<='0';
					ls_ack<='1';
					ls_state<=LS_WAIT;
				end if;
		
			when others =>
				null;

		end case;
	
	end if;
end process;


-- Prefetch enable/disable

fetch_word(2)<='0' when pc(2)='0' and prefetch=true else '1';
fetch_word(1 downto 0) <= pc(1 downto 0);
fetch2_word(2)<='0' when pc2(2)='0' and prefetch=true and dualthread=true else '1';
fetch2_word(1 downto 0) <= pc2(1 downto 0) when dualthread=true else (others=>'-');


-- aligner

load_store<=not ls_wr;
to_aligner <= ls_d when ls_wr='1' else ram_d;
ram_q<=from_aligner;

align_le:
if littleendian=true generate

dual_le:
if dualthread=true generate
with fetch2_word select opcode2 <=
	opcodebuffer2(63 downto 56) when "011",
	opcodebuffer2(55 downto 48) when "010",
	opcodebuffer2(47 downto 40) when "001",
	opcodebuffer2(39 downto 32) when "000",
	opcodebuffer2(31 downto 24) when "111",
	opcodebuffer2(23 downto 16) when "110",
	opcodebuffer2(15 downto 8) when "101",
	opcodebuffer2(7 downto 0) when "100",
	(others =>'-') when others;
end generate;

-- Fetch - little endian mode.
with fetch_word select opcode <=
	opcodebuffer(63 downto 56) when "011",
	opcodebuffer(55 downto 48) when "010",
	opcodebuffer(47 downto 40) when "001",
	opcodebuffer(39 downto 32) when "000",
	opcodebuffer(31 downto 24) when "111",
	opcodebuffer(23 downto 16) when "110",
	opcodebuffer(15 downto 8) when "101",
	opcodebuffer(7 downto 0) when "100",
	(others =>'-') when others;

aligner : entity work.eightthirtytwo_aligner_le
port map(
	d => to_aligner,
	q => from_aligner,
	mask => ls_mask,
	mask2 => ls_mask2,
	load_store => load_store,
	addr => ls_addr(1 downto 0),
	byteop => ls_byte,
	halfwordop => ls_halfword
);
end generate;

align_be:
if littleendian=false generate

-- Fetch - big endian mode

dual_be:
if dualthread=true generate

with fetch2_word select opcode2 <=
	opcodebuffer2(63 downto 56) when "000",
	opcodebuffer2(55 downto 48) when "001",
	opcodebuffer2(47 downto 40) when "010",
	opcodebuffer2(39 downto 32) when "011",
	opcodebuffer2(31 downto 24) when "100",
	opcodebuffer2(23 downto 16) when "101",
	opcodebuffer2(15 downto 8) when "110",
	opcodebuffer2(7 downto 0) when "111",
	(others =>'-') when others;
end generate;

with fetch_word select opcode <=
	opcodebuffer(63 downto 56) when "000",
	opcodebuffer(55 downto 48) when "001",
	opcodebuffer(47 downto 40) when "010",
	opcodebuffer(39 downto 32) when "011",
	opcodebuffer(31 downto 24) when "100",
	opcodebuffer(23 downto 16) when "101",
	opcodebuffer(15 downto 8) when "110",
	opcodebuffer(7 downto 0) when "111",
	(others =>'-') when others;

aligner : entity work.eightthirtytwo_aligner
port map(
	d => to_aligner,
	q => from_aligner,
	mask => ls_mask,
	mask2 => ls_mask2,
	load_store => load_store,
	addr => ls_addr(1 downto 0),
	byteop => ls_byte,
	halfwordop => ls_halfword
);
end generate;


end architecture;
