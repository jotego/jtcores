/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module capture_case #(
    parameter HEIGHT=7,
    parameter REQUEST_STEP=3
)(
    input clk,
    input spi_clk,
    input rst,
    output reg done=0
);
reg game_reset=0, pxl_cen=1, lhbl=0, lvbl=0;
reg [3:0] red=0, green=0, blue=0;
reg cab_active=0, dump_pause=0, rx_strobe=0, spi_read_consume=0;
reg [31:0] cab_frame=0;
reg [7:0] rx_cmd=0, rx_byte=0;
reg [4:0] rx_index=0;
reg [9:0] spi_pixel_addr=0;
wire [15:0] spi_pixel_data, info_width, info_height;
wire [31:0] info_frame;
wire spi_read_ready, spi_read_bank, cancel_toggle, pause_gate, capture_hold;
wire [7:0] spi_read_prefix;
integer x=0, y=0, expected_y=0, residue=0, n=0, sum, wait_count;
reg [15:0] row_word;
reg [11:0] row_pixel, expected_pixel;
localparam ACTIVE_HEIGHT=HEIGHT;
localparam CLAMPED_STEP=(REQUEST_STEP>HEIGHT ? HEIGHT : REQUEST_STEP==0 ? 1 : REQUEST_STEP);

always @(negedge clk) begin
    if(!rst) begin
        lhbl=(x==0);
        lvbl=(y<HEIGHT);
        red=y[11:8];
        green=y[7:4];
        blue=y[3:0];
        x=x+1;
        if(x==4) begin
            x=0;
            y=y+1;
            if(y==HEIGHT+1) y=0;
        end
    end
end

jtframe_capture #(
    .WIDTH ( 1 ),
    .HEIGHT ( HEIGHT ),
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
    input [255:0] message;
    begin
        if(ok !== 1'b1) begin
            $display("FAIL H=%0d step=%0d row=%0d expected=%0d actual=%0d: %0s",
                     HEIGHT,REQUEST_STEP,n,expected_y,uut.next_y,message);
            $finish;
        end
    end
endtask

task pulse_rx;
    input [4:0] index;
    input [7:0] value;
    begin
        @(negedge clk);
        rx_strobe=1; rx_cmd=8'h91; rx_index=index; rx_byte=value;
        @(negedge clk);
        rx_strobe=0;
    end
endtask

initial begin
    wait(!rst);
    check(info_width==1 && info_height==HEIGHT,"parameter geometry");
    pulse_rx(0,0);
    pulse_rx(1,1); pulse_rx(2,0); pulse_rx(3,0); pulse_rx(4,0);
    pulse_rx(5,REQUEST_STEP[7:0]); pulse_rx(6,REQUEST_STEP>>8);
    wait_count=0;
    while(n<HEIGHT && wait_count<2000000) begin
        @(negedge spi_clk); #1;
        if(spi_read_ready) begin
            check(spi_read_prefix==8'hff,"one-pixel row uses raw prefix");
            spi_pixel_addr={spi_read_bank,9'd0};
            @(posedge spi_clk); #1; row_word=spi_pixel_data;
            row_pixel={row_word[7:4],row_word[3:0],row_word[15:12]};
            expected_pixel=expected_y[11:0];
            check(row_pixel==expected_pixel,"published line contains oracle row color");
            spi_read_consume=1;
            @(posedge spi_clk); #1; spi_read_consume=0;
            n=n+1;
            sum=expected_y+CLAMPED_STEP;
            if(sum<HEIGHT) expected_y=sum;
            else expected_y=++residue;
        end
        wait_count=wait_count+1;
    end
    check(n==HEIGHT,"exact HEIGHT rows emitted");
    wait_count=0;
    while(pause_gate && wait_count<2000000) begin @(posedge clk); #1; wait_count=wait_count+1; end
    check(!pause_gate,"pause released after all rows drain");
    done=1;
end
endmodule

module test;
reg clk=0, spi_clk=0, rst=1;
wire [6:0] done;
always #5 clk=~clk;
always #7 spi_clk=~spi_clk;

capture_case #(.HEIGHT(1),.REQUEST_STEP(1)) c_h1_s1(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[0]));
capture_case #(.HEIGHT(3),.REQUEST_STEP(2)) c_h3_s2(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[1]));
capture_case #(.HEIGHT(7),.REQUEST_STEP(3)) c_h7_s3(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[2]));
capture_case #(.HEIGHT(223),.REQUEST_STEP(16)) c_h223_s16(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[3]));
capture_case #(.HEIGHT(224),.REQUEST_STEP(17)) c_h224_s17(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[4]));
capture_case #(.HEIGHT(511),.REQUEST_STEP(32)) c_h511_s32(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[5]));
capture_case #(.HEIGHT(512),.REQUEST_STEP(600)) c_h512_s600(.clk(clk),.spi_clk(spi_clk),.rst(rst),.done(done[6]));

initial begin
    repeat(6) @(negedge clk);
    rst=0;
    wait(&done);
    $display("PASS controller row sequence heights 1,3,7,223,224,511,512; nondividing and clamped steps");
    $finish;
end
initial begin #100000000; $display("FAIL timeout done=%b",done); $finish; end
endmodule
