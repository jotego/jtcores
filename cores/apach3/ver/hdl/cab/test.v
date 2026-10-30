/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, lvbl=1;
always #5 clk=~clk;
reg [6:0] joystick=7'h7f;
reg [15:0] joyana_l=0, joyana_r=0;
reg digital=0, invert_y=0, throttle_y=0;
reg test_n=1, service_n=1, start_n=1;
reg [1:0] coin_n=3;
wire [7:0] in0, stick_x, stick_y, throttle;
integer i;

jtapach3_cab dut (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .LVBL       ( lvbl       ),
    .joystick   ( joystick   ),
    .joyana_l   ( joyana_l   ),
    .joyana_r   ( joyana_r   ),
    .digital    ( digital    ),
    .invert_y   ( invert_y   ),
    .throttle_y ( throttle_y ),
    .test_n     ( test_n     ),
    .service_n  ( service_n  ),
    .coin_n     ( coin_n     ),
    .start_n    ( start_n    ),
    .in0        ( in0        ),
    .stick_x    ( stick_x    ),
    .stick_y    ( stick_y    ),
    .throttle   ( throttle   )
);

task frame;
    begin
        @(negedge clk); lvbl=1;
        repeat (3) @(negedge clk);
        lvbl=0;
        repeat (3) @(negedge clk);
    end
endtask

initial begin
    repeat (4) @(negedge clk);
    rst=0;
    for (i=0;i<256;i=i+1) begin
        {joystick[5],start_n,service_n,coin_n,joystick[6],joystick[4],test_n}=i;
        #1;
        if (in0 !== i[7:0]) $fatal(1,"cabinet digital map %h",i);
        joyana_l={i[7:0],~i[7:0]};
        joyana_r={~i[7:0],i[7:0]};
        #1;
        if (stick_x !== (~i[7:0]^8'h80) || stick_y !== (i[7:0]^8'h80)) $fatal(1,"analog stick %h",i);
        if (throttle !== (i[7:0]^8'h80)) $fatal(1,"throttle X %h",i);
        invert_y=1; throttle_y=1; #1;
        if (stick_y !== (~i[7:0]^8'h80) || throttle !== (~i[7:0]^8'h80)) $fatal(1,"axis options %h",i);
        invert_y=0; throttle_y=0;
    end
    @(negedge clk); joystick=7'h7f; digital=1;
    frame();
    if (stick_x!==127 || stick_y!==127) $fatal(1,"digital centre");
    joystick[0]=0; joystick[3]=0;
    frame();
    if (stick_x!==142 || stick_y!==112) $fatal(1,"digital step");
    repeat (20) frame();
    if (stick_x!==255 || stick_y!==0) $fatal(1,"digital saturation");
    joystick[1]=0; joystick[2]=0;
    repeat (20) frame();
    if (stick_x!==127 || stick_y!==127) $fatal(1,"opposite directions centre");
    joystick=7'h7f; joystick[1]=0; joystick[2]=0;
    repeat (20) frame();
    if (stick_x!==0 || stick_y!==255) $fatal(1,"reverse saturation");
    joystick=7'h7f;
    repeat (20) frame();
    if (stick_x!==127 || stick_y!==127) $fatal(1,"spring return");
    joystick[0]=0;
    frame();
    repeat (20) @(negedge clk);
    if (stick_x!==142) $fatal(1,"multiple updates in one blank");
    rst=1;
    repeat (3) @(negedge clk);
    if (stick_x!==127 || stick_y!==127) $fatal(1,"reset centre");
    $display("PASS cabinet map, analog endpoints, OSD axes, digital ramp, saturation and spring return");
    $finish;
end

initial begin
    #100000;
    $fatal(1,"cabinet test timed out");
end
endmodule
