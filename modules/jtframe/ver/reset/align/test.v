`timescale 1ns/1ps

// jtframe_reset must release game_rst on a fixed clk24 phase, whatever the
// length of the reset request. uut48 models clk_rom=48 MHz (clk24 = clk_rom/2),
// uut96 models clk_rom=96 MHz (clk24 = clk_rom/4). uut_noclk has no clk24 and
// must still leave reset. uut_rfsh must also wait for rfsh_safe, which models
// the second half of the SDRAM refresh period.
module test;

`include "test_tasks.vh"

reg clk=0, pll_locked=0, rst_req=1;
reg [1:0] div=0;
reg ph48=0, ph96=0;
wire game_rst48, game_rst96, game_rst_nc, game_rst_rf, rst;
reg  [5:0] rfsh_cnt=0;
wire rfsh_safe = rfsh_cnt[5];
integer k, ph48_ref=-1, ph96_ref=-1, released=0;

always #5.2 clk=~clk;

always @(posedge clk) begin
    div  <= div+1'd1;
    if( div[0] ) ph48 <= ~ph48; // clk24 rising edge every two clk_rom cycles
    if( div==3 ) ph96 <= ~ph96; // and every four
    rfsh_cnt <= rfsh_cnt+1'd1;
end


always @(negedge game_rst48) begin
    if( ph48_ref<0 ) ph48_ref = div[0];
    assert_msg( div[0]==ph48_ref, "clk_rom=48 MHz: game_rst released on a different clk24 phase" );
end
always @(negedge game_rst_rf) begin
    assert_msg( rfsh_safe, "game_rst released while a refresh could be pending" );
    assert_msg( div==ph96_ref || ph96_ref<0, "rfsh_safe: game_rst released on a different clk24 phase" );
end
always @(negedge game_rst96) begin
    if( ph96_ref<0 ) ph96_ref = div;
    assert_msg( div==ph96_ref, "clk_rom=96 MHz: game_rst released on a different clk24 phase" );
    released = released+1;
end

initial begin
    repeat(4) @(posedge clk); pll_locked = 1;
    for( k=0; k<24; k=k+1 ) begin
        rst_req = 1;
        wait( game_rst48 && game_rst96 && game_rst_nc && game_rst_rf );
        repeat( $urandom%17 ) @(posedge clk);
        #($urandom%10);
        rst_req = 0;
        wait( !game_rst48 && !game_rst96 && !game_rst_nc && !game_rst_rf );
        repeat( 5+($urandom%11) ) @(posedge clk);
    end
    if( released!=24 ) $display("%0d releases",released);
    assert_msg( released==24, "missing releases" );
    pass();
end

initial begin
    #100000;
    fail();
end

jtframe_reset uut48(
    .clk_sys    ( clk       ),
    .clk_rom    ( clk       ),
    .pxl_cen    ( 1'b1      ),
    .sdram_init ( 1'b0      ),
    .ioctl_rom  ( 1'b0      ),
    .dip_flip   ( 1'b0      ),
    .soft_rst   ( 1'b0      ),
    .rst_req    ( rst_req   ),
    .pll_locked ( pll_locked),
    .ph24       ( ph48      ),
    .rfsh_safe  ( 1'b1      ),
    .rst        ( rst       ),
    .rst_n      (           ),
    .game_rst   ( game_rst48),
    .game_rst_n (           )
);

jtframe_reset uut96(
    .clk_sys    ( clk       ),
    .clk_rom    ( clk       ),
    .pxl_cen    ( 1'b1      ),
    .sdram_init ( 1'b0      ),
    .ioctl_rom  ( 1'b0      ),
    .dip_flip   ( 1'b0      ),
    .soft_rst   ( 1'b0      ),
    .rst_req    ( rst_req   ),
    .pll_locked ( pll_locked),
    .ph24       ( ph96      ),
    .rfsh_safe  ( 1'b1      ),
    .rst        (           ),
    .rst_n      (           ),
    .game_rst   ( game_rst96),
    .game_rst_n (           )
);

jtframe_reset uut_noclk(
    .clk_sys    ( clk       ),
    .clk_rom    ( clk       ),
    .pxl_cen    ( 1'b1      ),
    .sdram_init ( 1'b0      ),
    .ioctl_rom  ( 1'b0      ),
    .dip_flip   ( 1'b0      ),
    .soft_rst   ( 1'b0      ),
    .rst_req    ( rst_req   ),
    .pll_locked ( pll_locked),
    .ph24       ( 1'b0      ),
    .rfsh_safe  ( 1'b1      ),
    .rst        (           ),
    .rst_n      (           ),
    .game_rst   ( game_rst_nc),
    .game_rst_n (           )
);

jtframe_reset uut_rfsh(
    .clk_sys    ( clk       ),
    .clk_rom    ( clk       ),
    .pxl_cen    ( 1'b1      ),
    .sdram_init ( 1'b0      ),
    .ioctl_rom  ( 1'b0      ),
    .dip_flip   ( 1'b0      ),
    .soft_rst   ( 1'b0      ),
    .rst_req    ( rst_req   ),
    .pll_locked ( pll_locked),
    .ph24       ( ph96      ),
    .rfsh_safe  ( rfsh_safe ),
    .rst        (           ),
    .rst_n      (           ),
    .game_rst   ( game_rst_rf),
    .game_rst_n (           )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
