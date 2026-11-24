`timescale 1ns/1ps

// game_rst stays high until a first download ends. A later dwnld_busy pulse
// without ioctl_rom (cartridge load) does not reset the game.
module test;

`include "test_tasks.vh"

reg  clk=0, pll_locked=0, dwnld_busy=0, ioctl_rom=0;
wire rst, rst_n, game_rst, game_rst_n;
integer k;

always #10 clk=~clk;

task wait_clks(input integer n); repeat(n) @(posedge clk); endtask

initial begin
    wait_clks(4); pll_locked=1;
    wait_clks(2000);
    assert_msg( !rst, "framework reset did not end" );
    assert_msg( game_rst && !game_rst_n, "game left reset before any download" );
    // ROM download
    ioctl_rom=1; dwnld_busy=1; wait_clks(50);
    ioctl_rom=0; wait_clks(5); dwnld_busy=0;
    for( k=0; k<200 && game_rst; k=k+1 ) wait_clks(1);
    assert_msg( !game_rst && game_rst_n, "game reset not released after the first download" );
    // cartridge download: dwnld_busy alone
    dwnld_busy=1; wait_clks(50); dwnld_busy=0;
    for( k=0; k<200; k=k+1 ) begin
        wait_clks(1);
        assert_msg( !game_rst, "a cartridge load reset the game" );
    end
    // a new ROM download resets the game again
    ioctl_rom=1; dwnld_busy=1; wait_clks(10);
    assert_msg( game_rst, "a ROM download did not reset the game" );
    pass();
end

jtframe_reset uut(
    .clk_sys    ( clk       ),
    .clk_rom    ( clk       ),
    .pxl_cen    ( 1'b1      ),
    .sdram_init ( 1'b0      ),
    .ioctl_rom  ( ioctl_rom ),
    .dwnld_busy ( dwnld_busy),
    .dip_flip   ( 1'b0      ),
    .soft_rst   ( 1'b0      ),
    .rst_req    ( 1'b0      ),
    .pll_locked ( pll_locked),
    .rst        ( rst       ),
    .rst_n      ( rst_n     ),
    .game_rst   ( game_rst  ),
    .game_rst_n ( game_rst_n)
);

endmodule
