// Boot-sequence unit test for jttc0030cmd using CUSTOM firmware (no
// copyrighted ROM). `boot_mrom.hex` is our own uPD78C11 program:
//   - writes 0x01 to the ASIC ready register (asic[1]) — "boot done"
//   - then loops echoing shared-RAM byte 0 -> byte 1
// The testbench plays the 68k host side and checks the full boot/handshake
// path: (1) the MCU signals ready, (2) a host->MCU->host round trip through
// the shared RAM works. Exercises the whole C-chip: MCU core, mask-ROM fetch,
// ASIC reg, banked shared RAM, and the 68k bus.
`timescale 1ns/1ps
module test;
    reg        clk = 0, rst = 1;
    reg  [2:0] cdiv = 0;
    wire       cen  = (cdiv == 3'd5);        // /6 MCU clock enable
    always #10 clk = ~clk;
    always @(posedge clk) cdiv <= cen ? 3'd0 : cdiv + 3'd1;

    reg         cs = 0, rnw = 1;
    reg  [10:0] addr = 0;
    reg  [ 7:0] din = 0;
    wire [ 7:0] dout;
    wire        dtack_n;

    wire [11:0] mrom_addr;
    wire [12:0] eprom_addr;
    wire [ 7:0] mrom_data;

    jttc0030cmd uut(
        .rst(rst), .clk(clk), .cen(cen),
        .cs(cs), .addr(addr), .din(din), .dout(dout), .rnw(rnw), .dtack_n(dtack_n),
        .int1(1'b0), .nmi_n(1'b1),
        .pa_in(8'd0), .pb_in(8'd0), .pc_in(8'd0),
        .pa_out(), .pb_out(), .pc_out(),
        .an(8'd0),
        .mrom_addr(mrom_addr), .mrom_data(mrom_data),
        .eprom_addr(eprom_addr), .eprom_data(8'd0),
        .dbg_pc(), .dbg_fetch()
    );

    // External mask-ROM BRAM loaded with the custom boot firmware — models what
    // the parent core supplies from a mem.yaml `bram:` (the module no longer
    // owns its ROM storage). This mask-ROM-only test needs no external EPROM.
    jtframe_prom #(.DW(8),.AW(12),.SIMHEX("boot_mrom.hex")) u_mask(
        .clk(clk), .cen(1'b1), .data(8'd0),
        .rd_addr(mrom_addr), .wr_addr(12'd0), .we(1'b0), .q(mrom_data)
    );

    reg [7:0] q;

    // word index: shared-RAM word N, ASIC reg at 0x400+n
    task host_write(input [10:0] a, input [7:0] d);
        begin
            @(posedge clk); cs = 1; rnw = 0; addr = a; din = d;
            @(posedge clk); cs = 0; rnw = 1;
            @(posedge clk);
        end
    endtask
    task host_read(input [10:0] a, output [7:0] d);
        begin
            @(posedge clk); cs = 1; rnw = 1; addr = a;
            repeat (3) @(posedge clk);
            d = dout; cs = 0;
            @(posedge clk);
        end
    endtask

    integer i;
    initial begin
        repeat (20) @(posedge clk);
        rst = 0;

        // ---- 1: wait for the MCU to signal boot-ready (asic[1]==0x01) ----
        q = 8'h00;
        for (i = 0; i < 4000 && q !== 8'h01; i = i + 1) host_read(11'h401, q);
        if (q !== 8'h01) begin
            $display("FAIL: MCU never set ASIC ready flag (got %02x)", q);
            $finish;
        end
        $display("boot ready: ASIC[1]=%02x after ~%0d polls", q, i);

        // ---- 2: host->MCU->host round trip via shared RAM ----
        // write a command byte to shared-RAM word 0, expect the MCU to echo
        // it into word 1.
        host_write(11'h000, 8'h41);          // host -> shared word0
        repeat (3000) @(posedge clk);          // let the MCU echo
        host_read(11'h001, q);                // read shared word1
        $display("round trip: wrote 41 -> read back %02x", q);
        if (q !== 8'h41) begin
            $display("FAIL: echo mismatch (got %02x, want 41)", q);
            $finish;
        end

        // ---- 3: second value, prove it tracks (not a stuck constant) ----
        host_write(11'h000, 8'h9C);
        repeat (3000) @(posedge clk);
        host_read(11'h001, q);
        $display("round trip 2: wrote 9C -> read back %02x", q);
        if (q !== 8'h9C) begin
            $display("FAIL: second echo mismatch (got %02x, want 9C)", q);
            $finish;
        end

        $display("PASS");
        $finish;
    end
endmodule
