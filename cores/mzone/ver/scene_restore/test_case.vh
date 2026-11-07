// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module test;
reg clk=0, clk24=0, rst=1;
always #5 clk=~clk;
always #10 clk24=~clk24;
reg [25:0] ioctl_addr=0;
wire [7:0] ioctl_din;
reg ioctl_ram=0;
reg [7:0] expected[0:7171];
integer file, bytes_read, i;
reg [15:0] cpu_address=0;
reg [7:0] cpu_data=0;
reg cpu_read=1, cpu_valid=0;

jtmzone_game_sdram dut(
    .clk(clk), .clk24(clk24), .clk96(clk),
    .rst(rst), .rst24(rst), .rst96(rst),
    .pxl_cen(1'b0), .pxl2_cen(1'b0),
    .ioctl_addr(ioctl_addr), .ioctl_ram(ioctl_ram),
    .ioctl_wr(1'b0), .ioctl_dout(8'd0), .ioctl_din(ioctl_din),
    .ioctl_cart(1'b0), .ioctl_rom(1'b0),
    .gfx_en(4'hf), .debug_bus(8'd0), .status(32'd0),
    .dip_pause(1'b1), .dip_test(1'b0), .dipsw(32'hffffffff),
    .cab_1p(4'hf), .coin(4'hf),
    .joystick1(6'h3f), .joystick2(6'h3f), .service(1'b1)
);

task clocks;
    begin repeat(8) @(negedge clk); end
endtask

task dump_check;
    begin
        ioctl_ram=1;
        for(i=0;i<7172;i=i+1) begin
            ioctl_addr=i;
            clocks;
            if(ioctl_din !== expected[i])
                $fatal(1,"dump[%04x]=%02x expected %02x",i,ioctl_din,expected[i]);
        end
        ioctl_ram=0;
        clocks;
    end
endtask

task registers_check;
    begin
        if({dut.u_game.video_scrolly,dut.u_game.video_scrollx,dut.u_game.video_flip}
            !== {expected[7168],expected[7169],expected[7170][0]})
            $fatal(1,"video register restoration failed");
    end
endtask

`ifndef NOMAIN
task cpu_write;
    input [15:0] address;
    input [7:0] data;
    begin
        cpu_address=address; cpu_data=data; cpu_read=0; cpu_valid=1;
        clocks;
        cpu_valid=0; cpu_read=1;
        clocks;
    end
endtask

task cpu_check;
    input [15:0] address;
    input [7:0] data;
    begin
        cpu_address=address; cpu_read=1; cpu_valid=1;
        clocks;
        if(dut.u_game.u_main.cpu_din !== data)
            $fatal(1,"CPU read[%04x]=%02x expected %02x",address,dut.u_game.u_main.cpu_din,data);
        cpu_valid=0;
        clocks;
    end
endtask
`endif

initial begin
    file=$fopen("dump.bin","rb");
    bytes_read=$fread(expected,file);
    $fclose(file);
    if(bytes_read!=7172) $fatal(1,"bad fixture size");
    // Keep the sound CPU from modifying shared RAM during deterministic checks.
    force dut.u_game.snd_shared_we=1'b0;
`ifndef NOMAIN
    force dut.u_game.u_main.A=cpu_address;
    force dut.u_game.u_main.cpu_dout=cpu_data;
    force dut.u_game.u_main.RnW=cpu_read;
    force dut.u_game.u_main.VMA=cpu_valid;
    force dut.u_game.u_main.cpu_cen=1'b1;
`endif
    clocks; rst=0; clocks;
`ifdef NOMAIN
    if({dut.u_game.main_addr,dut.u_game.main_cs,dut.u_game.main_cpu_rnw,
        dut.u_game.vram0_cs,dut.u_game.vram1_cs,dut.u_game.cram0_cs,dut.u_game.cram1_cs,
        dut.u_game.main_shared_addr,dut.u_game.main_shared_din,dut.u_game.main_shared_we,
        dut.u_game.vram_addr,dut.u_game.vram_din,dut.u_game.objcpu_addr,
        dut.u_game.objram_din,dut.u_game.objram_cs,dut.u_game.video_reg_cs,
        dut.u_game.video_reg_addr,dut.u_game.intsnd} !==
       {16'd0,1'b0,1'b1,4'd0,11'd0,8'd0,1'b0,10'd0,8'd0,10'd0,
        8'd0,1'b0,1'b0,2'd0,1'b0})
        $fatal(1,"NOMAIN module outputs are not idle");
`endif
    registers_check;
    dump_check;
    // Probe renderer read ports independently of the IOCTL address mux.
    force dut.scrram_addr=10'h123;
    force dut.fixram_addr=10'h123;
    force dut.objram_addr=10'h123;
    force dut.snd_shared_addr=11'h123;
    clocks;
    if({dut.u_game.u_video.u_scroll.vram,dut.u_game.u_video.u_scroll.cram,
        dut.u_game.u_video.u_fix.vram,dut.u_game.u_video.u_fix.cram,
        dut.u_game.u_video.u_obj.oram_dout,dut.snd_shared_din} !==
       {expected['h123],expected['h923],expected['h523],expected['hd23],
        expected['h1123],expected['h1523]})
        $fatal(1,"renderer/sound RAM read ports swapped or disconnected");
    force dut.snd_shared_dout=8'hb7;
    force dut.u_game.snd_shared_we=1'b1;
    clocks;
    force dut.u_game.snd_shared_we=1'b0;
    release dut.snd_shared_dout;
    release dut.snd_shared_addr;
    release dut.scrram_addr;
    release dut.fixram_addr;
    release dut.objram_addr;
    expected['h1523]=8'hb7;
    dump_check;
`ifndef NOMAIN
    // Check combinational ROM decode between clock edges: this test has no
    // SDRAM responder and must not start a cache transaction.
    @(negedge clk);
    cpu_address=16'h4000; cpu_read=1; cpu_valid=1;
    #1;
    if({dut.u_game.main_addr,dut.u_game.main_cs} !== {16'h4000,1'b1})
        $fatal(1,"main ROM address/select interface disconnected");
    cpu_address=16'hffff;
    #1;
    if({dut.u_game.main_addr,dut.u_game.main_cs} !== {16'hffff,1'b1})
        $fatal(1,"main ROM upper address disconnected");
    cpu_valid=0;
    // Exercise each generated CPU port, including both shared-RAM ports.
    cpu_check(16'h2123,expected['h123]);
    cpu_check(16'h2523,expected['h523]);
    cpu_check(16'h2923,expected['h923]);
    cpu_check(16'h2d23,expected['hd23]);
    cpu_check(16'h3123,expected['h1123]);
    cpu_check(16'h3923,expected['h1523]);
    cpu_write(16'h2123,8'h91); expected['h123]=8'h91;
    cpu_write(16'h2523,8'h82); expected['h523]=8'h82;
    cpu_write(16'h2923,8'h73); expected['h923]=8'h73;
    cpu_write(16'h2d23,8'h64); expected['hd23]=8'h64;
    cpu_write(16'h3123,8'h55); expected['h1123]=8'h55;
    cpu_write(16'h3923,8'h46); expected['h1523]=8'h46;
    cpu_check(16'h3923,8'h46);
    // The scroll registers are mirrored over their 2 KiB decode windows.
    cpu_write(16'h17ff,8'ha3); expected[7168]=8'ha3;
    cpu_write(16'h1fff,8'h5c); expected[7169]=8'h5c;
    cpu_write(16'h0005,8'h01); expected[7170]=8'h01;
    cpu_write(16'h0003,8'h01);
    cpu_write(16'h0007,8'h01);
    registers_check;
    dump_check;
    // Reset reloads the captured video registers, rather than zeroing them.
    file=$fopen("rest.bin","rb");
    for(i=7168;i<7172;i=i+1) expected[i]=$fgetc(file);
    $fclose(file);
    rst=1; clocks; rst=0; clocks;
    registers_check;
`endif
    $display("PASS scene RAM/register restore, CPU ports and IOCTL dump");
    $finish;
end
initial begin
    #20000000;
    $fatal(1,"timeout");
end
endmodule
