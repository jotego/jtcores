/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0,spi_clk=0,rst=1,game_reset=0,pxl_cen=1,lhbl=0,lvbl=0;
reg [3:0] red=0,green=0,blue=0;
reg cab_active=0,dump_pause=0,rx_strobe=0,spi_read_consume=0;
reg [31:0] cab_frame=0;
reg [7:0] rx_cmd=0,rx_byte=0;
reg [4:0] rx_index=0;
reg [9:0] spi_pixel_addr=0;
wire [15:0] spi_pixel_data,info_width,info_height;
wire [31:0] info_frame;
wire spi_read_ready,spi_read_bank,cancel_toggle,pause_gate,capture_hold;
wire [7:0] spi_read_prefix;
integer x=0,y=0,i,waited,rows=0;
reg first_bank;

always #10 clk=~clk;
always #13 spi_clk=~spi_clk;
always @(negedge clk) begin
    if(!rst) begin
        lhbl=(x<5);
        lvbl=(y<3);
        red=x[3:0];
        green=y[3:0];
        blue=4'hb;
        x=x+1;
        if(x==8) begin
            x=0;
            y=y+1;
            if(y==6) y=0;
        end
    end
end

jtframe_capture #(
    .WIDTH ( 5 ),
    .HEIGHT ( 3 ),
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
    .rx_index         ( rx_index         ),
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
    input [255:0] msg;
    begin
        if(ok !== 1'b1) begin
            $display("FAIL %0s",msg);
            $finish;
        end
    end
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

task begin_capture;
    input [31:0] target;
    input [15:0] stride;
    begin
        pulse_rx(8'h91,0,0);
        pulse_rx(8'h91,1,target[7:0]);
        pulse_rx(8'h91,2,target[15:8]);
        pulse_rx(8'h91,3,target[23:16]);
        pulse_rx(8'h91,4,target[31:24]);
        pulse_rx(8'h91,5,stride[7:0]);
        pulse_rx(8'h91,6,stride[15:8]);
    end
endtask

initial begin
    repeat(5) @(negedge clk);
    rst=0;
    check(info_width==5 && info_height==3,"INFO geometry is parameterized");
    begin_capture(1,1);

    waited=0;
    while(rows<3 && waited<50000) begin
        @(negedge spi_clk); #1;
        if(spi_read_ready) begin
            check(spi_read_prefix!=0,"ready slot has nonempty prefix");
            if(rows==0) first_bank=spi_read_bank;
            if(rows==1) check(spi_read_bank!=first_bank,"second row occupies other bank");
            spi_read_consume=1;
            @(negedge spi_clk); #1; spi_read_consume=0;
            rows=rows+1;
        end
        waited=waited+1;
    end
    check(rows==3,"exactly HEIGHT rows are published");
    check(uut.rows_remaining==0,"row budget reaches zero");
    check(info_width==5 && info_height==3,"INFO geometry remains known");
    check(uut.state==4,"final ACK remains in drain until native boundary");
    rows=0;
    begin_capture(3,1);
    check(uut.begin_pending===1'b1,"next BEGIN is queued during final drain");
    waited=0;
    while(rows<3 && waited<50000) begin
        @(negedge spi_clk); #1;
        if(spi_read_ready) begin
            check(spi_read_prefix!=0,"queued capture publishes a nonempty row");
            if(rows==0) first_bank=spi_read_bank;
            if(rows==1) check(spi_read_bank!=first_bank,"queued capture restarts ordered banks");
            spi_read_consume=1;
            @(negedge spi_clk); #1; spi_read_consume=0;
            rows=rows+1;
        end
        waited=waited+1;
    end
    check(rows==3,"queued BEGIN completes a second full image");
    check(uut.rows_remaining==0,"second row budget reaches zero");
    while(uut.publish_toggle!=uut.consume_sync) @(posedge clk);
    @(negedge clk);
    force uut.raster_tick=1'b1;
    rx_strobe=1; rx_cmd=8'h91; rx_index=6; rx_byte=0;
    @(posedge clk); #1;
    check(uut.state==1 && !uut.begin_pending,
          "BEGIN on final drain boundary starts directly without being stranded");
    rx_strobe=0;
    release uut.raster_tick;
    pulse_rx(8'h99,0,0);
    waited=0;
    while(pause_gate && waited<50000) begin @(posedge clk); #1; waited=waited+1; end
    check(!pause_gate,"capture releases pause after drain and boundary");
    check(!spi_read_ready,"all rows consumed");
    $display("PASS"); $finish;
end
initial begin #5000000; $display("FAIL timeout"); $finish; end
endmodule
