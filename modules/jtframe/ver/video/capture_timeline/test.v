/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0,rst=1,enable=0,lvbl=0,irq_taken_toggle=0,rx_strobe=0,cab_strobe=0;
reg [7:0] rx_cmd=0,rx_byte=0,cab_cmd=0,cab_byte=0;
reg [4:0] rx_index=0,cab_index=0;
reg [8:0] cycle=0;
integer period=255,p,n;
wire [31:0] cab_frame,cab_epoch;
wire capture_hold,pause_gate;
wire [1535:0] snapshot;
wire [63:0] logical;
assign logical=uut.u_progress.game_frame;
always #5 clk=~clk;
always @(negedge clk) begin
 if(rst || !enable) begin cycle=0;lvbl=0;irq_taken_toggle=0;end
 else begin
  cycle=cycle+1;if(cycle==period) begin cycle=0;if(!pause_gate)irq_taken_toggle=~irq_taken_toggle;end
  lvbl=cycle>=(period>>1);
 end
end
jtframe_capture #(
    .WIDTH    ( 5 ),
    .HEIGHT   ( 3 ),
    .FEEDBACK ( 1 )
) uut(
    .rst              ( rst              ),
    .clk              ( clk              ),
    .game_reset       ( 1'b0             ),
    .pxl_cen          ( 1'b1             ),
    .lhbl             ( 1'b0             ),
    .lvbl             ( lvbl             ),
    .red              ( 4'd0             ),
    .green            ( 4'd0             ),
    .blue             ( 4'd0             ),
    .irq_level        ( 1'b0             ),
    .irq_taken_toggle ( irq_taken_toggle ),
    .dump_pause       ( 1'b0             ),
    .cab_frame        ( cab_frame        ),
    .cab_epoch        ( cab_epoch        ),
    .rx_strobe        ( rx_strobe        ),
    .rx_cmd           ( rx_cmd           ),
    .rx_byte          ( rx_byte          ),
    .rx_index         ( rx_index         ),
    .pause_gate       ( pause_gate       ),
    .capture_hold     ( capture_hold     ),
    .snapshot         ( snapshot         ),
    .line_snapshot    (                  ),
    .window_snapshot  (                  ),
    .read_window      (                  )
);
jtframe_cab_stream u_cab(
    .rst           ( rst          ),
    .clk           ( clk          ),
    .lvbl          ( lvbl         ),
    .capture_hold  ( capture_hold ),
    .capture_frame ( cab_frame    ),
    .capture_epoch ( cab_epoch    ),
    .rx_strobe     ( cab_strobe   ),
    .rx_cmd        ( cab_cmd      ),
    .rx_byte       ( cab_byte     ),
    .rx_index      ( cab_index    ),
    .active        (              ),
    .hold_reset    (              ),
    .inputs        (              ),
    .dipsw_valid   (              ),
    .dipsw         (              ),
    .dump_pause    (              ),
    .snapshot      (              )
);
task tick;begin @(posedge clk);#1;@(negedge clk);#1;end endtask
task command;
 input cabinet;input[7:0]cmd;input integer count;input[191:0]data;
 integer i;
 begin
 for(i=0;i<=count;i=i+1)begin
  if(cabinet)begin cab_strobe=1;cab_cmd=cmd;cab_index=i;cab_byte=i==0?0:data[(i-1)*8+:8];end
  else begin rx_strobe=1;rx_cmd=cmd;rx_index=i;rx_byte=i==0?0:data[(i-1)*8+:8];end
  tick();cab_strobe=0;rx_strobe=0;tick();
 end
 repeat(4)tick();
 end
endtask
initial begin
 $dumpfile("test.lxt");$dumpvars;
 for(p=255;p<=260;p=p+1)begin
  period=p;enable=0;rst=1;repeat(4)tick();rst=0;repeat(8)tick();
  command(1,8'h82,9,{120'd0,8'd0,32'd1,32'd16});
  command(1,8'h83,16,{64'd0,32'd1,32'd16,32'd0,32'd1});
  command(1,8'h84,4,192'd1);
  command(0,8'h98,17,{56'd0,8'd1,64'd0,64'd1});
  command(0,8'h91,12,{96'd0,32'd0,64'd2});
  enable=1;
  for(n=0;n<20;n=n+1)begin
   @(posedge uut.raster_tick);repeat(5)tick();
   if(logical!={32'd0,cab_frame})begin $display("FAIL period=%d edge=%d game=%d cab=%d",p,n,logical,cab_frame);$finish;end
   if(n==12)command(0,8'h99,16,{64'd0,64'd1,64'd1});
  end
 end
 $display("PASS");$finish;
end
initial begin #2000000;$display("FAIL timeout");$finish;end
endmodule
