---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
ENTITY scandouble_ram_infer_9 IS
   PORT
   (
      clock: IN   std_logic;
      data:  IN   std_logic_vector (8 DOWNTO 0);
      address:  IN   integer RANGE 0 to 1824;
      we:    IN   std_logic;
      q:     OUT  std_logic_vector (8 DOWNTO 0)
   );
END scandouble_ram_infer_9;

ARCHITECTURE rtl OF scandouble_ram_infer_9 IS
   TYPE mem IS ARRAY(0 TO 1824) OF std_logic_vector(8 DOWNTO 0); -- TODO need 455 but this leads to glitches in the hblank
   SIGNAL ram_block : mem;
BEGIN
   PROCESS (clock)
   BEGIN
      IF (clock'event AND clock = '1') THEN
         IF (we = '1') THEN
            ram_block(address) <= data;
         END IF;
         q <= ram_block(address);
      END IF;
   END PROCESS;
END rtl;