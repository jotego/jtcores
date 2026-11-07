/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, spi_clk=0, rst=1, game_reset=0, pxl_cen=0, lhbl=0, lvbl=0;
reg [4:0] r5=0,g5=0,b5=0;
reg [5:0] r6=0,g6=0,b6=0;
reg [7:0] r8=0,g8=0,b8=0;
wire [14:0] rgb5,rgb6,rgb8;
wire [15:0] w5,h5,w6,h6,w8,h8;
wire [31:0] f5,f6,f8;
wire rr5,rr6,rr8,rb5,rb6,rb8,cc5,cc6,cc8,cancel5,cancel6,cancel8;
wire [7:0] p5,p6,p8;
wire [15:0] d5,d6,d8;

always #5 clk=~clk;
always #7 spi_clk=~spi_clk;
assign rgb5 = u5.rgb;
assign rgb6 = u6.rgb;
assign rgb8 = u8.rgb;

jtframe_capture #(
    .WIDTH  ( 1 ),
    .HEIGHT ( 1 ),
    .COLORW ( 5 )
) u5(
    .rst              ( rst       ),
    .clk              ( clk       ),
    .spi_clk          ( spi_clk   ),
    .game_reset       ( game_reset),
    .pxl_cen          ( pxl_cen   ),
    .lhbl             ( lhbl      ),
    .lvbl             ( lvbl      ),
    .red              ( r5        ),
    .green            ( g5        ),
    .blue             ( b5        ),
    .cab_active       ( 1'b0       ),
    .cab_frame        ( 32'd0      ),
    .dump_pause       ( 1'b0       ),
    .rx_strobe        ( 1'b0       ),
    .rx_cmd           ( 8'd0       ),
    .rx_byte          ( 8'd0       ),
    .rx_index         ( 5'd0       ),
    .spi_read_consume ( 1'b0       ),
    .spi_pixel_addr   ( 10'd0      ),
    .spi_pixel_data   ( d5         ),
    .info_width       ( w5         ),
    .info_height      ( h5         ),
    .info_frame       ( f5         ),
    .spi_read_ready   ( rr5        ),
    .spi_read_prefix  ( p5         ),
    .spi_read_bank    ( rb5        ),
    .cancel_toggle    ( cancel5    ),
    .pause_gate       (            ),
    .capture_hold     ( cc5        )
);

jtframe_capture #(
    .WIDTH  ( 1 ),
    .HEIGHT ( 1 ),
    .COLORW ( 6 )
) u6(
    .rst              ( rst       ),
    .clk              ( clk       ),
    .spi_clk          ( spi_clk   ),
    .game_reset       ( game_reset),
    .pxl_cen          ( pxl_cen   ),
    .lhbl             ( lhbl      ),
    .lvbl             ( lvbl      ),
    .red              ( r6        ),
    .green            ( g6        ),
    .blue             ( b6        ),
    .cab_active       ( 1'b0       ),
    .cab_frame        ( 32'd0      ),
    .dump_pause       ( 1'b0       ),
    .rx_strobe        ( 1'b0       ),
    .rx_cmd           ( 8'd0       ),
    .rx_byte           ( 8'd0       ),
    .rx_index         ( 5'd0       ),
    .spi_read_consume ( 1'b0       ),
    .spi_pixel_addr   ( 10'd0      ),
    .spi_pixel_data   ( d6         ),
    .info_width       ( w6         ),
    .info_height      ( h6         ),
    .info_frame       ( f6         ),
    .spi_read_ready   ( rr6        ),
    .spi_read_prefix  ( p6         ),
    .spi_read_bank    ( rb6        ),
    .cancel_toggle    ( cancel6    ),
    .pause_gate       (            ),
    .capture_hold     ( cc6        )
);

jtframe_capture #(
    .WIDTH  ( 1 ),
    .HEIGHT ( 1 ),
    .COLORW ( 8 )
) u8(
    .rst              ( rst       ),
    .clk              ( clk       ),
    .spi_clk          ( spi_clk   ),
    .game_reset       ( game_reset),
    .pxl_cen          ( pxl_cen   ),
    .lhbl             ( lhbl      ),
    .lvbl             ( lvbl      ),
    .red              ( r8        ),
    .green            ( g8        ),
    .blue             ( b8        ),
    .cab_active       ( 1'b0       ),
    .cab_frame        ( 32'd0      ),
    .dump_pause       ( 1'b0       ),
    .rx_strobe        ( 1'b0       ),
    .rx_cmd           ( 8'd0       ),
    .rx_byte          ( 8'd0       ),
    .rx_index         ( 5'd0       ),
    .spi_read_consume ( 1'b0       ),
    .spi_pixel_addr   ( 10'd0      ),
    .spi_pixel_data   ( d8         ),
    .info_width       ( w8         ),
    .info_height      ( h8         ),
    .info_frame       ( f8         ),
    .spi_read_ready   ( rr8        ),
    .spi_read_prefix  ( p8         ),
    .spi_read_bank    ( rb8        ),
    .cancel_toggle    ( cancel8    ),
    .pause_gate       (            ),
    .capture_hold     ( cc8        )
);

task check;
    input ok;
    input [255:0] msg;
    begin
        if(ok !== 1'b1) begin $display("FAIL %0s",msg); $finish; end
    end
endtask

initial begin
    r5=5'b00101; g5=5'b10101; b5=5'b01111;
    r6=6'b101011; g6=6'b010110; b6=6'b111001;
    r8=8'b10100111; g8=8'b01010111; b8=8'b11110101;
    #1;
    check(rgb5===15'b00101_10101_01111,"COLORW5 exact RGB555");
    check(rgb6===15'b10101_01011_11100,"COLORW6 selects component MSBs");
    check(rgb8===15'b10100_01010_11110,"COLORW8 selects component MSBs");
    r5=5'b00100; g5=5'b10100; b5=5'b01110;
    r6=6'b101010; g6=6'b010100; b6=6'b111000;
    r8=8'b10100000; g8=8'b01010000; b8=8'b11110000;
    #1;
    check(rgb5===15'b00100_10100_01110,"COLORW5 retained channel LSB changes output");
    check(rgb6===15'b10101_01010_11100,"COLORW6 retained LSB changes output");
    check(rgb8===15'b10100_01010_11110,"COLORW8 discarded low bits do not change output");
    check(w5===16'h8001 && w6===16'h8001 && w8===16'h8001,"all wide COLORW formats set INFO flag");
    $display("PASS"); $finish;
end
initial begin #1000; $display("FAIL timeout"); $finish; end
endmodule
