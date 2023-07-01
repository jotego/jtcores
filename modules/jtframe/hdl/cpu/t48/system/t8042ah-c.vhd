-------------------------------------------------------------------------------
--
-- T8042AH Microcontroller System
--
-- Copyright (c) 2004-2022, Arnim Laeuger (arniml@opencores.org)
--
-- All rights reserved
--
-------------------------------------------------------------------------------

configuration t8042ah_struct_c0 of t8042ah is

  for struct

    for t8042ah_notri_b : t8042ah_notri
      use configuration work.t8042ah_notri_struct_c0;
    end for;

  end for;

end t8042ah_struct_c0;
