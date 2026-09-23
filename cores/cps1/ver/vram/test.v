`timescale 1ns/1ps
module test;
`include "test_tasks.vh"
reg clk=0, clk_cpu=0, rst=1;
always #5 clk=~clk;
always #10 clk_cpu=~clk_cpu;
reg main_vram_cs=0, main_ram_cs=0, main_oram_cs=0, main_rnw=1, vram_dma_cs=0;
reg [17:1] main_ram_addr=0, vram_dma_addr=0;
reg [15:0] main_dout=0;
reg [1:0] dsn=0;
wire [15:0] main_ram_data, vram_dma_data;
wire main_ram_ok, vram_dma_ok, hold_rst;

jtcps1_sdram uut(
    .rst(rst), .clk(clk), .clk_cpu(clk_cpu), .clk_gfx(clk), .LVBL(1'b1),
    .hold_rst(hold_rst), .ioctl_rom(1'b0), .ioctl_addr(26'd0),
    .ioctl_dout(8'd0), .ioctl_wr(1'b0), .ioctl_ram(1'b0), .prog_rdy(1'b0),
    .sclk(1'b0), .sdi(1'b0), .scs(1'b0),
    .main_rom_cs(1'b0), .main_rom_addr(21'd0),
    .vram_clr(1'b0), .vram_dma_cs(vram_dma_cs), .main_ram_cs(main_ram_cs),
    .main_vram_cs(main_vram_cs), .main_oram_cs(main_oram_cs), .vram_rfsh_en(1'b0),
    .dsn(dsn), .main_dout(main_dout), .main_rnw(main_rnw),
    .main_ram_ok(main_ram_ok), .vram_dma_ok(vram_dma_ok),
    .main_ram_addr(main_ram_addr), .vram_dma_addr(vram_dma_addr),
    .main_ram_data(main_ram_data), .vram_dma_data(vram_dma_data),
    .snd_cs(1'b0), .pcm_cs(1'b0), .snd_addr(16'd0), .pcm_addr(18'd0),
    .rom0_cs(1'b0), .rom1_cs(1'b0), .rom0_addr(20'd0), .rom0_bank(2'd0),
    .rom1_addr(20'd0), .rom0_half(1'b0), .rom1_half(1'b0), .star_bank(1'b0),
    .star0_addr(13'd0), .star0_cs(1'b0), .star1_addr(13'd0), .star1_cs(1'b0),
    .ba_ack(4'd0), .ba_dst(4'd0), .ba_dok(4'd0), .ba_rdy(4'd0), .data_read(16'd0)
);

task write_word(input [17:0] addr, input [15:0] data, input [1:0] mask);
begin
    @(negedge clk_cpu);
    main_ram_addr=addr[17:1]; main_dout=data; dsn=mask;
    main_rnw=0; main_vram_cs=1;
    @(posedge clk_cpu); #1;
    assert_msg(main_ram_ok,"BRAM write must acknowledge in one CPU clock");
    assert_msg(!uut.ram_vram_cs,"VRAM write must not request SDRAM");
    @(negedge clk_cpu); main_vram_cs=0; main_rnw=1;
    @(posedge clk_cpu); #1;
    assert_msg(!main_ram_ok,"Acknowledge must clear between CPU accesses");
end
endtask

task read_word(input [17:0] addr, input [15:0] expected);
begin
    @(negedge clk_cpu);
    main_ram_addr=addr[17:1]; dsn=0; main_vram_cs=1;
    vram_dma_addr=addr[17:1]; vram_dma_cs=1;
    @(posedge clk_cpu); #1;
    assert_msg(main_ram_ok && main_ram_data===expected,"CPU read data mismatch");
    @(negedge clk_cpu);
    assert_msg(vram_dma_ok && vram_dma_data===expected,"DMA read data mismatch");
    main_vram_cs=0;
    @(posedge clk_cpu); #1;
end
endtask

integer bank;
initial begin
    $dumpfile("test.lxt");
    $dumpvars(1,test);
    repeat(4) @(negedge clk_cpu);
    rst=0;
    assert_msg(hold_rst,"CPU must remain reset during VRAM erase");
    wait(!uut.vram_hold_rst);
    for(bank=0;bank<3;bank=bank+1) begin
        read_word(bank*65536,16'd0);
        read_word(bank*65536+65534,16'd0);
        write_word(bank*65536,16'h1234+bank,2'b00);
        write_word(bank*65536+65534,16'h5678+bank,2'b00);
    end
    for(bank=0;bank<3;bank=bank+1) begin
        read_word(bank*65536,16'h1234+bank);
        read_word(bank*65536+65534,16'h5678+bank);
        write_word(bank*65536,16'habcd,2'b01);
        read_word(bank*65536,16'hab34+bank);
        write_word(bank*65536,16'heff0,2'b10);
        read_word(bank*65536,16'habf0);
        write_word(bank*65536,16'hffff,2'b11);
        read_word(bank*65536,16'habf0);
    end
    // DMA changes addresses without dropping CS, as the graphics engine does.
    @(negedge clk); vram_dma_addr=17'h0ffff;
    @(posedge clk); #1;
    assert_msg(vram_dma_ok && vram_dma_data==16'h5679,"DMA bank selection latency");
    @(negedge clk); vram_dma_addr=17'h17fff;
    @(posedge clk); #1;
    assert_msg(vram_dma_ok && vram_dma_data==16'h567a,"DMA consecutive bank crossing");
    // CPU writes one bank while DMA reads a different bank on its own clock.
    @(negedge clk_cpu);
    vram_dma_addr=17'h17fff;
    main_ram_addr=17'h08000; main_dout=16'hbeef; dsn=0;
    main_rnw=0; main_vram_cs=1;
    @(posedge clk_cpu); #1;
    assert_msg(main_ram_ok,"Concurrent CPU write acknowledgement");
    assert_msg(vram_dma_ok && vram_dma_data==16'h567a,"Concurrent independent DMA read");
    @(negedge clk_cpu); main_vram_cs=0; main_rnw=1;
    read_word(18'h10000,16'hbeef);
    read_word(18'h30000,16'hffff);
    @(negedge clk_cpu); main_ram_cs=1;
    #1; assert_msg(uut.ram_vram_cs,"Work RAM must still select SDRAM");
    main_ram_cs=0; main_oram_cs=1;
    #1; assert_msg(uut.ram_vram_cs,"Object RAM must still select SDRAM");
    main_oram_cs=0;
    @(negedge clk_cpu); rst=1;
    repeat(4) @(negedge clk_cpu);
    rst=0;
    wait(!uut.vram_hold_rst);
    for(bank=0;bank<3;bank=bank+1) begin
        read_word(bank*65536,16'd0);
        read_word(bank*65536+65534,16'd0);
    end
    pass();
end
initial begin
    #2000000;
    fail();
end
endmodule
