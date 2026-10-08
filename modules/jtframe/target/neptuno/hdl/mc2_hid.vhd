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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity MC2_HID is
generic
(
        OSD_CMD         : in   std_logic_vector(2 downto 0) := "011";
        CLK_SPEED       : integer := 50000
);
port 
(
        Clk_i             : in std_logic;
        reset_i           : in std_logic := '0';

        kbd_clk_i         : in std_logic;
        kbd_dat_i         : in std_logic;

        joystick_0_i      : in std_logic_vector(5 downto 0);
        joystick_1_i      : in std_logic_vector(5 downto 0);

        -- joystick_0 and joystick_1 should be swapped
        joyswap_i         : in std_logic := '0';

        -- player1 and player2 should get both joystick_0 and joystick_1
        oneplayer_i       : in std_logic := '0';

        -- tilt, coin4-1, start4-1
        controls_o        : out std_logic_vector(8 downto 0);

        -- Function Keys
        F_keys_o          : out std_logic_vector(12 downto 1);

        toggle_scandb_o   : out std_logic := '0';
        osd_rotate_o      : out std_logic_vector(1 downto 0) := "00";

        -- fire12-1, up, down, left, right
        player1_o         : out std_logic_vector(15 downto 0);
        player2_o         : out std_logic_vector(15 downto 0);

        osd_o             : out   std_logic_vector(7 downto 0);
        osd_enable_i      : in std_logic;

        -- sega joystick
        sega_strobe_o     : out std_logic;

        -- Front buttons
        front_buttons_i   : in std_logic_vector(3 downto 0) := "1111";
        front_buttons_o   : out std_logic_vector(3 downto 0)
);
end MC2_HID;

architecture Behavioral of MC2_HID is

-- Front buttons
signal   fb_o_s             : std_logic_vector (3 downto 0) := (others => '1');
signal   fb_reset           : std_logic := '1';
signal   fb_osd             : std_logic_vector (7 downto 0) := (others => '1');
constant fb_reset_time      : integer := (CLK_SPEED*1500); -- 1.5s button for hold to reset
constant fb_osd_time        : integer := (CLK_SPEED*200); -- 200 ms - duration of the open OSD command

signal ps2_key_code_s : std_logic_vector(7 downto 0) := (others => '0');
signal ps2_key_strobe_s   : std_logic := '0'; 
signal ps2_key_extended_s : std_logic; 
signal IsReleased : std_logic;

signal F_keys_s   : std_logic_vector(12 downto 1) := (others=>'0');

signal osd_s      : std_logic_vector(7 downto 0) := (others=>'1');
signal osd_sega   : std_logic_vector(7 downto 0) := (others=>'1');

-- keyboard controls
signal btn_tilt : std_logic := '0';
signal btn_one_player : std_logic := '0';
signal btn_two_players : std_logic := '0';
signal btn_three_players : std_logic := '0';
signal btn_four_players : std_logic := '0';
signal btn_left : std_logic := '0';
signal btn_right : std_logic := '0';
signal btn_down : std_logic := '0';
signal btn_up : std_logic := '0';
signal btn_fireA : std_logic := '0';
signal btn_fireB : std_logic := '0';
signal btn_fireC : std_logic := '0';
signal btn_fireD : std_logic := '0';
signal btn_fireE : std_logic := '0';
signal btn_fireF : std_logic := '0';
signal btn_fireG : std_logic := '0';
signal btn_fireH : std_logic := '0';
signal btn_fireI : std_logic := '0';
signal btn_coin  : std_logic := '0';
signal btn_start1_mame : std_logic := '0';
signal btn_start2_mame : std_logic := '0';
signal btn_start3_mame : std_logic := '0';
signal btn_start4_mame : std_logic := '0';
signal btn_coin1_mame : std_logic := '0';
signal btn_coin2_mame : std_logic := '0';
signal btn_coin3_mame : std_logic := '0';
signal btn_coin4_mame : std_logic := '0';
signal btn_up2 : std_logic := '0';
signal btn_down2 : std_logic := '0';
signal btn_left2 : std_logic := '0';
signal btn_right2 : std_logic := '0';
signal btn_fire2A : std_logic := '0';
signal btn_fire2B : std_logic := '0';
signal btn_fire2C : std_logic := '0';
signal btn_fire2D : std_logic := '0';
signal btn_fire2E : std_logic := '0';
signal btn_fire2F : std_logic := '0';
signal btn_fire2G : std_logic := '0';
signal btn_fire2H : std_logic := '0';
signal btn_fire2I : std_logic := '0';

