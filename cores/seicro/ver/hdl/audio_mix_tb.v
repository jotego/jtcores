/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module audio_mix_tb;
reg clk=0, rst=1, cen=0, filters=0;
reg [15:0] psg_snd=0, dac_snd=0;
reg [5:0] snd_en=6'h3f;
wire signed [15:0] snd;
wire sample, snd_peak;
wire [5:0] snd_vu;
integer n, channel, frequency, tone_index, cycles=0;
real phase, sum, sumsq, baseline, filtered, ratio, expected, cutoff;
always #5 clk=~clk;

seicro_mixer dut(
    .rst          ( rst      ),
    .clk          ( clk      ),
    .psg_snd      ( psg_snd  ),
    .dac_snd      ( dac_snd  ),
    .psg_snd_rcen ( filters  ),
    .dac_snd_rcen ( filters  ),
    .snd_en       ( snd_en   ),
    .snd_vol      ( 8'h80    ),
    .snd          ( snd      ),
    .sample       ( sample   ),
    .snd_peak     ( snd_peak ),
    .snd_vu       ( snd_vu   )
);

task tick;
    begin
        @(negedge clk); cen=1;
        @(negedge clk); cen=0;
        repeat(7) @(negedge clk);
    end
endtask

task tone;
    input integer selected, hz;
    input integer filtered_on;
    output real rms;
    integer index, level;
    begin
        rst=1; filters=filtered_on; psg_snd=0; dac_snd=0;
        repeat(4) tick;
        rst=0; sum=0; sumsq=0;
        for(index=0;index<12288;index=index+1) begin
            phase=6.283185307179586*hz*index/192000.0;
            level=$rtoi(12000.0+4000.0*$sin(phase));
            psg_snd=selected==0 ? level : 0;
            dac_snd=selected==1 ? level : 0;
            tick;
            if(snd_peak!==0) $fatal(1,"Tone clipped");
            if(index>=8192) begin
                sum=sum+$itor(snd);
                sumsq=sumsq+$itor(snd)*$itor(snd);
            end
        end
        rms=$sqrt(sumsq/4096.0-(sum/4096.0)*(sum/4096.0));
    end
endtask

initial begin
`ifdef NOSOUND
    rst=0; psg_snd=16'hffff; dac_snd=16'hffff;
    repeat(3000) begin
        @(negedge clk);
        if(sample) cycles=cycles+1;
        if(snd!==0 || snd_peak!==0 || snd_vu!==0) $fatal(1,"NOSOUND activity");
    end
    if(cycles<10) $fatal(1,"NOSOUND lost framework sample clock");
    $display("PASS audio NOSOUND: zero output and live framework sample clock");
`else
    force dut.u_rcmix.cen=cen;
    psg_snd=1; dac_snd=1;
    force dut.u_rcmix.ch2=16'd1;
    force dut.u_rcmix.ch3=16'd1;
    force dut.u_rcmix.ch4=16'd1;
    force dut.u_rcmix.ch5=16'd1;
    #1; psg_snd=0; dac_snd=0;
    force dut.u_rcmix.ch2=16'd0;
    force dut.u_rcmix.ch3=16'd0;
    force dut.u_rcmix.ch4=16'd0;
    force dut.u_rcmix.ch5=16'd0;
    #1;
    release dut.u_rcmix.ch2;
    release dut.u_rcmix.ch3;
    release dut.u_rcmix.ch4;
    release dut.u_rcmix.ch5;
    repeat(4) tick;
    rst=0;
    repeat(128) tick;
    if(snd!==0) $fatal(1,"Silence output=%h ch=%h/%h pre=%h mul=%h final=%h mute=%h cen=%b",snd,dut.u_rcmix.ft0,dut.u_rcmix.ft1,dut.u_rcmix.pre_r,dut.u_rcmix.mul_r,dut.u_rcmix.right,dut.mute,dut.u_rcmix.cen);
    cutoff=1.0/(6.283185307179586*47000.0*0.000000001);
    for(channel=0;channel<2;channel=channel+1) begin
        for(tone_index=0;tone_index<3;tone_index=tone_index+1) begin
            case(tone_index)
                0: frequency=375;
                1: frequency=3375;
                2: frequency=12000;
            endcase
            tone(channel,frequency,0,baseline);
            tone(channel,frequency,1,filtered);
            if(frequency==375 && (baseline<1350.0 || baseline>1450.0))
                $fatal(1,"Mixer gain differs from unity volume and half channel gain: %f",baseline);
            ratio=filtered/baseline;
            expected=1.0/$sqrt(1.0+(frequency/cutoff)*(frequency/cutoff));
            if(channel==0) expected=expected*expected;
            if(ratio<expected*0.92 || ratio>expected*1.08)
                $fatal(1,"Filter channel=%0d Hz=%0d ratio=%f expected=%f",channel,frequency,ratio,expected);
            $display("PASS filter channel=%0d Hz=%0d measured=%f nominal=%f bypass_rms=%f",channel,frequency,ratio,expected,baseline);
        end
    end
    rst=1; repeat(4) tick; rst=0; filters=0;
    for(n=0;n<4096;n=n+1) begin
        psg_snd=n[5] ? 32736 : 0;
        dac_snd=n[5] ? 20340 : 0;
        tick;
        if(snd_peak!==0) $fatal(1,"Combined maximum levels clipped");
    end
    snd_en=0;
    repeat(128) tick;
    if(snd!==0) $fatal(1,"Channel mute did not silence output");
    snd_en=6'h3f; psg_snd=12000; dac_snd=12000;
    repeat(16000) tick;
    if(snd>3 || snd< -3) $fatal(1,"DC removed incorrectly: %0d",snd);
    $display("PASS audio mixer: silence, filter response, headroom, channel mute and DC settling");
`endif
    $finish;
end
endmodule
