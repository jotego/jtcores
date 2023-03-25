module test;

reg                clk, clk24=0;
wire               cen_pcm, sample;
wire        [18:0] rom_addr;
wire signed [15:0] snd_left, snd_right;

reg         [ 7:0] cpu_addr, cpu_dout;
reg                cpu_cs, rst;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    clk = 0;
    forever #10.416 clk = ~clk;
end

initial begin
    rst      = 0;
    cpu_cs   = 0;
    cpu_addr = 0;
    cpu_dout = 0;
    #50 rst = 1;
    #50 rst = 0;
    #10_000_000 $finish;
end


always @(posedge clk) clk24 <= ~clk24;

jts16_cen u_cen(
    .clk        ( clk       ),
    .pxl2_cen   (           ),
    .pxl_cen    (           ),

    .clk24      ( clk24     ),
    .mcu_cen    ( cen_pcm   ), // 8 MHz
    .fm2_cen    (           ), // 4 MHz
    .fm_cen     (           ),
    .snd_cen    (           ),
    .pcm_cen    (           ),
    .pcm_cenb   (           )
);


jtoutrun_pcm #(.SIMHEXFILE("pcm.hex")) uut(
    .rst        ( rst       ),
    .clk        ( clk24     ),
    .cen        ( cen_pcm   ),

    .debug_bus  ( 8'd0      ),
    .st_dout    (           ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    (           ),
    .cpu_rnw    ( 1'b0      ),
    .cpu_cs     ( cpu_cs    ),

    // ROM interface
    .rom_addr   ( rom_addr  ),
    .rom_data   (rom_addr[7:0]^8'h80),
    .rom_ok     ( 1'b1      ),
    .rom_cs     (           ),

    // sound output
    .snd_left   ( snd_left  ),
    .snd_right  ( snd_right ),
    .sample     ( sample    )
);

endmodule