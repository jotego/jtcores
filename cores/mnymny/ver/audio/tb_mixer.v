/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// Compares jtmnymny_mixer against the bit-true golden vectors from
// analyze.py --emit (out/stim.hex, out/golden.hex).

`timescale 1ns/1ps

module tb_mixer;

localparam NT = 76800;

reg  [71:0] stim  [0:NT-1];
reg  [47:0] golden[0:NT-1];

reg         clk=0, rst=1, cen=0;
reg  [ 7:0] cnt=251;
integer     n=0, errors=0;

reg  [71:0] s;
wire [ 7:0] ay4g_a = s[ 7: 0];
wire [ 7:0] ay4g_b = s[15: 8];
wire [ 7:0] ay4g_c = s[23:16];
wire [ 7:0] ay4h_a = s[31:24];
wire [ 7:0] ay4h_b = s[39:32];
wire signed [13:0] speech = s[53:40];
wire [ 7:0] dac    = s[61:54];
wire [ 4:0] ioa    = s[66:62];
wire        level  = s[67];
wire        levelt = s[68];
wire        sw1    = s[69];

wire signed [15:0] music, voice, pcm;

jtmnymny_mixer uut(
    .rst(rst), .clk(clk), .cen(cen),
    .ay4g_a(ay4g_a), .ay4g_b(ay4g_b), .ay4g_c(ay4g_c),
    .ay4h_a(ay4h_a), .ay4h_b(ay4h_b),
    .speech(speech), .dac(dac), .ioa(ioa),
    .level(level), .levelt(levelt), .sw1(sw1),
    .music(music), .voice(voice), .pcm(pcm)
);

always #10 clk = ~clk;

initial begin
    $readmemh("out/stim.hex",   stim);
    $readmemh("out/golden.hex", golden);
    s = stim[0];
    repeat (8) @(posedge clk);
    rst = 0;
end

always @(posedge clk) if( !rst ) begin
    cnt <= cnt + 8'd1;
    cen <= cnt == 8'd255;
    if( cnt == 8'd250 ) begin
        if( { pcm, voice, music } !== golden[n] ) begin
            errors = errors + 1;
            if( errors <= 10 )
                $display("tick %0d: got %04x %04x %04x exp %04x %04x %04x",
                    n, music, voice, pcm,
                    golden[n][15:0], golden[n][31:16], golden[n][47:32]);
        end
        n <= n + 1;
        if( n == NT-1 ) begin
            if( errors == 0 ) $display("PASS %0d ticks", NT);
            else              $display("FAIL %0d errors", errors);
            $finish;
        end
    end
    if( cnt == 8'd252 ) s <= stim[n];
end

endmodule
