/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-10-2026 */

`timescale 1ns/1ps
module mix_tb;
reg signed [15:0] fm_left,fm_right;
reg signed [13:0] pcm;
wire signed [15:0] snd;
integer fm_values [0:8];
integer pcm_values [0:6];
integer l,r,p,expected,count=0;

jtroundu_mix u_mix (
    .fm_left  ( fm_left  ),
    .fm_right ( fm_right ),
    .pcm      ( pcm      ),
    .snd      ( snd      )
);

initial begin
    fm_values[0]=-32768; fm_values[1]=-16385; fm_values[2]=-4000;
    fm_values[3]=-1; fm_values[4]=0; fm_values[5]=1;
    fm_values[6]=4000; fm_values[7]=16383; fm_values[8]=32767;
    pcm_values[0]=-8192; pcm_values[1]=-4096; pcm_values[2]=-1;
    pcm_values[3]=0; pcm_values[4]=1; pcm_values[5]=4095; pcm_values[6]=8191;
    for (l=0;l<9;l=l+1) for (r=0;r<9;r=r+1) for (p=0;p<7;p=p+1) begin
        fm_left=fm_values[l][15:0];
        fm_right=fm_values[r][15:0];
        pcm=pcm_values[p][13:0];
        expected=(fm_values[l] >>> 2)+(fm_values[r] >>> 2)+pcm_values[p]*2;
        if (expected>32767) expected=32767;
        if (expected < -32768) expected=-32768;
        #1;
        if ($signed(snd) !== expected) $fatal(1,"mix left=%0d right=%0d pcm=%0d actual=%0d expected=%0d",fm_left,fm_right,pcm,snd,expected);
        count=count+1;
    end
    $display("PASS: %0d signed FM/PCM mixer vectors, negative values, cancellation and full scale",count);
    $finish;
end
endmodule
