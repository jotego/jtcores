--
-- Multicore 2 / Multicore 2+
--
-- Copyright (c) 2017-2021 - Victor Trucco
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
-- 15/04/23  Stripped down module for DeMiSTify boards, by @somhi
--

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity MC2_HID_JOY is
generic
(
        OSD_CMD         : in   std_logic_vector(2 downto 0) := "011";
        CLK_SPEED       : integer := 50000
);
port 
(
        Clk_i             : in std_logic;
        reset_i           : in std_logic := '0';

        joystick_0_i      : in std_logic_vector(5 downto 0);
        joystick_1_i      : in std_logic_vector(5 downto 0);

        -- joystick_0 and joystick_1 should be swapped
        joyswap_i         : in std_logic := '0';

        -- player1 and player2 should get both joystick_0 and joystick_1
        oneplayer_i       : in std_logic := '0';

        -- fire12-1, up, down, left, right
        player1_o         : out std_logic_vector(15 downto 0);
        player2_o         : out std_logic_vector(15 downto 0);

        -- sega joystick
        sega_strobe_o     : out std_logic

);
end MC2_HID_JOY;

architecture Behavioral of MC2_HID_JOY is

signal joy0 : std_logic_vector(5 downto 0);
signal joy1 : std_logic_vector(5 downto 0);

signal p1 : std_logic_vector(15 downto 0);
signal p2 : std_logic_vector(15 downto 0);

-- sega
signal clk_sega_s : std_logic := '0';
signal clk_delay : unsigned(9 downto 0) := (others=>'1');
signal TIMECLK   : integer;

signal joyP7_s : std_logic := '0';
signal sega1_s : std_logic_vector(11 downto 0) := (others=>'1');
signal sega2_s : std_logic_vector(11 downto 0) := (others=>'1');
signal segaf1_s : std_logic_vector(11 downto 0) := (others=>'1');
signal segaf2_s : std_logic_vector(11 downto 0) := (others=>'1');

begin 


joy0 <= joystick_1_i when joyswap_i = '1' else joystick_0_i;
joy1 <= joystick_0_i when joyswap_i = '1' else joystick_1_i;


-- output format MXYZ SACB UDLR 
p1 <= ("0000" & (not segaf1_s)); --or 
      --("000" & btn_fireI & btn_fireH  &  btn_fireE  & btn_fireF  & btn_fireG  & btn_fireD  & btn_fireA  & btn_fireC  & btn_fireB  & btn_up  & btn_down  & btn_left  & btn_right);   


p2 <= ("0000" & (not segaf2_s)); --or 
      --("000" & btn_fire2I & btn_fire2H &  btn_fire2E & btn_fire2F & btn_fire2G & btn_fire2D & btn_fire2A & btn_fire2C & btn_fire2B & btn_up2 & btn_down2 & btn_left2 & btn_right2);

player1_o <= p1 or p2 when oneplayer_i = '1' else p1;
player2_o <= p1 or p2 when oneplayer_i = '1' else p2;


--- Joystick read with sega 6 button support----------------------

process(clk_i)
begin
    if rising_edge(clk_i) then

        
        TIMECLK <= (9 * (CLK_SPEED/1000)); -- calculate ~9us from the master clock

        clk_delay <= clk_delay - 1;
        
        if (clk_delay = 0) then
            clk_sega_s <= not clk_sega_s;
            clk_delay <= to_unsigned(TIMECLK,10); 
        end if;

    end if;
end process;


process(clk_i)
    variable state_v : unsigned(8 downto 0) := (others=>'0');
    variable j1_sixbutton_v : std_logic := '0';
    variable j2_sixbutton_v : std_logic := '0';
    variable sega_edge : std_logic_vector(1 downto 0);
begin
    if rising_edge(clk_i) then

        sega_edge := sega_edge(0) & clk_sega_s;

        if sega_edge = "01" then
            state_v := state_v + 1;
            
            case state_v is
                -- joy_s format MXYZ SACB UDLR
                --              BA98 7654 3210
                
                when '0'&X"01" =>  
                    joyP7_s <= '0';
                    
                when '0'&X"02" =>  
                    joyP7_s <= '1';
                    
                when '0'&X"03" => 
                    sega1_s(5 downto 0) <= joy0(5 downto 0); -- C, B, up, down, left, right 
                    sega2_s(5 downto 0) <= joy1(5 downto 0);        
                    
                    j1_sixbutton_v := '0'; -- Assume it's not a six-button controller
                    j2_sixbutton_v := '0'; -- Assume it's not a six-button controller

                    joyP7_s <= '0';

                when '0'&X"04" =>
                    if joy0(0) = '0' and joy0(1) = '0' then -- it's a megadrive controller
                                sega1_s(7 downto 6) <= joy0(5 downto 4); -- Start, A
                    else
                             -- sega1_s(7 downto 4) <= "11" & joy0(5 downto 4);       -- It's an Atari or Master System controller (overwrite B and C)
                                sega1_s(7 downto 4) <= '1' & joy0(4) & '1' & joy0(5); -- It's an Atari or Master System controller (overwrite A and B)
                    end if;
                            
                    if joy1(0) = '0' and joy1(1) = '0' then -- it's a megadrive controller
                                sega2_s(7 downto 6) <= joy1(5 downto 4); -- Start, A
                    else
                            --  sega2_s(7 downto 4) <= "11" & joy1(5 downto 4);       -- It's an Atari or Master System controller (overwrite B and C)
                                sega2_s(7 downto 4) <= '1' & joy1(4) & '1' & joy1(5); -- It's an Atari or Master System controller (overwrite A and B)
                    end if;
                    
                                        
                    joyP7_s <= '1';
            
                when '0'&X"05" =>  
                    joyP7_s <= '0';
                    
                when '0'&X"06" =>
                    if joy0(2) = '0' and joy0(3) = '0' then 
                        j1_sixbutton_v := '1'; --it's a Sega six button
                    end if;
                    
                    if joy1(2) = '0' and joy1(3) = '0' then 
                        j2_sixbutton_v := '1'; --it's a Sega six button
                    end if;
                    
                    joyP7_s <= '1';
                    
                when '0'&X"07" =>
                    if j1_sixbutton_v = '1' then
                        sega1_s(11 downto 8) <= joy0(0) & joy0(1) & joy0(2) & joy0(3); -- Mode, X, Y e Z                        
                    end if;

                    if j2_sixbutton_v = '1' then
                        sega2_s(11 downto 8) <= joy1(0) & joy1(1) & joy1(2) & joy1(3); -- Mode, X, Y e Z
                    end if;

                    -- if (sega1_s(11) = '0' and sega1_s(7) = '0') or (sega2_s(11) = '0' and sega2_s(7) = '0') then
                    --     osd_sega <= (OSD_CMD & (sega1_s(4) and sega1_s(5) and sega1_s(6)) & sega1_s(0) & sega1_s(1) & sega1_s(2) & sega1_s(3));
                    -- else
                    --     osd_sega <= ("111" & (sega1_s(4) and sega1_s(5) and sega1_s(6)) & sega1_s(0) & sega1_s(1) & sega1_s(2) & sega1_s(3));
                    -- end if;
                    joyP7_s <= '0';

                when others =>
                    joyP7_s <= '1';
                    
            end case;

            segaf1_s <= sega1_s;
            segaf2_s <= sega2_s;
         

        end if;
    end if;
end process;

sega_strobe_o <= joyP7_s;

end Behavioral;