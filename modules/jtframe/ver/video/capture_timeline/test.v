/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, spi_clk=0, rst=1, game_reset=0, lvbl=0;
reg pxl_cen=1, lhbl=0, cab_active=0, dump_pause=0;
reg [3:0] red=0, green=0, blue=0;
reg [31:0] cab_frame=0;
reg rx_strobe=0;
reg [7:0] rx_cmd=0, rx_byte=0;
reg [4:0] rx_index=0;
reg spi_read_consume=0;
reg [9:0] spi_pixel_addr=0;
wire [15:0] spi_pixel_data, info_width, info_height;
wire [31:0] info_frame;
wire spi_read_ready, spi_read_bank, cancel_toggle, pause_gate, capture_hold;
wire [7:0] spi_read_prefix;
integer cycle=0, waited;

always #5 clk=~clk;
always #13 spi_clk=~spi_clk;
always @(negedge clk) begin
    if(rst) begin cycle=0; lvbl=0; end
    else begin
        cycle=cycle+1;
        if(cycle==20) begin cycle=0; lvbl=~lvbl; end
    end
end

jtframe_capture #(
    .WIDTH ( 1 ),
    .HEIGHT ( 1 ),
    .COLORW ( 4 )
) uut(
    .rst              ( rst              ),
    .clk              ( clk              ),
    .spi_clk          ( spi_clk          ),
    .game_reset       ( game_reset       ),
    .pxl_cen          ( pxl_cen          ),
    .lhbl             ( lhbl             ),
    .lvbl             ( lvbl             ),
    .red              ( red              ),
    .green            ( green            ),
    .blue             ( blue             ),
    .cab_active       ( cab_active       ),
    .cab_frame        ( cab_frame        ),
    .dump_pause       ( dump_pause       ),
    .rx_strobe        ( rx_strobe        ),
    .rx_cmd           ( rx_cmd           ),
    .rx_byte          ( rx_byte          ),
    .rx_index          ( rx_index         ),
    .spi_read_consume ( spi_read_consume ),
    .spi_pixel_addr   ( spi_pixel_addr   ),
    .spi_pixel_data   ( spi_pixel_data   ),
    .info_width       ( info_width       ),
    .info_height      ( info_height      ),
    .info_frame       ( info_frame       ),
    .spi_read_ready   ( spi_read_ready   ),
    .spi_read_prefix  ( spi_read_prefix  ),
    .spi_read_bank    ( spi_read_bank    ),
    .cancel_toggle    ( cancel_toggle    ),
    .pause_gate       ( pause_gate       ),
    .capture_hold     ( capture_hold     )
);

task check;
    input ok;
    input [255:0] message;
    begin if(ok !== 1'b1) begin $display("FAIL %0s",message); $finish; end end
endtask

initial begin
    repeat(5) @(negedge clk); rst=0;
    waited=0;
    while(uut.local_frame<3 && waited<1000) begin @(posedge clk); #1; waited=waited+1; end
    check(uut.local_frame>=3,"standalone timeline advances on native raster boundaries");
    @(negedge clk); game_reset=1;
    repeat(2) @(negedge clk);
    check(uut.local_frame==0,"game reset clears the standalone timeline");
    game_reset=0;
    waited=0;
    while(uut.local_frame<1 && waited<1000) begin @(posedge clk); #1; waited=waited+1; end
    check(uut.local_frame==1,"timeline resumes from zero after game reset");
    @(negedge clk); rx_strobe=1; rx_cmd=8'h90; rx_index=0;
    @(negedge clk); rx_strobe=0;
    repeat(2) @(posedge clk);
    check(info_frame==uut.local_frame,"INFO snapshots current standalone frame");
    check((^info_width)!==1'bx && (^info_height)!==1'bx,"INFO geometry has no unknown bits");
    $display("PASS standalone timeline, reset and INFO snapshot"); $finish;
end
initial begin #1000000; $display("FAIL timeout"); $finish; end
endmodule
