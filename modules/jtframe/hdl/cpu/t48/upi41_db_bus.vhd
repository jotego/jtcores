-------------------------------------------------------------------------------
--
-- The UPI-41 BUS unit.
-- Implements the BUS port logic.
--
-- Copyright (c) 2004-2022, Arnim Laeuger (arniml@opencores.org)
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
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
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
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.
--
-- The latest version of this file can be found at:
--      http://www.opencores.org/cvsweb.shtml/t48/
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.t48_pack.word_t;

entity upi41_db_bus is

  generic (
    is_type_a_g : integer := 1
  );
  port (
    -- Global Interface -------------------------------------------------------
    clk_i        : in  std_logic;
    res_i        : in  std_logic;
    en_clk_i     : in  boolean;
    -- UPI41 Bus Interface ----------------------------------------------------
    data_i       : in  word_t;
    data_o       : out word_t;
    write_bus_i  : in  boolean;
    read_bus_i   : in  boolean;
    write_sts_i  : in  boolean;
    set_f1_o     : out boolean;
    clear_f1_o   : out boolean;
    f0_i         : in  std_logic;
    f1_i         : in  std_logic;
    ibf_o        : out std_logic;
    obf_o        : out std_logic;
    int_n_o      : out std_logic;
    ibf_int_i    : in  boolean;
    en_dma_i     : in  boolean;
    en_flags_i   : in  boolean;
    -- P2 interface -----------------------------------------------------------
    write_p2_i   : in  boolean;
    mint_ibf_n_o : out std_logic;
    mint_obf_o   : out std_logic;
    dma_o        : out boolean;
    drq_o        : out std_logic;
    dack_n_i     : in  std_logic;
    -- BUS Interface ----------------------------------------------------------
    a0_i         : in  std_logic;
    cs_n_i       : in  std_logic;
    rd_n_i       : in  std_logic;
    wr_n_i       : in  std_logic;
    db_i         : in  word_t;
    db_o         : out word_t;
    db_dir_o     : out std_logic
  );

end upi41_db_bus;


use work.t48_pack.clk_active_c;
use work.t48_pack.res_active_c;
use work.t48_pack.bus_idle_level_c;
use work.t48_pack.to_stdLogic;

architecture rtl of upi41_db_bus is

  signal read_s, read_q,
         read_hold_q,
         write_s, write_q,
         read_pulse_s, write_pulse_s : boolean;

  signal a0_q : std_logic;

  signal ibf_q, obf_q : std_logic;

  -- the BUS output register
  signal dbbin_q,
         dbbout_q : word_t;
  -- the BUS status register
  signal sts_q    : std_logic_vector(7 downto 4);

  signal dma_q,
         flags_q : boolean;

  signal ext_acc_s : boolean;
  signal dack_s  : boolean;

begin

  -- pragma translate_off

  -- UPI41 configuration ------------------------------------------------------
  assert (is_type_a_g = 0) or (is_type_a_g = 1)
    report "is_type_a_g must be either 1 or 0!"
    severity failure;

  -- pragma translate_on


  -----------------------------------------------------------------------------
  -- Process master_access
  --
  -- Purpose:
  --   Generate read and write pulses based on master access.
  --
  dack_s    <= dack_n_i = '0' and dma_q;
  ext_acc_s <= cs_n_i = '0' or dack_s;
  read_s    <= ext_acc_s and rd_n_i = '0';
  write_s   <= ext_acc_s and wr_n_i = '0';
  --
  master_access: process (res_i, clk_i)
  begin
    if res_i = res_active_c then
      read_q      <= false;
      read_hold_q <= false;
      write_q     <= false;
      a0_q        <= '0';

    elsif clk_i'event and clk_i = clk_active_c then
      read_q  <= read_s;
      write_q <= write_s;

      if read_s then
        read_hold_q <= true;
      elsif ext_acc_s then
        read_hold_q <= false;
      end if;

      if dack_s then
        a0_q <= '0';
      elsif read_s or write_s then
        a0_q <= a0_i;
      end if;

    end if;
  end process master_access;
  --
  read_pulse_s  <= read_q and not read_s;
  write_pulse_s <= write_q and not write_s;

  -----------------------------------------------------------------------------
  -- Process bus_regs
  --
  -- Purpose:
  --   Implements the BUS output register.
  --
  bus_regs: process (res_i, clk_i)
  begin
    if res_i = res_active_c then
      dbbin_q  <= (others => '0');
      dbbout_q <= (others => '0');
      sts_q    <= (others => '0');
      ibf_q    <= '0';
      obf_q    <= '0';
      int_n_o  <= '1';
      dma_q    <= false;
      drq_o    <= '0';
      flags_q  <= false;

    elsif clk_i'event and clk_i = clk_active_c then
      -- master access
      if read_pulse_s and a0_q = '0' then
        obf_q <= '0';
      elsif write_pulse_s then
        dbbin_q <= db_i;
        ibf_q   <= '1';
        int_n_o <= '0';
      end if;

      if dack_s and (read_s or write_s) then
        drq_o <= '0';
      end if;

      if en_clk_i then
        if write_bus_i then
          dbbout_q <= data_i;
          obf_q    <= '1';
        elsif read_bus_i then
          ibf_q    <= '0';
        elsif write_sts_i then
          sts_q    <= data_i(7 downto 4);
        end if;

        if ibf_int_i then
          int_n_o <= '1';
        end if;

        if is_type_a_g = 1 then
          if en_dma_i then
            dma_q <= true;
            drq_o <= '0';
          end if;
          if en_flags_i then
            flags_q <= true;
          end if;

          if dma_q and write_p2_i and data_i(6) = '1' then
            drq_o <= '1';
          end if;
        end if;

      end if;

    end if;

  end process bus_regs;
  --
  -----------------------------------------------------------------------------


  -----------------------------------------------------------------------------
  -- Output Mapping.
  -----------------------------------------------------------------------------
  set_f1_o   <= write_pulse_s and a0_q = '1';
  clear_f1_o <= write_pulse_s and a0_q = '0';
  ibf_o      <= ibf_q;
  obf_o      <= obf_q;
  db_o       <= dbbout_q when a0_q = '0' else
                sts_q & f1_i & f0_i & ibf_q & obf_q when is_type_a_g = 1 else
                "0000" & f1_i & f0_i & ibf_q & obf_q;
  db_dir_o   <= '1' when ext_acc_s and read_hold_q else '0';
  data_o     <=   dbbin_q
                when read_bus_i else
                  (others => bus_idle_level_c);

  mint_ibf_n_o <= '0' when flags_q and ibf_q = '1' else '1';
  mint_obf_o   <= '0' when flags_q and obf_q = '0' else '1';

  dma_o <= dma_q;

end rtl;
