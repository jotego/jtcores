-------------------------------------------------------------------------------
--
-- T8041 Microcontroller System
--
-- Copyright (c) 2004-2022, Arnim Laeuger (arniml@opencores.org)
--
-- All rights reserved
--
-------------------------------------------------------------------------------

configuration t8041_struct_c0 of t8041 is

  for struct

    for t8041_notri_b : t8041_notri
      use configuration work.t8041_notri_struct_c0;
    end for;

  end for;

end t8041_struct_c0;
