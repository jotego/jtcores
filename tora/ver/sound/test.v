`timescale 1ns/1ps

// 30 intro song
// 24 fx
// 7f separator

module test;

wire        cen_fm;
reg         clk, rst;
reg  [ 7:0] snd_latch = 8'h7f;
wire [14:0] snd_addr;
reg  [ 7:0] snd_data;
wire        snd_cs, sample;
wire signed [15:0] snd;

reg [7:0] rom[0:(2**15-1)];
integer f,aux, sample_cnt=0;

initial begin
    f = $fopen("../../../rom/tora/tru_05.12k","rb");
    aux = $fread(rom,f);
    $display("INFO read %d bytes", aux);
end

initial begin
    rst = 1'b0;
    #200
    rst = 1'b1;
    #2500
    rst = 1'b0;
end

initial begin
    clk = 1'b0;
    forever #10.41 clk = ~clk;
end

always @(posedge clk)
    snd_data <= rom[snd_addr];

always @(posedge sample) begin
    sample_cnt<=sample_cnt+1;
    if( sample_cnt == 10_000 ) snd_latch <= `CODE;
    if( sample_cnt == 13_000 ) snd_latch <= 8'h7f;
    if( sample_cnt ==`FINISH ) $finish;
end

jtgng_cen3p57 u_cen3p57(
    .clk      ( clk       ),
    .cen_3p57 ( cen_fm    ),
    .cen_1p78 (           )     // unused
);

jtgng_sound #(.LAYOUT(3)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen_fm         ),
    .cen1p5         ( 1'b1           ),  // unused
    // Interface with main CPU
    .sres_b         ( 1'b1           ),  // unused
    .snd_latch      ( snd_latch      ),
    .snd_int        ( 1'b1           ),  // unused
    // sound control
    .enable_psg     ( 1'b1           ),
    .enable_fm      ( 1'b1           ),
    .psg_gain       ( 8'h10          ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( 1'b1           ),
    // sound output
    .ym_snd         ( snd            ),
    .sample         ( sample         )
);

`ifdef DUMP
initial $display("INFO: signal dump enabled");

`ifndef NCVERILOG
    initial begin
        $dumpfile("test.lxt");
        $dumpvars(2,test);
        $dumpon;
    end
`else
    initial begin
        $shm_open("test.shm");
        $shm_probe(test,"A");
        $shm_probe(test.u_sound,"A");
        $shm_probe(test.u_sound.u_fm0,"AS");
        $shm_probe(test.u_sound.u_fm1,"AS");
    end
`endif
`endif

endmodule