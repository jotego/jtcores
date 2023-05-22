`timescale 1ns/1ps
module test;

reg               rst, clk, r_wn, mr_wn, ma0, cs, mcs, cen=0;
reg         [5:0] addr;
reg         [7:0] din;
reg         [7:0] mdin;
wire        [7:0] mdout;

reg         [7:0]  rom[0:2**19-1];
wire        [7:0]  rom_data;
wire        [20:0] rom_addr;
wire               rom_cs;
reg                rom_ok;

integer k;

initial begin
    clk=0;
    forever #(140.05) clk=~clk;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

integer f, fcnt;
initial begin
    f=$fopen("roms/081a03","rb");
    fcnt=$fread(rom, f);
    $display("Read %d bytes for PCM rom",fcnt);
    $fclose(f);
end

assign rom_data = rom[ rom_addr[18:0] ];

always @(posedge clk) cen <= ~cen;

initial begin
    rst  = 0;
    cs   = 0;
    mcs  = 0;
    din  = 0;
    mdin = 0;
    addr = 0;
    ma0  = 0;
    rom_ok = 0;
    r_wn = 1;
    mr_wn = 1;
    #10 rst=1;
    #10 rst=0;
    repeat (64) @(posedge clk);

    // @(posedge clk);
    // cs=1;
    // r_wn=0;
    // addr=2;
    for(k=0;k<40;k=k+1) begin
        @(posedge clk);
        addr = k;
        din  = din+6;
        mdin  = mdin+6;
        cs   = 1;
        r_wn  = 0;
    end
    @(posedge clk);
    cs=1;
    mcs=1;
    r_wn=0;
    mr_wn=0;
    rom_ok = 1;
    addr=2;
    mdin=8'h06;
    @(posedge clk);
    addr=03;
    mdin=8'h0F;
    // ch pan
    @(posedge clk);
    addr=6'h2C;
    din=8'h02;
    @(posedge clk);
    addr=6'h2D;
    din=8'h04;
    @(posedge clk);
    addr=6'h2D;
    din=8'h08;
    // mode
    @(posedge clk);
    addr=6'h2F;
    din=8'h03;
    @(posedge clk);
    addr=6'h2A;
    din=8'h00;
    @(posedge clk);
    addr=6'h03;
    din=8'h02;
    @(posedge clk);
    addr=6'h28;
    din=8'h08;

    repeat (200000) begin
       @(posedge clk);
       r_wn = 0;
       cs = 1;
    end

    $finish;
end

watcher u_watcher();

jt053260 uut(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen       ( cen       ),
    .addr      ( addr      ),
    .ma0       ( ma0       ),
    .mr_wn     ( mr_wn     ),
    .mcs       ( mcs       ),
    .r_wn      ( r_wn      ),
    .cs        ( cs        ),
    .din       ( din       ),
    .mdin      ( mdin      ),
    .mdout     ( mdout     ),
    .rom_data  ( rom_data  ),
    .rom_addr  ( rom_addr  ),
    .rom_cs    ( rom_cs    ),
    .rom_ok    ( rom_ok    )
    // .romc_cs   ( romc_cs   ),
    // .romd_cs   ( romd_cs   )
    // .snd_l     ( snd_l     ),
    // .snd_r     ( snd_r     ),
    // .sample    ( sample    )
);

endmodule

module watcher;
    wire [20:0] addr0 = uut.cur_addr[0],
                addr1 = uut.cur_addr[1],
                addr2 = uut.cur_addr[2],
                addr3 = uut.cur_addr[3];
    wire [ 9:0] snd0  = uut.cur_snd[0],
                snd1  = uut.cur_snd[1],
                snd2  = uut.cur_snd[2],
                snd3  = uut.cur_snd[3];
    wire [16:0] cnt0  = uut.cur_cnt[0],
                cnt1  = uut.cur_cnt[1],
                cnt2  = uut.cur_cnt[2],
                cnt3  = uut.cur_cnt[3];
    wire [16:0] port0 = uut.portdata[0],
                port1 = uut.portdata[1],
                port2 = uut.portdata[2],
                port3 = uut.portdata[3];
endmodule
