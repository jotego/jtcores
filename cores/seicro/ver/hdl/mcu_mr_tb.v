/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module mcu_mr_tb;
parameter NSC=0;
reg clk=0, rst=1, run=0, lvbl=0, rom_hold=1, mcu_reset=0;
reg [5:0] divider=0;
wire cen=divider[3:0]==0;
reg [8:0] h=128;
wire release_clk, main_rom_cs, video_we;
wire [14:0] main_rom_addr, mcu_rom_addr;
reg [7:0] main_rom_data, mcu_rom_data, shared_data;
wire [15:0] main_addr;
wire [7:0] main_data, shared_din;
wire [10:0] shared_addr;
wire shared_we, mcu_rom_cs;
reg [7:0] rom[0:32767], ram[0:2047];
integer k, writes=0, held=0, z80_writes=0, reset_edges=0;
reg previous_e;

always #5 clk=~clk;
always @(posedge clk) begin
    divider <= divider+6'd1;
    case(main_rom_addr)
        0: main_rom_data <= 8'h3e;
        1: main_rom_data <= 8'h5a;
        2: main_rom_data <= 8'h32;
        3: main_rom_data <= 8'h00;
        4: main_rom_data <= 8'h90;
        5: main_rom_data <= 8'hc3;
        default: main_rom_data <= 8'h00;
    endcase
    mcu_rom_data <= rom[mcu_rom_addr];
    shared_data <= ram[shared_addr];
    if(shared_we) begin ram[shared_addr]<=shared_din; writes=writes+1; end
    if(video_we) z80_writes=z80_writes+1;
end

jtseicro_main u_main(
    .rst             ( rst           ),
    .cpu_rst         ( rst           ),
    .clk             ( clk           ),
    .cpu_cen         ( cen           ),
    .dip_pause       ( 1'b1          ),
    .LVBL            ( lvbl          ),
    .irq_en          ( 1'b0          ),
    .frisky          ( 1'b0          ),
    .radial          ( 1'b0          ),
    .tecfri          ( 1'b1          ),
    .video_h         ( h             ),
    .cab_1p          ( 2'b11         ),
    .coin            ( 2'b11         ),
    .joystick1       ( 6'h3f         ),
    .joystick2       ( 6'h3f         ),
    .service         ( 1'b1          ),
    .dip_test        ( 1'b1          ),
    .test_dip        ( 8'hff         ),
    .cpu_addr        ( main_addr     ),
    .cpu_dout        ( main_data     ),
    .videoram_we     ( video_we      ),
    .sharedram_dout  ( 8'd0          ),
    .videoram_dout   ( 8'd0          ),
    .colorram_dout   ( 8'd0          ),
    .spriteram0_dout ( 8'd0          ),
    .row_scroll_dout ( 8'd0          ),
    .rom_addr        ( main_rom_addr ),
    .rom_cs          ( main_rom_cs   ),
    .rom_data        ( main_rom_data ),
    .rom_ok          ( 1'b1          ),
    .ay_data         ( 8'hff         ),
    .mcu_release_clk ( release_clk   )
);

jtseicro_mcu u_mcu(
    .rst         ( rst          ),
    .cpu_rst     ( mcu_reset    ),
    .clk         ( clk          ),
    .cen         ( cen          ),
    .release_clk ( release_clk  ),
    .run         ( run          ),
    .reset_req   ( 1'b0         ),
    .dip_pause   ( 1'b1         ),
    .nsc8105     ( NSC!=0       ),
    .dipsw       ( 24'hffffff   ),
    .nvram_en    ( 1'b0         ),
    .nvram_dout  ( 8'hff        ),
    .rom_addr    ( mcu_rom_addr ),
    .rom_cs      ( mcu_rom_cs   ),
    .rom_data    ( mcu_rom_data ),
    .rom_ok      ( !rom_hold    ),
    .shared_addr ( shared_addr  ),
    .shared_din  ( shared_din   ),
    .shared_we   ( shared_we    ),
    .shared_dout ( shared_data  )
);

initial begin
    for(k=0;k<32768;k=k+1) rom[k]=8'h01;
    for(k=0;k<2048;k=k+1) ram[k]=0;
    ram[2046]=8'h80;
    rom[0]=8'h8e; rom[1]=8'hf8; rom[2]=8'h7f;
    rom[3]=8'h8d; rom[4]=5;
    rom[5]=8'hb7; rom[6]=8'hf8; rom[7]=0;
    rom[8]=8'h20; rom[9]=8'hfe;
    rom[10]=8'h86; rom[11]=8'h5a; rom[12]=8'h39;
    if(NSC) begin
        rom[0]=8'h4d; rom[3]=8'h4e; rom[5]=8'h77;
        rom[8]=8'h20; rom[10]=8'h45; rom[12]=8'h3a;
    end
    repeat(32) @(negedge clk);
    rst=0;
    wait(!u_main.mreq_n && !u_main.wr_n && main_addr==16'h9000);
    @(negedge clk); lvbl=1;
    wait(!u_main.wait_n);
    repeat(96) @(negedge clk);
    run=1;
    wait(!u_mcu.mr_n);
    repeat(320) begin
        @(negedge clk);
        if(!u_mcu.mcu_e || u_mcu.addr!==16'hfffe || u_mcu.step ||
            release_clk!==0 || u_main.wait_n!==0)
            $fatal(1,"MCU did not hold its E-high request while Z80 was waiting");
        if(cen) held=held+1;
    end
    mcu_reset=1;
    previous_e=u_mcu.mcu_e;
    repeat(96) begin
        @(negedge clk);
        if(u_mcu.mr_n || u_mcu.mcu_vma || u_mcu.step || shared_we)
            $fatal(1,"MCU reset changed the MR latch or allowed a transfer");
        if(previous_e!=u_mcu.mcu_e) reset_edges=reset_edges+1;
        previous_e=u_mcu.mcu_e;
    end
    if(reset_edges<2) $fatal(1,"MCU reset stopped the E divider");
    mcu_reset=0;
    h=132; lvbl=0;
    wait(u_mcu.mcu_e && u_mcu.mcu_vma && u_mcu.addr==16'hfffe);
    wait(mcu_rom_cs);
    repeat(160) @(negedge clk);
    rom_hold=0;
    wait(ram[0]==8'h5a);
    @(negedge clk);
    if(writes!=3 || ram[127]!==8'h05 || ram[126]!==8'h80 ||
        u_mcu.u_cpu.u_cpu.u_regs.s!==16'hf87f || held!=20 || z80_writes<2)
        $fatal(1,"Connected Z80/MCU result or write count failed");
    $display("PASS connected WAIT/MR NSC=%0d: 20 live Z80 enables hold MCU; reset preserves MR and free E; bus release, ROM wait, BSR/RTS and 3 MCU writes",NSC);
    $finish;
end

initial begin #2000000; $fatal(1,"Connected WAIT/MR timeout main=%h mcu=%h",main_addr,u_mcu.addr); end
endmodule
