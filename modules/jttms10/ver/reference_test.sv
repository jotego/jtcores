`timescale 1ns/1ps

// Runs the same program/checkpoint stream as test.sv against the established
// TMS34010 core. The old core has a different cycle schedule; completion is
// detected at its architectural instruction-final state -> FETCH transition.
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

  integer checks_fd, program_fd, data_fd, vector_fd, loaded, step_count, expected_count;
  integer index, reg_idx, nregs, nmem, expected_wvp, rc, word_index, data_count, data_index;
  integer field_size, vector_number;
  logic [15:0] program_word, expected_ir;
  logic [31:0] entry, expected_after, expected_pc, st_mask, st_value;
  logic [31:0] reg_value, actual_reg, data_at, field_addr, field_value;
  logic [31:0] vector_value, vector_addr;
  logic [15:0] pixel_size, convdp, convsp, control_value, pmask;

  function automatic logic [31:0] read_backing(input logic [31:0] address,
                                                input integer size);
    logic [31:0] physical;
    begin
      read_backing = 0;
      if (size < 1 || size > 32 || address + size > 32'd16384)
        $fatal(1, "reference memory assertion outside model");
      for (integer bit_index=0; bit_index<32; bit_index=bit_index+1) begin
        if (bit_index < size) begin
          physical = address + bit_index;
          read_backing[bit_index] = u_mem.mem[physical >> 4][physical[3:0]];
        end
      end
    end
  endfunction

  initial begin
    if (!$value$plusargs("entry=%h", entry) ||
        !$value$plusargs("count=%d", expected_count) ||
        !$value$plusargs("pixel_size=%h", pixel_size) ||
        !$value$plusargs("convdp=%h", convdp) ||
        !$value$plusargs("convsp=%h", convsp) ||
        !$value$plusargs("control=%h", control_value) ||
        !$value$plusargs("pmask=%h", pmask))
      $fatal(1, "missing graphics control plusargs");
    if (entry[3:0] != 0 || entry >= 32'd12288)
      $fatal(1, "program entry outside reference memory");
    checks_fd = $fopen("checks.txt", "r");
    program_fd = $fopen("program.mem", "r");
    data_fd = $fopen("memory_init.txt", "r");
    vector_fd = $fopen("vector_init.txt", "r");
    if (checks_fd == 0 || program_fd == 0 || data_fd == 0 || vector_fd == 0)
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
    while ($fscanf(data_fd, "%h %d", data_at, data_count) == 2) begin
      for (data_index=0; data_index<data_count; data_index=data_index+1) begin
        rc = $fscanf(data_fd, "%h", program_word);
        if (rc != 1) $fatal(1, "truncated memory_init.txt");
        word_index = (data_at >> 4) + data_index;
        if (word_index >= 1024) $fatal(1, "data exceeds reference memory");
        u_mem.mem[word_index] = program_word;
      end
    end
    $fclose(data_fd);
    while ($fscanf(vector_fd, "%d %h", vector_number, vector_value) == 2) begin
      if (vector_number < 1 || vector_number > 31)
        $fatal(1, "invalid trap vector %0d", vector_number);
      vector_addr = 32'hffffffe0 - (vector_number << 5);
      // The established sim_memory_model truncates non-reset physical word
      // addresses to ten index bits. Reserve its top 62 words for trap vectors.
      word_index = (vector_addr >> 4) & 1023;
      u_mem.mem[word_index] = vector_value[15:0];
      u_mem.mem[word_index+1] = vector_value[31:16];
    end
    $fclose(vector_fd);
    repeat (6) @(posedge clk);
    rst <= 0;
    #1;
    // The established core owns these mapped I/O registers internally;
    // initialize their architectural values without editing that submodule.
    u_core.u_io_regs.io_reg[IO_IDX_PSIZE] = pixel_size;
    u_core.u_io_regs.io_reg[IO_IDX_CONVDP] = convdp;
    u_core.u_io_regs.io_reg[IO_IDX_CONVSP] = convsp;
    u_core.u_io_regs.io_reg[IO_IDX_CONTROL] = control_value;
    u_core.u_io_regs.io_reg[IO_IDX_PMASK] = pmask;
  end

  task automatic check_step;
    begin
      rc = $fscanf(checks_fd, "%h %h %h %h %h %d %d %d",
                   expected_after, expected_pc, expected_ir,
                   st_mask, st_value, nregs, nmem, expected_wvp);
      if (rc != 8) $fatal(1, "missing checkpoint %0d", step_count);
      if (instr_w !== expected_ir || pc_w !== expected_pc)
        $fatal(1, "step %0d opcode @%h: IR %h/%h PC %h/%h",
               step_count, expected_after, instr_w, expected_ir,
               pc_w, expected_pc);
      if ((u_core.u_status_reg.st_o & st_mask) !== st_value)
        $fatal(1, "step %0d ST %h mask %h expected %h", step_count,
               u_core.u_status_reg.st_o, st_mask, st_value);
      if (expected_wvp >= 0 &&
          u_core.u_io_regs.io_reg[IO_IDX_INTPEND][INT_WV_BIT] !== expected_wvp[0])
        $fatal(1, "step %0d WVP %b expected %b", step_count,
               u_core.u_io_regs.io_reg[IO_IDX_INTPEND][INT_WV_BIT], expected_wvp[0]);
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
      for (index=0; index<nmem; index=index+1) begin
        rc = $fscanf(checks_fd, "%h %d %h", field_addr, field_size, field_value);
        if (rc != 3) $fatal(1, "truncated memory checkpoint");
        if (read_backing(field_addr, field_size) !== field_value)
          $fatal(1, "step %0d memory @%h size %0d: %h expected %h",
                 step_count, field_addr, field_size,
                 read_backing(field_addr, field_size), field_value);
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
    // Reserved opcodes enter vector 30 through interrupt microstates and
    // bypass WRITEBACK. The sticky illegal diagnostic distinguishes this
    // boundary from an ordinary hardware interrupt (TI guide §8.7). Array
    // instructions have dedicated final writeback, empty and window paths.
    if (!rst && ((last_state == CORE_WRITEBACK && state_w == CORE_FETCH) ||
                 (last_state == CORE_INT_DONE && state_w == CORE_FETCH && illegal_w) ||
                 (state_w == CORE_FETCH &&
                  (last_state == CORE_FILL_SETUP ||
                   last_state == CORE_FILL_WB ||
                   last_state == CORE_FILL_WIN_MISS ||
                   last_state == CORE_FILL_WIN_HIT ||
                   last_state == CORE_FILL_W1_DYDX ||
                   last_state == CORE_PBLT_SETUP ||
                   last_state == CORE_PBLT_WB2 ||
                   last_state == CORE_PBLT_WIN_MISS ||
                   last_state == CORE_PBLT_WIN_HIT ||
                   last_state == CORE_PBLT_W1_DYDX ||
                   last_state == CORE_LINE_WB_COUNT))))
      check_step();
    last_state = state_w;
  end

  initial begin
    repeat (20000) @(posedge clk);
    $fatal(1, "reference timeout after %0d checkpoints", step_count);
  end
endmodule
