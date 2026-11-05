/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */
`timescale 1ns/1ps

module test;
reg clk=0, rst=1, cen=0, cs=0, wr=0, rd=0, addr=0;
reg [7:0] din=0;
wire [7:0] dout;
wire cpu_ready, irq, rom_cs, rom_we, sample, overrun;
wire [23:0] rom_addr;
wire [7:0] rom_dout;
wire signed [15:0] snd_l, snd_r;
reg [7:0] rom_data=0;
reg rom_ok=0;
reg [7:0] memory [0:65535];
integer delay_count=0, latency=3, requests=0, writes=0;
reg served=0;
reg [23:0] held_address;
reg held_we;
reg [7:0] held_data;
integer checks=0, i, j, k, n, ref_signal, ref_step, scale, delta;
integer expected_l, expected_r, left_gain, right_gain;
integer frames=0, cycles=0, last_sample=0;
integer ref_pos [0:7], ref_phase [0:7], ref_prev [0:7], ref_curr [0:7];
integer ref_sig [0:7], ref_stp [0:7], ref_loop_sig [0:7], ref_loop_stp [0:7];
integer ref_saved [0:7], ref_mode [0:7], ref_freq [0:7], ref_pan [0:7], ref_vol [0:7];
integer sum_l, sum_r, interp, next_pos, first_addr, balance;
reg [3:0] nibble=0;
reg signed [15:0] signal_in=0;
reg [14:0] step_in=127;
wire signed [15:0] signal_out;
wire [14:0] step_out;

always #5 clk=~clk;
jtymz280b uut(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .cen       ( cen        ),
    .cs        ( cs         ),
    .wr        ( wr         ),
    .rd        ( rd         ),
    .addr      ( addr       ),
    .din       ( din        ),
    .dout      ( dout       ),
    .cpu_ready ( cpu_ready  ),
    .irq       ( irq        ),
    .rom_addr  ( rom_addr   ),
    .rom_cs    ( rom_cs     ),
    .rom_we    ( rom_we     ),
    .rom_dout  ( rom_dout   ),
    .rom_data  ( rom_data   ),
    .rom_ok    ( rom_ok     ),
    .snd_l     ( snd_l      ),
    .snd_r     ( snd_r      ),
    .sample    ( sample     ),
    .overrun   ( overrun    )
);

jtymz280b_adpcm decoder(
    .nibble     ( nibble     ),
    .signal_in  ( signal_in  ),
    .step_in    ( step_in    ),
    .signal_out ( signal_out ),
    .step_out   ( step_out   )
);

always @(negedge clk) begin
    if(rst || !rom_cs) begin
        delay_count=0;
        served=0;
        rom_ok=0;
    end else if(!served) begin
        if(delay_count==0) begin
            held_address=rom_addr;
            held_we=rom_we;
            held_data=rom_dout;
        end else if({rom_addr,rom_we,rom_dout}!=={held_address,held_we,held_data})
            $fatal(1,"memory request changed while waiting");
        delay_count=delay_count+1;
        if(delay_count>=latency) begin
            rom_data=memory[rom_addr[15:0]];
            if(rom_we) begin
                memory[rom_addr[15:0]]=rom_dout;
                writes=writes+1;
            end
            rom_ok=1;
            served=1;
            requests=requests+1;
        end
    end
end

task reset_chip;
begin
    @(negedge clk); rst=1; cen=0; cs=0; wr=0; rd=0;
    repeat(3) @(negedge clk);
    rst=0;
end
endtask

task bus_write(input a, input [7:0] value);
begin
    @(negedge clk);
    while(!cpu_ready) @(negedge clk);
    cs=1; wr=1; addr=a; din=value;
    @(negedge clk); cs=0; wr=0;
end
endtask

task write_reg(input [7:0] r, input [7:0] value);
begin
    bus_write(0,r);
    bus_write(1,value);
end
endtask

task read_port(input a, output [7:0] value);
begin
    @(negedge clk);
    while(!cpu_ready) @(negedge clk);
    addr=a; cs=1; rd=1;
    #1; value=dout;
    @(negedge clk); cs=0; rd=0;
end
endtask

task address_reg(input integer voice, input integer which, input [23:0] value);
begin
    write_reg(8'h20+voice*4+which,value[23:16]);
    write_reg(8'h40+voice*4+which,value[15:8]);
    write_reg(8'h60+voice*4+which,value[7:0]);
end
endtask

task voice_setup(input integer voice, input [1:0] m, input looped,
                 input [8:0] frequency, input [23:0] first, limit,
                 input [7:0] volume, input [3:0] balance);
begin
    address_reg(voice,0,first);
    address_reg(voice,3,limit);
    write_reg(voice*4,frequency[7:0]);
    write_reg(voice*4+2,volume);
    write_reg(voice*4+3,{4'd0,balance});
    write_reg(voice*4+1,{1'b1,m,looped,3'd0,frequency[8]});
end
endtask

task run_frame;
    integer timeout;
begin
    timeout=0;
    @(negedge clk); cen=1;
    while(!sample && timeout<2000) begin
        @(negedge clk); timeout=timeout+1;
    end
    if(timeout>=2000) $fatal(1,"sample timeout");
    @(negedge clk); cen=0;
    timeout=0;
    while((uut.state!=0 || uut.frame_pending) && timeout<2000) begin
        @(negedge clk); timeout=timeout+1;
    end
    if(timeout>=2000) $fatal(1,"scheduler timeout");
    checks=checks+1;
end
endtask

task check_mix(input integer l, r);
begin
    if(snd_l!==l || snd_r!==r)
        $fatal(1,"mix got %0d,%0d expected %0d,%0d",snd_l,snd_r,l,r);
    checks=checks+1;
end
endtask

reg [7:0] value;
reg [24:0] saved_position;
initial begin
    for(i=0;i<65536;i=i+1) memory[i]=8'(i*73+19);
    for(i=0;i<2000;i=i+1) begin
        ref_signal=0; ref_step=127;
        for(j=0;j<64;j=j+1) begin
            nibble=4'($random);
            signal_in=16'(ref_signal); step_in=15'(ref_step);
            delta=(ref_step*((nibble&7)*2+1))/8;
            ref_signal=ref_signal+(nibble[3] ? -delta : delta);
            if(ref_signal>32767) ref_signal=32767;
            if(ref_signal< -32768) ref_signal= -32768;
            case(nibble&7)
                0,1,2,3: scale=230;
                4: scale=307;
                5: scale=409;
                6: scale=512;
                7: scale=614;
            endcase
            ref_step=(ref_step*scale)/256;
            if(ref_step<127) ref_step=127;
            if(ref_step>24576) ref_step=24576;
            #1;
            if(signal_out!==16'(ref_signal) || step_out!==15'(ref_step))
                $fatal(1,"ADPCM mismatch nibble=%h signal=%0d step=%0d",nibble,signal_out,step_out);
            checks=checks+1;
        end
    end

    reset_chip;
    read_port(0,value);
    if(value!==8'hff) $fatal(1,"disabled external read");
    write_reg(8'hff,8'hc0);
    write_reg(8'h84,8'h12);
    write_reg(8'h85,8'h34);
    write_reg(8'h86,8'h56);
    read_port(0,value);
    if(value!==memory[16'h3456]) $fatal(1,"external prefetch");
    if(held_address!==24'h123456) $fatal(1,"external 24-bit address");
    read_port(0,value);
    if(value!==memory[16'h3456]) $fatal(1,"external latch pipeline");
    read_port(0,value);
    if(value!==memory[16'h3457]) $fatal(1,"external increment");
    write_reg(8'h87,8'ha5);
    while(!cpu_ready) @(negedge clk);
    if(memory[16'h3459]!==8'ha5 || writes!=1) $fatal(1,"external write");

    for(k=0;k<16;k=k+1) begin
        reset_chip;
        memory[0]=8'h40;
        write_reg(8'hff,8'h80);
        address_reg(0,1,0); address_reg(0,2,1);
        voice_setup(0,2,1,511,0,1,255,k);
        repeat(5) run_frame;
        left_gain=k<=8 ? 255 : 255*(15-k)/7;
        right_gain=k>=8 ? 255 : k==0 ? 0 : 255*(k-1)/7;
        check_mix(16384*left_gain/512,16384*right_gain/512);
        if(overrun) $fatal(1,"unexpected overrun");
    end

    reset_chip;
    memory[0]=8'h34; memory[1]=8'h92;
    write_reg(8'hff,8'h90); write_reg(8'hfe,1);
    voice_setup(0,3,0,511,0,2,255,8);
    run_frame;
    if(!irq || uut.playing[0] || uut.curr_data[0]!==16'h9234)
        $fatal(1,"PCM16/end/irq");
    read_port(1,value);
    if(value!==1 || irq) $fatal(1,"status read clear");
    repeat(2) run_frame;
    check_mix((-28108*255)>>>9,(-28108*255)>>>9);

    reset_chip;
    memory[0]=8'h12; memory[1]=8'h74; memory[2]=8'h9e;
    write_reg(8'hff,8'h80);
    address_reg(0,1,1); address_reg(0,2,3);
    voice_setup(0,1,1,255,0,4,255,8);
    repeat(11) run_frame;
    if(uut.position[0]!==2 || uut.signal_data[0]!==uut.loop_signal[0] ||
       uut.step_data[0]!==uut.loop_step[0] || !uut.playing[0])
        $fatal(1,"ADPCM loop context restore pos=%0d",uut.position[0]);
    ref_signal=uut.loop_signal[0]; ref_step=uut.loop_step[0];
    repeat(8) run_frame;
    if(uut.signal_data[0]!==16'(ref_signal) || uut.step_data[0]!==15'(ref_step))
        $fatal(1,"ADPCM loop drift");
    write_reg(1,8'h30);
    saved_position=uut.position[0];
    repeat(4) run_frame;
    if(uut.position[0]!==saved_position || uut.status!=0) $fatal(1,"keyoff");

    for(k=0;k<3;k=k+1) begin
        reset_chip;
        write_reg(8'hff,8'h80);
        voice_setup(0,2,0,k==0 ? 0 : k==1 ? 255 : 511,0,1000,255,8);
        for(n=0;n<520;n=n+1) run_frame;
        i=k==0 ? 2 : k==1 ? 260 : 520;
        if(uut.position[0]!==25'(i*2)) $fatal(1,"pitch k=%0d pos=%0d",k,uut.position[0]);
    end

    reset_chip;
    write_reg(8'hff,8'h80);
    for(k=0;k<8;k=k+1) begin
        memory[k*2]=8'hff; memory[k*2+1]=8'h7f;
        address_reg(k,1,k*2); address_reg(k,2,k*2+2);
        voice_setup(k,3,1,511,k*2,k*2+2,255,8);
    end
    repeat(5) run_frame;
    check_mix(32767,32767);
    if(overrun) $fatal(1,"eight voice overrun");
    write_reg(8'hff,0);
    run_frame;
    if(uut.playing!=0) $fatal(1,"global disable");
    write_reg(8'hff,8'h80);
    run_frame;
    if(uut.playing!=255) $fatal(1,"global loop resume");

    reset_chip;
    write_reg(8'hff,8'h90); write_reg(8'hfe,1);
    voice_setup(0,3,0,511,24'hfedcba,24'hfedcbc,255,8);
    run_frame;
    if(held_address!==24'hfedcbb || uut.position[0]!==25'h1fdb978 || !irq)
        $fatal(1,"playback 24-bit addressing");

    reset_chip;
    write_reg(8'hff,8'h80);
    for(k=0;k<8;k=k+1) begin
        memory[k*2]=0; memory[k*2+1]=8'h80;
        address_reg(k,1,k*2); address_reg(k,2,k*2+2);
        voice_setup(k,3,1,511,k*2,k*2+2,255,8);
    end
    repeat(5) run_frame;
    check_mix(-32768,-32768);

    reset_chip;
    write_reg(8'hff,8'h80);
    for(k=0;k<8;k=k+1) begin
        address_reg(k,1,0); address_reg(k,2,2);
        voice_setup(k,3,1,511,0,2,255,8);
    end
    cen=1;
    for(n=0;n<10000;n=n+1) begin
        @(negedge clk);
        if(sample) begin
            if(last_sample!=0 && n-last_sample!=192) $fatal(1,"sample cadence");
            last_sample=n;
            frames=frames+1;
        end
    end
    cen=0;
    if(overrun || frames<50) $fatal(1,"continuous eight voice schedule");

    reset_chip;
    write_reg(8'hff,8'h80);
    for(k=0;k<8;k=k+1) begin
        first_addr=256+k*32;
        ref_pos[k]=first_addr*2;
        ref_phase[k]=512;
        ref_prev[k]=0; ref_curr[k]=0;
        ref_sig[k]=0; ref_stp[k]=127;
        ref_loop_sig[k]=0; ref_loop_stp[k]=127; ref_saved[k]=0;
        ref_mode[k]=k%3+1;
        ref_freq[k]=k*73;
        ref_pan[k]=k*2+1;
        ref_vol[k]=255-k*17;
        address_reg(k,1,first_addr+2); address_reg(k,2,first_addr+8);
        voice_setup(k,ref_mode[k],1,ref_freq[k],first_addr,first_addr+16,ref_vol[k],ref_pan[k]);
    end
    expected_l=0; expected_r=0;
    for(n=0;n<2000;n=n+1) begin
        latency=1+n%5;
        run_frame;
        check_mix(expected_l,expected_r);
        sum_l=0; sum_r=0;
        for(k=0;k<8;k=k+1) begin
            first_addr=256+k*32;
            if(ref_phase[k]>=512) begin
                ref_phase[k]=ref_phase[k]-512;
                ref_prev[k]=ref_curr[k];
                case(ref_mode[k])
                1: begin
                    balance=(memory[ref_pos[k]/2] >> ((ref_pos[k]&1)==0 ? 4 : 0))&15;
                    delta=ref_stp[k]*((balance&7)*2+1)/8;
                    ref_sig[k]=ref_sig[k]+((balance&8)!=0 ? -delta : delta);
                    if(ref_sig[k]>32767) ref_sig[k]=32767;
                    if(ref_sig[k]< -32768) ref_sig[k]= -32768;
                    case(balance&7)
                        0,1,2,3: scale=230;
                        4: scale=307;
                        5: scale=409;
                        6: scale=512;
                        7: scale=614;
                    endcase
                    ref_stp[k]=ref_stp[k]*scale/256;
                    if(ref_stp[k]<127) ref_stp[k]=127;
                    if(ref_stp[k]>24576) ref_stp[k]=24576;
                    ref_curr[k]=ref_sig[k];
                    next_pos=ref_pos[k]+1;
                end
                2: begin
                    ref_curr[k]=$signed(memory[ref_pos[k]/2])*256;
                    next_pos=ref_pos[k]+2;
                end
                3: begin
                    ref_curr[k]=$signed({memory[ref_pos[k]/2+1],memory[ref_pos[k]/2]});
                    next_pos=ref_pos[k]+4;
                end
                endcase
                if(next_pos==(first_addr+2)*2 && !ref_saved[k]) begin
                    ref_loop_sig[k]=ref_sig[k];
                    ref_loop_stp[k]=ref_stp[k];
                    ref_saved[k]=1;
                end
                if(next_pos>=(first_addr+8)*2) begin
                    next_pos=(first_addr+2)*2;
                    ref_sig[k]=ref_loop_sig[k];
                    ref_stp[k]=ref_loop_stp[k];
                end
                ref_pos[k]=next_pos;
            end
            interp=(ref_prev[k]*(512-ref_phase[k])+ref_curr[k]*ref_phase[k])>>>9;
            left_gain=ref_pan[k]<=8 ? ref_vol[k] : ref_vol[k]*(15-ref_pan[k])/7;
            right_gain=ref_pan[k]>=8 ? ref_vol[k] : ref_vol[k]*(ref_pan[k]-1)/7;
            sum_l=sum_l+interp*left_gain;
            sum_r=sum_r+interp*right_gain;
            ref_phase[k]=ref_phase[k]+(ref_mode[k]==1 ? ref_freq[k]&255 : ref_freq[k])+1;
            if(uut.position[k]!==25'(ref_pos[k]) || uut.phase[k]!==10'(ref_phase[k]) ||
               uut.curr_data[k]!==16'(ref_curr[k])) $fatal(1,"voice scoreboard frame=%0d ch=%0d",n,k);
            checks=checks+1;
        end
        expected_l=sum_l>>>9; expected_r=sum_r>>>9;
        if(expected_l>32767) expected_l=32767;
        if(expected_l< -32768) expected_l= -32768;
        if(expected_r>32767) expected_r=32767;
        if(expected_r< -32768) expected_r= -32768;
    end

    reset_chip;
    write_reg(8'hff,8'h90); write_reg(8'hfe,0);
    for(k=0;k<8;k=k+1) voice_setup(k,2,0,511,k, k+1,255,8);
    run_frame;
    if(uut.status!==255 || irq) $fatal(1,"masked simultaneous endings");
    write_reg(8'hfe,8'h80);
    if(!irq) $fatal(1,"pending IRQ mask enable");
    read_port(1,value);
    if(value!==255 || irq) $fatal(1,"all voice status clear");

    reset_chip;
    latency=20;
    write_reg(8'hff,8'h90); write_reg(8'hfe,1);
    voice_setup(0,3,0,511,0,100,255,8);
    bus_write(0,1);
    cen=1;
    wait(rom_cs);
    bus_write(1,8'h60);
    cen=0;
    repeat(100) @(negedge clk);
    if(rom_cs || uut.playing[0] || uut.position[0]!=0 || irq)
        $fatal(1,"keyoff during memory wait");
    bus_write(1,8'he1);
    latency=3;
    run_frame;
    if(!uut.playing[0] || uut.position[0]!=4) $fatal(1,"keyon after cancelled fetch");

    reset_chip;
    latency=400;
    write_reg(8'hff,8'h80);
    voice_setup(0,2,0,511,0,100,255,8);
    cen=1;
    repeat(1000) @(negedge clk);
    if(!overrun) $fatal(1,"missing overrun diagnostic");
    $display("PASS YMZ280B: %0d checks, %0d continuous frames",checks,frames);
    $finish;
end

initial begin
    #100000000;
    $fatal(1,"timeout");
end
endmodule
