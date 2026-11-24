`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

`ifdef PASSIVE1_NOMODE4_TEST
localparam PASSIVE_MODE = 1;
localparam MODE4_ENABLED = 0;
`elsif PASSIVE1_TEST
localparam PASSIVE_MODE = 1;
localparam MODE4_ENABLED = 1;
`elsif PASSIVE0_TEST
localparam PASSIVE_MODE = 0;
localparam MODE4_ENABLED = 1;
`else
localparam PASSIVE_MODE = 0;
localparam MODE4_ENABLED = 1;
`endif

reg clk96 = 0, clk48 = 0;
wire clk = PASSIVE_MODE ? clk48 : clk96;
reg reset_n = 0;
reg mclk_e = 0;
reg cpu_clk = 0;
reg edclk = 0;
reg [22:0] ca = 0;
reg [15:0] cd = 0;
reg as_n = 1, uds = 1, lds = 1, rw = 1;
reg [22:0] ca_r = 0;
reg [15:0] cd_r = 0;
reg asn_r = 1, uds_r = 1, lds_r = 1, rnw_r = 1;
reg [7:0] ad_mem = 0, sd_mem = 0;
reg [1:0] dtack_r = 0;
reg [7:0] rd_i = 0;

always #5.208 clk96 = ~clk96;    // 96 MHz legacy YM master
always @(posedge clk96) clk48 <= ~clk48; // 48 MHz passive YM master
always #50 cpu_clk = ~cpu_clk;   // 10 MHz 68000 clock

