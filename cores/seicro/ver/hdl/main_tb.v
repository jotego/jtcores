// Author: Andrea Bogazzi
module main_tb;
reg rst=1, clk=0, LVBL=1;
reg [5:0] count=0;
wire cpu_cen=count[3:0]==0, audio_cen=count[4:0]==0;
wire [15:0] cpu_addr;
wire [7:0] cpu_dout, ay_data;
wire sharedram_we, videoram_we, colorram_we, spriteram0_we, spriteram1_we, row_scroll_we;
reg [7:0] sharedram_dout, videoram_dout, colorram_dout, spriteram0_dout, row_scroll_dout;
reg [7:0] ram[0:2047], vram[0:1023], colorram[0:511], obj0[0:127], obj1[0:31], scroll[0:31];
reg [7:0] rom[0:32767];
wire [14:0] rom_addr;
wire rom_cs, ay_bdir, ay_bc1, watchdog_clr, irq_en, flip, mcu_run;
wire [7:0] debug_view;
wire [9:0] psg;
wire sample;
wire rom_ok=count[5:0]>=20;
reg [7:0] rom_data;
integer i, release_count=0, irq_acks=0;
reg mcu_run_l=0;
reg iack_l=0;

always #5 clk=~clk;
always @(negedge clk) begin
    iack_l<=!dut.m1_n && !dut.iorq_n;
    if(!rst && !dut.m1_n && !dut.iorq_n) begin
        if(!dut.irq_pending) $fatal(1,"CPU acknowledge cleared the IRQ latch");
        if(!iack_l) irq_acks<=irq_acks+1;
    end
