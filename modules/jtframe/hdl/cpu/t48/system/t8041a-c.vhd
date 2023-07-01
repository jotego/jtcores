-------------------------------------------------------------------------------
--
-- T8041A Microcontroller System
--
-- Copyright (c) 2004-2022, Arnim Laeuger (arniml@opencores.org)
--
-- All rights reserved
--
-------------------------------------------------------------------------------

configuration t8041a_struct_c0 of t8041a is

  for struct

    for t8041a_notri_b : t8041a_notri
      use configuration work.t8041a_notri_struct_c0;
    end for;

  end for;

end t8041a_struct_c0;
