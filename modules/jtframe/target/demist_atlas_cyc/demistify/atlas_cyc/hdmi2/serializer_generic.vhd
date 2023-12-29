-- (c) EMARD
-- LICENSE=BSD

-- generic (vendor-agnostic) serializer

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY serializer_generic IS
GENERIC
(
  C_channel_bits: integer := 10; -- number of bits per channel
  C_output_bits: integer := 1; -- output bits per channel
  C_channels: integer := 3 -- number of channels to serialize
);
PORT
(
  tx_in	       : IN STD_LOGIC_VECTOR(C_channel_bits*C_channels-1 DOWNTO 0);
  tx_inclock   : IN STD_LOGIC; -- 10x tx_syncclock
  tx_syncclock : IN STD_LOGIC;
  tx_out       : OUT STD_LOGIC_VECTOR((C_channels+1)*C_output_bits-1 DOWNTO 0) -- one more channel for clock
);
END;

ARCHITECTURE SYN OF serializer_generic IS
  signal R_tx_latch: std_logic_vector(C_channel_bits*C_channels-1 downto 0);
  signal S_tx_clock: std_logic_vector(C_channel_bits-1 downto 0);
  type T_channel_shift is array(0 to C_channels) of std_logic_vector(C_channel_bits-1 downto 0); -- -- one channel more for clock
  signal S_channel_latch, R_channel_shift: T_channel_shift;
  signal R_pixel_clock_toggle, R_prev_pixel_clock_toggle: std_logic;
  signal R_clock_edge: std_logic;
  constant C_shift_pad: std_logic_vector(C_output_bits-1 downto 0) := (others => '0');
BEGIN
  process(tx_syncclock) -- pixel clock
  begin
    if rising_edge(tx_syncclock) then
      R_tx_latch <= tx_in; -- add the clock to be shifted to the channels
    end if;
  end process;

  -- rename - separate to shifted 4 channels
  separate_channels:
  for i in 0 to C_channels-1 generate
    reverse_bits:
    for j in 0 to C_channel_bits-1 generate
      S_channel_latch(i)(j) <= R_tx_latch(C_channel_bits*(i+1)-j-1);
    end generate;
  end generate;

  S_channel_latch(3) <= "1111100000"; -- the clock pattern

  process(tx_syncclock)
  begin
    if rising_edge(tx_syncclock) then
      R_pixel_clock_toggle <= not R_pixel_clock_toggle;
    end if;
  end process;

  -- shift-synchronous pixel clock edge detection
  process(tx_inclock) -- pixel shift clock (250 MHz)
  begin
    if rising_edge(tx_inclock) then -- pixel clock (25 MHz)
      R_prev_pixel_clock_toggle <= R_pixel_clock_toggle;
      R_clock_edge <= R_pixel_clock_toggle xor R_prev_pixel_clock_toggle;
    end if;
  end process;

  -- fixme: initial state issue (clock shifting?)
  process(tx_inclock) -- pixel shift clock
  begin
    if rising_edge(tx_inclock) then
      if R_clock_edge='1' then -- rising edge detection
        R_channel_shift(0) <= S_channel_latch(0);
        R_channel_shift(1) <= S_channel_latch(1);
        R_channel_shift(2) <= S_channel_latch(2);
        R_channel_shift(3) <= S_channel_latch(3);
      else
        R_channel_shift(0) <= C_shift_pad & R_channel_shift(0)(C_channel_bits-1 downto C_output_bits);
        R_channel_shift(1) <= C_shift_pad & R_channel_shift(1)(C_channel_bits-1 downto C_output_bits);
        R_channel_shift(2) <= C_shift_pad & R_channel_shift(2)(C_channel_bits-1 downto C_output_bits);
        R_channel_shift(3) <= C_shift_pad & R_channel_shift(3)(C_channel_bits-1 downto C_output_bits);
      end if;
    end if;
  end process;

  tx_out <= R_channel_shift(3)(C_output_bits-1 downto 0) 
          & R_channel_shift(2)(C_output_bits-1 downto 0) 
          & R_channel_shift(1)(C_output_bits-1 downto 0) 
          & R_channel_shift(0)(C_output_bits-1 downto 0);

END SYN;