end
always @(posedge clk) begin
    count<=count+6'd1;
    rom_data<=rom[rom_addr];
    sharedram_dout<=ram[cpu_addr[10:0]];
    videoram_dout<=vram[cpu_addr[9:0]];
    colorram_dout<=colorram[{cpu_addr[9:6],cpu_addr[4:0]}];
    spriteram0_dout<=obj0[cpu_addr[6:0]-7'h20];
    row_scroll_dout<=scroll[cpu_addr[4:0]];
    if(sharedram_we) ram[cpu_addr[10:0]]<=cpu_dout;
    if(videoram_we) vram[cpu_addr[9:0]]<=cpu_dout;
    if(colorram_we) colorram[{cpu_addr[9:6],cpu_addr[4:0]}]<=cpu_dout;
    if(spriteram0_we) obj0[cpu_addr[6:0]-7'h20]<=cpu_dout;
    if(spriteram1_we) obj1[cpu_addr[4:0]]<=cpu_dout;
    if(row_scroll_we) scroll[cpu_addr[4:0]]<=cpu_dout;
    mcu_run_l<=mcu_run;
    if(mcu_run && !mcu_run_l) release_count<=release_count+1;
end

jtseicro_main dut(
    .rst             ( rst             ),
    .cpu_rst         ( rst             ),
    .clk             ( clk             ),
    .cpu_cen         ( cpu_cen         ),
    .dip_pause       ( 1'b1            ),
    .LVBL            ( LVBL            ),
    .irq_en          ( irq_en          ),
    .frisky          ( 1'b0            ),
    .radial          ( 1'b0            ),
    .cab_1p          ( 2'b10           ),
    .coin            ( 2'b01           ),
    .joystick1       ( 6'b101110       ),
    .joystick2       ( 6'b110111       ),
    .service         ( 1'b0            ),
    .dip_test        ( 1'b0            ),
    .test_dip        ( 8'h02           ),
    .cpu_addr        ( cpu_addr        ),
    .cpu_dout        ( cpu_dout        ),
    .sharedram_we    ( sharedram_we    ),
    .videoram_we     ( videoram_we     ),
    .colorram_we     ( colorram_we     ),
    .spriteram0_we   ( spriteram0_we   ),
    .spriteram1_we   ( spriteram1_we   ),
    .row_scroll_we   ( row_scroll_we   ),
    .sharedram_dout  ( sharedram_dout  ),
    .videoram_dout   ( videoram_dout   ),
    .colorram_dout   ( colorram_dout   ),
    .spriteram0_dout ( spriteram0_dout ),
    .row_scroll_dout ( row_scroll_dout ),
    .rom_addr        ( rom_addr        ),
    .rom_cs          ( rom_cs          ),
    .rom_data        ( rom_data        ),
    .rom_ok          ( rom_ok          ),
    .ay_bdir         ( ay_bdir         ),
    .ay_bc1          ( ay_bc1          ),
    .ay_data         ( ay_data         ),
    .watchdog_clr    ( watchdog_clr    ),
    .debug_view      ( debug_view      )
);
jtseicro_snd snd(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .audio_cen ( audio_cen ),
    .bdir      ( ay_bdir   ),
    .bc1       ( ay_bc1    ),
    .cpu_dout  ( cpu_dout  ),
    .cpu_din   ( ay_data   ),
    .debug_dip ( 8'he0     ),
    .irq_en    ( irq_en    ),
    .flip      ( flip      ),
    .mcu_run   ( mcu_run   ),
    .psg       ( psg       ),
    .sample    ( sample    )
);

initial begin
    for(i=0;i<32768;i=i+1) rom[i]=0;
    for(i=0;i<2048;i=i+1) ram[i]=0;
    rom[0]=8'h31;
    rom[1]=8'hf0;
    rom[2]=8'h7f;
    rom[3]=8'hc3;
    rom[4]=8'h42;
    rom[5]=8'h00;
    rom[6]=8'h00;
    rom[7]=8'h00;
    rom[8]=8'h00;
    rom[9]=8'h00;
    rom[10]=8'h00;
    rom[11]=8'h00;
    rom[12]=8'h00;
    rom[13]=8'h00;
    rom[14]=8'h00;
    rom[15]=8'h00;
    rom[16]=8'h00;
    rom[17]=8'h00;
    rom[18]=8'h00;
    rom[19]=8'h00;
    rom[20]=8'h00;
    rom[21]=8'h00;
    rom[22]=8'h00;
    rom[23]=8'h00;
    rom[24]=8'h00;
    rom[25]=8'h00;
    rom[26]=8'h00;
    rom[27]=8'h00;
    rom[28]=8'h00;
    rom[29]=8'h00;
    rom[30]=8'h00;
    rom[31]=8'h00;
    rom[32]=8'h00;
    rom[33]=8'h00;
    rom[34]=8'h00;
    rom[35]=8'h00;
    rom[36]=8'h00;
    rom[37]=8'h00;
    rom[38]=8'h00;
    rom[39]=8'h00;
    rom[40]=8'h00;
    rom[41]=8'h00;
    rom[42]=8'h00;
    rom[43]=8'h00;
    rom[44]=8'h00;
    rom[45]=8'h00;
    rom[46]=8'h00;
    rom[47]=8'h00;
    rom[48]=8'h00;
    rom[49]=8'h00;
    rom[50]=8'h00;
    rom[51]=8'h00;
    rom[52]=8'h00;
    rom[53]=8'h00;
    rom[54]=8'h00;
    rom[55]=8'h00;
    rom[56]=8'hc3;
    rom[57]=8'h00;
    rom[58]=8'h01;
    rom[66]=8'h3e;
    rom[67]=8'ha5;
    rom[68]=8'h32;
    rom[69]=8'h00;
    rom[70]=8'h78;
    rom[71]=8'h3e;
    rom[72]=8'h00;
    rom[73]=8'h32;
    rom[74]=8'h06;
    rom[75]=8'h78;
    rom[76]=8'h3e;
    rom[77]=8'h11;
    rom[78]=8'h32;
    rom[79]=8'h20;
    rom[80]=8'h88;
    rom[81]=8'h3e;
    rom[82]=8'h22;
    rom[83]=8'h32;
    rom[84]=8'h7f;
    rom[85]=8'h88;
    rom[86]=8'h3e;
    rom[87]=8'h33;
    rom[88]=8'h32;
    rom[89]=8'h00;
    rom[90]=8'h90;
    rom[91]=8'h3e;
    rom[92]=8'h44;
    rom[93]=8'h32;
    rom[94]=8'hff;
    rom[95]=8'h93;
    rom[96]=8'h3e;
    rom[97]=8'h55;
    rom[98]=8'h32;
    rom[99]=8'h00;
    rom[100]=8'h98;
    rom[101]=8'h3e;
    rom[102]=8'h66;
    rom[103]=8'h32;
    rom[104]=8'h1f;
    rom[105]=8'h98;
    rom[106]=8'h3e;
    rom[107]=8'h77;
    rom[108]=8'h32;
    rom[109]=8'h80;
    rom[110]=8'h98;
    rom[111]=8'h3e;
    rom[112]=8'h88;
    rom[113]=8'h32;
    rom[114]=8'h9f;
    rom[115]=8'h98;
    rom[116]=8'h3e;
    rom[117]=8'h99;
    rom[118]=8'h32;
    rom[119]=8'h00;
    rom[120]=8'h9c;
    rom[121]=8'h3a;
    rom[122]=8'h00;
    rom[123]=8'ha0;
    rom[124]=8'h32;
    rom[125]=8'h01;
    rom[126]=8'h78;
    rom[127]=8'h3a;
    rom[128]=8'h00;
    rom[129]=8'ha8;
    rom[130]=8'h32;
    rom[131]=8'h02;
    rom[132]=8'h78;
    rom[133]=8'h3a;
    rom[134]=8'h00;
    rom[135]=8'hb0;
    rom[136]=8'h32;
    rom[137]=8'h03;
    rom[138]=8'h78;
    rom[139]=8'h3a;
    rom[140]=8'h80;
    rom[141]=8'h98;
    rom[142]=8'h32;
    rom[143]=8'h04;
    rom[144]=8'h78;
    rom[145]=8'h3a;
    rom[146]=8'h20;
    rom[147]=8'h9c;
    rom[148]=8'h32;
    rom[149]=8'h07;
    rom[150]=8'h78;
    rom[151]=8'h3e;
    rom[152]=8'h0f;
    rom[153]=8'hd3;
    rom[154]=8'h00;
    rom[155]=8'h3e;
    rom[156]=8'h03;
    rom[157]=8'hd3;
    rom[158]=8'h01;
    rom[159]=8'h3e;
    rom[160]=8'h07;
    rom[161]=8'hd3;
    rom[162]=8'h00;
    rom[163]=8'h3e;
    rom[164]=8'h80;
    rom[165]=8'hd3;
    rom[166]=8'h01;
    rom[167]=8'h3e;
    rom[168]=8'h0f;
    rom[169]=8'hd3;
    rom[170]=8'h00;
    rom[171]=8'h3e;
    rom[172]=8'h07;
    rom[173]=8'hd3;
    rom[174]=8'h01;
    rom[175]=8'h3e;
    rom[176]=8'h00;
    rom[177]=8'hdb;
    rom[178]=8'h0c;
    rom[179]=8'h32;
    rom[180]=8'h05;
    rom[181]=8'h78;
    rom[182]=8'hfb;
    rom[183]=8'h76;
    rom[184]=8'hc3;
    rom[185]=8'hb7;
    rom[186]=8'h00;
    rom[256]=8'h3a;
    rom[257]=8'h06;
    rom[258]=8'h78;
    rom[259]=8'h3c;
    rom[260]=8'h32;
    rom[261]=8'h06;
    rom[262]=8'h78;
    rom[263]=8'h3e;
    rom[264]=8'h0f;
    rom[265]=8'hd3;
    rom[266]=8'h00;
    rom[267]=8'h3e;
    rom[268]=8'h06;
    rom[269]=8'hd3;
    rom[270]=8'h01;
    rom[271]=8'h3e;
    rom[272]=8'h07;
    rom[273]=8'hd3;
    rom[274]=8'h01;
    rom[275]=8'hfb;
    rom[276]=8'hed;
    rom[277]=8'h4d;
    repeat(20) @(negedge clk);
    rst=0;
    wait(dut.u_cpu.u_z80_devwait.u_cpu.u_cpu.HALT_n===1'b0);
    repeat(16) @(negedge clk);
    if(ram[0]!==8'ha5 || ram[1]!==8'h68 || ram[2]!==8'h51 || ram[3]!==8'h03 ||
       ram[4]!==8'hff || ram[5]!==8'he7 || ram[7]!==8'h99)
        $fatal(1,"CPU/cab/AY/readback %h %h %h %h %h %h %h",ram[0],ram[1],ram[2],ram[3],ram[4],ram[5],ram[7]);
    if(obj0[0]!==8'h11 || obj0[95]!==8'h22 || vram[0]!==8'h33 || vram[1023]!==8'h44 ||
       scroll[0]!==8'h55 || scroll[31]!==8'h66 || obj1[0]!==8'h77 || obj1[31]!==8'h88)
        $fatal(1,"memory endpoint write failed");
    if(release_count!=1 || !mcu_run || !irq_en || !flip)
        $fatal(1,"AY GPIO direction/release failed count=%d",release_count);
    LVBL=0;
    wait(ram[6]==1);
    wait(!irq_en);
    repeat(2) @(negedge clk);
    if(dut.irq_pending) $fatal(1,"AY B0 low did not clear IRQ");
    wait(irq_en);
    wait(dut.u_cpu.u_z80_devwait.u_cpu.u_cpu.HALT_n===1'b0);
    repeat(1000) @(negedge clk);
    if(ram[6]!=1 || dut.irq_pending || irq_acks!=1) $fatal(1,"IRQ acknowledge failed");
    LVBL=1;
    repeat(16) @(negedge clk);
    LVBL=0;
    wait(ram[6]==2);
    wait(!irq_en);
    wait(irq_en);
    wait(dut.u_cpu.u_z80_devwait.u_cpu.u_cpu.HALT_n===1'b0);
    repeat(1000) @(negedge clk);
    if(ram[6]!=2 || dut.irq_pending || irq_acks!=2) $fatal(1,"IRQ rearm failed");
    $display("PASS Z80 program: stalled ROM, six RAMs, inputs, color alias, AY GPIO, held IRQ and software acknowledge/rearm");
    $finish;
end
initial begin #1000000; $fatal(1,"CPU timeout PC=%h",cpu_addr); end
endmodule