wire [7:0] ym_rd_o, ym_ad_o, ym_sd_o, ym_vram_ad_o, ym_vram_sd_o;
wire ym_rd_d, ym_ad_d, ym_sd_d, ym_vram_ad_d, ym_vram_sd_d;
wire [7:0] ym_r, ym_g, ym_b;
wire [15:0] ym_cd_o, ym_sound;
wire ym_cd_d, ym_reg_m5, ym_ys, ym_dtack;
wire ym_ras, ym_cas, ym_we0, ym_oe, ym_sc, ym_se0;
wire ym_spa_b, ym_bgack, ym_int, ym_br, ym_ipl1, ym_ipl2;
wire ym_de_h, ym_de_v, ym_vsync2, ym_hsync2;
wire [7:0] ym_sd;
wire [7:0] ad_bus = (~ym_ad_d ? ym_ad_o : 8'h00) |
                    (~ym_vram_ad_d ? ym_vram_ad_o : 8'h00) |
                    ((ym_ad_d && ym_vram_ad_d) ? ad_mem : 8'h00);
wire [7:0] sd_bus = ym_vram_sd_d ? sd_mem : ym_vram_sd_o;
wire ym_dtack_n = ~dtack_r[0];
always @(posedge clk) begin
    mclk_e <= ~mclk_e;
    ca_r <= ca;
    cd_r <= cd;
    asn_r <= as_n;
    uds_r <= uds;
    lds_r <= lds;
    rnw_r <= rw;
    ad_mem <= ad_bus;
    sd_mem <= sd_bus;
    dtack_r <= {dtack_r[0],ym_dtack};
    edclk <= ~edclk;
end
integer bus_timeout;
integer phase_i;
integer legacy_phase_transitions;
reg last_clk1;

ym7101 #(.PASSIVE(PASSIVE_MODE),.MODE4(MODE4_ENABLED)) uut (
    .MCLK(clk), .pxl_cen(1'b0), .pxl2_cen(1'b0),
    .HS(1'b1), .VS(1'b1), .LHBL(1'b0), .LVBL(1'b0), .SD(sd_bus),
    .SE1(), .SE0(ym_se0), .SC(ym_sc), .RAS1(ym_ras), .CAS1(ym_cas),
    .WE1(), .WE0(ym_we0), .OE1(ym_oe),
    .RD_i(ym_rd_o), .RD_o(ym_rd_o), .RD_d(ym_rd_d),
    .DAC_R(ym_r), .DAC_G(ym_g), .DAC_B(ym_b),
    .AD_i(ad_bus), .AD_o(ym_ad_o), .AD_d(ym_ad_d), .YS(ym_ys),
    .SPA_B_i(1'b1), .SPA_B_pull(ym_spa_b), .VSYNC(),
    .CSYNC_i(1'b1), .CSYNC_pull(), .HSYNC_i(1'b1), .HSYNC_pull(),
    .HL(1'b1), .SEL0(1'b1), .PAL(1'b0), .RESET(reset_n),
    .CLK1_i(cpu_clk), .CLK1_o(), .SBCR(), .CLK0(), .MCLK_e(mclk_e),
    .EDCLK_i(edclk), .EDCLK_o(), .EDCLK_d(), .reg_m5(ym_reg_m5),
    .CD_i(ym_cd_d ? cd_r : ym_cd_o), .CD_o(ym_cd_o), .CD_d(ym_cd_d),
    .CA_i(ca_r), .CA_o(), .CA_d(), .SOUND(ym_sound),
    .INT_pull(ym_int), .BR_pull(ym_br), .BGACK_i(1'b1), .BGACK_pull(ym_bgack),
    .BG(1'b1), .MREQ(1'b1), .INTAK(1'b0), .IPL1_pull(ym_ipl1), .IPL2_pull(ym_ipl2),
    .IORQ(1'b1), .RD(1'b1), .WR(1'b1), .M1(1'b1), .AS(asn_r),
    .UDS(uds_r), .LDS(lds_r), .RW(rnw_r), .DTACK_i(dtack_r[1]), .DTACK_pull(ym_dtack),
    .UWR(), .LWR(), .OE0(), .CAS0(), .RAS0(), .RA(), .ext_test_2(1'b0),
    .vdp_hclk1(), .vdp_intfield(), .vdp_de_h(ym_de_h), .vdp_de_v(ym_de_v),
    .vdp_m5(), .vdp_rs1(), .vdp_m2(), .vdp_lcb(), .vdp_psg_clk1(),
    .vdp_vsync2(ym_vsync2), .vdp_hsync2(ym_hsync2), .vdp_cramdot_dis(1'b0),
    .vdp_dma_oe_early(), .vdp_dma()
);

vram #(.SERIAL_LOOKAHEAD(PASSIVE_MODE)) vram_model (
    .MCLK(clk), .RAS(ym_ras), .CAS(ym_cas), .WE(ym_we0), .OE(ym_oe),
    .SC(ym_sc), .SE(ym_se0), .AD(ad_bus), .RD_i(ad_bus),
    .RD_o(ym_vram_ad_o), .RD_d(ym_vram_ad_d), .SD_o(ym_vram_sd_o), .SD_d(ym_vram_sd_d)
);

task cpu_write(input [22:0] address, input [15:0] data);
    integer timeout;
    begin
        @(posedge cpu_clk);
        ca = address; rw = 0; uds = 1; lds = 1; as_n = 1;
        @(negedge cpu_clk);
        as_n = 0;
        @(posedge cpu_clk);
        cd = data;
        @(negedge cpu_clk);
        timeout = 0;
        uds = 0; lds = 0;
        while (ym_dtack_n && timeout < 1024) begin
            @(posedge cpu_clk); #2; timeout = timeout + 1;
        end
        if (ym_dtack_n !== 1'b0) begin
            $display("FAIL: CPU write %06x/%04x timed out", address, data);
            $fatal(1);
        end
        @(negedge cpu_clk);
        @(posedge cpu_clk);
        as_n = 1; uds = 1; lds = 1;
        @(negedge cpu_clk);
        timeout = 0;
        while (!ym_dtack_n && timeout < 32) begin
            @(posedge cpu_clk); #2; timeout = timeout + 1;
        end
        if (ym_dtack_n !== 1'b1) begin
            $display("FAIL: CPU write %06x/%04x did not release DTACK", address, data);
            $fatal(1);
        end
    end
endtask

task cpu_read(input [22:0] address, output [15:0] data);
    integer timeout;
    begin
        @(posedge cpu_clk);
        ca = address; cd = 16'hffff; rw = 1; uds = 1; lds = 1; as_n = 1;
        @(negedge cpu_clk);
        as_n = 0;
        @(posedge cpu_clk);
        @(negedge cpu_clk);
        uds = 0; lds = 0;
        timeout = 0;
        while (ym_dtack_n && timeout < 1024) begin
            @(posedge cpu_clk); #2; timeout = timeout + 1;
        end
        if (ym_dtack_n !== 1'b0) begin
            $display("FAIL: CPU read %06x timed out", address);
            $fatal(1);
        end
        @(negedge cpu_clk);
        @(posedge cpu_clk); #2;
        if (ym_cd_d !== 1'b0 || (^ym_cd_o) === 1'bx) begin
            $display("FAIL: CPU read %06x returned invalid data %04x dir=%b", address, ym_cd_o, ym_cd_d);
            $fatal(1);
        end
        data = ym_cd_o;
        as_n = 1; uds = 1; lds = 1;
        @(negedge cpu_clk);
        timeout = 0;
        while (!ym_dtack_n && timeout < 32) begin
            @(posedge cpu_clk); #2; timeout = timeout + 1;
        end
        if (ym_dtack_n !== 1'b1) begin
            $display("FAIL: CPU read %06x did not release DTACK", address);
            $fatal(1);
        end
    end
endtask

task check_muted;
    integer n;
    begin
        for (n=0; n<16; n=n+1) begin
            @(posedge clk); #1;
            if ({ym_r,ym_g,ym_b} !== 24'h000000) begin
                $display("FAIL: pre-acquisition pixels not muted YS=%b RGB=%06x ready=%b",
                    ym_ys,{ym_r,ym_g,ym_b},uut.passive_render_ready);
                $fatal(1);
            end
            if (PASSIVE_MODE && ym_ys !== 1'b0) begin
                $display("FAIL: passive YS asserted before renderer acquisition");
                $fatal(1);
            end
            if (PASSIVE_MODE && uut.passive_geometry_supported !== 1'b0) begin
                $display("FAIL: smoke unexpectedly acquired external geometry");
                $fatal(1);
            end
        end
    end
endtask

initial begin : smoke
    reg [15:0] status, word0, word1;
    integer q_expected, tick_expected;
    integer n;
    repeat (8) @(posedge clk);
    @(negedge clk);
    reset_n = 1;

    if (PASSIVE_MODE) begin
        // With no active raster edges, normal passive timing must cycle through
        // the 2-tick Q0/Q1/Q2/Q3 sequence and produce the documented phases.
        for (phase_i=0; phase_i<16; phase_i=phase_i+1) begin
            @(posedge clk); #1;
            q_expected = ((phase_i+1)/2) % 4;
            tick_expected = phase_i % 2 ? 0 : 1;
            if (uut.passive_quarter !== q_expected[1:0] || uut.passive_tick !== tick_expected[2:0] ||
                uut.passive_dwell !== 3'd2 ||
                uut.clk1 !== ((q_expected==0)||(q_expected==2)) ||
                uut.clk2 !== ((q_expected==1)||(q_expected==3)) ||
                uut.hclk1 !== ((q_expected==1)||(q_expected==2)) ||
                uut.hclk2 !== ((q_expected==0)||(q_expected==3))) begin
                $display("FAIL: passive normal phase step=%0d Q/tick/dwell=%0d/%0d/%0d clocks=%b%b%b%b expected Q/tick=%0d/%0d",
                    phase_i,uut.passive_quarter,uut.passive_tick,uut.passive_dwell,
                    uut.clk1,uut.clk2,uut.hclk1,uut.hclk2,q_expected,tick_expected);
                $fatal(1);
            end
        end
    end else begin
        // The original clock generator must settle to known clock phases too.
        legacy_phase_transitions = 0;
        last_clk1 = uut.clk1;
        for (n=0; n<512; n=n+1) begin
            @(posedge clk); #1;
            if (uut.clk1 === 1'bx || uut.clk2 === 1'bx || uut.hclk1 === 1'bx || uut.hclk2 === 1'bx) begin
                $display("FAIL: PASSIVE=0 clock phase unknown at sample %0d", n);
                $fatal(1);
            end
            if (uut.clk1 !== last_clk1) legacy_phase_transitions = legacy_phase_transitions+1;
            last_clk1 = uut.clk1;
        end
        if (legacy_phase_transitions == 0) begin
            $display("FAIL: PASSIVE=0 clock phase did not transition");
            $fatal(1);
        end
    end

    check_muted();
    cpu_write(23'h600002,16'h8104); // Mode 5 enabled, display held off
    n = 0;
    while ((ym_reg_m5 !== 1'b1 || uut.reg_disp !== 1'b0) && n<512) begin
        @(posedge clk); #1; n=n+1;
    end
    if (ym_reg_m5 !== 1'b1 || uut.reg_disp !== 1'b0) begin
        $display("FAIL: R1 MMR write did not settle: M5=%b disp=%b data=%05x addr=%05x code=%b DTACK=%b",
            ym_reg_m5,uut.reg_disp,uut.reg_data_l2,uut.reg_addr,uut.reg_code,ym_dtack_n);
        $fatal(1);
    end
    cpu_read(23'h600002,status);
    if ((^status) === 1'bx) begin
        $display("FAIL: status MMR read returned unknown bits %04x", status);
        $fatal(1);
    end
    check_muted();

    cpu_write(23'h600002,16'h8f02); // Autoincrement by two
    cpu_write(23'h600002,16'h4000); // VRAM write setup
    cpu_write(23'h600002,16'h0000);
    cpu_write(23'h600000,16'h1234);
    cpu_write(23'h600000,16'h5678);
    n = 0;
    while ({vram_model.mem[0],vram_model.mem[1],vram_model.mem[2],vram_model.mem[3]} !==
           {8'h34,8'h12,8'h78,8'h56} && n<4096) begin
        @(posedge clk); #1; n=n+1;
    end
    if ({vram_model.mem[0],vram_model.mem[1],vram_model.mem[2],vram_model.mem[3]} !==
        {8'h34,8'h12,8'h78,8'h56}) begin
        $display("FAIL: VRAM write/autoincrement bytes were %02x %02x %02x %02x",
            vram_model.mem[0],vram_model.mem[1],vram_model.mem[2],vram_model.mem[3]);
        $fatal(1);
    end
    cpu_write(23'h600002,16'h0000); // VRAM read setup
    cpu_write(23'h600002,16'h0000);
    cpu_read(23'h600000,word0);
    cpu_read(23'h600000,word1);
    if (word0 !== 16'h1234 || word1 !== 16'h5678) begin
        $display("FAIL: VRAM CPU readback got %04x/%04x expected 1234/5678", word0,word1);
        $fatal(1);
    end
    check_muted();
    $display("YM7101 smoke PASSIVE=%0d MODE4=%0d: normal phase, MMR/status, VRAM write/readback, blank output",
        PASSIVE_MODE,MODE4_ENABLED);
    pass();
end

endmodule
