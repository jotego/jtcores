`timescale 1ns/1ps

// Regression for jtcores #1017.  A Gulun.Pa OKI6295 channel can consume a
// sustained stream of 0xf nibbles.  It must not enter the -863/-2048/+2047
// decoder limit cycle, which creates the audible 2.5 kHz ringing.
module test;

`include "test_tasks.vh"

reg rst = 1'b1;
reg clk = 1'b0;
reg wrn = 1'b1;
reg [7:0] din = 8'd0;
wire [7:0] dout;
wire [17:0] rom_addr;
wire [7:0] rom_data;
wire signed [13:0] sound;
wire sample;

always #5 clk = ~clk;

// This is a one-clock BRAM read, matching the normal sample-ROM interface.
jtframe_prom #(.AW(18), .SIMHEX("ringing.hex")) rom(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( 8'd0     ),
    .rd_addr( rom_addr ),
    .wr_addr( 18'd0    ),
    .we     ( 1'b0     ),
    .q      ( rom_data )
);

jt6295 uut(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      ( 1'b1      ),
    .ss       ( 1'b1      ),
    .wrn      ( wrn       ),
    .din      ( din       ),
    .dout     ( dout      ),
    .rom_addr ( rom_addr  ),
    .rom_data ( rom_data  ),
    .rom_ok   ( 1'b1      ),
    .sound    ( sound     ),
    .sample   ( sample    )
);

task write_command(input [7:0] value);
begin
    @(posedge sample);
    din <= value;
    wrn <= 1'b0;
    @(posedge sample);
    wrn <= 1'b1;
end
endtask

integer decoded = 0;
integer cycle_count = 0;
integer unclamped_count = 0;
reg signed [11:0] old0, old1;

// snd_V changes once per decoded nibble.  Looking here avoids any ambiguity
// from the accumulator while still exercising the complete jt6295 command,
// ROM and serializer paths above.
always @(posedge clk) if (!rst && uut.u_adpcm.cen) begin
    if (uut.u_adpcm.en_V) begin
        decoded = decoded + 1;
        if (old1 == -12'sd863 && old0 == -12'sd2048 &&
            uut.u_adpcm.snd_V == 12'sd2047)
            cycle_count = cycle_count + 1;
        if (decoded >= 40 && uut.u_adpcm.snd_V != -12'sd2048)
            unclamped_count = unclamped_count + 1;
        old1 = old0;
        old0 = uut.u_adpcm.snd_V;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0, test);
    repeat (8) @(posedge clk);
    rst <= 1'b0;

    // Start phrase 0 on channel 0 at full volume.
    write_command(8'h80);
    write_command(8'h10);

    // 0x40..0xff provides 384 decoder nibbles, much more than needed to
    // reach the bad saturated three-state loop.
    wait (decoded >= 300);
    if (cycle_count != 0) begin
        $display("FAIL: detected %0d -863/-2048/+2047 clamp cycles", cycle_count);
        fail();
    end
    if (unclamped_count != 0) begin
        $display("FAIL: decoder left the negative clamp %0d times", unclamped_count);
        fail();
    end
    pass();
end

endmodule
