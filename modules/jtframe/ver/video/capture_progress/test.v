/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0,rst=1,game_reset=0,lvbl=0,irq_level=0,irq_taken_toggle=0;
reg feedback_valid=1,contract_valid=1,pause_request=0,step=0;
wire tick,pause_gate,effective,lost,step_done,step_failed;
wire [63:0] epoch,raster_frame,game_frame,irq_count,irq_generation,raster_now,game_now,irq_now;
wire [31:0] raster_period;
reg [63:0] before_game,before_raster;
always #5 clk=~clk;
`include "test_tasks.vh"
task clocks(input integer n); begin repeat(n) @(negedge clk); end endtask
task frame; begin lvbl=0;clocks(6);lvbl=1;clocks(6);lvbl=0;clocks(6);end endtask
initial begin
    $dumpfile("test.lxt");$dumpvars;
    clocks(8);rst=0;clocks(5);
    frame();frame();assert_msg(game_frame==2 && raster_frame==2,"normal raster-based time");
    // Request expiry, masked boot and IRQ silence are never acceptance evidence.
    irq_level=1;clocks(8);irq_level=0;clocks(8);
    assert_msg(irq_count==0,"request deassertion is not interrupt acceptance");
    pause_request=1;frame();frame();
    assert_msg(!effective && game_frame==4,"masked boot continues logical time");
    irq_level=1;irq_taken_toggle=1;clocks(20);
    assert_msg(irq_count==1 && !effective,"stretched ACK counts once; pending IRQ prevents pause");
    irq_level=0;clocks(15);
    assert_msg(effective,"recent VBL acceptance and settling confirm pause");
    before_game=game_frame;before_raster=raster_frame;
    frame();frame();frame();frame();
    assert_msg(game_frame==before_game && raster_frame==before_raster+4,"long pause retains service evidence and CAB time");
    // A step releases one logical interval and can accept a fresh VBL.
    step=1;clocks(1);step=0;frame();
    irq_taken_toggle=0;clocks(8);frame();clocks(15);
    assert_msg(effective && game_frame==before_game+1,"single step advances exactly once");
    irq_level=1;clocks(5);
    assert_msg(!effective,"unexpected pending IRQ releases confirmed hold");
    before_game=game_frame;frame();
    assert_msg(game_frame==before_game+1,"time resumes after pause failure");
    pause_request=0;irq_level=0;frame();frame();frame();
    pause_request=1;clocks(20);
    assert_msg(!effective,"old acceptance cannot confirm a later masked phase");
    irq_taken_toggle=1;clocks(15);
    assert_msg(effective,"new acceptance restores pause eligibility");
    // Distinct accepted events within one raster count independently.
    pause_request=0;irq_taken_toggle=0;clocks(8);irq_taken_toggle=1;clocks(8);
    assert_msg(irq_count==5,"multiple events within one raster remain distinct");
    feedback_valid=0;pause_request=1;clocks(20);
    assert_msg(!effective,"unsupported feedback cannot confirm pause");
    feedback_valid=1;contract_valid=0;clocks(20);
    assert_msg(!effective,"disabled policy cannot confirm pause");
    contract_valid=1;pause_request=0;clocks(5);game_reset=1;irq_taken_toggle=0;clocks(8);
    assert_msg(epoch==1 && game_frame==0 && irq_count==0,"reset starts new epoch and absorbs toggle clear");
    clocks(8);assert_msg(epoch==1,"held reset creates only one epoch");
    game_reset=0;clocks(8);frame();pause_request=1;clocks(20);
    assert_msg(game_frame==1 && irq_count==0 && !effective,"reset discards previous service evidence");
    pass();
end
initial begin #100000;fail();end
jtframe_capture_progress #(
    .QUIET_CYCLES ( 8 )
) uut(
    .rst              ( rst              ),
    .clk              ( clk              ),
    .game_reset       ( game_reset       ),
    .pxl_cen          ( 1'b1             ),
    .lvbl             ( lvbl             ),
    .irq_level        ( irq_level        ),
    .irq_taken_toggle ( irq_taken_toggle ),
    .feedback_valid   ( feedback_valid   ),
    .contract_valid   ( contract_valid   ),
    .pause_request    ( pause_request    ),
    .step             ( step             ),
    .raster_tick      ( tick             ),
    .pause_gate       ( pause_gate       ),
    .pause_effective  ( effective        ),
    .contract_lost    ( lost             ),
    .step_done        ( step_done        ),
    .step_failed      ( step_failed      ),
    .epoch            ( epoch            ),
    .raster_frame     ( raster_frame     ),
    .game_frame       ( game_frame       ),
    .irq_count        ( irq_count        ),
    .irq_generation   ( irq_generation   ),
    .raster_period    ( raster_period    ),
    .irq_observed     (                  ),
    .service_observed (                  ),
    .raster_now       ( raster_now       ),
    .game_now         ( game_now         ),
    .irq_now          ( irq_now          )
);
endmodule
