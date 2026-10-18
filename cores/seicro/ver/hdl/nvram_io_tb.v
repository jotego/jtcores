/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-10-2026 */

module nvram_io_tb;
reg clk=0, rst=1, ioctl_ram=0, ioctl_wr=0;
reg [25:0] ioctl_addr=0;
reg [7:0] ioctl_dout=0;
wire [7:0] ioctl_din;
integer i;

always #5 clk=~clk;

jtseicro_game_sdram dut(
    .clk        ( clk        ),
    .rst        ( rst        ),
    .clk24      ( clk        ),
    .clk96      ( clk        ),
    .rst24      ( rst        ),
    .rst96      ( rst        ),
    .ioctl_addr ( ioctl_addr ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_wr   ( ioctl_wr   ),
    .ioctl_ram  ( ioctl_ram  ),
    .ioctl_rom  ( 1'b0       ),
    .ioctl_cart ( 1'b0       ),
    .ioctl_din  ( ioctl_din  ),
    .dip_flip   ( 1'b1       ),
    .dip_pause  ( 1'b0       ),
    .ba_ack     ( 4'd0       ),
    .ba_dst     ( 4'd0       ),
    .ba_dok     ( 4'd0       ),
    .ba_rdy     ( 4'd0       ),
    .data_read  ( 16'd0      )
);

initial begin
    force dut.u_game.u_main.cpu_step=1'b0;
    force dut.u_game.u_mcu.step=1'b0;
    repeat(8) @(negedge clk); rst=0; ioctl_ram=1;
    for(i=0;i<256;i=i+1) begin
        ioctl_addr=i;
        ioctl_dout=i[7:0]^8'ha5;
        ioctl_wr=1;
        repeat(4) @(negedge clk);
        ioctl_wr=0;
        repeat(2) @(negedge clk);
    end
    ioctl_addr=256; ioctl_dout=8'hff; ioctl_wr=1;
    repeat(4) @(negedge clk);
    ioctl_wr=0;
    rst=1;
    repeat(8) @(negedge clk); rst=0;
    for(i=0;i<256;i=i+1) begin
        ioctl_addr=i;
        repeat(6) @(negedge clk);
        if(ioctl_din!==(i[7:0]^8'ha5))
            $fatal(1,"NVRAM save/restore addr=%02x got=%02x",i,ioctl_din);
    end
    $display("PASS NVRAM IOCTL: 256-byte restore/save, upper boundary and core reset retention");
    $finish;
end

initial begin #2000000; $fatal(1,"NVRAM IOCTL timeout"); end
endmodule
