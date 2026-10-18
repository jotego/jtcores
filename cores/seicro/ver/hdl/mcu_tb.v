// Author: Andrea Bogazzi
module mcu_tb;
reg rst=1, clk=0, run=0, reset_req=0, dip_pause=1;
reg [5:0] cnt=0;
wire cen=cnt[3:0]==0;
wire [14:0] rom_addr;
wire rom_cs, shared_we;
wire [10:0] shared_addr;
wire [7:0] shared_din,debug_view;
reg [7:0] rom_data, shared_dout;
reg [7:0] rom[0:32767], ram[0:2047];
wire rom_ok=cnt>=8;
wire [3:0] dac;
wire [7:0] nvram_addr, nvram_din;
wire nvram_we;
integer i,steps=0;
always #5 clk=~clk;
always @(posedge clk) begin
    cnt<=cnt+6'd1;
    rom_data<=rom[rom_addr];
    shared_dout<=ram[shared_addr];
    if(shared_we) ram[shared_addr]<=shared_din;
    if(dut.step && !dut.core_rst) steps<=steps+1;
end
jtseicro_mcu dut(
    .*,
    .nsc8105    ( 1'b0       ),
    .nvram_en   ( 1'b0       ),
    .nvram_dout ( 8'hff      ),
    .dipsw      ( 24'hfae3f5 )
);
initial begin
    for(i=0;i<32768;i=i+1) rom[i]=8'h01;
    for(i=0;i<2048;i=i+1) ram[i]=0;
    ram[2046]=8'h80;
    ram[2047]=0;
    rom[0]=8'h8e;
    rom[1]=8'h00;
    rom[2]=8'h7f;
    rom[3]=8'h86;
    rom[4]=8'h5a;
    rom[5]=8'h97;
    rom[6]=8'h20;
    rom[7]=8'h96;
    rom[8]=8'h20;
    rom[9]=8'hb7;
    rom[10]=8'hf8;
    rom[11]=8'h00;
    rom[12]=8'hb6;
    rom[13]=8'h10;
    rom[14]=8'h03;
    rom[15]=8'hb7;
    rom[16]=8'hf8;
    rom[17]=8'h01;
    rom[18]=8'hb6;
    rom[19]=8'h10;
    rom[20]=8'h05;
    rom[21]=8'hb7;
    rom[22]=8'hf8;
    rom[23]=8'h02;
    rom[24]=8'hb6;
    rom[25]=8'h10;
    rom[26]=8'h06;
    rom[27]=8'hb7;
    rom[28]=8'hf8;
    rom[29]=8'h03;
    rom[30]=8'h86;
    rom[31]=8'ha0;
    rom[32]=8'hb7;
    rom[33]=8'h20;
    rom[34]=8'h00;
    rom[35]=8'hce;
    rom[36]=8'h10;
    rom[37]=8'h00;
    rom[38]=8'h0d;
    rom[39]=8'h8c;
    rom[40]=8'h10;
    rom[41]=8'h01;
    rom[42]=8'h07;
    rom[43]=8'hb7;
    rom[44]=8'hf8;
    rom[45]=8'h04;
    rom[46]=8'hce;
    rom[47]=8'h80;
    rom[48]=8'h00;
    rom[49]=8'h0c;
    rom[50]=8'h8c;
    rom[51]=8'h01;
    rom[52]=8'hff;
    rom[53]=8'h07;
    rom[54]=8'hb7;
    rom[55]=8'hf8;
    rom[56]=8'h05;
    rom[57]=8'h86;
    rom[58]=8'hc3;
    rom[59]=8'hb7;
    rom[60]=8'hf8;
    rom[61]=8'h06;
    rom[62]=8'h20;
    rom[63]=8'hfe;
    repeat(20) @(negedge clk); rst=0;
    repeat(100) @(negedge clk);
    if(steps || shared_we || rom_cs) $fatal(1,"MCU ran before AY release");
    run=1;
    wait(ram[6]==8'hc3);
    if(ram[0]!==8'h5a || ram[1]!==5 || ram[2]!==3 || ram[3]!==10 || dac!==10)
        $fatal(1,"MCU buses/DIPs/DAC failed %h %h %h %h %h",ram[0],ram[1],ram[2],ram[3],dac);
    if((ram[4]&8'h0f)!==1 || (ram[5]&8'h0f)!==2)
        $fatal(1,"M6802 CPX flags incorrect %h %h",ram[4],ram[5]);
    dip_pause=0;
    i=steps;
    repeat(100) @(negedge clk);
    if(steps!=i) $fatal(1,"MCU pause failed");
    dip_pause=1;
    reset_req=1;
    @(negedge clk); reset_req=0;
    repeat(100) @(negedge clk);
    if(dac!==0) $fatal(1,"MCU reset failed");
    $display("PASS M6802: reset vector, internal/shared RAM, DIPs, DAC, ROM stalls, CPX, pause/reset");
    $finish;
end
initial begin #1000000; $fatal(1,"MCU timeout addr=%h",dut.addr);end
endmodule
