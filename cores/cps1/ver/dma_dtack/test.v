`timescale 1ns/1ps
module test;
`include "test_tasks.vh"

reg clk=0, rst=0;
reg [23:0] data_address=24'h020000;
wire cen10, cen10b, cpu_cen, cpu_rnw;
wire [17:1] cpu_addr;
wire [15:0] cpu_dout;
wire ram_cs, vram_cs, rom_cs;
wire [21:1] rom_addr;
reg [15:0] rom_data=16'h4e71, ram_data=16'h4e71;
reg rom_ok=0, ram_ok=0;
wire [15:0] fave;
wire busack, udsw, ldsw;
wire ppu1_cs, ppu2_cs, ppu_rstn;
wire [7:0] snd_latch0, snd_latch1;
reg [8:0] v=0;
reg lvbl=1, lhbl=1;
reg [15:0] mmr_dout=16'hffff;
reg [1:0] joymode=0;
reg [9:0] joystick1=0, joystick2=0;
reg [1:0] dial_x=0, dial_y=0;
reg [1:0] cab_1p=0, coin=0;
reg charger=0, service=0, tilt=0, busreq=0;
reg dip_pause=1, dip_test=0;
reg [7:0] dipsw_a=8'hff, dipsw_b=8'hff, dipsw_c=8'hff;
integer response_delay=0;
integer rom_wait_count=0, ram_wait_count=0;
reg [21:1] last_rom_addr=0;
reg [17:1] last_ram_addr=0;
reg [31:0] timeout_count=0;

always #10.416667 clk=~clk; // 48 MHz, matching JTFRAME_MCLK and DTACK MFREQ
always @(posedge clk) begin
    timeout_count <= timeout_count+1;
    if(timeout_count==32'd30000000) begin
        $display("FAIL global timeout");
        $finish;
    end
end

function [15:0] rom_word(input [20:0] word_address);
    reg [15:0] op;
    begin
        op=16'h4e71;
        case(word_address)
            21'h000000: op=16'h00ff;             // initial SP = $00FF8000
            21'h000001: op=16'h8000;
            21'h000002: op=16'h0000;             // initial PC = $00000100
            21'h000003: op=16'h0100;
            21'h000080: op=16'h7000;             // MOVEQ #0,D0
            21'h000081: op=16'h207c;             // MOVEA.L #data_address,A0
            21'h000082: op={8'd0,data_address[23:16]};
            21'h000083: op=data_address[15:0];
            21'h000084: op=16'h3210; // MOVE.W (A0),D1
            21'h000085: op=16'h60fc; // BRA.S to read
            default: begin
                if(word_address==21'h010000) op=16'hcafe;
                if(word_address==21'h010001) op=16'hcafe;
            end
        endcase
        rom_word=op;
    end
endfunction

function [15:0] ram_word(input [16:0] word_address);
    reg [15:0] op;
    begin
        op=16'h4e71;
        if(word_address==17'h02000 && data_address==24'hff4000) op=16'hbeef;
        ram_word=op;
    end
endfunction

// A one-master-clock external memory response; jtcps1_main's ok-delay and
// DTACK block then complete the bus cycle on their normal production path.
always @(posedge clk) begin
    if(rst) begin
        rom_data <= 16'h4e71;
        ram_data <= 16'h4e71;
        rom_ok <= 0;
        ram_ok <= 0;
        rom_wait_count <= 0;
        ram_wait_count <= 0;
        last_rom_addr <= 0;
        last_ram_addr <= 0;
    end else begin
        if(!rom_cs || rom_addr!=last_rom_addr) begin
            rom_wait_count <= 0;
            rom_ok <= 0;
        end else if(rom_cs) begin
            if(rom_wait_count<response_delay) begin
                rom_wait_count <= rom_wait_count+1;
                rom_ok <= 0;
            end else begin
                rom_data <= rom_word(rom_addr);
                rom_ok <= 1;
            end
        end
        if(!ram_cs && !vram_cs || cpu_addr!=last_ram_addr) begin
            ram_wait_count <= 0;
            ram_ok <= 0;
        end else if(ram_cs || vram_cs) begin
            if(ram_wait_count<response_delay) begin
                ram_wait_count <= ram_wait_count+1;
                ram_ok <= 0;
            end else begin
                ram_data <= ram_word(cpu_addr[17:1]);
                ram_ok <= 1;
            end
        end
        last_rom_addr <= rom_addr;
        last_ram_addr <= cpu_addr;
    end
end

jtcps1_main dut(
    .rst(rst), .clk(clk), .cen10(cen10), .cen10b(cen10b), .turbo(1'b0),
    .cpu_cen(cpu_cen), .V(v), .LVBL(lvbl), .LHBL(lhbl),
    .ppu1_cs(ppu1_cs), .ppu2_cs(ppu2_cs), .ppu_rstn(ppu_rstn),
    .mmr_dout(mmr_dout), .joymode(joymode),
    .snd_latch0(snd_latch0), .snd_latch1(snd_latch1), .UDSWn(udsw), .LDSWn(ldsw),
    .charger(charger), .joystick1(joystick1), .joystick2(joystick2),
    .joyana_r1(16'd0), .joyana_r2(16'd0),
    .dial_x(dial_x), .dial_y(dial_y), .cab_1p(cab_1p), .coin(coin),
    .service(service), .tilt(tilt), .busreq(busreq), .busack(busack),
    .RnW(cpu_rnw), .addr(cpu_addr), .cpu_dout(cpu_dout),
    .ram_cs(ram_cs), .vram_cs(vram_cs), .ram_data(ram_data), .ram_ok(ram_ok),
    .rom_cs(rom_cs), .rom_addr(rom_addr), .rom_data(rom_data), .rom_ok(rom_ok),
    .dip_pause(dip_pause), .dip_test(dip_test),
    .dipsw_a(dipsw_a), .dipsw_b(dipsw_b), .dipsw_c(dipsw_c), .fave(fave)
);

integer debt_on_grant;
initial begin
    $dumpfile("test.lxt"); $dumpvars(0,test);
    data_address=24'hff4000; response_delay=200;
    rst=1; repeat(12) @(negedge clk); rst=0;
    while(dut.u_dtack.missing<8 && timeout_count<20000) @(negedge clk);
    assert_msg(dut.u_dtack.missing>=8,"memory stall created recovery debt");
    busreq=1;
    while(!busack && timeout_count<50000) @(negedge clk);
    assert_msg(busack,"DMA was granted bus");
    debt_on_grant=dut.u_dtack.missing;
    assert_msg(debt_on_grant>0,"recovery debt remains when DMA owns bus");
    repeat(40) @(negedge clk);
    $display("debt at grant=%0d after 40 master clocks=%0d",debt_on_grant,dut.u_dtack.missing);
    assert_msg(dut.u_dtack.missing==debt_on_grant,"recovery debt remains unchanged during DMA ownership");
    busreq=0;
    while(busack && timeout_count<60000) @(negedge clk);
    assert_msg(!busack,"DMA releases the bus");
    while(!dut.u_dtack.recover && timeout_count<70000) @(negedge clk);
    assert_msg(dut.u_dtack.recover,"recovery resumes after DMA releases the bus");
    pass();
end
endmodule
