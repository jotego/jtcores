// Unit test: the host (68k) side of jttc0030cmd's C-chip memory map.
//
// Addresses are the chip's word index (A10..A0), matching taitocchip.cpp:
//   word < 0x400        : 1 KB shared-SRAM window, selected by bank_68k
//   word 0x400-0x7FF    : ASIC region
//   word 0x600          : write bank_68k (low 3 bits)
//   word 0x401..(<0x600): asic_ram[word[1:0]]  (read/write)
//
// The mask ROM is unloaded (zeros), so the MCU only executes NOPs and never
// writes the shared RAM / ASIC — the host side is fully deterministic here.
// This checks: shared-RAM write/read, bank_68k independence between banks,
// the ASIC 4-byte reg file, and /DTACK.
`timescale 1ns/1ps
module test;
    reg        clk = 0, rst = 1;
    reg  [2:0] cdiv = 0;
    wire       cen  = (cdiv == 3'd5);
    always #10 clk = ~clk;
    always @(posedge clk) cdiv <= cen ? 3'd0 : cdiv + 3'd1;

    reg         cs = 0, rnw = 1;
    reg  [10:0] addr = 0;
    reg  [ 7:0] din = 0;
    wire [ 7:0] dout;
    wire        dtack_n;

    jttc0030cmd uut(
        .rst(rst), .clk(clk), .cen(cen),
        .cs(cs), .addr(addr), .din(din), .dout(dout), .rnw(rnw), .dtack_n(dtack_n),
        .int1(1'b0), .nmi_n(1'b1),
        .pa_in(8'd0), .pb_in(8'd0), .pc_in(8'd0),
        .pa_out(), .pb_out(), .pc_out(),
        .an(8'd0),
        .prog_addr(13'd0), .prog_data(8'd0), .mrom_we(1'b0), .eprom_we(1'b0),
        .dbg_pc(), .dbg_fetch()
    );

    integer errors = 0;
    reg [7:0] q;

    task host_write(input [10:0] a, input [7:0] d);
        begin
            @(posedge clk); cs = 1; rnw = 0; addr = a; din = d;
            @(posedge clk); cs = 0; rnw = 1;
            @(posedge clk);
        end
    endtask

    // Read: hold cs a few clks so the (1-cycle) BRAM output settles, sample dout.
    task host_read(input [10:0] a, output [7:0] d);
        begin
            @(posedge clk); cs = 1; rnw = 1; addr = a;
            repeat (3) @(posedge clk);
            d = dout;
            cs = 0;
            @(posedge clk);
        end
    endtask

    task expect_eq(input [7:0] got, input [7:0] exp, input [127:0] name);
        begin
            if (got !== exp) begin
                $display("FAIL: %0s = %02x, expected %02x", name, got, exp);
                errors = errors + 1;
            end else begin
                $display("ok: %0s = %02x", name, got);
            end
        end
    endtask

    initial begin
        repeat (20) @(posedge clk);
        rst = 0;
        repeat (10) @(posedge clk);

        // ---- shared SRAM, bank 0 ----
        host_write(11'h600, 8'h00);           // bank_68k = 0
        host_write(11'h005, 8'hAB);
        host_write(11'h006, 8'h5C);
        host_read (11'h005, q); expect_eq(q, 8'hAB, "bank0 word5");
        host_read (11'h006, q); expect_eq(q, 8'h5C, "bank0 word6");

        // ---- bank independence: same offset, bank 1 holds different data ----
        host_write(11'h600, 8'h01);           // bank_68k = 1
        host_read (11'h005, q); expect_eq(q, 8'h00, "bank1 word5 (fresh)");
        host_write(11'h005, 8'hCD);
        host_read (11'h005, q); expect_eq(q, 8'hCD, "bank1 word5");
        host_write(11'h600, 8'h00);           // back to bank 0
        host_read (11'h005, q); expect_eq(q, 8'hAB, "bank0 word5 preserved");

        // ---- ASIC 4-byte reg file ----
        host_write(11'h401, 8'h33);           // asic_ram[1]
        host_write(11'h402, 8'h77);           // asic_ram[2]
        host_read (11'h401, q); expect_eq(q, 8'h33, "asic_ram[1]");
        host_read (11'h402, q); expect_eq(q, 8'h77, "asic_ram[2]");

        // ---- /DTACK asserts on a host access ----
        @(posedge clk); cs = 1; rnw = 1; addr = 11'h005;
        @(posedge clk);
        @(posedge clk);
        if (dtack_n !== 1'b0) begin
            $display("FAIL: dtack_n not asserted during host access");
            errors = errors + 1;
        end else $display("ok: dtack_n asserted");
        cs = 0;
        @(posedge clk);

        if (errors == 0) $display("PASS");
        else             $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
