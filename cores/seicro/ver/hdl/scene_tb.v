`timescale 1ns/1ps
module scene_tb;
reg clk=0, rst=1;
wire [7:0] cpu_din;
wire irq_en, flip, mcu_run, sample;
wire [9:0] psg;
wire [7:0] porta;
always #5 clk=~clk;

jtseicro_snd u_snd(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .audio_cen ( 1'b1      ),
    .bdir      ( 1'b0      ),
    .bc1       ( 1'b0      ),
    .cpu_dout  ( 8'd0      ),
    .cpu_din   ( cpu_din   ),
    .debug_dip ( 8'hff     ),
    .irq_en    ( irq_en    ),
    .flip      ( flip      ),
    .mcu_run   ( mcu_run   ),
    .psg       ( psg       ),
    .porta     ( porta     ),
    .sample    ( sample    )
);

initial begin
    repeat(5) @(negedge clk);
    if(u_snd.portb!==8'ha7 || !flip || !irq_en) $fatal(1,"Restore lost during reset");
    rst=0;
    repeat(100) @(negedge clk);
    if(u_snd.portb!==8'ha7 || !flip || !irq_en) $fatal(1,"Restore changed after reset");
    if(porta!==0 || psg!==0 || sample!==0 || mcu_run!==0 || cpu_din!==8'hff)
        $fatal(1,"Sound or MCU active");
    $display("PASS scene: raw port-B/flip preserved through reset; PSG and MCU release disabled");
    $finish;
end
endmodule
