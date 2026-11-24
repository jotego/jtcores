/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2026 */

`timescale 1ns/1ps
module test;
reg clk_sys=0, clk_sd=0;
reg SPI_CLK=0, SPI_SS_IO=1, SPI_MOSI=0;
wire SPI_MISO;
reg rst=0, game_reset=0, pxl_cen=1, lhbl=0, lvbl=0;
reg [3:0] red=0, green=0, blue=0;
reg cab_active=0, dump_pause=0;
reg [31:0] cab_frame=0;
reg [9:0] spi_pixel_addr;
wire [15:0] spi_pixel_data;
wire [15:0] info_width, info_height;
wire [31:0] info_frame;
wire read_ready, read_bank, read_consume, cancel_toggle, pause_gate, capture_hold;
wire [7:0] read_prefix;
wire rx_strobe;
wire [7:0] rx_cmd, rx_byte;
wire [4:0] rx_index;
reg [7:0] conf_chr=0;
integer x=0, y=0, rows=0, polls=0, idx, n;
reg [7:0] info[0:7], got[0:767];
reg [7:0] pfx;
reg [7:0] partial0, partial1;
reg old_bank;
reg [31:0] info_snapshot;
real half=20.833333;
realtime last_sck_rise=0.0;
real measured_period;
integer sck_edges=0, total_sck_edges=0, bad_periods=0;
reg [11:0] p0,p1,p2,p3,p4;
reg [7:0] expected[0:767];

always #10.416667 clk_sys=~clk_sys;
always #10.416667 clk_sd=~clk_sd;
always @(posedge SPI_SS_IO) sck_edges=0;
always @(posedge SPI_CLK) begin
    if(!SPI_SS_IO) begin
        if(sck_edges!=0) begin
            measured_period=$realtime-last_sck_rise;
            if(measured_period<41.65 || measured_period>41.68) bad_periods=bad_periods+1;
        end
        last_sck_rise=$realtime;
        sck_edges=sck_edges+1;
        total_sck_edges=total_sck_edges+1;
    end else sck_edges=0;
end

always @(negedge clk_sys) begin
    if(!rst) begin
        lhbl=(x<511);
        lvbl=(y<3);
        red=x[3:0];
        green=y[3:0];
        blue=(x^y)^4'hb;
        x=x+1;
        if(x==514) begin
            x=0;
            y=y+1;
            if(y==6) y=0;
        end
    end
end

function [11:0] test_pixel;
    input integer xx;
    input integer yy;
    reg [3:0] bx,by,bb;
    begin
        bx=xx[3:0]; by=yy[3:0]; bb=bx^by^4'hb;
        test_pixel={bx,by,bb};
    end
endfunction

jtframe_capture #(
    .WIDTH ( 511 ),
    .HEIGHT ( 3 ),
    .COLORW ( 4 )
) capture(
    .rst              ( rst              ),
    .clk              ( clk_sys          ),
    .spi_clk          ( SPI_CLK          ),
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
    .spi_read_consume ( read_consume     ),
    .spi_pixel_addr   ( spi_pixel_addr   ),
    .spi_pixel_data   ( spi_pixel_data   ),
    .info_width       ( info_width       ),
    .info_height      ( info_height      ),
    .info_frame       ( info_frame       ),
    .spi_read_ready   ( read_ready       ),
    .spi_read_prefix  ( read_prefix      ),
    .spi_read_bank    ( read_bank        ),
    .cancel_toggle    ( cancel_toggle    ),
    .pause_gate       ( pause_gate       ),
    .capture_hold     ( capture_hold     )
);

/* verilator lint_off PINMISSING */
user_io #(
    .STRLEN        ( 1 ),
    .SD_IMAGES     ( 2 ),
    .FEATURES      ( 32'h001e0000 ),
    .VIDEO_WIDTH   ( 511 ),
    .VIDEO_HEIGHT  ( 3 )
) uio(
    .conf_str                ( 8'd0            ),
    .conf_chr                ( conf_chr        ),
    .clk_sys                 ( clk_sys         ),
    .clk_sd                  ( clk_sd          ),
    .SPI_CLK                 ( SPI_CLK         ),
    .SPI_SS_IO               ( SPI_SS_IO       ),
    .SPI_MISO                ( SPI_MISO        ),
    .SPI_MOSI                ( SPI_MOSI        ),
    .video_read_ready        ( read_ready      ),
    .video_read_prefix       ( read_prefix     ),
    .video_read_bank         ( read_bank       ),
    .video_read_consume      ( read_consume    ),
    .video_cancel_toggle     ( cancel_toggle   ),
    .video_width             ( info_width      ),
    .video_height            ( info_height     ),
    .video_frame             ( info_frame      ),
    .video_pixel_addr        ( spi_pixel_addr  ),
    .video_pixel_data        ( spi_pixel_data  ),
    .video_rx_strobe         ( rx_strobe       ),
    .video_rx_cmd            ( rx_cmd          ),
    .video_rx_byte           ( rx_byte         ),
    .video_rx_index          ( rx_index        ),
    .video_hold              ( capture_hold    ),
    .video_cab_frame         (                 ),
    .cab_rst                 ( rst             ),
    .cab_lvbl                ( lvbl            ),
    .cab_active              (                 ),
    .cab_hold_reset          (                 ),
    .cab_inputs              (                 ),
    .cab_dipsw_valid         (                 ),
    .cab_dipsw               (                 ),
    .cab_dump_pause          (                 )
);
/* verilator lint_on PINMISSING */

task check;
    input ok;
    input [255:0] msg;
    begin
        if(ok !== 1'b1) begin
            $display("FAIL %0s t=%0t",msg,$time);
            $finish;
        end
    end
endtask

task spi_byte;
    input [7:0] tx;
    output [7:0] rx;
    integer b;
    begin
        rx=0;
        for(b=7;b>=0;b=b-1) begin
            SPI_MOSI=tx[b];
            #half;
            SPI_CLK=1;
            #0.2;
            rx[b]=SPI_MISO;
            #(half-0.2);
            SPI_CLK=0;
        end
    end
endtask

task cs_open;
    begin SPI_SS_IO=0; #2.1; end
endtask

task cs_close;
    begin SPI_SS_IO=1; SPI_MOSI=0; #3.0; end
endtask

task cmd_byte;
    input [7:0] op;
    reg [7:0] discarded;
    begin spi_byte(op,discarded); end
endtask

task begin_capture;
    reg [7:0] discarded;
    begin
        cs_open(); cmd_byte(8'h91);
        spi_byte(8'd1,discarded); spi_byte(8'd0,discarded);
        spi_byte(8'd0,discarded); spi_byte(8'd0,discarded);
        spi_byte(8'd1,discarded); spi_byte(8'd0,discarded);
        cs_close();
    end
endtask

task read_info;
    integer k;
    reg [7:0] discarded;
    begin
        cs_open(); cmd_byte(8'h90);
        for(k=0;k<4;k=k+1) spi_byte(8'h00,info[k]);
        info_snapshot=info_frame;
        force capture.local_frame=32'h5a4b3c2d;
        for(k=4;k<8;k=k+1) spi_byte(8'h00,info[k]);
        release capture.local_frame;
        cs_close();
        for(k=0;k<8;k=k+1) check((^info[k])!==1'bx,"INFO byte known");
        check({info[1],info[0]}==511,"INFO width");
        check({info[3],info[2]}==3,"INFO height");
        check({info[7],info[6],info[5],info[4]}==info_snapshot,
              "INFO frame remains coherent while the live counter changes");
    end
endtask

task read_one_row;
    integer k, plen;
    reg [7:0] discarded;
    begin
        cs_open(); cmd_byte(8'h94); spi_byte(0,pfx);
        if(pfx==0) begin
            cs_close(); polls=polls+1;
        end else begin
            check(pfx==8'hff,"width 511 distinct pixels use raw prefix");
            plen=767;
            for(k=0;k<plen-1;k=k+1) spi_byte(0,discarded);
            old_bank=read_bank;
            cs_close();
            check(read_ready===1'b1,"partial CS transfer does not consume row");
            check(read_bank==old_bank,"partial transfer retains ordered head");
            cs_open(); cmd_byte(8'h94); spi_byte(0,discarded);
            check(discarded==pfx,"retry begins with same prefix");
            for(k=0;k<plen;k=k+1) spi_byte(0,got[k]);
            check(read_bank!=old_bank,"final payload bit consumes exactly one row");
            old_bank=read_bank;
            spi_byte(0,discarded);
            cs_close();
            check(read_bank==old_bank,"extra clocks after the payload do not consume a second row");
            for(k=0;k<plen;k=k+1) check((^got[k])!==1'bx,"payload byte known");
            for(k=0;k<511;k=k+1) begin
                p0=test_pixel(k,rows);
                n=k*3/2;
                if(k[0]) begin
                    expected[n][3:0]=p0[11:8]; expected[n+1]=p0[7:0];
                end else begin
                    expected[n]=p0[11:4]; expected[n+1]={p0[3:0],4'd0};
                end
            end
            for(k=0;k<plen;k=k+1) check(got[k]===expected[k],"width 511 SPI raw payload matches RGB444 oracle");
            rows=rows+1;
        end
    end
endtask

integer timeout_count;
reg [7:0] discarded;
initial begin

    SPI_SS_IO=0; #1; SPI_SS_IO=1;
    rst=1;
    repeat(5) @(negedge clk_sys);
    rst=0;
    #7.31; // make the first SCK edge independent of clk_sys
    read_info();
    read_one_row();
    begin_capture();
    #500000; // Stop SCK until new publications already exist.
    timeout_count=0;
    while(rows<3 && timeout_count<100) begin
        read_one_row();
        timeout_count=timeout_count+1;
    end
    check(rows==3,"three rows stream through actual user_io/controller/RAM");
    check(polls>0,"empty READ polls are exactly prefix-only transactions");
    repeat(4) @(posedge clk_sys);
    cs_open(); cmd_byte(8'h99); cs_close();
    repeat(8) @(posedge clk_sys);
    check(!pause_gate,"ABORT releases capture-owned pause");
    check(bad_periods==0 && total_sck_edges>0,"SPI test clock is 24 MHz with independent phase");
    $display("PASS polls=%0d",polls); $finish;
end
initial begin  #10000000; $display("FAIL timeout"); $finish; end
endmodule
