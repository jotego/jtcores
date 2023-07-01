-------------------------------------------------------------------------------
--
-- $Id: cond_branch_pack-p.vhd 303 2022-12-16 19:56:46Z arniml $
--
-- Copyright (c) 2004, Arnim Laeuger (arniml@opencores.org)
--
-- All rights reserved
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package t48_cond_branch_pack is

  -----------------------------------------------------------------------------
  -- The branch conditions.
  -----------------------------------------------------------------------------
  type branch_conditions_t is (COND_ON_BIT, COND_Z,
                               COND_C,
                               COND_F0, COND_F1,
                               COND_INT,
                               COND_T0, COND_T1,
                               COND_TF,
                               -- UPI41
                               COND_NIBF,
                               COND_OBF);

  subtype comp_value_t is std_logic_vector(2 downto 0);

end t48_cond_branch_pack;
