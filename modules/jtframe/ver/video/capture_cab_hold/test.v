/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, spi_clk=0, rst=1, game_reset=0, lvbl=0;
reg pxl_cen=1, lhbl=0, dump_pause=0;
reg [3:0] red=0, green=0, blue=0;
reg rx_strobe=0, spi_read_consume=0;
reg [7:0] rx_cmd=0, rx_byte=0;
reg [4:0] rx_index=0;
reg [9:0] spi_pixel_addr=0;
wire [15:0] spi_pixel_data, info_width, info_height;
wire [31:0] info_frame, cab_frame;
wire spi_read_ready, spi_read_bank, cancel_toggle, pause_gate, capture_hold;
wire [7:0] spi_read_prefix;
wire cab_active, hold_reset, dipsw_valid, cab_dump_pause;
wire [20:0] cab_inputs;
wire [31:0] dipsw;
wire [511:0] cab_snapshot;
integer cycle=0, waited;
reg [31:0] frames_at_abort;

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

jtframe_cab_stream cab(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .lvbl         ( lvbl         ),
    .capture_hold ( capture_hold ),
    .capture_frame( cab_frame    ),
    .rx_strobe    ( rx_strobe    ),
    .rx_cmd       ( rx_cmd       ),
    .rx_byte      ( rx_byte      ),
    .rx_index     ( rx_index     ),
    .active       ( cab_active   ),
    .hold_reset   ( hold_reset   ),
    .inputs       ( cab_inputs   ),
    .dipsw_valid  ( dipsw_valid  ),
    .dipsw        ( dipsw        ),
    .dump_pause   ( cab_dump_pause ),
    .snapshot     ( cab_snapshot )
);

task check;
    input ok;
    input [255:0] message;
    begin if(ok !== 1'b1) begin $display("FAIL %0s",message); $finish; end end
endtask

task pulse_rx;
    input [7:0] command;
    input [4:0] index;
    input [7:0] value;
    begin
        @(negedge clk); rx_strobe=1; rx_cmd=command; rx_index=index; rx_byte=value;
        @(negedge clk); rx_strobe=0;
    end
endtask

task word_rx;
    input [7:0] command;
    input [4:0] index;
    input [31:0] value;
    begin
        pulse_rx(command,index,value[7:0]);
        pulse_rx(command,index+1,value[15:8]);
        pulse_rx(command,index+2,value[23:16]);
        pulse_rx(command,index+3,value[31:24]);
    end
endtask

task arm_cab;
    begin
        pulse_rx(8'h82,0,0);
        word_rx(8'h82,1,100);
        word_rx(8'h82,5,1);
        pulse_rx(8'h82,9,0);
        pulse_rx(8'h83,0,0);
        word_rx(8'h83,1,cab.epoch);
        word_rx(8'h83,5,0);
        word_rx(8'h83,9,100);
        word_rx(8'h83,13,0);
        pulse_rx(8'h84,0,0);
        word_rx(8'h84,1,cab.epoch);
    end
endtask

task begin_capture;
    begin
        pulse_rx(8'h91,0,0);
        word_rx(8'h91,1,3);
        pulse_rx(8'h91,5,1);
        pulse_rx(8'h91,6,0);
    end
endtask

initial begin
    repeat(5) @(negedge clk); rst=0;
    arm_cab();
    check(cab_active && cab.state==2,"CAB stream enters RUNNING from real command sequence");
    begin_capture();
    waited=0;
    while(!(pause_gate && capture_hold) && waited<10000) begin @(posedge clk); #1; waited=waited+1; end
    check(pause_gate && capture_hold,"capture pause crosses into actual CAB hold");
    @(posedge uut.raster_tick);
    @(posedge clk); #1;
    check(capture_hold,"native boundary latches the CAB hold");
    frames_at_abort=cab.frames;
    @(negedge clk); rx_strobe=1; rx_cmd=8'h99; rx_index=0; rx_byte=0;
    @(posedge clk); #1; rx_strobe=0;
    check(!pause_gate && capture_hold,"ABORT releases acquisition but holds this boundary through CAB synchronization");
    repeat(4) @(posedge clk);
    #1;
    check(cab.frames==frames_at_abort,"CAB delayed tick does not consume duration after boundary-adjacent ABORT");
    check(cab_active,"CAB remains active while capture aborts");
    waited=0;
    while(capture_hold && waited<10000) begin @(posedge clk); #1; waited=waited+1; end
    check(!capture_hold,"CAB hold releases at the next native boundary");
    waited=0;
    while(cab.frames==frames_at_abort && waited<10000) begin @(posedge clk); #1; waited=waited+1; end
    check(cab.frames==frames_at_abort+1,"CAB resumes exactly one duration at the next eligible boundary");
    $display("PASS capture_hold CAB entry/abort/resume"); $finish;
end
initial begin #2000000; $display("FAIL timeout"); $finish; end
endmodule
