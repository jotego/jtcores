`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

reg clk = 0;
always #5 clk = ~clk;

reg         ioctl_rom = 1;
reg [26:0] addr_f = 0, addr_r = 0;
reg [ 7:0] dout_f = 0, dout_r = 0;
reg        wr_f = 0, wr_r = 0;

wire [23:1] prog_addr_f, prog_addr_r;
wire [15:0] prog_data_f, prog_data_r;
wire [ 1:0] prog_mask_f, prog_mask_r;
wire        prog_we_f, prog_we_r;
wire        prog_rd_f, prog_rd_r;
wire [ 1:0] prog_ba_f, prog_ba_r;
wire        prom_we_f, prom_we_r;
wire        header_f, header_r;

jtframe_dwnld #(
    .SDRAMW        ( 24 ),
    .HEADER        ( 26'd32 ),
    .BALUT         ( 1 ),
    .BALUT_REVERSE ( 0 ),
    .LUTSH         ( 4 ),
    .PROM_START    ( ~27'd0 )
) uut_forward (
    .clk        ( clk ),
    .ioctl_rom  ( ioctl_rom ),
    .ioctl_addr ( addr_f ),
    .ioctl_dout ( dout_f ),
    .ioctl_wr   ( wr_f ),
    .prog_addr  ( prog_addr_f ),
    .prog_data  ( prog_data_f ),
    .prog_mask  ( prog_mask_f ),
    .prog_we    ( prog_we_f ),
    .prog_rd    ( prog_rd_f ),
    .prog_ba    ( prog_ba_f ),
    .gfx4_en    ( 1'b0 ),
    .gfx8_en    ( 1'b0 ),
    .gfx16_en   ( 1'b0 ),
    .gfx16b_en  ( 1'b0 ),
    .gfx16c_en  ( 1'b0 ),
    .prom_we    ( prom_we_f ),
    .header     ( header_f ),
    .sdram_ack  ( 1'b1 )
);

jtframe_dwnld #(
    .SDRAMW        ( 24 ),
    .HEADER        ( 26'd32 ),
    .BALUT         ( 1 ),
    .BALUT_REVERSE ( 1 ),
    .LUTSH         ( 4 ),
    .PROM_START    ( ~27'd0 )
) uut_reverse (
    .clk        ( clk ),
    .ioctl_rom  ( ioctl_rom ),
    .ioctl_addr ( addr_r ),
    .ioctl_dout ( dout_r ),
    .ioctl_wr   ( wr_r ),
    .prog_addr  ( prog_addr_r ),
    .prog_data  ( prog_data_r ),
    .prog_mask  ( prog_mask_r ),
    .prog_we    ( prog_we_r ),
    .prog_rd    ( prog_rd_r ),
    .prog_ba    ( prog_ba_r ),
    .gfx4_en    ( 1'b0 ),
    .gfx8_en    ( 1'b0 ),
    .gfx16_en   ( 1'b0 ),
    .gfx16b_en  ( 1'b0 ),
    .gfx16c_en  ( 1'b0 ),
    .prom_we    ( prom_we_r ),
    .header     ( header_r ),
    .sdram_ack  ( 1'b1 )
);

task write_forward;
    input [26:0] a;
    input [ 7:0] d;
    begin
        @(negedge clk);
        addr_f = a;
        dout_f = d;
        wr_f = 1;
        @(negedge clk);
        wr_f = 0;
    end
endtask

task write_reverse;
    input [26:0] a;
    input [ 7:0] d;
    begin
        @(negedge clk);
        addr_r = a;
        dout_r = d;
        wr_r = 1;
        @(negedge clk);
        wr_r = 0;
    end
endtask

task check_forward;
    input [25:0] part_addr;
    input [ 1:0] want_ba;
    begin
        @(negedge clk);
        addr_f = 26'd32 + part_addr;
        dout_f = 8'ha5;
        wr_f = 1;
        @(posedge clk);
        #1;
        assert_msg( prog_we_f, "forward prog_we" );
        assert_msg( prog_ba_f == want_ba, "forward bank" );
        assert_msg( prog_addr_f == 0, "forward bank-relative address" );
        assert_msg( prog_mask_f == 2'b01, "forward byte mask" );
        @(negedge clk);
        wr_f = 0;
        @(posedge clk);
        #1;
        assert_msg( !prog_we_f, "forward prog_we clears" );
    end
endtask

task check_reverse;
    input [25:0] part_addr;
    input [ 1:0] want_ba;
    begin
        @(negedge clk);
        addr_r = 26'd32 + part_addr;
        dout_r = 8'h5a;
        wr_r = 1;
        @(posedge clk);
        #1;
        assert_msg( prog_we_r, "reverse prog_we" );
        assert_msg( prog_ba_r == want_ba, "reverse bank" );
        assert_msg( prog_addr_r == 0, "reverse bank-relative address" );
        assert_msg( prog_mask_r == 2'b01, "reverse byte mask" );
        @(negedge clk);
        wr_r = 0;
        @(posedge clk);
        #1;
        assert_msg( !prog_we_r, "reverse prog_we clears" );
    end
endtask

initial begin
    repeat (2) @(negedge clk);

    // High/low words: 0000, 0001, 0002, 0003, ffff.
    write_forward( 0, 8'h00 ); write_forward( 1, 8'h00 );
    write_forward( 2, 8'h00 ); write_forward( 3, 8'h01 );
    write_forward( 4, 8'h00 ); write_forward( 5, 8'h02 );
    write_forward( 6, 8'h00 ); write_forward( 7, 8'h03 );
    write_forward( 8, 8'hff ); write_forward( 9, 8'hff );

    // Low/high words: 0000, 0001, 0002, 0003, ffff.
    write_reverse( 0, 8'h00 ); write_reverse( 1, 8'h00 );
    write_reverse( 2, 8'h01 ); write_reverse( 3, 8'h00 );
    write_reverse( 4, 8'h02 ); write_reverse( 5, 8'h00 );
    write_reverse( 6, 8'h03 ); write_reverse( 7, 8'h00 );
    write_reverse( 8, 8'hff ); write_reverse( 9, 8'hff );

    check_forward( 26'h00, 2'd0 );
    check_forward( 26'h10, 2'd1 );
    check_forward( 26'h20, 2'd2 );
    check_forward( 26'h30, 2'd3 );

    check_reverse( 26'h00, 2'd0 );
    check_reverse( 26'h10, 2'd1 );
    check_reverse( 26'h20, 2'd2 );
    check_reverse( 26'h30, 2'd3 );

    pass();
end

endmodule
