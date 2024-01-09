library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity joystick_sega is
generic
(
        CLK_SPEED       : integer := 50000
);
port 
(
		joy0 			: in std_logic_vector(5 downto 0);
		joy1 			: in std_logic_vector(5 downto 0);
		
		-- fire12-1, up, down, left, right
		player1			: out std_logic_vector(11 downto 0);
		player2			: out std_logic_vector(11 downto 0);
		
		-- sega joystick
		clk_i    		: in std_logic;
		sega_strobe		: out std_logic
);
end joystick_sega;

architecture Behavioral of joystick_sega is

-- sega
signal joyP7_s : std_logic := '0';
signal sega1_s : std_logic_vector(11 downto 0) := (others=>'1');
signal sega2_s : std_logic_vector(11 downto 0) := (others=>'1');

signal clk_sega_s : std_logic := '0';
signal clk_delay : unsigned(9 downto 0) := (others=>'1');
signal TIMECLK   : integer;


begin 
				
    player1 <= sega1_s;
    player2 <= sega2_s;
	

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
                                    sega1_s(7 downto 6) <= joy0(5 downto 4); -- A, Start
                        else
                                    --sega1_s(7 downto 4) <= "11" & joy0(5 downto 4); -- read A/B as master System
								
                                    sega1_s(7 downto 4) <= '1' & joy0(4) & '1' & joy0(5); -- read A/B as master System
                        end if;
							
                        if joy1(0) = '0' and joy1(1) = '0' then -- it's a megadrive controller
								sega2_s(7 downto 6) <=  joy1(5 downto 4); -- A, Start
                        else
								--sega2_s(7 downto 4) <= "11" & joy1(5 downto 4); -- read A/B as master System
								
								--              1098 7654 3210 
								-- joy_s format MXYZ SACB UDLR
								sega2_s(7 downto 4) <= '1' & joy1( 4)  & '1' & joy1(5); -- read A/B as master System																								
                        end if;
					
										
                        joyP7_s <= '1';
			
                    when '0'&X"05" =>  
                        joyP7_s <= '0';
					
                    when '0'&X"06" =>
                        if joy0(2) = '0' and joy0(3) = '0' then 
                            j1_sixbutton_v := '1'; --it's a six button
                        end if;
					
                        if joy1(2) = '0' and joy1(3) = '0' then 
                            j2_sixbutton_v := '1'; --it's a six button
                        end if;
					
                        joyP7_s <= '1';
					
                    when '0'&X"07" =>
                        if j1_sixbutton_v = '1' then
                            sega1_s(11 downto 8) <= joy0(0) & joy0(1) & joy0(2) & joy0(3); -- Mode, X, Y e Z
                        end if;
					
                        if j2_sixbutton_v = '1' then
                            sega2_s(11 downto 8) <= joy1(0) & joy1(1) & joy1(2) & joy1(3); -- Mode, X, Y e Z
                        end if;
					
                        joyP7_s <= '0';
					


                    when others =>
                        joyP7_s <= '1';
					
                end case;

            end if;
        end if;
	end process;
	
	sega_strobe <= joyP7_s;
---------------------------

end Behavioral;


