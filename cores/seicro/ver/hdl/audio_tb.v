`timescale 1ns/1ps
module audio_tb;
reg clk=0, rst=1, bdir=0, bc1=0, seicross=1;
reg [7:0] data=0;
reg [9:0] psg=1023;
reg [3:0] dac=0;
wire [7:0] porta, cpu_din;
wire [15:0] psg_snd, dac_snd;
integer control, code, bitno;
real conductance, reference_v, expected;
always #5 clk=~clk;

jtseicro_snd u_snd(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .audio_cen ( 1'b1      ),
    .bdir      ( bdir      ),
    .bc1       ( bc1       ),
    .cpu_dout  ( data      ),
    .cpu_din   ( cpu_din   ),
    .debug_dip ( 8'hff     ),
    .irq_en    (           ),
    .flip      (           ),
    .mcu_run   (           ),
    .psg       (           ),
    .porta     ( porta     ),
    .sample    (           )
);

jtseicro_audio dut(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .seicross ( seicross ),
    .psg      ( psg      ),
    .porta    ( porta    ),
    .dac      ( dac      ),
    .psg_snd  ( psg_snd  ),
    .dac_snd  ( dac_snd  )
);

task ay_write;
    input [7:0] address, value;
    begin
        @(negedge clk); data=address; bdir=1; bc1=1;
        repeat(4) @(negedge clk); bdir=0; bc1=0;
        repeat(4) @(negedge clk); data=value; bdir=1;
        repeat(4) @(negedge clk); bdir=0;
        repeat(8) @(negedge clk);
    end
endtask

task check_level;
    input integer actual;
    input real level;
    real error;
    begin
        error=actual-level;
        if(error<0) error=-error;
        if(error>2.0+level*0.001)
            $fatal(1,"Resistor model port=%h DAC=%h actual=%0d expected=%f",porta,dac,actual,level);
    end
endtask

initial begin
    repeat(5) @(negedge clk);
    if(psg_snd!==0 || dac_snd!==0) $fatal(1,"Audio reset");
    rst=0;
    ay_write(14,0);
    if(porta!==8'hff) $fatal(1,"Input-mode pull-ups lost");
    ay_write(7,8'h40);
    if(porta!==0) $fatal(1,"Output-mode latch lost");
    for(control=0;control<256;control=control+1) begin
        ay_write(14,control[7:0]);
        if(porta!==control[7:0]) $fatal(1,"AY port A disconnected");
        conductance=0;
        for(bitno=0;bitno<4;bitno=bitno+1)
            if(control & (1<<bitno)) conductance=conductance+(1<<bitno)/800000.0;
        expected=32768.0*0.6*psg/1024.0*47000.0*conductance;
        check_level(psg_snd,expected);
        for(code=0;code<16;code=code+1) begin
            dac=code[3:0];
            repeat(2) @(negedge clk);
            conductance=0;
            for(bitno=0;bitno<4;bitno=bitno+1)
                if(control & (16<<bitno)) conductance=conductance+(1<<bitno)/800000.0;
            reference_v=5.0*47000.0*conductance;
            conductance=0;
            for(bitno=0;bitno<4;bitno=bitno+1)
                if(code & (1<<bitno)) conductance=conductance+(bitno%2 ? 1.0/200000.0 : 1.0/400000.0);
            expected=32768.0/5.0*reference_v*47000.0*conductance;
            check_level(dac_snd,expected);
        end
    end
    ay_write(14,0);
    ay_write(7,0);
    if(porta!==8'hff) $fatal(1,"Stale output latch used in input mode");
    ay_write(7,8'h40);
    if(porta!==0) $fatal(1,"Output latch not retained through direction change");
    seicross=0;
    for(code=0;code<16;code=code+1) begin
        dac=code[3:0];
        ay_write(14,code[7:0]);
        if(psg_snd!==16'd32736 || dac_snd!==(code*1024))
            $fatal(1,"Unverified variants gained schematic controls");
    end
    rst=1;
    repeat(4) @(negedge clk);
    if(psg_snd!==0 || dac_snd!==0) $fatal(1,"Audio reset after activity");
    $display("PASS audio: 256 GPIO codes x 16 DAC codes against resistor currents; direction, pull-ups, reset and variant isolation");
    $finish;
end
endmodule
