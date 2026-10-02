--
-- Copyright (c) MikeJ - May 2004
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS CODE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- You are responsible for any legal issues arising from your use of this code.
--
-- The latest version of this file can be found at: www.fpgaarcade.com
--
-- Email support@fpgaarcade.com
--
-- Revision list
--
-- version 002 return 00 on allpot when fast scan completed to fix self test
-- version 001 initial release (this version should be considered Beta
--   it seems to make all the right sort of sounds however ... )
--
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.std_logic_unsigned.all;
	use ieee.numeric_std.all;

entity POKEY is
port (
	ADDR      : in  std_logic_vector(3 downto 0);
	DIN       : in  std_logic_vector(7 downto 0);
	DOUT      : out std_logic_vector(7 downto 0);
	DOUT_OE_L : out std_logic;
	RW_L      : in  std_logic;
	CS        : in  std_logic; -- used as enable
	CS_L      : in  std_logic;
	--
	AUDIO_OUT : out signed(5 downto 0);
	--
	PIN       : in  std_logic_vector(7 downto 0);
	ENA       : in  std_logic;
	CLK       : in  std_logic  -- note 6 Mhz
);
end;

architecture RTL of POKEY is
	type  array_8x8   is array (0 to 7) of std_logic_vector(7 downto 0);
	type  array_4x8   is array (1 to 4) of std_logic_vector(7 downto 0);
	type  array_4x4   is array (1 to 4) of std_logic_vector(3 downto 0);
	type  array_4x9   is array (1 to 4) of std_logic_vector(8 downto 0);
	type  array_2x17  is array (1 to 2) of std_logic_vector(16 downto 0);
	type  bool_4      is array (1 to 4) of boolean;

	signal we                   : std_logic;
	signal oe                   : std_logic;
	--
	signal ena_64k_15k          : std_logic;
	signal cnt_64k              : std_logic_vector(4 downto 0) := (others => '0');
	signal ena_64k              : std_logic;
	signal cnt_15k              : std_logic_vector(6 downto 0) := (others => '0');
	signal ena_15k              : std_logic;
	--
	signal poly4                : std_logic_vector(3 downto 0) := (others => '0');
	signal poly5                : std_logic_vector(4 downto 0) := (others => '0');
	signal poly9                : std_logic_vector(8 downto 0) := (others => '0');
	signal poly17               : std_logic_vector(16 downto 0) := (others => '0');
	signal poly_17_9            : std_logic;

	-- registers
	signal audf                 : array_4x8 := (others => (others => '0'));
	signal audc                 : array_4x8 := (others => (others => '0'));
	signal audctl               : std_logic_vector(7 downto 0) := (others => '0');
	signal stimer               : std_logic_vector(7 downto 0);
	signal skres                : std_logic_vector(7 downto 0);
	signal potgo                : std_logic;
	signal serout               : std_logic_vector(7 downto 0);
	signal irqen                : std_logic_vector(7 downto 0);
	signal skctls               : std_logic_vector(7 downto 0);
	signal reset                : std_logic;
	--
	signal kbcode               : std_logic_vector(7 downto 0);
	signal random               : std_logic_vector(7 downto 0);
	signal serin                : std_logic_vector(7 downto 0);
	signal irqst                : std_logic_vector(7 downto 0);
	signal skstat               : std_logic_vector(7 downto 0);
	--
	signal pot_fin              : std_logic;
	signal pot_cnt              : std_logic_vector(7 downto 0);
	signal pot_val              : array_8x8;
	signal pin_reg              : std_logic_vector(7 downto 0);
	signal pin_reg_gated        : std_logic_vector(7 downto 0);
	--
	signal chan_ena             : std_logic_vector(4 downto 1);
	signal tone_gen_div         : std_logic_vector(4 downto 1);
	signal tone_gen_cnt         : array_4x8 := (others => (others => '0'));
	signal tone_gen_div_mux     : std_logic_vector(4 downto 1);
	signal tone_gen_zero        : std_logic_vector(4 downto 1);
	signal tone_gen_zero_t      : array_4x8 := (others => (others => '0'));
	signal chan_done_load       : std_logic_vector(4 downto 1) := (others => '0');
	--
	signal poly_sel             : std_logic_vector(4 downto 1);
	signal poly_sel_hp          : std_logic_vector(4 downto 1);
	signal poly_sel_hp_t1       : std_logic_vector(4 downto 1);
	signal poly_sel_hp_reg      : std_logic_vector(4 downto 1);
	signal tone_gen_final       : std_logic_vector(4 downto 1) := (others => '0');
