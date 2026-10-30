/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, cen=1, ym_cen=0;
always #5 clk=~clk;
reg [15:0] control=0;
reg [7:0] oki_data=0;
reg oki_ok=0;
wire [17:0] oki_addr;
wire oki_cs;
reg [14:0] host_addr=0;
reg host_sel=0, host_rd=0, host_wr=0;
reg [7:0] host_din=0;
wire [7:0] host_dout;
wire host_ok;
wire [12:0] host_ram_addr;
wire [7:0] host_ram_din;
wire host_ram_we;
integer phase, previous, address;
reg [7:0] expected;

jtapach3_snd u_snd (
    .rst                ( rst           ),
    .clk                ( clk           ),
    .cen                ( cen           ),
    .ym_cen             ( ym_cen        ),
    .oki_cen            ( 1'b0          ),
    .control            ( control       ),
    .in0                ( 8'h8e         ),
    .stick_x            ( 8'h12         ),
    .stick_y            ( 8'h34         ),
    .throttle           ( 8'h56         ),
    .host_addr          ( host_addr     ),
    .host_sel           ( host_sel      ),
    .host_rd            ( host_rd       ),
    .host_wr            ( host_wr       ),
    .host_din           ( host_din      ),
    .host_dout          ( host_dout     ),
    .host_ok            ( host_ok       ),
    .fm_l               (               ),
    .fm_r               (               ),
    .pcm                (               ),
    .sound_rom_addr     (               ),
    .sound_rom_cs       (               ),
    .sound_rom_data     ( 8'h96         ),
    .sound_rom_ok       ( 1'b1          ),
    .v30_sound_rom_addr (               ),
    .v30_sound_rom_cs   (               ),
    .v30_sound_rom_data ( 8'hff         ),
    .v30_sound_rom_ok   ( 1'b1          ),
    .oki_addr           ( oki_addr      ),
    .oki_cs             ( oki_cs        ),
    .oki_data           ( oki_data      ),
    .oki_ok             ( oki_ok        ),
    .soundram_addr      (               ),
    .soundram_din       (               ),
    .soundram_dout      ( 8'h34         ),
    .soundram_we        (               ),
    .v30_soundram_addr  ( host_ram_addr ),
    .v30_soundram_din   ( host_ram_din  ),
    .v30_soundram_dout  ( 8'h5a         ),
    .v30_soundram_we    ( host_ram_we   )
);

initial begin
    u_snd.u_pcm.rom_addr=18'h111;
    repeat (5) @(negedge clk);
    rst=0;
    while (!oki_cs) @(negedge clk);
    if (oki_addr!==18'h111) $fatal(1,"initial sample ROM address");
    u_snd.u_pcm.rom_addr=18'h222;
    repeat (10) begin
        @(negedge clk);
        if (!oki_cs || oki_addr!==18'h111 || u_snd.pcm_rom_ok) $fatal(1,"sample ROM request changed before response");
    end
    oki_data=8'ha5; oki_ok=1;
    @(negedge clk); oki_ok=0;
    if (u_snd.pcm_rom_ok) $fatal(1,"stale sample ROM response marked ready");
    while (!oki_cs) @(negedge clk);
    if (oki_addr!==18'h222) $fatal(1,"new sample ROM address not requested");
    oki_data=8'h3c; oki_ok=1;
    @(negedge clk); oki_ok=0;
    if (!u_snd.pcm_rom_ok || u_snd.pcm_rom_data!==8'h3c) $fatal(1,"sample ROM response lost");
    oki_ok=1;
    u_snd.u_cpu.req=1; u_snd.u_cpu.bs=5; u_snd.u_cpu.rd_n=0;
    for (address=0;address<1048576;address=address+1) begin
        u_snd.u_cpu.A=address;
        #1;
        expected=8'hff;
        if (address<=20'h01fff) expected=8'h34;
        else if (address>=20'h04000 && address<=20'h04003) expected=8'h42;
        else if (address>=20'h06000 && address<=20'h06001) expected=8'h8e;
        else if (address>=20'h08000 && address<=20'h08001) expected=8'h51;
        else if (address==20'h0a000) expected=8'h63;
        else if (address>=20'hf0000) expected=8'h96;
        if (u_snd.cpu_din !== expected) $fatal(1,"V20 read %h got=%h expected=%h",address,u_snd.cpu_din,expected);
    end
    u_snd.u_cpu.req=0; u_snd.u_cpu.rd_n=1;
    repeat (3) @(negedge clk);
    for (phase=0;phase<8;phase=phase+1) begin
        @(negedge clk);
        u_snd.u_cpu.A=20'he000+phase; u_snd.u_cpu.bs=6;
        u_snd.u_cpu.req=1; u_snd.u_cpu.wr_n=0;
        repeat (3) @(negedge clk);
        u_snd.u_cpu.req=0; u_snd.u_cpu.wr_n=1;
        repeat (2) @(negedge clk);
        u_snd.u_cpu.A=20'he000; u_snd.u_cpu.bs=5;
        u_snd.u_cpu.req=1; u_snd.u_cpu.rd_n=0;
        case (phase)
            0: expected=8'h12;
            1: expected=8'h34;
            2,4,6,7: expected=0;
            3: expected=8'hff;
            5: expected=8'h56;
        endcase
        #1;
        if (u_snd.cpu_din !== expected) $fatal(1,"ADC channel %0d got=%h expected=%h",phase,u_snd.cpu_din,expected);
        u_snd.u_cpu.req=0; u_snd.u_cpu.rd_n=1;
        repeat (2) @(negedge clk);
    end
    for (phase=0;phase<24;phase=phase+1) begin
        @(negedge clk);
        u_snd.u_cpu.A=20'h08000; u_snd.u_cpu.bs=6;
        u_snd.u_cpu.req=1; u_snd.u_cpu.wr_n=0; u_snd.u_cpu.dout=phase;
        previous=u_snd.u_fm.writes;
        repeat (phase+1) begin
            @(negedge clk);
            if (u_snd.cpu_ready !== 0) $fatal(1,"FM write acknowledged before sampling");
        end
        while (!u_snd.fm_half) begin
            ym_cen=1; @(negedge clk); ym_cen=0; @(negedge clk);
            if (u_snd.cpu_ready !== 0) $fatal(1,"FM write acknowledged on wrong phase");
        end
        ym_cen=1; @(negedge clk); ym_cen=0;
        if (!u_snd.cpu_ready || u_snd.u_fm.writes != previous+1)
            $fatal(1,"FM write did not reach sampling enable");
        u_snd.u_cpu.req=0; u_snd.u_cpu.wr_n=1;
        repeat (3) @(negedge clk);
    end
    host_sel=1; host_wr=1; host_addr=15'h1fff; host_din=8'h73;
    control=0;
    #1;
    if (!host_ram_we || host_ram_addr!=13'h1fff || host_ram_din!=8'h73 || !host_ok)
        $fatal(1,"host RAM write in unselected bank");
    rst=1; #1;
    if (host_ram_we) $fatal(1,"reset allowed V20 host RAM write");
    rst=0;
    control=16'h0060;
    #1;
    if (!host_ram_we) $fatal(1,"host RAM write in ROM bank");
    host_wr=0; host_rd=1; control=16'h0080;
    #1;
    if (host_dout!=8'h5a || !host_ok) $fatal(1,"host RAM read");
    @(negedge clk); rst=1; cen=0; host_sel=0; host_rd=0; control=0;
    repeat (8) @(negedge clk);
    rst=0; u_snd.u_cpu.check_phase=1;
    for (phase=0;phase<6;phase=phase+1) begin
        @(negedge clk); cen=1;
        @(negedge clk); cen=0;
        repeat (phase) @(negedge clk);
        control=16'h0080;
        repeat (8) @(negedge clk);
        control=0;
        repeat (3) @(negedge clk);
        if (u_snd.u_cpu.phase_failures!=0) $fatal(1,"V20 half-cycle lost at halt phase %0d",phase);
    end
    @(negedge clk); cen=1;
    @(negedge clk); cen=0;
    repeat (5) @(negedge clk);
    if (u_snd.u_cpu.phase_failures!=0) $fatal(1,"V20 half-cycle lost on resume");
    $display("PASS V20 map, ADC, FM, sample ROM stalls, host bridge and halt/resume phases");
    $finish;
end
initial begin
    #2000000;
    $fatal(1,"sound test timed out");
end
endmodule
