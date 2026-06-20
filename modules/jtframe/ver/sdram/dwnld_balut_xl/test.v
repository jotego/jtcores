`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam SDRAMW     = 24;
localparam HEADER     = 26'd32;
localparam LUTSH      = 4;
localparam CHIP1_ADDR = 23'h400000;

reg         clk = 0;
reg         ioctl_rom = 1;
reg [25:0] ioctl_addr = 0;
reg [ 7:0] ioctl_dout = 0;
reg         ioctl_wr = 0;

wire [SDRAMW-1:1] prog_addr;
wire [15:0]       prog_data;
wire [ 1:0]       prog_mask;
wire              prog_we;
wire              prog_rd;
wire [ 1:0]       prog_ba;
wire              prom_we;
wire              header;
wire              gfx4_en = 0;
wire              gfx8_en = 0;
wire              gfx16_en = 0;
wire              gfx16b_en = 0;
wire              gfx16c_en = 0;
wire              sdram_ack = 1;

always #5 clk = ~clk;

jtframe_dwnld #(
    .SDRAMW        ( SDRAMW  ),
    .HEADER        ( HEADER  ),
    .BALUT         ( 1       ),
    .BALUT_LEN     ( 9       ),
    .BALUT_REVERSE ( 1       ),
    .LUTSH         ( LUTSH   ),
    .PROM_START    ( ~26'd0  ),
    .XL            ( 1       )
) uut(
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

task write_offset;
    input [ 3:0] index;
    input [15:0] offset_word;
    begin
        write_byte( {22'd0, index, 1'b0}, offset_word[ 7:0] );
        write_byte( {22'd0, index, 1'b1}, offset_word[15:8] );
    end
endtask

task check_bank;
    input [25:0] part_addr;
    input [ 1:0] want_ba;
    input        want_chip;
    begin
        @(negedge clk);
        ioctl_addr = HEADER + part_addr;
        ioctl_dout = 8'ha5;
        ioctl_wr   = 1;
        @(posedge clk);
        #1;
        assert_msg( prog_we, "prog_we" );
        assert_msg( !prom_we, "prom_we low for SDRAM bank" );
        assert_msg( prog_ba == want_ba, "bank address" );
        assert_msg( prog_addr == (want_chip ? CHIP1_ADDR : 0), "bank-relative address" );
        assert_msg( prog_mask == 2'b01, "byte mask" );
        assert_msg( prog_data == 16'ha5a5, "program data" );
        @(negedge clk);
        ioctl_wr = 0;
        @(posedge clk);
        #1;
        assert_msg( !prog_we, "prog_we clears" );
    end
endtask

task check_prom;
    input [25:0] part_addr;
    begin
        @(negedge clk);
        ioctl_addr = HEADER + part_addr;
        ioctl_dout = 8'h5a;
        ioctl_wr   = 1;
        @(posedge clk);
        #1;
        assert_msg( !prog_we, "prog_we low for PROM" );
        assert_msg( prom_we, "prom_we" );
        assert_msg( prog_addr == part_addr[SDRAMW-2:0], "PROM address" );
        assert_msg( prog_data == 16'h5a5a, "PROM data" );
        @(negedge clk);
        ioctl_wr  = 0;
        ioctl_rom = 0;
        @(posedge clk);
        #1;
        assert_msg( !prom_we, "prom_we clears" );
        @(negedge clk);
        ioctl_rom = 1;
    end
endtask

initial begin
    repeat (2) @(negedge clk);

    write_offset( 4'd0, 16'h0000 );
    write_offset( 4'd1, 16'h0001 );
    write_offset( 4'd2, 16'h0002 );
    write_offset( 4'd3, 16'h0003 );
    write_offset( 4'd4, 16'h0004 );
    write_offset( 4'd5, 16'h0005 );
    write_offset( 4'd6, 16'h0006 );
    write_offset( 4'd7, 16'h0007 );
    write_offset( 4'd8, 16'h0008 );

    check_bank( 26'h00, 2'd0, 1'b0 );
    check_bank( 26'h10, 2'd1, 1'b0 );
    check_bank( 26'h20, 2'd2, 1'b0 );
    check_bank( 26'h30, 2'd3, 1'b0 );
    check_bank( 26'h40, 2'd0, 1'b1 );
    check_bank( 26'h50, 2'd1, 1'b1 );
    check_bank( 26'h60, 2'd2, 1'b1 );
    check_bank( 26'h70, 2'd3, 1'b1 );
    check_prom( 26'h80 );

    pass();
end

endmodule
