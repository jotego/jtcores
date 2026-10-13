`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg rst=1, swap_bytes=0, sclk=0, sdi=0, scs=0;
wire sdo, busy;
reg [25:0] ioctl_addr=0;
reg [7:0] ioctl_dout=0;
reg ioctl_wr=0, ioctl_ram=0;
wire [7:0] ioctl_din;
reg [7:0] expected [0:127];
reg [15:0] word_q;
integer n, mode;
jtosman_eeprom dut(.*);

task tick;
    input integer count;
    repeat(count) begin @(posedge clk); #1; end
endtask
task bit_out;
    input value;
    begin
        @(negedge clk); sclk=0; sdi=value;
        tick(4);
        @(negedge clk); sclk=1;
        tick(4);
        @(negedge clk); sclk=0;
        tick(4);
    end
endtask
task command;
    input [1:0] op;
    input [5:0] addr;
    integer k;
    begin
        @(negedge clk); scs=0; sclk=0; sdi=0;
        tick(4);
        @(negedge clk); scs=1;
        bit_out(0); bit_out(1);
        bit_out(op[1]); bit_out(op[0]);
        for(k=5; k>=0; k=k-1) bit_out(addr[k]);
    end
endtask
task read_word;
    input [5:0] addr;
    integer k;
    begin
        command(2'b10,addr);
        for(k=15; k>=0; k=k-1) begin
            bit_out(0);
            word_q[k]=sdo;
        end
        @(negedge clk); scs=0;
        tick(4);
    end
endtask
task write_word;
    input [5:0] addr;
    input [15:0] value;
    integer k;
    begin
        command(2'b00,6'b110000); // EWEN
        @(negedge clk); scs=0;
        tick(4);
        command(2'b01,addr);
        for(k=15; k>=0; k=k-1) bit_out(value[k]);
        @(negedge clk); scs=0;
        tick(4);
    end
endtask
task upload_check;
    integer k;
    begin
        @(negedge clk); ioctl_ram=1;
        for(k=0; k<128; k=k+1) begin
            @(negedge clk); ioctl_addr=k;
            tick(2);
            if(ioctl_din !== expected[k])
                $fatal(1,"upload[%0d]: got %02x expected %02x",k,ioctl_din,expected[k]);
            if(busy) $fatal(1,"upload must not reset the CPU");
        end
        @(negedge clk); ioctl_ram=0;
        tick(3);
    end
endtask
task download;
    input integer delay_cycles;
    integer k;
    begin
        @(negedge clk); ioctl_ram=1;
        for(k=0; k<128; k=k+1) begin
            @(negedge clk); ioctl_addr=k; ioctl_dout=expected[k]; ioctl_wr=1;
            tick(1);
            if(!busy) $fatal(1,"restore did not hold CPU reset");
            if(delay_cycles>0) begin
                @(negedge clk); ioctl_wr=0;
                tick(delay_cycles);
            end
        end
        // Change address immediately after the final byte: delayed word must
        // still land at 63. Drop ioctl_ram before the pending write commits.
        @(negedge clk); ioctl_wr=0; ioctl_ram=0; ioctl_addr=0;
        tick(1);
        if(delay_cycles==0 && !busy) $fatal(1,"restore released before final write settled");
        tick(3);
        if(busy) $fatal(1,"restore never finished");
    end
endtask
task serial_check;
    integer k;
    reg [15:0] wanted;
    begin
        for(k=0; k<64; k=k+1) begin
            read_word(k);
            wanted=swap_bytes ? {expected[2*k+1],expected[2*k]} :
                                {expected[2*k],expected[2*k+1]};
            if(word_q !== wanted)
                $fatal(1,"serial word[%0d]: got %04x expected %04x",k,word_q,wanted);
        end
    end
endtask

initial begin
    tick(8);
    @(negedge clk); rst=0;
    tick(70);
    for(n=0;n<128;n=n+1) expected[n]=8'hff;
    expected[0]=8'hff; expected[1]=8'hbe;
    expected[64]=8'h00; expected[65]=8'h88;
    download(0);
    read_word(0);
    if(word_q!==16'hffbe) $fatal(1,"Osman word 0 = %04x",word_q);
    read_word(32);
    if(word_q!==16'h0088) $fatal(1,"Osman word 32 = %04x",word_q);
    upload_check();
    for(mode=0; mode<2; mode=mode+1) begin
        swap_bytes=mode;
        // Defaults downloaded under ROM reset, with realistic gaps.
        rst=1;
        for(n=0;n<128;n=n+1) expected[n]=(n*37+11)&255;
        download(5);
        rst=0; tick(4);
        serial_check(); upload_check();
        // Saved settings overwrite defaults without a global reset, at one
        // byte per clock. Exercise every address including first/last words.
        for(n=0;n<128;n=n+1) expected[n]=255-n;
        download(0);
        serial_check(); upload_check();
        // Serial CPU write is immediately visible to the save interface.
        write_word(32,16'h0088);
        expected[64]=swap_bytes ? 8'h88 : 8'h00;
        expected[65]=swap_bytes ? 8'h00 : 8'h88;
        upload_check();
        @(negedge clk); rst=1;
        tick(4);
        @(negedge clk); rst=0;
        tick(4);
        serial_check(); upload_check();
        // A ROM download / out-of-range byte must not alias the EEPROM.
        @(negedge clk); ioctl_ram=0; ioctl_wr=1; ioctl_addr=0; ioctl_dout=0;
        tick(2);
        @(negedge clk); ioctl_ram=1; ioctl_addr=128;
        tick(2);
        @(negedge clk); ioctl_addr=129;
        tick(2);
        @(negedge clk); ioctl_wr=0; ioctl_ram=0;
        tick(4);
        upload_check();
    end
    $display("PASS: defaults, saved restore, serial read/write, upload, reset, byte order, bounds");
    $finish;
end
initial begin #10000000; $fatal(1,"timeout"); end
endmodule