begin

	p_we : process(RW_L, CS_L, CS, ENA)
	begin
		we <= (not CS_L) and CS and (not RW_L) and ENA;
	end process;

	p_oe : process(RW_L, CS_L, CS)
	begin
		oe <= (not CS_L) and CS and RW_L;
	end process;
	DOUT_OE_L <= not oe;

	p_ipreg : process
	begin
		wait until rising_edge(CLK);
		pin_reg <= PIN;
	end process;

	p_dividers : process
	begin
		wait until rising_edge(CLK);
		if (ENA = '1') then
			ena_64k <= '0';
			if cnt_64k = "00000" then
				cnt_64k <= "11011"; -- 28 - 1
				ena_64k <= '1';
			else
				cnt_64k <= cnt_64k - "1";
			end if;

			ena_15k <= '0';
			if cnt_15k = "0000000" then
				cnt_15k <= "1110001"; -- 114 - 1
				ena_15k <= '1';
			else
				cnt_15k <= cnt_15k - "1";
			end if;
		end if;
	end process;

	p_ena_64k_15k : process(ena_64k, ena_15k, audctl)
	begin
		if (audctl(0) = '1') then
			ena_64k_15k <= ena_15k;
		else
			ena_64k_15k <= ena_64k;
		end if;
	end process;

	p_poly : process
		variable poly9_zero : std_logic;
		variable poly17_zero : std_logic;
	begin
		wait until rising_edge(CLK);
		if (ENA = '1') then
			poly4 <= poly4(2 downto 0) & not (poly4(3) xor poly4(2));
			poly5 <= poly5(3 downto 0) & not (poly5(4) xor poly4(2)); -- used inverted

			-- not correct
			poly9_zero := '0';
			if (poly9 = "000000000") then poly9_zero := '1'; end if;
			poly9  <= poly9(7 downto 0) & (poly9(8) xor poly9(3) xor poly9_zero);

			poly17_zero := '0';
			if (poly17 = "00000000000000000") then poly17_zero := '1'; end if;
			poly17 <= poly17(15 downto 0) & (poly17(16) xor poly17(2) xor poly17_zero);

		end if;
	end process;

	p_random_mux : process(audctl, poly9, poly17)
	begin
		-- bit unnecessary this ....
		for i in 0 to 7 loop
			if (audctl(7) = '1') then -- 9 bit poly
				random(i) <= poly9(8-i);
			else
				random(i) <= poly17(16-i);
			end if;
		end loop;

		if (audctl(7) = '1') then
			poly_17_9 <= poly9(8);
		else
			poly_17_9 <= poly17(16);
		end if;
	end process;

	p_wdata : process
	begin
		wait until rising_edge(CLK);
		potgo <= '0';

		--if (reset = '1') then
			-- no idea what the reset state is
			--audf <= (others => (others => '0'));
			--audc <= (others => (others => '0'));
			--audctl <= x"00";
		--else
		if (we = '1') then
			case ADDR is
				when x"0" => audf(1)  <= DIN;
				when x"1" => audc(1)  <= DIN;
				when x"2" => audf(2)  <= DIN;
				when x"3" => audc(2)  <= DIN;
				when x"4" => audf(3)  <= DIN;
				when x"5" => audc(3)  <= DIN;
				when x"6" => audf(4)  <= DIN;
				when x"7" => audc(4)  <= DIN;
				when x"8" => audctl   <= DIN;
				when x"9" => stimer   <= DIN;
				when x"A" => skres    <= DIN;
				when x"B" => potgo    <= '1';
				--when x"C" =>
				when x"D" => serout   <= DIN;
				when x"E" => irqen    <= DIN;
				when x"F" => skctls   <= DIN;
				when others => null;
			end case;
		end if;
		--end if;
	end process;

	p_reset : process(skctls)
	begin
		-- chip in reset if bits 1..0 of skctls are both zero
		reset <= '0';
		if (skctls(1 downto 0) = "00") then
			reset <= '1';
		end if;
	end process;

	p_rdata : process(oe, ADDR, pot_val, pin_reg_gated, kbcode, random, serin, irqst, skstat)
	begin
		DOUT <= x"00";
		if (oe = '1') then -- keep things quiet
			case ADDR IS
				when x"0" => DOUT <= pot_val(0);   -- pot 0
				when x"1" => DOUT <= pot_val(1);   -- pot 1
				when x"2" => DOUT <= pot_val(2);   -- pot 2
				when x"3" => DOUT <= pot_val(3);   -- pot 3
				when x"4" => DOUT <= pot_val(4);   -- pot 4
				when x"5" => DOUT <= pot_val(5);   -- pot 5
				when x"6" => DOUT <= pot_val(6);   -- pot 6
				when x"7" => DOUT <= pot_val(7);   -- pot 7
				when x"8" => DOUT <= pin_reg_gated;-- allpot
				when x"9" => DOUT <= kbcode;
				when x"A" => DOUT <= random;
				when x"B" => DOUT <= x"FF";
				when x"C" => DOUT <= x"FF";
				when x"D" => DOUT <= serin;
				when x"E" => DOUT <= irqst;
				when x"F" => DOUT <= skstat;
				when others => null;
			end case;
		end if;
	end process;

	-- POT ANALOGUE IN UNTESTED !!
	p_pot_cnt : process
	begin
		wait until rising_edge(CLK);
		if (potgo = '1') then
			pot_cnt <= x"00";
		elsif ((ena_15k = '1') or (skctls(2) = '1')) and (ENA = '1') then -- fast scan mode
			pot_cnt <= pot_cnt + "1";
		end if;
	end process;

	p_pot_comp : process
	begin
		wait until rising_edge(CLK);
		if (reset = '1') then
			pot_fin <= '1';
		else
			if (potgo = '1') then
				pot_fin <= '0';
			elsif (pot_cnt = x"E4") then -- 228
				pot_fin <= '1';
			end if;
		end if;
	end process;

	p_pot_val : process
	begin
		wait until rising_edge(CLK);
		for i in 0 to 7 loop
			if (pot_fin = '0') and (pin_reg(i) = '0') then
				-- continue latching counter value until input reaches ViH threshold
				pot_val(i) <= pot_cnt;
			end if;
		end loop;
	end process;

	-- dump transistors
	--PIN <= x"00" when (pot_fin = '1') else (others => 'Z');
	p_in_gate : process(pin_reg, reset, pot_fin) -- dump transistor fakeup
	begin
		pin_reg_gated <= pin_reg;
		-- I think the datasheet lies about dump transistors being disabled
		-- in fast scan mode, as the self test fails ....
		if (reset = '1') or (pot_fin = '1') then --and (skctls(2) = '0'))
			pin_reg_gated <= x"00";
		end if;
	end process;

	p_tone_cnt_ena : process(audctl, ena_64k_15k, tone_gen_div)
		variable chan_ena1, chan_ena3 : std_ulogic;
	begin

		if (audctl(6) = '1') then
			chan_ena1 := '1'; -- 1.5 MHz,
		else
			chan_ena1 := ena_64k_15k;
		end if;
		chan_ena(1) <= chan_ena1;

		if (audctl(4) = '1') then -- chan 1/2 joined
			chan_ena(2) <= chan_ena1;
		else
			chan_ena(2) <= ena_64k_15k;
		end if;

		if (audctl(5) = '1') then
			chan_ena3 := '1'; -- 1.5 MHz,
		else
			chan_ena3 := ena_64k_15k; -- 64 KHz
		end if;
		chan_ena(3) <= chan_ena3;

		if (audctl(3) = '1') then -- chan 3/4 joined
			chan_ena(4) <= chan_ena3;
		else
			chan_ena(4) <= ena_64k_15k; -- 64 KHz
		end if;
	end process;

	p_tone_generator_zero : process(tone_gen_cnt, chan_ena)
	begin
		for i in 1 to 4 loop
			if (tone_gen_cnt(i) = "00000000") and (chan_ena(i) = '1') then
				tone_gen_zero(i) <= '1';
			else
				tone_gen_zero(i) <= '0';
			end if;
		end loop;
	end process;

	p_tone_generators : process
		variable chan_load : std_logic_vector(4 downto 1);
		variable chan_dec : std_logic_vector(4 downto 1);
	begin
		-- quite tricky this .. but I think it does the correct stuff
		-- bet this is not how is was done originally !
		--
		-- nasty frig to easily get exact chip behaviour in high speed mode
		-- fout = fin / 2(audf + n) when n=4 or 7 in 16 bit mode
		wait until rising_edge(CLK);
		if (ENA = '1') then
			tone_gen_div <= "0000";

			if (audctl(4) = '1') then -- chan 1/2 joined
				chan_load(1) := '0';
				chan_load(2) := '0';
				if (tone_gen_zero_t(1)(5) = '1') and (tone_gen_zero_t(2)(5) = '1') and (chan_done_load(1) = '0') then
					chan_load(1) := '1';
					chan_load(2) := '1';
				end if;
				chan_dec(1) := '1';
				chan_dec(2) := tone_gen_zero(1);
			else
				chan_load(1) := tone_gen_zero_t(1)(2) and not chan_done_load(1);
				chan_load(2) := tone_gen_zero_t(2)(2) and not chan_done_load(2);

				chan_dec(1) := '1';
				chan_dec(2) := '1';
			end if;

			if (audctl(3) = '1') then -- chan 1/2 joined
				chan_load(3) := '0';
				chan_load(4) := '0';
				if (tone_gen_zero_t(3)(5) = '1') and (tone_gen_zero_t(4)(5) = '1') and (chan_done_load(3) = '0') then
					chan_load(3) := '1';
					chan_load(4) := '1';
				end if;
				chan_dec(3) := '1';
				chan_dec(4) := tone_gen_zero(3);
			else
				chan_load(3) := tone_gen_zero_t(3)(2) and not chan_done_load(3);
				chan_load(4) := tone_gen_zero_t(4)(2) and not chan_done_load(4);

				chan_dec(3) := '1';
				chan_dec(4) := '1';
			end if;

			for i in 1 to 4 loop

				if (chan_load(i) = '1') then
					chan_done_load(i) <= '1';
					tone_gen_div(i) <= '1';
					tone_gen_cnt(i) <= audf(i);
				elsif (chan_dec(i) = '1') and (chan_ena(i) = '1') then
					chan_done_load(i) <= '0';
					tone_gen_cnt(i) <= tone_gen_cnt(i) - "1";
				end if;

				tone_gen_div(i) <= chan_load(i);
				tone_gen_zero_t(i)(7 downto 0) <= tone_gen_zero_t(i)(6 downto 0) & tone_gen_zero(i);
			end loop;

		end if;
	end process;

	p_tone_generator_mux : process(audctl, tone_gen_div)
	begin
		if (audctl(4) = '1') then -- chan 1/2 joined
			tone_gen_div_mux(1) <= tone_gen_div(1); -- do they both waggle
			tone_gen_div_mux(2) <= tone_gen_div(2); -- or do I mute chan 1?
		else
			tone_gen_div_mux(1) <= tone_gen_div(1);
			tone_gen_div_mux(2) <= tone_gen_div(2);
		end if;

		if (audctl(3) = '1') then -- chan 3/4 joined
			tone_gen_div_mux(3) <= tone_gen_div(3); -- ditto
			tone_gen_div_mux(4) <= tone_gen_div(4);
		else
			tone_gen_div_mux(3) <= tone_gen_div(3);
			tone_gen_div_mux(4) <= tone_gen_div(4);
		end if;
	end process;

	p_poly_gating : process(audc, poly4, poly5, poly_17_9, tone_gen_div_mux)
		variable filter_a : std_logic_vector(4 downto 1);
		variable filter_b : std_logic_vector(4 downto 1);
	begin
		for i in 1 to 4 loop
			if (audc(i)(7) = '0') then
				filter_a(i) := poly5(4) and tone_gen_div_mux(i);-- 5 bit poly
			else
				filter_a(i) := tone_gen_div_mux(i);
			end if;

			if (audc(i)(6) = '0') then
				filter_b(i) := poly_17_9 and filter_a(i);-- 17 bit poly
			else
				filter_b(i) := poly4(3) and filter_a(i);-- 4 bit poly
			end if;

			if (audc(i)(5) = '0') then
				poly_sel(i) <= filter_b(i);
			else
				poly_sel(i) <= filter_a(i);
			end if;
		end loop;
	end process;

	p_high_pass_filters : process(audctl, poly_sel, poly_sel_hp_reg)
	begin
		poly_sel_hp <= poly_sel;

		if (audctl(2) = '1') then
			poly_sel_hp(1) <= poly_sel(1) xor poly_sel_hp_reg(1);
		end if;

		if (audctl(1) = '1') then
			poly_sel_hp(2) <= poly_sel(2) xor poly_sel_hp_reg(2);
		end if;
	end process;

	p_audio_out : process
	begin
		wait until rising_edge(CLK);
		if (ENA = '1') then
			for i in 1 to 4 loop
				-- filter reg
				if (tone_gen_div(3) = '1') then -- tone gen 1 clocked by gen 3
					poly_sel_hp_reg(1) <= poly_sel(1);
				end if;

				if (tone_gen_div(4) = '1') then -- tone gen 2 clocked by gen 4
					poly_sel_hp_reg(2) <= poly_sel(2);
				end if;

				poly_sel_hp_t1 <= poly_sel_hp;

				if (poly_sel_hp(i) = '1') and (poly_sel_hp_t1(i) = '0') then -- rising edge
					tone_gen_final(i) <= not tone_gen_final(i);
				end if;
			end loop;
		end if;
	end process;

	p_op_mixer : process
		variable vol : array_4x4;
		variable sum12 : std_logic_vector(4 downto 0);
		variable sum34 : std_logic_vector(4 downto 0);
		variable sum   : std_logic_vector(5 downto 0);
	begin
		wait until rising_edge(CLK);
		if (ENA = '1') then
			for i in 1 to 4 loop
				if (audc(i)(4) = '1') then -- vol only
					vol(i) := audc(i)(3 downto 0);
				else
					if (tone_gen_final(i) = '1') then
						vol(i) := audc(i)(3 downto 0);
					else
						vol(i) := "0000";
					end if;
				end if;
			end loop;

			sum12 := ('0' & vol(1)) + ('0' & vol(2));
			sum34 := ('0' & vol(3)) + ('0' & vol(4));
			sum   := ('0' & sum12 ) + ('0' & sum34 );

			if (reset = '1') then
				AUDIO_OUT <= (others=>'0');
			else
				AUDIO_OUT <= signed((not sum(sum'left)) & sum(sum'left-1 downto 0) );
			end if;
		end if;
	end process;

	-- keyboard / serial etc to do
end architecture RTL;
