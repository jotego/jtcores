`timescale 1ns/1ps

module test;
reg clk=0, rst=1, cs_byte=0, cs_word=0, cpu_we=0, rom_ok=0;
reg mmr_noa1=1;
reg [3:0] mmr_addr=0;
reg [15:0] mmr_din=0;
reg [1:0] mmr_dsn=2'b11;
reg [31:0] rom_data=32'hde_fe_3e_20;
wire [21:2] addr_byte, addr_word;
wire [15:0] data_byte, data_word;
wire csrom_byte, csrom_word, ok_byte, ok_word;

always #5 clk=~clk;

jtriders_obj #(.RAMW(10),.CPU_ROM_REG(1),.CPU_8BIT(1)) uut_byte(
    .rst(rst),.clk(clk),.pxl_cen(1'b0),.pxl2_cen(1'b0),
    .hdump(9'd0),.vdump(9'd0),.hs(1'b0),.lvbl(1'b0),.lgtnfght(1'b0),
    .ram_cs(1'b0),.reg_cs(cs_byte),.mmr_we(cpu_we),
    .mmr_addr(mmr_addr),.mmr_din(mmr_din),.mmr_dsn(mmr_dsn),.mmr_noa1(1'b0),
    .ram_din(16'd0),.ram_we(2'b0),.ram_addr(10'd0),
    .cpu_din(data_byte),.cpu_ok(ok_byte),.dma_bsy(),
    .rom_addr(addr_byte),.rom_data(rom_data),.rom_cs(csrom_byte),.rom_ok(rom_ok),.objcha_n(1'b1),
    .shd(),.prio(),.pxl(),.gfx_en(4'hf),.ioctl_ram(1'b0),
    .ioctl_addr(14'd0),.dump_ram(),.dump_reg(),.debug_bus(8'd0)
);

jtriders_obj #(.RAMW(10),.CPU_ROM_REG(1)) uut_word(
    .rst(rst),.clk(clk),.pxl_cen(1'b0),.pxl2_cen(1'b0),
    .hdump(9'd0),.vdump(9'd0),.hs(1'b0),.lvbl(1'b0),.lgtnfght(1'b0),
    .ram_cs(1'b0),.reg_cs(cs_word),.mmr_we(cpu_we),
    .mmr_addr(mmr_addr),.mmr_din(mmr_din),.mmr_dsn(mmr_dsn),.mmr_noa1(mmr_noa1),
    .ram_din(16'd0),.ram_we(2'b0),.ram_addr(10'd0),
    .cpu_din(data_word),.cpu_ok(ok_word),.dma_bsy(),
    .rom_addr(addr_word),.rom_data(rom_data),.rom_cs(csrom_word),.rom_ok(rom_ok),.objcha_n(1'b1),
    .shd(),.prio(),.pxl(),.gfx_en(4'hf),.ioctl_ram(1'b0),
    .ioctl_addr(14'd0),.dump_ram(),.dump_reg(),.debug_bus(8'd0)
);

task write_reg;
    input byte_mode;
    input [3:0] address;
    input [15:0] value;
    input [1:0] dsn;
    begin
        @(negedge clk);
        mmr_addr=address; mmr_din=value; mmr_dsn=dsn;
        cs_byte=byte_mode; cs_word=!byte_mode; cpu_we=1;
        @(negedge clk);
        cs_byte=0; cs_word=0; cpu_we=0;
    end
endtask

initial begin
    repeat(2) @(negedge clk);
    rst=0;
    write_reg(1,4'h8,16'h1212,2'b11);
    write_reg(1,4'h9,16'h3434,2'b11);
    write_reg(1,4'hb,16'h0505,2'b11);
    cs_byte=1;
    for (integer lane=0;lane<4;lane=lane+1) begin
        mmr_addr=4'hc+lane[3:0];
        #1;
        if (addr_byte[20:2]!==19'h51234 || !csrom_byte || ok_byte ||
            data_byte[7:0]!==rom_data[(lane^1)*8+:8]) begin
            $display("FAIL: byte lane %0d addr=%h data=%h",lane,addr_byte,data_byte);
            $finish;
        end
    end
    cs_byte=0;
    write_reg(0,4'h8,16'h1234,2'b00);
    write_reg(0,4'ha,16'h0005,2'b10);
    cs_word=1; mmr_addr=4'hc;
    #1;
    if (addr_word[20:2]!==19'h51234 || data_word!==16'h3e20 || ok_word) begin
        $display("FAIL: word C/D addr=%h data=%h",addr_word,data_word);
        $finish;
    end
    mmr_addr=4'he;
    #1;
    if (data_word!==16'hdefe) begin
        $display("FAIL: word E/F data=%h",data_word);
        $finish;
    end
    rom_ok=1;
    #1;
    if (ok_word) begin $display("FAIL: stale ROM ok accepted"); $finish; end
    @(posedge clk);
    #1;
    if (!ok_word) begin $display("FAIL: ROM wait release"); $finish; end
    cs_word=0; rom_ok=0;
    @(negedge clk);
    rst=1;
    @(negedge clk);
    rst=0; mmr_noa1=0;
    write_reg(0,4'h8,16'h0012,2'b10);
    write_reg(0,4'h9,16'h0034,2'b10);
    write_reg(0,4'hb,16'h0005,2'b10);
    cs_word=1; mmr_addr=4'hc;
    #1;
    if (addr_word[20:2]!==19'h51234 || data_word!==16'h003e || ok_word) begin
        $display("FAIL: direct register C addr=%h data=%h",addr_word,data_word);
        $finish;
    end
    mmr_addr=4'hd;
    #1;
    if (data_word!==16'h0020) begin
        $display("FAIL: direct register D data=%h",data_word);
        $finish;
    end
    mmr_addr=4'h0;
    #1;
    if (data_word!==16'd0 || !ok_word) begin
        $display("FAIL: non-ROM register read data=%h ok=%b",data_word,ok_word);
        $finish;
    end
    $display("PASS");
    $finish;
end
endmodule
