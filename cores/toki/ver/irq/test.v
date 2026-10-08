`timescale 1ns/1ps

module test;

reg        fm_irq_n=1, main_irq_trig=0, cpu_irq_ack=0;
reg        fm_eoi=0, main_eoi=0;
wire       rst, clk, cpu_irq_n;
wire [7:0] im0_opcode;

`include "test_tasks.vh"

task tick;
begin
    @(posedge clk);
    #1;
end
endtask

task cpu_event;
begin
    main_irq_trig = 1'b1;
    tick();
    main_irq_trig = 1'b0;
    tick();
end
endtask

task take_irq(input [7:0] expected);
begin
    assert_msg(!cpu_irq_n, "interrupt request missing");
    assert_msg(im0_opcode == expected, "wrong pending interrupt vector");
    cpu_irq_ack = 1'b1;
    tick();
    assert_msg(im0_opcode == expected, "interrupt vector changed during acknowledge");
    cpu_irq_ack = 1'b0;
    tick();
end
endtask

task pulse_fm_eoi;
begin
    fm_eoi = 1'b1;
    tick();
    fm_eoi = 1'b0;
    tick();
end
endtask

task pulse_main_eoi;
begin
    main_eoi = 1'b1;
    tick();
    main_eoi = 1'b0;
    tick();
end
endtask

initial begin
    @(negedge rst);
    tick();
    assert_msg(cpu_irq_n, "interrupt active after reset");

    // A spurious acknowledge must return MAME's harmless NOP opcode.
    assert_msg(im0_opcode == 8'h00, "wrong idle interrupt vector");
    cpu_irq_ack = 1'b1;
    tick();
    assert_msg(im0_opcode == 8'h00, "spurious acknowledge did not return NOP");
    cpu_irq_ack = 1'b0;
    tick();

    // FM and CPU requests must both survive a simultaneous assertion.
    fm_irq_n = 1'b0;
    main_irq_trig = 1'b1;
    tick();
    main_irq_trig = 1'b0;
    take_irq(8'hdf);
    assert_msg(!cpu_irq_n, "simultaneous RST10 was lost");
    assert_msg(im0_opcode == 8'hd7, "RST10 did not follow RST18");
    take_irq(8'hd7);
    fm_irq_n = 1'b1;
    tick();
    pulse_fm_eoi();
    pulse_main_eoi();
    assert_msg(cpu_irq_n, "interrupt remained active after both EOIs");

    // A second CPU edge during service must remain pending until EOI.
    cpu_event();
    take_irq(8'hdf);
    assert_msg(cpu_irq_n, "RST18 remained active while in service");
    cpu_event();
    assert_msg(cpu_irq_n, "queued RST18 ignored in-service gate");
    pulse_main_eoi();
    assert_msg(!cpu_irq_n, "queued RST18 was lost at EOI");
    take_irq(8'hdf);
    pulse_main_eoi();
    assert_msg(cpu_irq_n, "second RST18 did not complete");

    // A new CPU edge coincident with acceptance must not be cleared with the old request.
    cpu_event();
    main_irq_trig = 1'b1;
    cpu_irq_ack   = 1'b1;
    tick();
    assert_msg(im0_opcode == 8'hdf, "coincident RST18 changed the acknowledge vector");
    main_irq_trig = 1'b0;
    cpu_irq_ack   = 1'b0;
    tick();
    assert_msg(cpu_irq_n, "coincident RST18 bypassed the in-service gate");
    pulse_main_eoi();
    assert_msg(!cpu_irq_n, "coincident RST18 was lost during acknowledgement");
    take_irq(8'hdf);
    pulse_main_eoi();
    assert_msg(cpu_irq_n, "coincident RST18 did not complete");

    // A held FM request must become visible again when its EOI arrives.
    fm_irq_n = 1'b0;
    tick();
    take_irq(8'hd7);
    assert_msg(cpu_irq_n, "RST10 remained active while in service");
    pulse_fm_eoi();
    assert_msg(!cpu_irq_n, "held FM request was lost at EOI");
    take_irq(8'hd7);
    fm_irq_n = 1'b1;
    tick();
    pulse_fm_eoi();
    assert_msg(cpu_irq_n, "RST10 did not clear after FM deassertion");

    // A level held high at the CPU input represents one write event only.
    main_irq_trig = 1'b1;
    tick();
    take_irq(8'hdf);
    pulse_main_eoi();
    assert_msg(cpu_irq_n, "held CPU trigger generated a duplicate interrupt");
    main_irq_trig = 1'b0;
    tick();

    pass();
end

jttoki_irq uut(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .fm_irq_n      ( fm_irq_n      ),
    .main_irq_trig ( main_irq_trig ),
    .cpu_irq_ack   ( cpu_irq_ack   ),
    .fm_eoi        ( fm_eoi        ),
    .main_eoi      ( main_eoi      ),
    .cpu_irq_n     ( cpu_irq_n     ),
    .im0_opcode    ( im0_opcode    )
);

jtframe_test_clocks clocks(
    .rst        ( rst ),
    .clk        ( clk )
);

endmodule
