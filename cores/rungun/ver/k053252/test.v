`timescale 1ns/1ps

module test;

reg rst, clk; // 32 MHz
wire      nc, pxl_cen, hs, vs, lvbl, lhbl, rdy, timer_rst;
integer   download_hs, download_vs, download_lvbl_up, download_lvbl_dn,
          cab_hs, cab_vs, cab_lvbl_up, cab_lvbl_dn;
reg       cs, rnw, prog_done, first=0, download_done=0, cab_arm=0;
reg [3:0] addr;
reg [7:0] din;

`include "test_tasks.vh"



initial begin
    clk=0;
    forever #15.625 clk=~clk;   // 32 MHz
end

initial begin
    rst=0;
    download_hs=0;
    download_vs=0;
    download_lvbl_up=0;
    download_lvbl_dn=0;
    cab_hs=0;
    cab_vs=0;
    cab_lvbl_up=0;
    cab_lvbl_dn=0;
    #10 rst=1;
    #1;
    assert_msg(timer_rst,"timer must reset at the start of each held reset");
    repeat (2) @(negedge clk);
    assert_msg(!timer_rst,"timer reset must be one clock wide");
    repeat (512*600) @(negedge pxl_cen);
    assert_msg(download_hs>100,"HS must run during download reset");
    assert_msg(download_vs>0,"VS must run during download reset");
    assert_msg(download_lvbl_up>0,"LVBL active boundary must run during download reset");
    assert_msg(download_lvbl_dn>0,"LVBL blank boundary must run during download reset");
    rst=0;
    repeat (2) @(negedge clk);
    assert_msg(!timer_rst,"timer reset must clear after game reset drops");
    cab_arm=1;
    rst=1;
    #1;
    assert_msg(timer_rst,"CAB arm must reset the timer for one clock");
    repeat (2) @(negedge clk);
    assert_msg(!timer_rst,"CAB arm reset must also be one clock wide");
    repeat (512*600) @(negedge pxl_cen);
    assert_msg(cab_hs>100,"HS must run during CAB arm reset");
    assert_msg(cab_vs>0,"VS must run during CAB arm reset");
    assert_msg(cab_lvbl_up>0,"LVBL active boundary must run during CAB arm reset");
    assert_msg(cab_lvbl_dn>0,"LVBL blank boundary must run during CAB arm reset");
    rst=0;
    download_done=1;
end

assign rdy = prog_done & first;

always @(posedge hs) if(rst && !cab_arm) download_hs <= download_hs+1;
always @(posedge vs) if(rst && !cab_arm) download_vs <= download_vs+1;
always @(posedge lvbl) if(rst && !cab_arm) download_lvbl_up <= download_lvbl_up+1;
always @(negedge lvbl) if(rst && !cab_arm) download_lvbl_dn <= download_lvbl_dn+1;
always @(posedge hs) if(rst && cab_arm) cab_hs <= cab_hs+1;
always @(posedge vs) if(rst && cab_arm) cab_vs <= cab_vs+1;
always @(posedge lvbl) if(rst && cab_arm) cab_lvbl_up <= cab_lvbl_up+1;
always @(negedge lvbl) if(rst && cab_arm) cab_lvbl_dn <= cab_lvbl_dn+1;

task write_all(input [127:0] cfg);
    for(integer k=0;k<16;k=k+1) write(k,cfg[(15-k)*8+:8]);
endtask

task write(input [3:0]a, input [7:0] d);
    addr = a;
    rnw  = 0;
    cs   = 1;
    din  = d;
    repeat(4) @(negedge clk);
    rnw  = 1;
    cs   = 0;
    repeat(4) @(negedge clk);
endtask    

initial begin
    prog_done = 0;
    repeat (100) @(negedge clk);
    wait(download_done);
    write_all(128'h01_FF_00_21_00_37_01_00_01_20_0C_0E_54_00_00_00);
    prog_done = 1;
    repeat (512*256*6) @(negedge pxl_cen);
    pass();
end

always @(posedge clk) if(pxl_cen & rdy) begin
    assert_msg( !vs || !lvbl,"vs cannot be high if lvbl is high too");
    assert_msg( !hs || !lhbl,"hs cannot be high if lhbl is high too");
end

always @(negedge lvbl) if(prog_done) begin
    first <= 1;
end

always @(posedge lvbl) if(rdy) begin
    assert_msg(uut.vcnt==9'hf8,"lvbl at unexpected time");
end

reg lvbl_l;
reg [8:0] lines;

always @(posedge hs) begin
    if(!rdy) begin
        lines  <= 0;
        lvbl_l <= 0;
    end else begin
        lvbl_l <= lvbl;
        lines  <= lines + 1;
        if(!lvbl && lvbl_l) begin
            lines <= 1;
            if(lines!=0) assert_msg(lines==9'd289,"Must have 289 lines");
        end
    end
end

jtk053252 uut(
    .rst        ( rst       ),
    .timer_rst  ( timer_rst ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .sel        ( 3'd0      ),

    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .din        ( din       ),
    .dout       (           ),

    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lhbl       ( lhbl      ),
    // IOCTL dump
    .ioctl_addr (           ),
    .ioctl_din  (           )
);

jtrungun_timer_rst u_timer_rst(
    .clk       ( clk       ),
    .rst       ( rst       ),
    .timer_rst ( timer_rst )
);

// Furrtek's model for the chip. Use as reference
k053252 u_ref(
    .PIN_RESET  ( ~rst              ),
    .PIN_CLK    ( clk               ),
    .PIN_SEL    ( 3'd0              ),
    .PIN_CCS    ( ~cs               ),
    .PIN_RW     ( rnw               ),
    .PIN_AB     ( addr              ),
    .PIN_DB_IN  ( din               ),
    .PIN_HLD1   ( 1'b1              ),
    .PIN_VLD1   ( 1'b1              )
);

jtframe_frac_cen #(2,3) u_frac_cen(
    .clk    ( clk       ),
    .n      ( 3'd1      ),
    .m      ( 3'd4      ),
    .cen    ( {nc,pxl_cen} ),
    .cenb   (           )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