--signal btn_scroll : std_logic := '0';

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

signal osd_rotate_s : std_logic_vector(1 downto 0);
signal direct_video_s : std_logic := '0';

signal keyb_strobe_s : std_logic := '1';

begin 

osd_rotate_o <= osd_rotate_s;
toggle_scandb_o <= direct_video_s;
front_buttons_o <= fb_reset & fb_o_s(2 downto 0);
                    --when osd_enable_i = '0' else fb_reset & "111"; --ideally we should know when the OSD is open

joy0 <= joystick_1_i when joyswap_i = '1' else joystick_0_i;
joy1 <= joystick_0_i when joyswap_i = '1' else joystick_1_i;


controls_o <= ( btn_tilt ) &
              ( btn_coin or btn_coin4_mame ) & 
              ( btn_coin or btn_coin3_mame ) &
              ( btn_coin or btn_coin2_mame ) & 
              ( btn_coin or btn_coin1_mame ) &
              ( btn_start4_mame ) & 
              ( btn_start3_mame ) & 
              ( btn_start2_mame ) &
              ( btn_start1_mame );


-- output format MXYZ SACB UDLR 
p1 <= ("0000" & (not segaf1_s)) or 
      ("000" & btn_fireI & btn_fireH  &  btn_fireE  & btn_fireF  & btn_fireG  & btn_fireD  & btn_fireA  & btn_fireC  & btn_fireB  & btn_up  & btn_down  & btn_left  & btn_right);   
          --  when osd_enable_i = '0' else (others=>'0'); --ideally we should know when the OSD is open


p2 <= ("0000" & (not segaf2_s)) or 
      ("000" & btn_fire2I & btn_fire2H &  btn_fire2E & btn_fire2F & btn_fire2G & btn_fire2D & btn_fire2A & btn_fire2C & btn_fire2B & btn_up2 & btn_down2 & btn_left2 & btn_right2);
         --   when osd_enable_i = '0' else (others=>'0'); --ideally we should know when the OSD is open


player1_o <= p1 or p2 when oneplayer_i = '1' else p1;
player2_o <= p1 or p2 when oneplayer_i = '1' else p2;

osd_o <= osd_s and osd_sega and fb_osd 
            when osd_enable_i = '1' else (osd_s(7 downto 5) and osd_sega(7 downto 5) and fb_osd(7 downto 5)) & "11111";


F_keys_o <= F_keys_s;

bt1 : entity work.debounce port map(clk_i, front_buttons_i(0), fb_o_s(0));
bt2 : entity work.debounce port map(clk_i, front_buttons_i(1), fb_o_s(1));
bt3 : entity work.debounce port map(clk_i, front_buttons_i(2), fb_o_s(2));
bt4 : entity work.debounce port map(clk_i, front_buttons_i(3), fb_o_s(3));

-- Front buttons debouncing process
process(clk_i)
  variable cnt_r : integer := 0;
  variable osd_on : integer := 0;
