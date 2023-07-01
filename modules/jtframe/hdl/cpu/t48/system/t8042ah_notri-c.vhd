-------------------------------------------------------------------------------
--
-- T8042AH Microcontroller System
--
-- Copyright (c) 2004-2022, Arnim Laeuger (arniml@opencores.org)
--
-- All rights reserved
--
-------------------------------------------------------------------------------

configuration t8042ah_notri_struct_c0 of t8042ah_notri is

  for struct

    for rom_2k_b : t49_rom
      use configuration work.t49_rom_lpm_c0;
    end for;

    for ram_256_b : generic_ram_ena
      use configuration work.generic_ram_ena_rtl_c0;
    end for;

    for upi41a_core_b : upi41_core
      use configuration work.upi41_core_struct_c0;
    end for;

  end for;

end t8042ah_notri_struct_c0;
