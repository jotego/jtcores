/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module test;

`include "test_tasks.vh"
reg clk=0, rst=1, lvbl=0;
reg [15:0] stick1=0, stick2=0;
reg [23:1] bus_addr=0;
integer axis, sample;
reg [15:0] stimulus;
reg expected;

always #5 clk=~clk;

jtcps1_main uut(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .turbo       ( 1'b0         ),
    .V           ( 9'd0         ),
    .LVBL        ( lvbl         ),
    .LHBL        ( 1'b1         ),
    .mmr_dout    ( 16'd0        ),
    .joymode     ( 2'd0         ),
    .charger     ( 1'b0         ),
    .joystick1   ( 10'h3ff      ),
    .joystick2   ( 10'h3ff      ),
    .dial_x      ( 2'd0         ),
    .dial_y      ( 2'd0         ),
    .joyana_r1   ( stick1       ),
    .joyana_r2   ( stick2       ),
    .cab_1p      ( 2'b11        ),
    .coin        ( 2'b11        ),
    .service     ( 1'b1         ),
    .tilt        ( 1'b1         ),
    .busreq      ( 1'b0         ),
    .ram_data    ( 16'd0        ),
    .ram_ok      ( 1'b1         ),
    .rom_data    ( 16'd0        ),
    .rom_ok      ( 1'b1         ),
    .dip_pause   ( 1'b1         ),
    .dip_test    ( 1'b1         ),
    .dipsw_a     ( 8'hff        ),
    .dipsw_b     ( 8'hff        ),
    .dipsw_c     ( 8'hff        )
);

task ticks;
    repeat(5) @(negedge clk);
endtask

task reset_mode;
    rst=1;
    ticks;
    rst=0;
    ticks;
endtask

task frame;
    lvbl=0;
    ticks;
    lvbl=1;
    ticks;
endtask

task read_mode(input [23:0] address, input [15:0] value);
    bus_addr=address[23:1];
    ticks;
    assert_msg(uut.sys_data === value, $sformatf("register %x: got %x, expected %x", address, uut.sys_data, value));
endtask

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    // Exercise the actual I/O decoder with the CPU bus held in a read cycle.
    force uut.A=bus_addr;
    force uut.ASn=0;
    force uut.BGACKn=1;
    force uut.RnW=1;
    ticks;
    reset_mode;
    read_mode(24'h800064,16'h4a54);
    read_mode(24'h800066,16'h4a54);
    // Every signed byte on each axis/player, including both dead-zone edges.
    for(axis=0; axis<4; axis=axis+1) begin
        for(sample=0; sample<256; sample=sample+1) begin
            stick1=0;
            stick2=0;
            reset_mode;
            stimulus=axis%2==0 ? {8'd0,sample[7:0]} : {sample[7:0],8'd0};
            if(axis<2) stick1=stimulus;
            else       stick2=stimulus;
            ticks;
            assert_msg(uut.aim_enable === 2'b00,"activation must wait for frame sample");
            frame;
            expected=sample>=24 && sample<=232;
            read_mode(24'h800064, {15'h252a,axis<2 && expected});
            read_mode(24'h800066, {15'h252a,axis>=2 && expected});
            if(axis<2) read_mode(24'h800060,stimulus);
            else       read_mode(24'h800062,stimulus);
            stick1=0;
            stick2=0;
            frame;
            read_mode(24'h800064, {15'h252a,axis<2 && expected});
            read_mode(24'h800066, {15'h252a,axis>=2 && expected});
        end
    end
    stick1=16'h0018;
    stick2=16'he800;
    frame;
    read_mode(24'h800064,16'h4a55);
    read_mode(24'h800066,16'h4a55);
    reset_mode;
    read_mode(24'h800064,16'h4a54);
    read_mode(24'h800066,16'h4a54);
    pass();
end

initial begin
    #2000000;
    fail();
end

endmodule