begin
  if rising_edge(clk_i) then

    -- And this is the reset specific check
    if (fb_o_s(3) = '0' and fb_reset = '1') then
        if (cnt_r = 0) then
            cnt_r := fb_reset_time;
        elsif (cnt_r = 1) then
            cnt_r := 0;
            fb_reset <= '0';
        else
            cnt_r := cnt_r - 1;
        end if;
    elsif (fb_o_s(3) = '1' and fb_reset = '0') then
        fb_reset <= '1';
        cnt_r := 0;
    elsif (fb_o_s(3) = '1' and cnt_r /= 0) then -- the button was released before the reset time, so it´s an "open OSD"
        osd_on := fb_osd_time;
        cnt_r := 0;
    else
        cnt_r := 0;
    end if;

    -- This is what sends the OSD invoking
--    if (fb_o_s(3) = '0' and fb_reset = '1') then
    if osd_on /= 0 then
        osd_on := osd_on - 1;
        fb_osd(7 downto 5) <= OSD_CMD; -- OSD Menu command
    else
        fb_osd(7 downto 5) <= "111";
    end if;

    -- And this is what sends UP (0), DOWN (2) and enter (1)
    if (osd_enable_i = '1' and fb_reset = '1') then
        fb_osd(0) <= fb_o_s(0);
        fb_osd(1) <= fb_o_s(2);
        fb_osd(4) <= fb_o_s(1);
    elsif (osd_enable_i = '1' and fb_reset = '0') then
        fb_osd(7 downto 5) <= OSD_CMD; -- OSD Menu command to disable it after reset
        fb_osd(4 downto 0) <= "11111";
    else
        fb_osd(4 downto 0) <= "11111";
    end if;
  end if;
end process;

ps2_keyboard : entity work.ps2_intf
port map 
(
    CLK             => clk_i,
    nRESET          => not reset_i,

    -- PS/2 interface
    PS2_CLK      => kbd_clk_i,
    PS2_DATA     => kbd_dat_i,
    
    -- Direct Access
    VALID    => ps2_key_strobe_s,
    DATA     => ps2_key_code_s
);


-- PS2 Keyboard Scan Conversion
process(clk_i)

