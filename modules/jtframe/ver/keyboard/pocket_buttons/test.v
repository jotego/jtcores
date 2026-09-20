`timescale 1ns/1ps

module test;

wire rst, clk_sys;
reg clk_rom=0, clk_74a=0;
reg [31:2] sys_addr=0;
reg [31:0] sys_dout=0;
reg sys_wr=0;
wire [23:0] map_rom, button_map;
reg [15:0] cont1=0, cont2=0, cont3=0, cont4=0;
wire [15:0] joy1, joy2, joy3, joy4, ana_l1, ana_r1;
reg [31:0] analog1=32'hff008180;
reg [31:0] analog_zero=32'h80808080;
reg [3:0] analog_en=4'b0001;
integer bit_index;
reg [15:0] expected;

`include "test_tasks.vh"

always #7 clk_rom=~clk_rom;
always #6.734 clk_74a=~clk_74a;

initial begin
    @(posedge rst);
    @(negedge rst);
    repeat(8) @(negedge clk_sys);
    assert_msg(button_map===24'h543210,"reset must select identity map");
    for(bit_index=0; bit_index<16; bit_index=bit_index+1) begin
        drive(16'h1<<bit_index,16'h1<<bit_index,16'h1<<bit_index,16'h1<<bit_index);
        expected = bit_index<4 ? 16'h1<<(3-bit_index) :
                   bit_index<14 ? 16'h1<<bit_index : 16'd0;
        check(expected,expected,expected,expected);
    end
    assert_msg(ana_l1===16'h0100 && ana_r1===16'h7f80,"analogue conversion changed");
    write_mmr(32'hfc000000,32'h00fff023);
    assert_msg(button_map===24'hfff023,"button map register write failed");
    drive(16'h0080,16'h0040,16'h0010,16'h0020);
    check(16'h0010,16'h0020,16'h0040,16'h0000);
    drive(16'h031f,16'h038f,16'h034f,16'h03ff);
    check(16'h004f,16'h001f,16'h002f,16'h007f);
    write_mmr(32'hfa000000,32'hffffffff);
    assert_msg(button_map===24'hfff023,"DIP write altered button map");
    write_mmr(32'hfc000000,32'h00ff5413);
    drive(16'h0100,16'h0200,16'h0080,16'h0020);
    check(16'h0040,16'h0080,16'h0010,16'h0020);
    write_mmr(32'hfc000000,32'h00fff0f3);
    drive(16'h0080,16'h0010,16'h0040,16'h03f0);
    check(16'h0010,16'h0040,16'h0000,16'h0050);
    write_mmr(32'hfc000000,32'h00543210);
    drive(16'h03f0,16'h0080,16'h0010,16'h3c0f);
    check(16'h03f0,16'h0080,16'h0010,16'h3c0f);
    pass();
end

task drive(input [15:0] a,b,c,d);
begin
    @(negedge clk_sys);
    cont1=a; cont2=b; cont3=c; cont4=d;
    repeat(3) @(negedge clk_sys);
end
endtask

task check(input [15:0] a,b,c,d);
begin
    if(joy1!==a || joy2!==b || joy3!==c || joy4!==d) begin
        $display("expected %h %h %h %h, got %h %h %h %h",a,b,c,d,joy1,joy2,joy3,joy4);
        fail();
    end
end
endtask

task write_mmr(input [31:0] address, data);
begin
    @(negedge clk_74a);
    sys_addr=address[31:2]; sys_dout=data; sys_wr=1;
    repeat(8) @(negedge clk_74a);
    sys_wr=0;
    repeat(8) @(negedge clk_sys);
end
endtask

jtframe_test_clocks clocks(
    .rst        ( rst       ),
    .clk        ( clk_sys   ),
    .pxl_cen    (           ),
    .lhbl       (           ),
    .lvbl       (           ),
    .hs         (           ),
    .vs         (           ),
    .h          (           ),
    .v          (           ),
    .framecnt   (           )
);

jtframe_pocket_cfg uut_cfg(
    .rst_rom    ( rst       ),
    .clk_rom    ( clk_rom   ),
    .clk_74a    ( clk_74a   ),
    .sys_addr   ( sys_addr  ),
    .sys_dout   ( sys_dout  ),
    .sys_wr     ( sys_wr    ),
    .dipsw      (           ),
    .dipsw_rst  (           ),
    .core_mod   (           ),
    .button_map ( map_rom   ),
    .game_vol   (           ),
    .status     (           )
);

jtframe_sync #(.W(24)) u_sync(
    .clk_in     ( clk_rom    ),
    .clk_out    ( clk_sys    ),
    .raw        ( map_rom    ),
    .sync       ( button_map )
);

jtframe_pocket_joystick uut(
    .clk_sys    ( clk_sys     ),
    .button_map ( button_map  ),
    .cont1      ( cont1       ),
    .cont2      ( cont2       ),
    .cont3      ( cont3       ),
    .cont4      ( cont4       ),
    .cont1_joy  ( analog1     ),
    .cont2_joy  ( analog_zero ),
    .cont3_joy  ( analog_zero ),
    .cont4_joy  ( analog_zero ),
    .analog_en  ( analog_en   ),
    .joystick1  ( joy1        ),
    .joystick2  ( joy2        ),
    .joystick3  ( joy3        ),
    .joystick4  ( joy4        ),
    .joyana_l1  ( ana_l1      ),
    .joyana_l2  (             ),
    .joyana_l3  (             ),
    .joyana_l4  (             ),
    .joyana_r1  ( ana_r1      ),
    .joyana_r2  (             ),
    .joyana_r3  (             ),
    .joyana_r4  (             )
);

endmodule
