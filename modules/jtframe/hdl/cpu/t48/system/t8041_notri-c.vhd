-------------------------------------------------------------------------------
--
-- T8041 Microcontroller System
--
-- Copyright (c) 2004-2022, Arnim Laeuger (arniml@opencores.org)
--
-- All rights reserved
--
-------------------------------------------------------------------------------

configuration t8041_notri_struct_c0 of t8041_notri is

  for struct

    for rom_1k_b : t48_rom
      use configuration work.t48_rom_lpm_c0;
    end for;

    for ram_64_b : generic_ram_ena
      use configuration work.generic_ram_ena_rtl_c0;
    end for;

    for upi41_core_b : upi41_core
      use configuration work.upi41_core_struct_c0;
    end for;

  end for;

end t8041_notri_struct_c0;