begin
  if rising_edge(clk_i) then
  
        if ps2_key_strobe_s = '1' then
      
            if (ps2_key_code_s = "11110000") then IsReleased <= '1'; else IsReleased <= '0'; end if;          

            if ps2_key_code_s = x"05" then F_keys_s(1)       <= not(IsReleased); end if; -- F1
            if ps2_key_code_s = x"06" then F_keys_s(2)       <= not(IsReleased); end if; -- F2
            if ps2_key_code_s = x"04" then F_keys_s(3)       <= not(IsReleased); end if; -- F3
            if ps2_key_code_s = x"0C" then F_keys_s(4)       <= not(IsReleased); end if; -- F4
            if ps2_key_code_s = x"78" then F_keys_s(11)      <= not(IsReleased); if osd_enable_i = '1' and  IsReleased = '0'  then osd_rotate_s <= osd_rotate_s + 1; end if; end if; -- F11

            if ps2_key_code_s = x"7E" then if IsReleased = '0' then direct_video_s <= not direct_video_s;   end if; end if; -- Scroll Lock

            if ps2_key_code_s = x"75" then btn_up            <= not(IsReleased); end if; -- up
            if ps2_key_code_s = x"72" then btn_down          <= not(IsReleased); end if; -- down
            if ps2_key_code_s = x"6B" then btn_left          <= not(IsReleased); end if; -- left
            if ps2_key_code_s = x"74" then btn_right         <= not(IsReleased); end if; -- right
            if ps2_key_code_s = x"76" then btn_coin          <= not(IsReleased); end if; -- ESC

            if ps2_key_code_s = x"12" then btn_fireD         <= not(IsReleased); end if; -- l-shift
            if ps2_key_code_s = x"14" then btn_fireA         <= not(IsReleased); end if; -- ctrl
            if ps2_key_code_s = x"11" then btn_fireB         <= not(IsReleased); end if; -- alt
            if ps2_key_code_s = x"29" then btn_fireC         <= not(IsReleased); end if; -- Space
            if ps2_key_code_s = x"1A" then btn_fireE         <= not(IsReleased); end if; -- Z
            if ps2_key_code_s = x"22" then btn_fireF         <= not(IsReleased); end if; -- X
            if ps2_key_code_s = x"21" then btn_fireG         <= not(IsReleased); end if; -- C
            if ps2_key_code_s = x"2A" then btn_fireH         <= not(IsReleased); end if; -- V
            if ps2_key_code_s = x"32" then btn_fireI         <= not(IsReleased); end if; -- B
            if ps2_key_code_s = x"66" then btn_tilt          <= not(IsReleased); end if; -- Backspace

            -- JPAC/IPAC/MAME Style Codes
            if ps2_key_code_s = x"16" then btn_start1_mame   <= not(IsReleased); end if; -- 1
            if ps2_key_code_s = x"1E" then btn_start2_mame   <= not(IsReleased); end if; -- 2
            if ps2_key_code_s = x"26" then btn_start3_mame   <= not(IsReleased); end if; -- 3
            if ps2_key_code_s = x"25" then btn_start4_mame   <= not(IsReleased); end if; -- 4
            if ps2_key_code_s = x"2E" then btn_coin1_mame    <= not(IsReleased); end if; -- 5
            if ps2_key_code_s = x"36" then btn_coin2_mame    <= not(IsReleased); end if; -- 6
            if ps2_key_code_s = x"3D" then btn_coin3_mame    <= not(IsReleased); end if; -- 7
            if ps2_key_code_s = x"3E" then btn_coin4_mame    <= not(IsReleased); end if; -- 8
            

            osd_s (4 downto 0) <= "11111";
            if (IsReleased = '0') then  
                    if ps2_key_code_s = x"75" then osd_s(4 downto 0) <= "11110"; end if; -- up    arrow : 0x75
                    if ps2_key_code_s = x"72" then osd_s(4 downto 0) <= "11101"; end if; -- down  arrow : 0x72
                    if ps2_key_code_s = x"6b" then osd_s(4 downto 0) <= "11011"; end if; -- left  arrow : 0x6B
                    if ps2_key_code_s = x"74" then osd_s(4 downto 0) <= "10111"; end if; -- right arrow : 0x74
                    if ps2_key_code_s = x"5A" then osd_s(4 downto 0) <= "01111"; end if; -- ENTER
                        
                    if ps2_key_code_s = x"1c" then osd_s(4 downto 0) <= "00000"; end if;   -- A
                    if ps2_key_code_s = x"32" then osd_s(4 downto 0) <= "00001"; end if;   -- B
                    if ps2_key_code_s = x"21" then osd_s(4 downto 0) <= "00010"; end if;   -- C
                    if ps2_key_code_s = x"23" then osd_s(4 downto 0) <= "00011"; end if;   -- D
                    if ps2_key_code_s = x"24" then osd_s(4 downto 0) <= "00100"; end if;   -- E
                    if ps2_key_code_s = x"2b" then osd_s(4 downto 0) <= "00101"; end if;   -- F
                    if ps2_key_code_s = x"34" then osd_s(4 downto 0) <= "00110"; end if;   -- G
                    if ps2_key_code_s = x"33" then osd_s(4 downto 0) <= "00111"; end if;   -- H
                    if ps2_key_code_s = x"43" then osd_s(4 downto 0) <= "01000"; end if;   -- I
                    if ps2_key_code_s = x"3b" then osd_s(4 downto 0) <= "01001"; end if;   -- J
                    if ps2_key_code_s = x"42" then osd_s(4 downto 0) <= "01010"; end if;   -- K
                    if ps2_key_code_s = x"4b" then osd_s(4 downto 0) <= "01011"; end if;   -- L
                    if ps2_key_code_s = x"3a" then osd_s(4 downto 0) <= "01100"; end if;   -- M
                    if ps2_key_code_s = x"31" then osd_s(4 downto 0) <= "01101"; end if;   -- N
                    if ps2_key_code_s = x"44" then osd_s(4 downto 0) <= "01110"; end if;   -- O
                    if ps2_key_code_s = x"4d" then osd_s(4 downto 0) <= "10000"; end if;   -- P
                    if ps2_key_code_s = x"15" then osd_s(4 downto 0) <= "10001"; end if;   -- Q
                    if ps2_key_code_s = x"2d" then osd_s(4 downto 0) <= "10010"; end if;   -- R
                    if ps2_key_code_s = x"1b" then osd_s(4 downto 0) <= "10011"; end if;   -- S
                    if ps2_key_code_s = x"2c" then osd_s(4 downto 0) <= "10100"; end if;   -- T
                    if ps2_key_code_s = x"3c" then osd_s(4 downto 0) <= "10101"; end if;   -- U
                    if ps2_key_code_s = x"2a" then osd_s(4 downto 0) <= "10110"; end if;   -- V
                    if ps2_key_code_s = x"1d" then osd_s(4 downto 0) <= "11000"; end if;   -- W
                    if ps2_key_code_s = x"22" then osd_s(4 downto 0) <= "11001"; end if;   -- X
                    if ps2_key_code_s = x"35" then osd_s(4 downto 0) <= "11010"; end if;   -- Y
                    if ps2_key_code_s = x"1a" then osd_s(4 downto 0) <= "11100"; end if;   -- Z
                    
            end if;
            
            if (ps2_key_code_s = x"07" and IsReleased = '0') or  -- key F12
               (ps2_key_code_s = x"76" and IsReleased = '0' and osd_enable_i = '1') then -- ESC to abort an opened menu
                osd_s(7 downto 5) <= OSD_CMD; -- OSD Menu command
            else
                osd_s(7 downto 5) <= "111"; -- release
            end if;
        end if;

  end if;
