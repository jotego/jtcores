--
-- Copyright (c) 2015 Davor Jadrijevic
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions
-- are met:
-- 1. Redistributions of source code must retain the above copyright
--    notice, this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
-- ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
-- LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
-- OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
-- SUCH DAMAGE.
--
-- $Id$
--

-- vendor-independent module for simulating differential HDMI output
-- this module tested on scarab and it works :)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library unisim;
use unisim.vcomponents.all;

entity hdmi_out_xilinx is
	port (
		clock_pixel_i		: in std_logic;	-- x1
		clock_tdms_i		: in std_logic;	-- x5
		red_i					: in  std_logic_vector(9 downto 0);
		green_i				: in  std_logic_vector(9 downto 0);
		blue_i				: in  std_logic_vector(9 downto 0);
		tmds_out_p			: out std_logic_vector(3 downto 0);
		tmds_out_n			: out std_logic_vector(3 downto 0)
	);
end entity;

architecture Behavioral of hdmi_out_xilinx is

	signal mod5				: std_logic_vector(2 downto 0);
	signal shift_r, shift_g, shift_b	: std_logic_vector(9 downto 0);

	type a_output_bits is array (0 to 3) of std_logic_vector(1 downto 0);
	signal output_bits    : a_output_bits := (others => (others => '0'));
	-- The signals from the DDR outputs to the output buffers
	signal serial_outputs : std_logic_vector(3 downto 0);

begin

	process (clock_tdms_i)
	begin
		if rising_edge(clock_tdms_i) then
			if mod5(2) = '1' then
				mod5 <= "000";
				shift_r <= red_i;
				shift_g <= green_i;
				shift_b <= blue_i;
			else
				mod5 <= mod5 + "001";
				shift_r <= "00" & shift_r(9 downto 2);
				shift_g <= "00" & shift_g(9 downto 2);
				shift_b <= "00" & shift_b(9 downto 2);
			end if;
		end if;
	end process;

	output_bits(3) <= clock_pixel_i & not clock_pixel_i;
	output_bits(2) <= shift_r(1 downto 0);
	output_bits(1) <= shift_g(1 downto 0);
	output_bits(0) <= shift_b(1 downto 0);

	g1: for i in 0 to 3 generate
		--------------------------------------------------------
		-- Convert the TMDS codes into a serial stream, two bits 
		-- at a time using a DDR register
		--------------------------------------------------------
		to_serial: ODDR2
		generic map (
			DDR_ALIGNMENT => "C0",
			INIT          => '0',
			SRTYPE        => "ASYNC"
		)
		port map (
			C0  =>     clock_tdms_i,
			C1  => not clock_tdms_i,
			CE  => '1',
			R   => '0',
			S   => '0',
			D0  => output_bits(i)(0),
			D1  => output_bits(i)(1),
			Q   => serial_outputs(i)
		);
	end generate;

	-- vendor-specific differential output buffering for HDMI clock and video
	hdmis: for i in 0 to 3 generate
		tmds_video: obufds
		--generic map(IOSTANDARD => "DEFAULT")
		port map(
			i  => serial_outputs(i),
			o  => tmds_out_p(i),
			ob => tmds_out_n(i)
		);
    end generate;

end Behavioral;
