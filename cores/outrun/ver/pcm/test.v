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

// A CPU control write can coincide with the scanner's periodic writeback
// of the same voice. The CPU command must take precedence so a one-shot
// sample start is not lost.
initial begin
    @(negedge rst);
    @(negedge clk);
    force uut.st     = 4'd8;
    force uut.cur_ch = 4'd8;
    force uut.cfg_en = 8'h01;
    uut.u_ram.u_ram.mem[9'h0c6] = 8'h01;
    cpu_addr = 8'hc6;
    cpu_dout = 8'h00;
    cpu_cs   = 1'b1;
    @(posedge clk);
    #1;
    if (uut.u_ram.u_ram.mem[9'h0c6] !== 8'h00) begin
        $fatal(1, "PCM writeback overwrote the Z80 channel-8 start command");
    end
    $display("PASS: Z80 channel-8 start command wins the PCM RAM collision");

    // The collision check above only protects the single cycle of the CPU write.
    // The enable register is a read-modify-write spanning st==0 (read) to st==8
    // (write-back), about 24 clk cycles at cen 16MHz. A CPU write landing anywhere
    // else in that window is not a collision, yet an unconditional write-back at
    // st==8 still restores the stale byte and the voice start is silently lost.
    // So: the CPU has already written 0x00, no write is in flight, and cfg_en still
    // holds the 0x01 read at st==0. st==8 must leave RAM alone.
    cpu_cs = 1'b0;
    uut.u_ram.u_ram.mem[9'h0c6] = 8'h00;  // the CPU's start command, already stored
    force uut.st     = 4'd8;              // cfg_addr=5'o16 -> RAM 0x0c6 for channel 8
    force uut.cur_ch = 4'd8;
    force uut.cfg_en = 8'h01;             // stale copy, read at st==0 before the CPU wrote
    @(posedge clk24);                     // the RAM is clocked by clk24, not clk
    @(posedge clk24);
    #1;
    if (uut.u_ram.u_ram.mem[9'h0c6] !== 8'h00) begin
        $fatal(1, "st==8 write-back restored the stale enable byte and dropped the voice start");
    end
    $display("PASS: st==8 does not write back an unchanged enable register");
    $finish;
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