end process;


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

                    if (sega1_s(11) = '0' and sega1_s(7) = '0') or (sega2_s(11) = '0' and sega2_s(7) = '0') then
                        osd_sega <= (OSD_CMD & (sega1_s(4) and sega1_s(5) and sega1_s(6)) & sega1_s(0) & sega1_s(1) & sega1_s(2) & sega1_s(3));
                    else
                        osd_sega <= ("111" & (sega1_s(4) and sega1_s(5) and sega1_s(6)) & sega1_s(0) & sega1_s(1) & sega1_s(2) & sega1_s(3));
                    end if;
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
---------------------------

end Behavioral;


--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY debounce IS
  GENERIC(
    counter_size  :  INTEGER := 3); --counter size 
  PORT(
    clk_i     : IN  STD_LOGIC;  --input clock
    button_i  : IN  STD_LOGIC;  --input signal to be debounced
    result_o  : OUT STD_LOGIC); --debounced signal
END debounce;

ARCHITECTURE logic OF debounce IS
  SIGNAL flipflops   : STD_LOGIC_VECTOR(1 DOWNTO 0); --input flip flops
  SIGNAL counter_set : STD_LOGIC;                    --sync reset to zero
  SIGNAL counter_out : STD_LOGIC_VECTOR(counter_size DOWNTO 0) := (OTHERS => '0'); --counter output
BEGIN

  counter_set <= flipflops(0) xor flipflops(1);   --determine when to start/reset counter
  
  PROCESS(clk_i)
  BEGIN
    IF(clk_i'EVENT and clk_i= '1') THEN
      flipflops(0) <= button_i;
      flipflops(1) <= flipflops(0);
      If(counter_set = '1') THEN                  --reset counter because input is changing
        counter_out <= (OTHERS => '0');
      ELSIF(counter_out(counter_size) = '0') THEN --stable input time is not yet met
        counter_out <= counter_out + 1;
      ELSE                                        --stable input time is met
        result_o <= flipflops(1);
      END IF;    
    END IF;
  END PROCESS;
END logic;