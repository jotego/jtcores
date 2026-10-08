`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

reg         clk = 0;
reg         ioctl_rom = 1;
reg [25:0] ioctl_addr = 0;
reg [ 7:0] ioctl_dout = 0;
reg         ioctl_wr = 0;
reg         sdram_ack = 0;

wire [22:1] prog_addr;
wire [15:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire        prog_rd;
wire [ 1:0] prog_ba;
wire        prom_we;
wire        header;
wire        gfx4_en = 0;
wire        gfx8_en = 0;
wire        gfx16_en = 0;
wire        gfx16b_en = 0;
wire        gfx16c_en = 0;

always #5 clk = ~clk;

jtframe_dwnld uut(
    .clk        ( clk        ),
    .ioctl_rom  ( ioctl_rom  ),
    .ioctl_addr ( ioctl_addr ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_wr   ( ioctl_wr   ),
    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_mask  ( prog_mask  ),
    .prog_we    ( prog_we    ),
    .prog_rd    ( prog_rd    ),
    .prog_ba    ( prog_ba    ),
    .gfx4_en    ( gfx4_en    ),
    .gfx8_en    ( gfx8_en    ),
    .gfx16_en   ( gfx16_en   ),
    .gfx16b_en  ( gfx16b_en  ),
    .gfx16c_en  ( gfx16c_en  ),
    .prom_we    ( prom_we    ),
    .header     ( header     ),
    .sdram_ack  ( sdram_ack  )
);

task write_byte;
    input [25:0] addr;
    input [ 7:0] data;
    begin
        @(negedge clk);
        ioctl_addr = addr;
        ioctl_dout = data;
        ioctl_wr   = 1;
        @(negedge clk);
        ioctl_wr   = 0;
    end
endtask

initial begin
    repeat (2) @(negedge clk);

    write_byte( 26'h000000, 8'h12 );
    @(posedge clk);
    #1;
    assert_msg( prog_we, "first byte prog_we" );
    assert_msg( prog_addr == 0, "first byte address" );
    assert_msg( prog_data == 16'h1212, "first byte data" );
    assert_msg( prog_mask == 2'b01, "first byte mask" );

    write_byte( 26'h000001, 8'h34 );
    @(posedge clk);
    #1;
    assert_msg( prog_we, "pending first byte prog_we" );
    assert_msg( prog_addr == 0, "first byte held while ack low" );
    assert_msg( prog_data == 16'h1212, "first byte data held" );
    assert_msg( prog_mask == 2'b01, "first byte mask held" );

    @(negedge clk);
    sdram_ack = 1;
    @(posedge clk);
    #1;
    assert_msg( prog_we, "second byte promoted" );
    assert_msg( prog_addr == 0, "second byte word address" );
    assert_msg( prog_data == 16'h3434, "second byte data" );
    assert_msg( prog_mask == 2'b10, "second byte mask" );

    @(negedge clk);
    sdram_ack = 0;
    @(negedge clk);
    sdram_ack = 1;
    @(posedge clk);
    #1;
    assert_msg( !prog_we, "prog_we clears after second ack" );

    pass();
end

endmodule
