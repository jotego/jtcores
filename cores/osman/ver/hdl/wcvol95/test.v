/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, wc=1, hv=0, lvbl=1;
reg [31:0] bus_addr=0, bus_data=0;
reg [3:0] bus_sel=15;
reg bus_we=0, bus_active=0;
wire ymz_cs, ymz_wr, ymz_rd, ymz_addr, ready;
wire [7:0] ymz_din, ymz_dout;
wire rom_cs, overrun;
wire [20:0] rom_addr;
reg [7:0] rom_data=0;
reg rom_ok=0;
reg cen=0;
wire signed [15:0] snd_l, snd_r;
reg [7:0] memory [0:65535];
reg [20:0] held_addr;
integer ticks=0, latency=5, checks=0, a, i;
reg served=0;
reg [9:0] expected;
reg [7:0] pf1=0, pf2=0;
reg [11:0] obj=0;
wire [9:0] pal_addr;
wire [7:0] red, green, blue;
always #5 clk=~clk;

jtosman_main main(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cen_arm    ( 1'b0         ),
    .LVBL       ( lvbl         ),
    .jm         ( 1'b0         ),
    .cr         ( 1'b0         ),
    .md         ( 1'b0         ),
    .mdp        ( 1'b0         ),
    .hv         ( hv           ),
    .wc         ( wc           ),
    .oki1_bank  (              ),
    .ioctl_addr ( 26'd0        ),
    .ioctl_dout ( 8'd0         ),
    .ioctl_wr   ( 1'b0         ),
    .ioctl_ram  ( 1'b0         ),
    .ioctl_din  (              ),
    .mram_addr  (              ),
    .mram_we    (              ),
    .mram_dout  ( 16'h5678     ),
    .mramh_we   (              ),
    .mramh_dout ( 16'h1234     ),
    .rom_cs     (              ),
    .rom_addr   (              ),
    .rom_data   ( 32'd0        ),
    .rom_ok     ( 1'b1         ),
    .cpu_addr   (              ),
    .cpu_dout   (              ),
    .cpu_dhi    (              ),
    .cpu_rnw    (              ),
    .dsn        (              ),
    .pf_cs      (              ),
    .pfram_cs   (              ),
    .pal_cs     (              ),
    .oram_cs    (              ),
    .rowscr_cs  (              ),
    .obj_copy   (              ),
    .pf_dout    ( 16'd0        ),
    .pal_dout   ( 16'd0        ),
    .oram_dout  ( 16'd0        ),
    .flip       (              ),
    .oki1_wr    (              ),
    .oki2_wr    (              ),
    .oki_din    (              ),
    .oki2_bank  (              ),
    .oki1_dout  ( 8'ha5        ),
    .oki2_dout  ( 8'h5a        ),
    .ymz_cs     ( ymz_cs       ),
    .ymz_wr     ( ymz_wr       ),
    .ymz_rd     ( ymz_rd       ),
    .ymz_addr   ( ymz_addr     ),
    .ymz_din    ( ymz_din      ),
    .ymz_dout   ( ymz_dout     ),
    .ymz_ready  ( ready        ),
    .joystick1  ( 7'h7f        ),
    .joystick2  ( 7'h7f        ),
    .cab_1p     ( 4'hf         ),
    .coin       ( 4'hf         ),
    .service    ( 1'b1         ),
    .dip_test   ( 1'b1         ),
    .dip_pause  ( 1'b1         ),
    .vdump      ( 9'd0         )
);

jtosman_ymz sound(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen       ( cen       ),
    .cs        ( ymz_cs    ),
    .wr        ( ymz_wr    ),
    .rd        ( ymz_rd    ),
    .addr      ( ymz_addr  ),
    .din       ( ymz_din   ),
    .dout      ( ymz_dout  ),
    .ready     ( ready     ),
    .rom_cs    ( rom_cs    ),
    .rom_addr  ( rom_addr  ),
    .rom_data  ( rom_data  ),
    .rom_ok    ( rom_ok    ),
    .snd_l     ( snd_l     ),
    .snd_r     ( snd_r     ),
    .overrun   ( overrun   )
);

jtosman_colmix mixer(
    .clk        ( clk         ),
    .pxl_cen    ( 1'b1        ),
    .LHBL       ( 1'b1        ),
    .LVBL       ( 1'b1        ),
    .pf1a_pxl   ( pf1         ),
    .pf1b_pxl   ( 8'd0        ),
    .pf2a_pxl   ( pf2         ),
    .pf2b_pxl   ( 8'd0        ),
    .obj_pxl    ( obj         ),
    .pal_addr   ( pal_addr    ),
    .pal_data   ( 16'h7c1f    ),
    .palhi_data ( 16'h0055    ),
    .pal888     ( hv          ),
    .wc         ( wc          ),
    .red        ( red         ),
    .green      ( green       ),
    .blue       ( blue        )
);

always @(negedge clk) begin
    if(!rom_cs || rst) begin
        ticks=0; served=0; rom_ok=0;
    end else if(!served) begin
        if(ticks==0) held_addr=rom_addr;
        else if(held_addr!==rom_addr) $fatal(1,"SDRAM address changed before ack");
        ticks=ticks+1;
        if(ticks>=latency) begin
            rom_data=memory[rom_addr[15:0]];
            rom_ok=1;
            served=1;
        end
    end
end

task write_bus(input [23:0] address, input [31:0] value, input [3:0] lanes);
    integer timeout;
begin
    @(negedge clk);
    bus_addr={8'd0,address}; bus_data=value; bus_sel=lanes; bus_we=1; bus_active=1;
    timeout=0;
    #1;
    while(!main.wb_ack && timeout<1000) begin
        @(negedge clk); #1; timeout=timeout+1;
    end
    if(timeout>=1000) $fatal(1,"CPU write timeout");
    @(negedge clk); bus_active=0;
end
endtask

task read_bus(input [23:0] address, output [31:0] value);
begin
    @(negedge clk);
    bus_addr={8'd0,address}; bus_sel=15; bus_we=0; bus_active=1;
    #1;
    while(!main.wb_ack) begin @(negedge clk); #1; end
    value=main.wb_rdat;
    @(negedge clk); bus_active=0;
end
endtask

task write_reg(input [7:0] r, input [7:0] value);
begin
    write_bus(24'h1a0000,{24'd0,r},1);
    write_bus(24'h1a0004,{24'd0,value},1);
end
endtask

reg [31:0] value;
initial begin
    force main.wb_adr=bus_addr;
    force main.wb_wdat=bus_data;
    force main.wb_sel=bus_sel;
    force main.wb_we=bus_we;
    force main.wb_cyc=bus_active;
    force main.wb_stb=bus_active;
    for(i=0;i<65536;i=i+1) memory[i]=8'(i*31+7);
    repeat(3) @(negedge clk);
    rst=0;
    repeat(600) @(negedge clk);
    for(a=0;a<25'h1000000;a=a+4) begin
        bus_addr=a;
        #1;
        expected={a<24'h100000,
                  a>=24'h130000 && a<=24'h137fff,
                  a>=24'h160000 && a<=24'h161fff,
                  a>=24'h180000 && a<=24'h180fff,
                  a>=24'h140000 && a<=24'h140003,
                  a>=24'h100000 && a<=24'h10001f,
                  (a>=24'h110000 && a<=24'h111fff) || (a>=24'h114000 && a<=24'h115fff),
                  (a>=24'h120000 && a<=24'h120fff) || (a>=24'h124000 && a<=24'h124fff),
                  a>=24'h1a0000 && a<=24'h1a0007,
                  a>=24'h150000 && a<=24'h150003};
        if({main.is_rom,main.is_mram,main.is_oram,main.is_pal,main.is_io,
            main.is_pfctl,main.is_pfram,main.is_rowscr,main.is_ymz,main.is_wcee}!==expected)
            $fatal(1,"decode address=%h",a);
        if(main.is_okisfx || main.is_okimus || main.is_sram || main.is_in0)
            $fatal(1,"simpl156 alias in WC map");
        checks=checks+1;
    end
    read_bus(24'h130000,value);
    if(value!==32'h12345678) $fatal(1,"32-bit work RAM");
    read_bus(24'h140000,value);
    if(value[20]!==1'b1) $fatal(1,"WC vblank polarity outside blank");
    lvbl=0;
    read_bus(24'h140000,value);
    if(value[20]!==1'b0) $fatal(1,"WC vblank polarity in blank");
    write_bus(24'h150000,7,1);
    if({main.ee_scs,main.ee_sclk,main.ee_sdi}!==3'b111) $fatal(1,"WC EEPROM pins");
    write_bus(24'h150000,0,2);
    if({main.ee_scs,main.ee_sclk,main.ee_sdi}!==3'b111) $fatal(1,"EEPROM lane mask");
    write_reg(8'hff,8'hc0);
    write_reg(8'h84,0); write_reg(8'h85,0); write_reg(8'h86,1);
    read_bus(24'h1a0000,value);
    if(value[7:0]!==memory[2] || held_addr!==21'd2) $fatal(1,"YMZ readback/address permutation");
    write_bus(24'h1a0000,8'hfe,2);
    if(sound.u_chip.reg_sel!==8'h86) $fatal(1,"YMZ byte mask");
    write_reg(8'hfe,1);
    write_reg(8'hff,8'h90);
    write_reg(8'h63,1);
    write_reg(8'h00,255); write_reg(8'h02,255); write_reg(8'h03,8);
    write_reg(8'h01,8'hc1);
    cen=1;
    repeat(1000) @(negedge clk);
    read_bus(24'h1a0004,value);
    if(value[7:0]!==1 || sound.u_chip.status!==0) $fatal(1,"YMZ status clear through CPU bus");
    if(overrun) $fatal(1,"YMZ board timing");
    cen=0;
    for(i=0;i<3;i=i+1) begin
        wc=i==2; hv=i==1;
        pf1=0; pf2=8'ha0; obj=0;
        repeat(3) @(negedge clk);
        if(pal_addr!==(i==0 ? 10'h100 : 10'h1a0)) $fatal(1,"opaque PF2 board selection");
        if(i!=1 && {red,green,blue}!==24'hff00ff) $fatal(1,"555 palette");
        obj={1'b0,2'b11,5'd3,4'h5};
        repeat(3) @(negedge clk);
        if(pal_addr!==10'h235) $fatal(1,"sprite draw order");
        pf2=8'ha1;
        repeat(3) @(negedge clk);
        if(pal_addr!==(i==0 ? 10'h1a1 : 10'h235)) $fatal(1,"board sprite priority");
        pf1=8'h27;
        repeat(3) @(negedge clk);
        if(pal_addr!==10'h027) $fatal(1,"PF1 foreground");
    end
    wc=0; hv=0;
    read_bus(24'h180000,value);
    if(value!==32'hffff5678) $fatal(1,"Mitchell work RAM unchanged");
    read_bus(24'h140000,value);
    if(value!==32'hffffff5a) $fatal(1,"Mitchell OKI unchanged");
    hv=1;
    read_bus(24'h100000,value);
    if(value!==32'h12345678) $fatal(1,"Heavy Smash work RAM unchanged");
    $display("PASS WCVol95: %0d dword decode checks, CPU/YMZ/EEPROM/video integration",checks);
    $finish;
end
initial begin
    #100000000;
    $fatal(1,"timeout");
end
endmodule
