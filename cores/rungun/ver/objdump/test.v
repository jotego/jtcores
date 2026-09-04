`timescale 1ns/1ps

// The Rungun object RAM is an 8 KiB jtframe_dual_nvram16.  During an IOCTL
// dump its byte port is selected for four clocks per byte by the Verilator
// harness.  Keep this focused test independent of game boot-up and DMA.
module test;

reg         clk = 0;
reg  [15:0] cpu_din;
reg  [12:1] cpu_addr;
reg  [ 1:0] cpu_we;
reg  [12:1] dma_addr;
reg  [12:0] ioctl_addr;
reg         ioctl_ram;
wire [15:0] cpu_dout, dma_dout;
wire [ 7:0] ioctl_din;

`include "test_tasks.vh"

always #5 clk = ~clk;

jtframe_dual_nvram16 #(
    .AW     ( 12           ),
    .SIMFILE( "objdump.bin" )
) uut(
    .clk0   ( clk        ),
    .data0  ( cpu_din    ),
    .addr0  ( cpu_addr   ),
    .we0    ( cpu_we     ),
    .q0     ( cpu_dout   ),
    .clk1   ( clk        ),
    .addr1a ( dma_addr   ),
    .q1a    ( dma_dout   ),
    .data1  ( 8'd0       ),
    .addr1b ( ioctl_addr ),
    .we1b   ( 1'b0       ),
    .sel_b  ( ioctl_ram  ),
    .q1b    ( ioctl_din  )
);

task write_word(input [11:0] addr, input [15:0] data);
    begin
        @(negedge clk);
        cpu_addr = addr;
        cpu_din  = data;
        cpu_we   = 2'b11;
        @(negedge clk);
        cpu_we   = 0;
    end
endtask

task read_dump_byte(input [12:0] addr, input [7:0] expected);
    string msg;
    begin
        @(negedge clk);
        ioctl_addr = addr;
        // This is the Verilator harness cadence: each IOCTL address is held
        // for four clocks before it samples ioctl_din.
        repeat(4) @(posedge clk);
        #1 begin
            msg = $sformatf("object IOCTL byte %04X: got %02X expected %02X", addr, ioctl_din, expected);
            assert_msg(ioctl_din == expected, msg);
        end
    end
endtask

initial begin
    cpu_din    = 0;
    cpu_addr   = 0;
    cpu_we     = 0;
    dma_addr   = 0;
    ioctl_addr = 0;
    ioctl_ram  = 0;

    ioctl_ram = 1;
    // Validate binary scene restore before writing through the CPU port. The
    // two byte lanes must take alternating bytes from the 16-bit SIMFILE.
    read_dump_byte(13'h0000, 8'h0d);
    read_dump_byte(13'h0001, 8'h32);
    read_dump_byte(13'h0002, 8'h57);
    read_dump_byte(13'h0003, 8'h7c);
    read_dump_byte(13'h1001, 8'h32);

    write_word(12'h000, 16'h1234);
    write_word(12'h001, 16'habcd);
    write_word(12'h7ff, 16'h5aa5);

    read_dump_byte(13'h0000, 8'h34);
    read_dump_byte(13'h0001, 8'h12);
    read_dump_byte(13'h0002, 8'hcd);
    read_dump_byte(13'h0003, 8'hab);
    read_dump_byte(13'h0ffe, 8'ha5);
    read_dump_byte(13'h0fff, 8'h5a);

    pass();
end

endmodule
