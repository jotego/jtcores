`timescale 1ns/1ps
module test;

reg clk=0, rst=1;
reg [31:0] gp_out=0;
reg [3:0] pins=4'ha;
wire [31:0] gp_in;
reg [23:0] reply;
reg [15:0] expected;
integer bit_index, word_index;
reg [15:0] serial_words[0:11];
reg [3:0] yamaha_pins;
integer i, stride, stopped_count, clocks=0, last_sample=-1;
reg check_period=0;

always #5 clk=~clk;
always @(posedge clk) begin
    clocks=clocks+1;
    if (check_period && uut.take_sample) begin
        if (last_sample>=0 && clocks-last_sample!=7) begin
            $display("FAIL sample divider"); $finish;
        end
        last_sample=clocks;
    end
end

c96_capture #(.AW(5)) uut(
    .clk(clk), .rst(rst), .pins(pins), .gp_out(gp_out), .gp_in(gp_in)
);

task automatic check(input bit condition, input string message);
    if (!condition) begin $display("FAIL %s",message); $finish; end
endtask

task automatic cmd(input [5:0] op, input [23:0] value, input bit want_error);
    integer n;
    reg toggle;
    begin
        // Change command at several phases relative to the FPGA clock.
        #(3+(clocks%5));
        toggle=~gp_out[31];
        gp_out={toggle,1'b0,op,value};
        n=0;
        while (gp_in[31]!==toggle && n<100) begin #3; n=n+1; end
        check(n<100,"command timeout");
        check(gp_in[29:24]===op,"reply opcode");
        check(gp_in[30]===want_error,"reply error flag");
        reply=gp_in[23:0];
        #11;
    end
endtask

task automatic wait_done;
    integer n;
    begin
        n=0;
        cmd(3,0,0);
        while (reply[0] && n<1000) begin cmd(3,0,0); n=n+1; end
        check(n<1000 && reply[1],"capture completion");
    end
endtask

task automatic verify(input integer words, input [15:0] initial_seed);
    reg [15:0] x;
    integer j;
    begin
        x=initial_seed;
        for (j=0;j<words;j=j+1) begin
            cmd(8,24'(j),0);
            check(reply=={8'd0,x},"captured sample");
            // Independent reference: bit mask/parity rather than concatenation.
            x=(x<<1) | {15'd0,^(x & 16'hb400)};
        end
    end
endtask

initial begin
    $dumpfile("test.lxt"); $dumpvars(0,test);
    #42; @(negedge clk); rst=0;
    cmd(0,0,0); check(reply==24'h960104,"protocol identity");
    cmd(1,0,0); check(reply==32,"capacity");
    cmd(8,0,1); // No completed acquisition yet.
    cmd(4,0,1); cmd(4,24'h10000,1);
    cmd(5,0,1); cmd(5,33,1); cmd(9,0,1); cmd(63,0,1);
    cmd(4,1,0); cmd(5,32,0); cmd(9,7,0);
    check_period=1;
    cmd(6,123,0);
    #2; gp_out={~gp_out[31],1'b1,6'd7,24'd0};
    wait(gp_in[31]==gp_out[31]);
    check(gp_in[30],"reserved command bit rejected");
    wait_done();
    check_period=0;
    check(reply==6,"full completion flags");
    cmd(2,0,0); check(reply==32,"full sample count");
    cmd(10,0,0); check(reply==123,"capture id");
    // Seed 1 starts 0001,0002,0004,...,0400,0801,1002,2005,400b,8016.
    cmd(8,11,0); check(reply==16'h0801,"independent LFSR known vector");
    verify(32,1);
    cmd(8,32,1); cmd(8,24'h800000,1);
    #1000; cmd(2,0,0); check(reply==32,"no buffer overwrite");
    verify(32,1);
    cmd(4,16'hace1,0); cmd(5,31,0); cmd(9,1,0);
    cmd(6,124,0); wait_done(); check(reply==2,"short completion flags");
    verify(31,16'hace1);
    cmd(5,1,0); cmd(6,125,0); wait_done();
    cmd(2,0,0); check(reply==1,"single sample"); verify(1,16'hace1);
    cmd(5,32,0); cmd(9,100,0); cmd(6,126,0);
    cmd(6,999,1); cmd(4,3,1); cmd(5,2,1); cmd(9,2,1); cmd(8,0,1);
    #2200; cmd(7,0,0);
    cmd(3,0,0); check(reply==10,"stop flags");
    cmd(2,0,0); stopped_count=reply;
    check(stopped_count>0 && stopped_count<32,"partial capture count");
    #2000; cmd(2,0,0); check(reply==24'(stopped_count),"stopped count stable");
    cmd(10,0,0); check(reply==126,"rejected arm preserves id");
    verify(stopped_count,16'hace1);
    cmd(7,0,0); cmd(2,0,0); check(reply==24'(stopped_count),"stop idempotence");
    // Same request held: no second command or capture can be accepted.
    #3000; cmd(2,0,0); check(reply==24'(stopped_count),"toggle executes once");
    cmd(6,127,0);
    @(negedge clk); rst=1; gp_out=0;
    repeat(4) @(negedge clk);
    rst=0;
    cmd(3,0,0); check(reply==0,"reset cancels capture");
    cmd(2,0,0); check(reply==0,"reset clears count");
    cmd(8,0,1); // Old RAM contents are not exportable after reset.
    cmd(5,1,0); cmd(6,128,0); wait_done(); verify(1,1);
    cmd(14,4,1); cmd(16,16,1); cmd(18,4,1);
    cmd(14,1,0); cmd(16,15,0); cmd(18,3,0);
    cmd(15,0,0); check(reply==1,"raw mode retained");
    cmd(17,0,0); check(reply==15,"polarity retained");
    cmd(19,0,0); check(reply==3,"format retained");
    cmd(5,32,0); cmd(9,1,0); cmd(6,129,0); wait_done();
    for (i=0;i<32;i=i+1) begin
        cmd(8,24'(i),0); check(reply==10,"raw input is not polarity corrected");
    end
    cmd(14,2,0); cmd(6,130,0);
    cmd(14,0,1); cmd(16,0,1); cmd(18,0,1);
    cmd(2,0,0); check(reply==0,"missing bit clock cannot generate PCM words");
    cmd(7,0,0); cmd(3,0,0); check(reply==10,"clockless capture can stop");
    // Entire asynchronous pin -> decoder -> capture RAM -> HPS indexed read path.
    serial_words[0]=16'h1111; serial_words[1]=16'h2222;
    serial_words[2]=16'h8000; serial_words[3]=16'h7fff;
    serial_words[4]=16'hffff; serial_words[5]=16'h0001;
    serial_words[6]=16'h5555; serial_words[7]=16'haaaa;
    serial_words[8]=16'h1234; serial_words[9]=16'h0000;
    serial_words[10]=16'h1357; serial_words[11]=16'h2468;
    pins=15;
    cmd(18,0,0); cmd(5,8,0); cmd(6,131,0);
    for (word_index=0;word_index<12;word_index=word_index+1) begin
        for (bit_index=15;bit_index>=0;bit_index=bit_index-1) begin
            pins={1'b0,serial_words[word_index][bit_index],1'b0,word_index[0]} ^ 4'hf;
            #103;
            pins[1]=0; // Corrected rising DTCK; no direct FPGA clock relationship.
            #97;
        end
    end
    wait_done(); check(reply==2,"PCM completion flags");
    cmd(2,0,0); check(reply==8,"PCM bounded capture count");
    cmd(21,0,0); check(reply==0,"PCM clean framing");
    for (i=0;i<8;i=i+1) begin
        cmd(8,24'(i),0);
        check(reply=={8'd0,serial_words[i+2]},"PCM RAM/readout polarity and phase order");
    end
    // Yamaha: alternate SH edges, preserve all sixteen SO bits and start at latch 0.
    yamaha_pins=3; pins=yamaha_pins^15;
    cmd(14,3,0); cmd(18,0,0); cmd(5,8,0); cmd(6,132,0);
    for(word_index=0;word_index<12;word_index=word_index+1) begin
        yamaha_pins[word_index%2]=0;
        for(bit_index=0;bit_index<16;bit_index=bit_index+1) begin
            if(bit_index==8) yamaha_pins[(word_index+1)%2]=1;
            yamaha_pins[2]=serial_words[word_index][bit_index];
            pins=yamaha_pins^15;
            #560;
        end
    end
    wait_done(); check(reply==2,"Yamaha completion flags");
    cmd(2,0,0); check(reply==8,"Yamaha bounded capture count");
    cmd(21,0,0); check(reply==0,"Yamaha clean framing");
    cmd(22,0,0); check(reply==1792,"Yamaha measured frame clocks");
    for(i=0;i<8;i=i+1) begin
        cmd(8,24'(i),0);
        check(reply=={8'd0,serial_words[i+1]},"Yamaha RAM/readout packing and channel order");
    end
    // Independent source words encode their absolute serial index. Selected
    // frames must contain adjacent latch-0/latch-1 words, with exactly stride
    // native frames between pairs, including the maximum 1024-frame stride.
    for(i=0;i<4;i=i+1) begin
        case(i) 0:stride=1; 1:stride=2; 2:stride=3; 3:stride=1024; endcase
        if(stride==1024) $dumpoff;
        yamaha_pins=3; pins=yamaha_pins^15;
        cmd(9,24'(stride),0); cmd(5,i==2 ? 5 : 6,0); cmd(6,24'(140+i),0);
        for(word_index=0;word_index<4*stride+4;word_index=word_index+1) begin
            expected=16'h3000+16'(word_index);
            yamaha_pins[word_index%2]=0;
            for(bit_index=0;bit_index<16;bit_index=bit_index+1) begin
                if(bit_index==8) yamaha_pins[(word_index+1)%2]=1;
                yamaha_pins[2]=expected[bit_index];
                pins=yamaha_pins^15;
                #560;
            end
        end
        wait_done(); check(reply==2,"decimated completion flags");
        cmd(21,0,0); check(reply==0,"decimated clean framing");
        for(word_index=0;word_index<(i==2 ? 5 : 6);word_index=word_index+1) begin
            expected=16'h3001+16'(2*stride*(word_index/2)+word_index%2);
            cmd(8,24'(word_index),0);
            check(reply=={8'd0,expected},"decimation retains complete indexed pairs");
        end
    end
    cmd(9,1025,1); cmd(9,0,1);
    cmd(14,0,0); cmd(9,1025,0); cmd(14,3,0);
    cmd(6,150,1); // Changing modes cannot bypass the stride limit.
    cmd(9,1024,0); cmd(5,6,0); cmd(6,151,0);
    yamaha_pins=3; pins=yamaha_pins^15;
    for(word_index=0;word_index<4;word_index=word_index+1) begin
        yamaha_pins[word_index%2]=0;
        for(bit_index=0;bit_index<16;bit_index=bit_index+1) begin
            if(bit_index==8) yamaha_pins[(word_index+1)%2]=1;
            pins=yamaha_pins^15;
            #560;
        end
    end
    #30000; // Missing strobes during an unretained frame must still be errors.
    cmd(21,0,0); check(reply!=0,"framing errors survive decimation");
    cmd(2,0,0); stopped_count=reply;
    check(stopped_count==2,"one complete pair before skipped frames");
    cmd(7,0,0); cmd(3,0,0); check(reply==10,"stride capture stops after skipped frames");
    #2000; cmd(2,0,0); check(reply==24'(stopped_count),"stopped stride count stable");
    cmd(9,1,0); cmd(6,152,0);
    @(negedge clk); rst=1; gp_out=0;
    repeat(4) @(negedge clk);
    rst=0;
    check(uut.frame_skip==0 && !uut.select_frame,"reset clears pair selection");
    $display("PASS finite capture: PRNG, raw, PCM, Yamaha and HPS protocol"); $finish;
end

initial begin #100000000; $display("FAIL watchdog"); $finish; end
endmodule
