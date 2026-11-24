`timescale 1ns/1ps
module mc6809_batch_tb #(parameter integer HD_MODE=0);
  reg clk = 0;
  always #5 clk = ~clk;
  reg reset_n = 0;
  reg [1:0] phase = 0;
  wire cen_E = (phase == 2'b00);
  wire cen_Q = (phase == 2'b10);
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) phase <= 0;
    else phase <= phase + 1'b1;
  end

  reg [7:0] mem [0:65535];
  wire [7:0] dout;
  wire [15:0] addr;
  wire rnw, bs, ba, avma, busy, lic, op;
  wire [111:0] regs;
  reg [7:0] ram_dout;
  integer fd, outfd, n, i, j;
  integer case_id, target_pc, expected_close_pc, flags, native_mode, expected_cycles, max_cycles, watchdog;
  reg [7:0] case_bytes [0:15];
  reg [31:0] interval_cycles;
  reg running, complete, started_this_edge;
  reg [15:0] closing_pc;
  integer cycles_result;
  integer target_fetch_count;
  reg target_is_prefixed;
  string vector_path, result_path;

  assign ram_dout = mem[addr];
  mc6809i #(.HD6309(HD_MODE), .ILLEGAL_INSTRUCTIONS("STOP")) u_cpu (
    .D(ram_dout), .DOut(dout), .ADDR(addr), .RnW(rnw),
    .clk(clk), .cen_E(cen_E), .cen_Q(cen_Q), .BS(bs), .BA(ba),
    .nIRQ(1'b1), .nFIRQ(1'b1), .nNMI(1'b1), .AVMA(avma), .BUSY(busy), .LIC(lic),
    .nHALT(1'b1), .nRESET(reset_n), .nDMABREQ(1'b1), .OP(op), .RegData(regs)
  );
  always @(posedge clk) if (reset_n && cen_Q && !rnw) mem[addr] <= dout;

  initial begin
    if (!$value$plusargs("vectors=%s", vector_path)) vector_path = "vectors.hex";
    if (!$value$plusargs("results=%s", result_path)) result_path = "results.csv";
    if (!$value$plusargs("max_cycles=%d", max_cycles)) max_cycles = 10000;
    fd = $fopen(vector_path, "r");
    if (!fd) $fatal(1, "cannot open vectors file %0s", vector_path);
    outfd = $fopen(result_path, "w");
    if (!outfd) $fatal(1, "cannot open results file %0s", result_path);
    $fdisplay(outfd, "case_id,target_pc,closing_pc,e_cycles,expected_cycles,expected_close,status,target_fetches");
    for (i=0; i<65536; i=i+1) mem[i] = 8'h12; // NOP-safe deterministic fill
    mem[16'hfffe] = 8'h01;
    mem[16'hffff] = 8'h00;
    // Common register setup; flags are cleared then selected per case.
    mem[16'h0100] = 8'h10; mem[16'h0101] = 8'hce; mem[16'h0102] = 8'h30; mem[16'h0103] = 8'h00; // LDS #$3000
    mem[16'h0104] = 8'hce; mem[16'h0105] = 8'h40; mem[16'h0106] = 8'h00; // LDU #$4000
    mem[16'h0107] = 8'h8e; mem[16'h0108] = 8'h20; mem[16'h0109] = 8'h00; // LDX #$2000
    mem[16'h010a] = 8'h10; mem[16'h010b] = 8'h8e; mem[16'h010c] = 8'h21; mem[16'h010d] = 8'h00; // LDY #$2100
    mem[16'h010e] = 8'h86; mem[16'h010f] = 8'h11; // LDA #$11
    mem[16'h0110] = 8'hc6; mem[16'h0111] = 8'h22; // LDB #$22
    mem[16'h0112] = 8'h1f; mem[16'h0113] = 8'h8b; // TFR A,DP
    mem[16'h0114] = 8'h1c; mem[16'h0115] = 8'h00; // ANDCC #0
    mem[16'h0116] = 8'h1a; mem[16'h0117] = 8'h00; // ORCC #case flags
    for (i=16'h0118; i<16'h0120; i=i+1) mem[i] = 8'h12;
    n = 0;
    while (!$feof(fd)) begin
      j = $fscanf(fd, "%d %h %h %h %h %d", case_id, target_pc, expected_close_pc, flags, native_mode, expected_cycles);
      if (j == 6) begin
        for (i=0; i<16; i=i+1) begin
          j = $fscanf(fd, "%h", case_bytes[i]);
          if (j != 1) $fatal(1, "short vector record %0d at byte %0d", case_id, i);
        end
        for (i=16'h0100; i<=16'h0170; i=i+1) mem[i] = 8'h12;
        // Rebuild the common prelude each vector because a previous PC-relative
        // store can legally write into the program image.
        mem[16'h0100] = 8'h10; mem[16'h0101] = 8'hce; mem[16'h0102] = 8'h30; mem[16'h0103] = 8'h00;
        mem[16'h0104] = 8'hce; mem[16'h0105] = 8'h40; mem[16'h0106] = 8'h00;
        mem[16'h0107] = 8'h8e; mem[16'h0108] = 8'h20; mem[16'h0109] = 8'h00;
        mem[16'h010a] = 8'h10; mem[16'h010b] = 8'h8e; mem[16'h010c] = 8'h21; mem[16'h010d] = 8'h00;
        mem[16'h010e] = 8'h86; mem[16'h010f] = 8'h00;
        mem[16'h0110] = 8'hc6; mem[16'h0111] = 8'h00;
        mem[16'h0112] = 8'h1f; mem[16'h0113] = 8'h8b;
        // Set execution mode and seed E/F so W-indexed postbytes have a
        // deterministic base. The target begins after this short prelude.
        mem[16'h0114] = 8'h11; mem[16'h0115] = 8'h3d; mem[16'h0116] = native_mode[0];
        // Use a safe nonzero W base. W=0 makes [,--W] read its pointer from
        // $FFFE, which aliases the reset vector and corrupts later vectors.
        mem[16'h0117] = 8'h11; mem[16'h0118] = 8'h86; mem[16'h0119] = 8'h22; // LDE #$22
        mem[16'h011a] = 8'h11; mem[16'h011b] = 8'hc6; mem[16'h011c] = 8'h00; // LDF #0
        // Restore the requested branch flags after setup instructions, since
        // LDMD/LDE/LDF may change N/Z/V.
        mem[16'h011d] = 8'h1c; mem[16'h011e] = 8'h00; // ANDCC #0
        mem[16'h011f] = 8'h1a; mem[16'h0120] = flags[7:0]; // ORCC #flags
        for (i=0; i<16; i=i+1) mem[target_pc+i] = case_bytes[i];
        for (i=0; i<257; i=i+1) mem[16'h1f80+i] = 8'h00;
        for (i=0; i<32; i=i+1) begin
          mem[16'h3000+i] = 8'h01;
          mem[16'h4000+i] = 8'h01;
        end
        // Stable data and pointer targets for direct, extended, and indirect modes.
        mem[16'h2000] = 8'h21; mem[16'h2001] = 8'h00;
        mem[16'h2100] = 8'h12;
        mem[16'h21fe] = 8'h21; mem[16'h21ff] = 8'h00; // [,--W] pointer
        mem[16'h2200] = 8'h21; mem[16'h2201] = 8'h00; // [,W++] pointer; W base
        mem[16'h0138] = 8'h21; mem[16'h0139] = 8'h00; // PCR/absolute-indirect safe pointer
        // Keep the software-interrupt vectors distinct so a wrong vector
        // selection cannot pass by landing at a shared target.
        mem[16'hfffa] = 8'h01; mem[16'hfffb] = 8'h50; // SWI
        mem[16'hfff4] = 8'h01; mem[16'hfff5] = 8'h60; // SWI2
        mem[16'hfff2] = 8'h01; mem[16'hfff3] = 8'h70; // SWI3
        mem[16'hfff8] = 8'h01; mem[16'hfff9] = 8'h50; // IRQ
        target_is_prefixed = (mem[target_pc] == 8'h10) || (mem[target_pc] == 8'h11);
        running = 0;
        complete = 0;
        interval_cycles = 0;
        cycles_result = -1;
        closing_pc = 16'hffff;
        target_fetch_count = 0;

        watchdog = 0;
        reset_n = 0;
        repeat (8) @(posedge clk);
        @(negedge clk); reset_n = 1;
        while (!complete && watchdog < max_cycles) begin
          @(posedge clk);
          if (cen_E) begin
            started_this_edge = 0;
            watchdog = watchdog + 1;
            if (op && addr == target_pc[15:0]) begin
              target_fetch_count = target_fetch_count + 1;
              if (!running) begin
                running = 1;
                interval_cycles = 0;
                started_this_edge = 1;
              end
            end else if (running && op && !(target_is_prefixed && addr == ((target_pc + 1) & 16'hffff))) begin
              closing_pc = addr;
              cycles_result = interval_cycles + 1;
              complete = 1;
            end
            if (running && !complete && !started_this_edge) interval_cycles = interval_cycles + 1;
          end
        end
        if (complete)
          $fdisplay(outfd, "%0d,%04h,%04h,%0d,%0d,%04h,ok,%0d", case_id, target_pc, closing_pc, cycles_result, expected_cycles, expected_close_pc, target_fetch_count);
        else
          $fdisplay(outfd, "%0d,%04h,ffff,-1,%0d,%04h,watchdog,%0d", case_id, target_pc, expected_cycles, expected_close_pc, target_fetch_count);
        $fflush(outfd);
        n = n + 1;
        @(negedge clk); reset_n = 0;
      end
    end
    $display("Completed %0d vectors", n);
    $fclose(fd);
    $fclose(outfd);
    $finish;
  end
endmodule
