`timescale 1ns/1ps

`ifndef CPS1_TIMING_SDRAM_CASE
`define CPS1_TIMING_SDRAM_CASE 0
`endif

module test;
`include "test_tasks.vh"


reg clk48=0, clk96=0;
wire clk_sdram;
reg mem_rst=0, path_rst=0, startup_hold=0;
reg [23:0] target_addr=24'h020000;
wire sdram_init, mem_hold;
wire cpu_rst=mem_rst | path_rst | sdram_init | mem_hold | startup_hold;
reg rfsh=0;
integer rfsh_count=0;
integer timeout_count=0;
integer mux_write_accepts=0;
reg count_mux_writes=0;
reg last_mux_we=0;
reg fetch_transaction_seen=0;
reg [3:0] boot_vector_seen=0;
wire [23:0] cpu_bus_address={dut.A,1'b0};

wire cen10, cen10b, cpu_cen, cpu_rnw;
wire [17:1] cpu_addr;
wire [15:0] cpu_dout;
wire ram_cs, vram_cs, rom_cs;
wire [21:1] rom_addr;
wire [15:0] ram_data, rom_data;
wire ram_ok, rom_ok;
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

wire [22:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [3:0] ba_rd, ba_wr, ba_ack, ba_dst, ba_dok, ba_rdy;
wire [15:0] ba0_din, data_read;
wire [1:0] ba0_dsn;
wire [12:0] sdram_a;
wire [1:0] sdram_ba, sdram_dqm;
wire sdram_nwe, sdram_ncas, sdram_nras, sdram_ncs, sdram_cke;
wire [15:0] sdram_dq;
wire sdram_dqml, sdram_dqmh;

always #5.208333  clk96=~clk96;       // 96 MHz controller
always @(posedge clk96) clk48<=~clk48; // exact 48 MHz CPU phase
assign clk_sdram=clk96;               // SiDi128 c0 SDRAM and c2 controller clocks are phase-aligned

initial begin
    $dumpfile("test.lxt");
    $dumpvars(1,test);
    $dumpon;
end

always @(posedge clk96) begin
    if(mem_rst) begin
        rfsh<=0;
        rfsh_count<=0;
    end else if(rfsh_count==6143) begin
        rfsh<=1;
        rfsh_count<=0;
    end else begin
        rfsh<=0;
        rfsh_count<=rfsh_count+1;
    end
end
always @(posedge clk96) begin
    last_mux_we<=dut_mem.u_bank0.u_slot0.we;
    if(count_mux_writes && dut_mem.u_bank0.u_slot0.we && !last_mux_we &&
            !dut_mem.u_bank0.u_slot0.req_rnw)
        mux_write_accepts<=mux_write_accepts+1;
end
always @(posedge clk48) begin
    timeout_count <= timeout_count+1;
    if(timeout_count==32'd30000000) begin
        $display("FAIL production SDRAM path global timeout");
        fail();
    end
end
// Check all reset-vector reads before running the test program.
always @(negedge clk48) begin
    if(cpu_rst) begin
        fetch_transaction_seen <= 0;
        boot_vector_seen <= 0;
    end else if(dut.ASn) begin
        fetch_transaction_seen <= 0;
    end else if(!fetch_transaction_seen && dut.RnW && dut.FC==3'b110 && !dut.DTACKn) begin
        fetch_transaction_seen <= 1;
        case(cpu_bus_address)
            24'h000000: if(dut.cpu_din===16'h00ff) boot_vector_seen[0]<=1;
            24'h000002: if(dut.cpu_din===16'h8000) boot_vector_seen[1]<=1;
            24'h000004: if(dut.cpu_din===16'h0000) boot_vector_seen[2]<=1;
            24'h000006: if(dut.cpu_din===16'h0100) boot_vector_seen[3]<=1;
            default: ;
        endcase
    end
end

jtcps1_main dut(
    .rst(cpu_rst), .clk(clk48), .cen10(cen10), .cen10b(cen10b), .turbo(1'b0),
    .cpu_cen(cpu_cen), .V(v), .LVBL(lvbl), .LHBL(lhbl),
    .ppu1_cs(ppu1_cs), .ppu2_cs(ppu2_cs), .ppu_rstn(ppu_rstn),
    .mmr_dout(mmr_dout), .joymode(joymode),
    .snd_latch0(snd_latch0), .snd_latch1(snd_latch1), .UDSWn(udsw), .LDSWn(ldsw),
    .charger(charger), .joystick1(joystick1), .joystick2(joystick2),
    .dial_x(dial_x), .dial_y(dial_y), .cab_1p(cab_1p), .coin(coin),
    .service(service), .tilt(tilt), .busreq(busreq), .busack(busack),
    .RnW(cpu_rnw), .addr(cpu_addr), .cpu_dout(cpu_dout),
    .ram_cs(ram_cs), .vram_cs(vram_cs), .ram_data(ram_data), .ram_ok(ram_ok),
    .rom_cs(rom_cs), .rom_addr(rom_addr), .rom_data(rom_data), .rom_ok(rom_ok),
    .dip_pause(dip_pause), .dip_test(dip_test),
    .dipsw_a(dipsw_a), .dipsw_b(dipsw_b), .dipsw_c(dipsw_c), .fave(fave)
);

jtcps1_sdram_test #(.CPS(1)) dut_mem(
    .rst(path_rst), .clk(clk96), .clk_gfx(clk96), .clk_cpu(clk48), .LVBL(lvbl),
    .hold_rst(mem_hold),
    .ioctl_rom(1'b0), .dwnld_busy(), .cfg_we(), .ioctl_addr(26'd0),
    .ioctl_dout(8'd0), .ioctl_din(), .ioctl_wr(1'b0), .ioctl_ram(1'b0),
    .prog_addr(), .prog_data(), .prog_mask(), .prog_ba(), .prog_we(), .prog_rd(),
    .prog_rdy(1'b0), .prog_qsnd(),
    .sclk(1'b0), .sdi(1'b0), .sdo(), .scs(1'b0), .kabuki_we(),
    .cps2_key_we(), .cps2_joymode(),
    .main_rom_cs(rom_cs), .main_rom_ok(rom_ok), .main_rom_addr(rom_addr[21:1]),
    .main_rom_data(rom_data), .vram_clr(1'b0), .vram_dma_cs(1'b0),
    .main_ram_cs(ram_cs), .main_vram_cs(vram_cs), .main_oram_cs(1'b0),
    .vram_rfsh_en(1'b0), .dsn({udsw,ldsw}), .main_dout(cpu_dout),
    .main_rnw(cpu_rnw), .main_ram_ok(ram_ok), .vram_dma_ok(),
    .main_ram_addr(cpu_addr), .vram_dma_addr(17'd0), .main_ram_data(ram_data),
    .vram_dma_data(), .snd_cs(1'b0), .pcm_cs(1'b0), .snd_ok(), .pcm_ok(),
    .snd_addr(16'd0), .pcm_addr(18'd0), .snd_data(), .pcm_data(),
    .rom0_cs(1'b0), .rom1_cs(1'b0), .rom0_ok(), .rom1_ok(),
    .rom0_addr(20'd0), .rom0_bank(2'd0), .rom1_addr(20'd0),
    .rom0_half(1'b0), .rom1_half(1'b0), .rom0_data(), .rom1_data(),
    .star_bank(1'b0), .star0_addr(13'd0), .star0_data(), .star0_ok(), .star0_cs(1'b0),
    .star1_addr(13'd0), .star1_data(), .star1_ok(), .star1_cs(1'b0),
    .ba0_addr(ba0_addr), .ba1_addr(ba1_addr), .ba2_addr(ba2_addr), .ba3_addr(ba3_addr),
    .ba_rd(ba_rd), .ba_wr(ba_wr), .ba0_din(ba0_din), .ba0_dsn(ba0_dsn),
    .ba_ack(ba_ack), .ba_dst(ba_dst), .ba_dok(ba_dok), .ba_rdy(ba_rdy),
    .data_read(data_read), .dump_flag()
);

jtframe_sdram64 #(
    .AW(23), .HF(1), .SHIFTED(0), .BA0_LEN(64), .BA1_LEN(16), .BA2_LEN(16), .BA3_LEN(16),
    .BA0_AUTOPRECH(1), .MISTER(0)
) dut_sdram(
    .rst(mem_rst), .clk(clk96), .init(sdram_init),
    .ba0_addr(ba0_addr), .ba1_addr(ba1_addr), .ba2_addr(ba2_addr), .ba3_addr(ba3_addr),
    .rd(ba_rd), .wr(ba_wr), .ba0_din(ba0_din), .ba0_dsn(ba0_dsn),
    .ba1_din(16'd0), .ba1_dsn(2'b11), .ba2_din(16'd0), .ba2_dsn(2'b11),
    .ba3_din(16'd0), .ba3_dsn(2'b11),
    .prog_en(1'b0), .prog_addr(23'd0), .prog_rd(1'b0), .prog_wr(1'b0),
    .prog_din(16'd0), .prog_dsn(2'b11), .prog_ba(2'd0),
    .prog_dst(), .prog_dok(), .prog_rdy(), .prog_ack(), .rfsh(rfsh),
    .ack(ba_ack), .dst(ba_dst), .dok(ba_dok), .rdy(ba_rdy), .dout(data_read),
    .sdram_dq(sdram_dq), .sdram_a(sdram_a), .sdram_dqml(sdram_dqml),
    .sdram_dqmh(sdram_dqmh), .sdram_ba(sdram_ba), .sdram_nwe(sdram_nwe),
    .sdram_ncas(sdram_ncas), .sdram_nras(sdram_nras), .sdram_ncs(sdram_ncs),
    .sdram_cke(sdram_cke)
);
assign sdram_dqm={sdram_dqmh,sdram_dqml};

mt48lc16m16a2 dut_model(
    .Clk(clk_sdram), .Cke(sdram_cke), .Dq(sdram_dq), .Addr(sdram_a), .Ba(sdram_ba),
    .Cs_n(sdram_ncs), .Ras_n(sdram_nras), .Cas_n(sdram_ncas), .We_n(sdram_nwe),
    .Dqm(sdram_dqm), .downloading(1'b0), .VS(1'b0), .frame_cnt(32'd0)
);

task load_image(input integer slots);
    integer i;
    reg [23:0] base;
    begin
        // Initialize complete cache/burst lines and guard words so speculative
        // fetches never consume simulator-dependent X data.
        for(i=0;i<64;i=i+1) begin
            dut_model.Bank0[i] = 16'h4e71;
            dut_model.Bank0[24'h000080+i] = 16'h4e71;
            dut_model.Bank0[24'h010000+i] = 16'h4e71;
            dut_model.Bank0[24'h307000+i] = 16'h4e71;
        end
        // Reset vector: SP=$00FF8000, PC=$00000100.
        dut_model.Bank0[0] = 16'h00ff;
        dut_model.Bank0[1] = 16'h8000;
        dut_model.Bank0[2] = 16'h0000;
        dut_model.Bank0[3] = 16'h0100;
        dut_model.Bank0[21'h000080] = 16'h7000; // MOVEQ #0,D0
        dut_model.Bank0[21'h000081] = 16'h207c; // MOVEA.L #target,A0
        dut_model.Bank0[21'h000082] = {8'd0,target_addr[23:16]};
        dut_model.Bank0[21'h000083] = target_addr[15:0];
        dut_model.Bank0[23'h302000] = 16'h7f01; // RAM $FF4000
        dut_model.Bank0[23'h010000] = 16'hcafe; // ROM $020000
        dut_model.Bank0[23'h010001] = 16'hcafe;
        base=24'h000084;
        dut_model.Bank0[base] = 16'h4ad0; // TAS.B (A0)
        dut_model.Bank0[base+1] = 16'h60fc; // BRA.S back

    end
endtask

task start_system(input integer slots);
    integer wait_cycles,boot_wait;
    begin
        boot_vector_seen=0;
        startup_hold=1;
        mem_rst=1;
        path_rst=1;
        repeat(20) @(negedge clk96);
        load_image(slots);
        mem_rst=0;
        wait_cycles=0;
        while(sdram_init && wait_cycles<200000) begin
            @(negedge clk96);
            wait_cycles=wait_cycles+1;
        end
        assert_msg(wait_cycles<200000,"SDRAM controller initialization completed");
        repeat(8) @(negedge clk96);
        path_rst=0;
        wait_cycles=0;
        while(mem_hold && wait_cycles<200000) begin
            @(negedge clk96);
            wait_cycles=wait_cycles+1;
        end
        assert_msg(wait_cycles<200000,"production VRAM reset clear completed");
        // Seed shared VRAM bank 1 after its production reset clear.
        // $91F000 maps to bank 1, local word address 0x7800.
        dut_mem.u_vram.gen_vram[1].u_ram.u_lo.u_ram.mem[15'h7800]=8'h3c;
        dut_mem.u_vram.gen_vram[1].u_ram.u_hi.u_ram.mem[15'h7800]=8'h5a;
        repeat(8) @(negedge clk96);
        startup_hold=0;
        repeat(8) @(negedge clk48);
        boot_wait=0;
        while(boot_vector_seen!=4'b1111 && boot_wait<300000) begin
            @(negedge clk48); boot_wait=boot_wait+1;
        end
        assert_msg(boot_wait<300000,"CPU completed all four reset-vector fetches after each SDRAM restart");
        boot_wait=0;
        while(!(dut.u_cpu.D0===32'd0 && dut.u_cpu.PC>=24'h000102 && dut.u_cpu.PC<=24'h000108) && boot_wait<300000) begin
            @(negedge clk48); boot_wait=boot_wait+1;
        end
        assert_msg(boot_wait<300000,"CPU executed the reset-stub MOVEQ before loop measurement");
        repeat(8) @(negedge clk48);
    end
endtask

integer tas_reads=0,tas_writes=0,tas_gaps=0;
reg read_seen=0,write_seen=0,gap_seen=0,completed=0;
reg [15:0] expected_value;
always @(negedge clk48) if(!cpu_rst && !dut.ASn && {dut.A,1'b0}=={target_addr[23:1],1'b0}) begin
    if (!dut.DTACKn && dut.RnW && !read_seen) begin
        tas_reads=tas_reads+1; read_seen=1;
        if(tas_reads==2) begin
            assert_msg(dut.cpu_din===expected_value,"second TAS read sees previous write through actual memory path");
            completed=1;
        end
    end
    if (read_seen && (&{dut.UDSn,dut.LDSn}) && dut.DTACKn) begin gap_seen=1; tas_gaps=tas_gaps+1; end
    if (!dut.DTACKn && !dut.RnW && !write_seen) begin
        assert_msg(read_seen && gap_seen,"TAS write follows read and DTACK release");
        assert_msg(ram_ok && dut.ok_dly,"TAS write waits for memory response");
        assert_msg(target_addr[0] ? (dut.UDSn && !dut.LDSn) : (!dut.UDSn && dut.LDSn),"TAS lane is correct");
        write_seen=1; tas_writes=tas_writes+1;
    end
end
always @(posedge clk48) if(!cpu_rst && dut.ASn && write_seen) begin
    read_seen=0; write_seen=0; gap_seen=0;
end
initial begin
    #1;
    target_addr=(`CPS1_TIMING_SDRAM_CASE & 2) ? 24'h91f000 : 24'hff4000;
    if (`CPS1_TIMING_SDRAM_CASE & 1) target_addr=target_addr+1;
    expected_value=(`CPS1_TIMING_SDRAM_CASE & 2) ?
        (target_addr[0] ? 16'h5abc : 16'hda3c) :
        (target_addr[0] ? 16'h7f81 : 16'hff01);
    count_mux_writes=1;
    start_system(0);
    while(!completed && timeout_count<2000000) @(negedge clk48);
    assert_msg(completed && tas_reads==2 && tas_writes==1 && tas_gaps>0,"back-to-back TAS completed");
    if(!(`CPS1_TIMING_SDRAM_CASE & 2)) begin
        assert_msg(mux_write_accepts==1,"SDRAM slot accepted exactly one TAS write");
        assert_msg(dut_model.Bank0[23'h302000]===expected_value,"SDRAM contains TAS result and untouched byte");
    end else begin
        assert_msg({dut_mem.u_vram.gen_vram[1].u_ram.u_hi.u_ram.mem[15'h7800],
                    dut_mem.u_vram.gen_vram[1].u_ram.u_lo.u_ram.mem[15'h7800]}===expected_value,"VRAM contains TAS result and untouched byte");
    end
    $display("TAS production path address=%06x result=%04x reads=%0d writes=%0d sdram_accepts=%0d",target_addr,expected_value,tas_reads,tas_writes,mux_write_accepts);
    pass();
end
endmodule
