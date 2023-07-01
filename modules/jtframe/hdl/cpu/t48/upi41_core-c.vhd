-------------------------------------------------------------------------------
--
-- UPI-41 Microcontroller Core
--
-------------------------------------------------------------------------------

configuration upi41_core_struct_c0 of upi41_core is

  for struct

    for alu_b : t48_alu
      use configuration work.t48_alu_rtl_c0;
    end for;

    for bus_mux_b : t48_bus_mux
      use configuration work.t48_bus_mux_rtl_c0;
    end for;

    for clock_ctrl_b : t48_clock_ctrl
      use configuration work.t48_clock_ctrl_rtl_c0;
    end for;

    for cond_branch_b : t48_cond_branch
      use configuration work.t48_cond_branch_rtl_c0;
    end for;

    for db_bus_b : upi41_db_bus
      use configuration work.upi41_db_bus_rtl_c0;
    end for;

    for decoder_b : t48_decoder
      use configuration work.t48_decoder_rtl_c0;
    end for;

    for dmem_ctrl_b : t48_dmem_ctrl
      use configuration work.t48_dmem_ctrl_rtl_c0;
    end for;

    for timer_b : t48_timer
      use configuration work.t48_timer_rtl_c0;
    end for;

    for p1_b : t48_p1
      use configuration work.t48_p1_rtl_c0;
    end for;

    for p2_b : t48_p2
      use configuration work.t48_p2_rtl_c0;
    end for;

    for pmem_ctrl_b : t48_pmem_ctrl
      use configuration work.t48_pmem_ctrl_rtl_c0;
    end for;

    for psw_b : t48_psw
      use configuration work.t48_psw_rtl_c0;
    end for;

  end for;

end upi41_core_struct_c0;
