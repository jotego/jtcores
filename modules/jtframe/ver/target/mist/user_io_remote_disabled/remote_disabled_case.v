`timescale 1ns/1ps

module remote_disabled_case #(parameter [31:0] FEATURES=32'd0)(output reg done=0);
reg clk_sys=0;
reg clk_sd=0;
reg SPI_CLK=0;
reg SPI_SS_IO=1;
reg SPI_MOSI=0;
wire SPI_MISO;
reg video_read_ready=1;
reg [7:0] video_read_prefix=8'hff;
reg video_read_bank=1;
wire video_read_consume;
reg video_cancel_toggle=0;
reg [15:0] video_width=16'd320;
reg [15:0] video_height=16'd224;
reg [31:0] video_frame=32'hdeadbeef;
wire [9:0] video_pixel_addr;
reg [15:0] video_pixel_data=16'h1234;
wire video_rx_strobe;
wire [7:0] video_rx_cmd, video_rx_byte;
wire [4:0] video_rx_index;
reg video_hold=1;
wire [31:0] video_cab_frame;
reg cab_rst=0;
reg cab_lvbl=1;
wire cab_active, cab_hold_reset;
wire [20:0] cab_inputs;
wire cab_dipsw_valid;
wire [31:0] cab_dipsw;
wire cab_dump_pause;
wire [1:0] buttons, switches;
reg [7:0] rx;
integer i;

always #10.416667 clk_sys=~clk_sys;
always #17.000000 clk_sd=~clk_sd;

/* verilator lint_off PINMISSING */
user_io #(
    .FEATURES(FEATURES)
) dut(
    .clk_sys(clk_sys),
    .clk_sd(clk_sd),
    .SPI_CLK(SPI_CLK),
    .SPI_SS_IO(SPI_SS_IO),
    .SPI_MISO(SPI_MISO),
    .SPI_MOSI(SPI_MOSI),
    .video_read_ready(video_read_ready),
    .video_read_prefix(video_read_prefix),
    .video_read_bank(video_read_bank),
    .video_read_consume(video_read_consume),
    .video_cancel_toggle(video_cancel_toggle),
    .video_width(video_width),
    .video_height(video_height),
    .video_frame(video_frame),
    .video_pixel_addr(video_pixel_addr),
    .video_pixel_data(video_pixel_data),
    .video_rx_strobe(video_rx_strobe),
    .video_rx_cmd(video_rx_cmd),
    .video_rx_byte(video_rx_byte),
    .video_rx_index(video_rx_index),
    .video_hold(video_hold),
    .video_cab_frame(video_cab_frame),
    .cab_rst(cab_rst),
    .cab_lvbl(cab_lvbl),
    .cab_active(cab_active),
    .cab_hold_reset(cab_hold_reset),
    .cab_inputs(cab_inputs),
    .cab_dipsw_valid(cab_dipsw_valid),
    .cab_dipsw(cab_dipsw),
    .cab_dump_pause(cab_dump_pause),
    .buttons(buttons),
    .switches(switches)
);
/* verilator lint_on PINMISSING */

task automatic spi_byte(input [7:0] tx, output reg [7:0] got);
    integer b;
    begin
        got=0;
        for(b=7;b>=0;b=b-1) begin
            SPI_MOSI=tx[b];
            #20.833333;
            SPI_CLK=1;
            #0.2;
            got[b]=SPI_MISO;
            #20.633333;
            SPI_CLK=0;
        end
    end
endtask

task automatic command(input [7:0] op);
    begin
        SPI_SS_IO=0;
        #5;
        spi_byte(op,rx);
    end
endtask

task automatic close_command;
    begin
        SPI_SS_IO=1;
        SPI_MOSI=0;
        #10;
    end
endtask

task automatic expect_byte(input [7:0] expected, input [255:0] label);
    begin
        spi_byte(8'h00,rx);
        if(rx !== expected) begin
            $display("FAIL FEATURES=%08x %0s expected=%02x got=%02x",FEATURES,label,expected,rx);
            $fatal(1);
        end
    end
endtask

initial begin
    SPI_SS_IO=0;
    #1;
    SPI_SS_IO=1;
    #2;
    repeat(4) @(posedge clk_sys);
    command(8'h90);
    for(i=0;i<8;i=i+1) expect_byte(8'd0,"INFO reply");
    close_command();

    command(8'h94);
    expect_byte(8'd0,"READ prefix");
    for(i=0;i<8;i=i+1) expect_byte(8'd0,"READ body");
    close_command();

    command(8'h81);
    for(i=0;i<16;i=i+1) expect_byte(8'd0,"CAB snapshot");
    close_command();

    command(8'h91);
    for(i=0;i<6;i=i+1) spi_byte(8'hA5,rx);
    close_command();
    command(8'h81);
    for(i=0;i<8;i=i+1) spi_byte(8'h5A,rx);
    close_command();

    if({video_read_consume,video_pixel_addr,video_rx_strobe,video_rx_cmd,video_rx_byte,video_rx_index,
        video_cab_frame,cab_active,cab_hold_reset,cab_inputs,cab_dipsw_valid,cab_dipsw,cab_dump_pause} !== 0) begin
        $display("FAIL FEATURES=%08x remote outputs not neutral",FEATURES);
        $fatal(1);
    end

    command(8'h80);
    expect_byte(8'h80,"features tag");
    expect_byte(8'h00,"features byte3");
    expect_byte(8'h00,"features byte2");
    expect_byte(FEATURES[15:8],"features byte1");
    expect_byte(FEATURES[7:0],"features byte0");
    close_command();

    command(8'h01);
    spi_byte(8'h05,rx);
    close_command();
    repeat(8) @(posedge clk_sys);
    if({buttons,switches} !== 4'b0101) begin
        $display("FAIL FEATURES=%08x legacy button update",FEATURES);
        $fatal(1);
    end
    done=1;
end
endmodule
