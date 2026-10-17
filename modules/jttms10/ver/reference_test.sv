`timescale 1ns/1ps

// Runs the same program/checkpoint stream as test.sv against the established
// TMS34010 core. The old core has a different cycle schedule; completion is
// detected at its architectural WRITEBACK -> FETCH transition.
module reference_test;
  import tms34010_pkg::*;

  logic clk = 0;
  logic rst = 1;
  always #5 clk = ~clk;

  logic mem_req, mem_we, mem_ack;
  logic [31:0] mem_addr, mem_wdata, mem_rdata;
  logic [5:0] mem_size;
  core_state_t state_w, last_state;
  logic [31:0] pc_w;
  logic [15:0] instr_w;
  logic illegal_w;

  tms34010_core #(.CLKS_PER_STATE(1), .CYCLE_ACCURATE(1'b0)) u_core (
    .clk(clk), .vclk_i(clk), .rst(rst), .vclk_rst_i(rst),
    .video_hsync_n_i(1'b1), .video_vsync_n_i(1'b1),
    .mem_req(mem_req), .mem_we(mem_we), .mem_addr(mem_addr),
    .mem_size(mem_size), .mem_wdata(mem_wdata), .mem_rdata(mem_rdata),
    .mem_ack(mem_ack), .mem_busy(1'b0), .mem_keep(), .mem_rmw(),
    .mem_late(), .mem_late_wdata(), .mem_late_keep(),
    .mem_iaq(), .mem_srt(), .mem_is_io(), .mem_io_we(), .mem_io_rdata(),
    .state_o(state_w), .pc_o(pc_w), .instr_word_o(instr_w),
    .illegal_opcode_o(illegal_w),
    .run_emu_n_i(1'b1), .emua_n_o(),
    .lint1_n_i(1'b1), .lint2_n_i(1'b1), .hcs_n_i(1'b0),
    .host_req_i(1'b0), .host_we_i(1'b0),
    .host_reg_i(HOST_REG_HSTCTL), .host_be_i(2'b00),
    .host_wdata_i(16'h0000), .host_rdata_o(), .host_ack_o(),
    .host_busy_o(), .hint_n_o(), .host_mem_req_o(),
    .host_mem_we_o(), .host_mem_addr_o(), .host_mem_wdata_o(),
    .host_mem_is_io_o(), .host_mem_io_rdata_o(),
    .host_mem_rdata_i(16'h0000), .host_mem_ack_i(1'b0),
    .dpyint_set_i(1'b0), .refresh_req_o(), .refresh_row_o(),
    .refresh_cbr_o(), .video_hsync_o(), .video_vsync_o(),
    .video_hblank_o(), .video_vblank_o(), .video_blank_o(),
    .video_hsync_oe_o(), .video_vsync_oe_o(), .screen_refresh_req_o(),
    .screen_refresh_ack_i(1'b0), .screen_refresh_srfaddr_o(),
    .screen_refresh_dpytap_o(), .screen_refresh_org_o()
  );

  sim_memory_model #(.DEPTH_WORDS(1024), .WORD_WAIT_CYCLES(2)) u_mem (
    .clk(clk), .rst(rst), .mem_req(mem_req), .mem_we(mem_we),
    .mem_addr(mem_addr), .mem_size(mem_size), .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata), .mem_ack(mem_ack)
  );

  integer checks_fd, program_fd, loaded, step_count, expected_count;
  integer index, reg_idx, nregs, rc, word_index;
  logic [15:0] program_word, expected_ir;
  logic [31:0] entry, expected_after, expected_pc, st_mask, st_value;
  logic [31:0] reg_value, actual_reg;

  initial begin
    if (!$value$plusargs("entry=%h", entry) ||
        !$value$plusargs("count=%d", expected_count))
      $fatal(1, "missing entry/count plusargs");
    if (entry[3:0] != 0 || entry >= 32'd12288)
      $fatal(1, "program entry outside reference memory");
    checks_fd = $fopen("checks.txt", "r");
    program_fd = $fopen("program.mem", "r");
    if (checks_fd == 0 || program_fd == 0)
      $fatal(1, "missing generated input");
    #1;
    u_mem.level0_vector = entry;
    loaded = 0;
    while ($fscanf(program_fd, "%h", program_word) == 1) begin
      word_index = (entry >> 4) + loaded;
      if (word_index >= 1024) $fatal(1, "program exceeds memory");
      u_mem.mem[word_index] = program_word;
      loaded = loaded + 1;
    end
    $fclose(program_fd);
    repeat (6) @(posedge clk);
    rst <= 0;
  end

  task automatic check_step;
    begin
      rc = $fscanf(checks_fd, "%h %h %h %h %h %d",
                   expected_after, expected_pc, expected_ir,
                   st_mask, st_value, nregs);
      if (rc != 6) $fatal(1, "missing checkpoint %0d", step_count);
      if (instr_w !== expected_ir || pc_w !== expected_pc)
        $fatal(1, "step %0d opcode @%h: IR %h/%h PC %h/%h",
               step_count, expected_after, instr_w, expected_ir,
               pc_w, expected_pc);
      if ((u_core.u_status_reg.st_o & st_mask) !== st_value)
        $fatal(1, "step %0d ST %h mask %h expected %h", step_count,
               u_core.u_status_reg.st_o, st_mask, st_value);
      for (index=0; index<nregs; index=index+1) begin
        rc = $fscanf(checks_fd, "%d %h", reg_idx, reg_value);
        if (rc != 2) $fatal(1, "truncated checkpoint register list");
        if (reg_idx == 15) actual_reg = u_core.u_regfile.sp_q;
        else if (reg_idx >= 16) actual_reg = u_core.u_regfile.b_regs[reg_idx-16];
        else actual_reg = u_core.u_regfile.a_regs[reg_idx];
        if (actual_reg !== reg_value)
          $fatal(1, "step %0d register %0d: %h expected %h",
                 step_count, reg_idx, actual_reg, reg_value);
      end
      step_count = step_count + 1;
      if (step_count == expected_count) begin
        $display("TEST_RESULT: PASS (%0d reference retire checkpoints)", step_count);
        $finish;
      end
    end
  endtask

  initial begin
    last_state = CORE_RESET;
    step_count = 0;
  end
  always @(negedge clk) begin
    if (!rst && last_state == CORE_WRITEBACK && state_w == CORE_FETCH)
      check_step();
    last_state = state_w;
  end

  initial begin
    repeat (20000) @(posedge clk);
    $fatal(1, "reference timeout after %0d checkpoints", step_count);
  end
endmodule
