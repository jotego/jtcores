`timescale 1ns/1ps

module test;
localparam SIZE=512;
reg clk=0, rst=1, cs=0, cpu_we=0, bk=0, start=0;
reg [1:0] div=0;
reg [12:0] cpu_addr=0;
reg [7:0] cpu_dout=0;
wire cen, out0, cpu2ram_we, ram_we, ram_oe;
wire [12:0] ram_addr;
wire [7:0] cpu_din, cpu_ram_dout, ram_dout, ram_din;
reg [7:0] program_common[0:319], program_alternate[0:319];
reg [7:0] initial_mem[0:SIZE-1], expected[0:SIZE-1];
integer variant, case_id, a, n, p, q, s0, s1, count0, count1;
integer xdist, ydist, threshold, timeout, seed=32'h52591;
integer random_value;
reg [7:0] observed;
assign cen=div==0;
always #10 clk=~clk;
always @(posedge clk) div<=div+1'd1;

jt052591 uut(
    .rst(rst), .clk(clk), .cen(cen), .cs(cs), .cpu_we(cpu_we),
    .cpu_addr(cpu_addr), .cpu_dout(cpu_dout), .cpu_ram_dout(cpu_ram_dout),
    .cpu_din(cpu_din), .cpu2ram_we(cpu2ram_we), .bk(bk), .start(start),
    .out0(out0), .ram_addr(ram_addr), .ram_din(ram_din), .ram_we(ram_we),
    .ram_oe(ram_oe), .ram_dout(ram_dout), .st_dout()
);
jtframe_dual_ram #(.AW(13)) u_ram(
    .clk0(clk), .data0(cpu_dout), .addr0(cpu_addr), .we0(cpu2ram_we), .q0(cpu_ram_dout),
    .clk1(clk), .data1(ram_din), .addr1(ram_addr), .we1(ram_we), .q1(ram_dout)
);

// Deliberately hold each write over several enables: one CPU cycle is one byte.
task host_write;
    input [12:0] address;
    input [7:0] data;
    begin
        @(negedge clk); cpu_addr=address; cpu_dout=data; cs=1; cpu_we=1;
        repeat(12) @(negedge clk);
        cs=0; cpu_we=0;
        repeat(4) @(negedge clk);
    end
endtask

task host_read;
    input [12:0] address;
    output [7:0] data;
    begin
        @(negedge clk); cpu_addr=address; cs=1; cpu_we=0;
        repeat(8) @(negedge clk);
        data=cpu_din; cs=0;
    end
endtask

function [7:0] random_byte;
    input integer dummy;
    begin
        random_value=$random(seed);
        random_byte=random_value[7:0];
    end
endfunction

task object;
    input integer address;
    input [7:0] flags, width, height, x, y;
    begin
        initial_mem[address]=flags;
        initial_mem[address+1]=width;
        initial_mem[address+2]=height;
        initial_mem[address+3]=x;
        initial_mem[address+4]=y;
    end
endtask

// This is an object-level specification derived from the decoded instructions,
// independent of DUT ALU, PC, instruction fetch and external-bus implementation.
task model;
    begin
        for(a=0;a<SIZE;a=a+1) expected[a]=initial_mem[a];
        for(p=s0;p<s0+5*count0;p=p+5) begin
            if((expected[p]&expected[3])!=0) begin : candidates
                // Instruction 34 continues on carry from end - next, inclusive.
                for(q=s1;q<=s1+5*(count1-1);q=q+5) begin
                    xdist=integer'(expected[q+3])-integer'(expected[p+3]);
                    ydist=integer'(expected[q+4])-integer'(expected[p+4]);
                    if(xdist<0) xdist=-xdist;
                    if(ydist<0) ydist=-ydist;
                    // Instructions 1d/24 reject equality as well as separation.
                    if((expected[q]&expected[4])!=0 &&
                       xdist<integer'(expected[q+1])+integer'(expected[p+1]) &&
                       ydist<integer'(expected[q+2])+integer'(expected[p+2])) begin
                        expected[q]=(expected[q]&8'h9f)|8'h10;
                        if(p+4>=threshold)
                            expected[p]=(expected[p]&8'h9b)|(expected[q]&8'h04)|8'h10;
                        disable candidates;
                    end
                end
            end
        end
    end
endtask

// Host-visible controls, separate from the collision program's behavior.
task upload_word;
    input [39:0] data;
    integer byte_index;
    begin
        for(byte_index=0;byte_index<5;byte_index=byte_index+1)
            host_write(13'h000,data[byte_index*8+:8]);
    end
endtask

task host_controls;
    integer bank;
    begin
        bk=1; host_write(13'h123,8'ha6);
        for(bank=0;bank<2;bank=bank+1) begin
            bk=bank;
            host_read(13'h123,observed);
            if(observed!==(bank==0 ? 8'hff : 8'ha6)) begin
                $display("FAIL external CPU read BK=%0d value=%02h",bank,observed); $fatal(1);
            end
        end
        // Unlocked entry zero contains an infinite loop. START must prevent
        // both configuration and instruction writes, even with PC unlocked.
        bk=0; host_write(13'h200,8'h3f);
        upload_word(40'h08e000fe5f); // Sentinel if a live PC write is accepted.
        upload_word(40'h08ad0000e7);
        host_write(13'h200,8'h00);
        @(negedge clk); start=1;
        repeat(80) @(negedge clk);
        upload_word(40'h08e000fe5f); // Attempt to replace loop with completion.
        host_write(13'h200,8'hbf);   // Attempt to change entry point to 63.
        bk=1; host_write(13'h123,8'h59);
        repeat(80) @(negedge clk);
        if(out0!==1'b1) begin $display("FAIL program changed during START"); $fatal(1); end
        @(negedge clk); start=0;
        repeat(16) @(negedge clk);
        host_read(13'h123,observed);
        if(observed!==8'ha6) begin $display("FAIL CPU external write during START"); $fatal(1); end
        // Re-start without reconfiguring: an ignored PC write must not have
        // altered the next entry point, nor may the loop have been rewritten.
        @(negedge clk); start=1;
        repeat(160) @(negedge clk);
        if(out0!==1'b1) begin $display("FAIL loader changed while running"); $fatal(1); end
        @(negedge clk); start=0;
        repeat(16) @(negedge clk);
        // Upload from slot 63. OUT0=1 at 63 must fall through to OUT0=0 at
        // wrapped slot 0. The upper nibble of each fifth host byte is garbage.
        bk=0; host_write(13'h200,8'h3f);
        upload_word(40'hf8e001fe5f);
        upload_word(40'ha8e000fe5f);
        host_write(13'h200,8'hbf);
        @(negedge clk); start=1;
        timeout=0;
        while(out0!==1'b0 && timeout<160) begin
            @(negedge clk); timeout=timeout+1;
        end
        if(timeout==160) begin
            $display("FAIL nonzero entry / upload wrap / fifth-byte nibble"); $fatal(1);
        end
        @(negedge clk); start=0;
        repeat(16) @(negedge clk);
    end
endtask

initial begin
    $dumpfile("test.lxt");
    $dumpvars(1,test);
    $readmemh("thunderx.hex",program_common);
    $readmemh("thunderxa.hex",program_alternate);
    repeat(8) @(negedge clk); rst=0;
    host_controls;
    for(variant=0;variant<2;variant=variant+1) begin
        bk=0;
        host_write(13'h200,8'h00);
        for(n=0;n<320;n=n+1)
            host_write(13'h000,variant==0 ? program_common[n] : program_alternate[n]);
        host_write(13'h200,8'h81);
        threshold=variant==0 ? 'he6 : 'h136;
        // Each run reuses the uploaded program and its locked entry point.
        for(case_id=0;case_id<80;case_id=case_id+1) begin
            bk=1;
            for(a=0;a<SIZE;a=a+1) initial_mem[a]=random_byte(0);
            s0=threshold-4; s1=32; count0=4; count1=5;
            initial_mem[3]=8'h01; initial_mem[4]=8'h02;
            for(n=0;n<count0;n=n+1)
                object(s0+5*n,random_byte(0),random_byte(0),random_byte(0),random_byte(0),random_byte(0));
            for(n=0;n<count1;n=n+1)
                object(s1+5*n,random_byte(0),random_byte(0),random_byte(0),random_byte(0),random_byte(0));
            if(case_id<24) begin
                count0=1; count1=2;
                object(s0,8'he5,8'd10,8'd20,8'd100,8'd100);
                object(s1,8'he6,8'd15,8'd30,8'd100,8'd100);
                object(s1+5,8'he2,8'd15,8'd30,8'd100,8'd100);
                case(case_id)
                    0: begin end // First hit only; threshold equality writable.
                    1: initial_mem[s1+3]=125; // Exact x boundary misses first candidate.
                    2: initial_mem[s1+3]=124; // One pixel inside.
                    3: initial_mem[s1+3]=126; // One pixel outside.
                    4: initial_mem[s1+4]=150; // Exact y boundary.
                    5: initial_mem[s1+4]=149;
                    6: initial_mem[s1+4]=151;
                    7: begin initial_mem[s0+1]=200; initial_mem[s1+1]=200;
                             initial_mem[s0+3]=0; initial_mem[s1+3]=255; end
                    8: begin initial_mem[s0+2]=200; initial_mem[s1+2]=200;
                             initial_mem[s0+4]=255; initial_mem[s1+4]=0; end
                    9: initial_mem[s0]=8'he4; // Collide mask excludes object0.
                    10: initial_mem[s1]=8'he4; // Hit mask excludes first object1.
                    11: begin // Last candidate at inclusive end must be tested.
                        initial_mem[s1]=0; initial_mem[s1+5]=8'he6;
                    end
                    12: begin // Protected flags just below writable threshold.
                        s0=threshold-5;
                        object(s0,8'he5,8'd10,8'd20,8'd100,8'd100);
                    end
                    13: begin initial_mem[3]=0; initial_mem[4]=0; end
                    14: begin initial_mem[s0+1]=0; initial_mem[s1+1]=0;
                              initial_mem[s1+6]=0; end // Coincident zero-width boxes miss.
                    15: begin initial_mem[s0+3]=255; initial_mem[s1+3]=0;
                              initial_mem[s1+8]=0; end // Coordinates do not wrap.
                    16: initial_mem[s1+3]=75; // Negative exact x boundary.
                    17: initial_mem[s1+3]=76;
                    18: initial_mem[s1+3]=74;
                    19: initial_mem[s1+4]=50; // Negative exact y boundary.
                    20: initial_mem[s1+4]=51;
                    21: initial_mem[s1+4]=49;
                    22: begin initial_mem[3]=8'h80; initial_mem[4]=8'h80; end
                    23: begin // One byte above the protected region boundary.
                        s0=threshold-3;
                        object(s0,8'he5,8'd10,8'd20,8'd100,8'd100);
                    end
                endcase
            end
            initial_mem[0]=(s0+count0*5)>>8;
            initial_mem[1]=(s0+count0*5)&255;
            initial_mem[2]=s1+(count1-1)*5;
            if(variant==0) begin initial_mem[5]=s0; initial_mem[6]=s1; end
            else begin initial_mem[5]=s0>>8; initial_mem[6]=s0&255; initial_mem[7]=s1; end
            model;
            for(a=0;a<SIZE;a=a+1) host_write(a,initial_mem[a]);
            @(negedge clk); start=1;
            timeout=0;
            while(out0!==1'b0 && timeout<100000) begin
                @(negedge clk); timeout=timeout+1;
            end
            if(timeout==100000) begin
                $display("FAIL program timeout variant=%0d case=%0d",variant,case_id);
                $fatal(1);
            end
            @(negedge clk); start=0;
            repeat(16) @(negedge clk);
            if(out0!==1'b1) begin $display("FAIL OUT0 not restored on STOP"); $fatal(1); end
            for(a=0;a<SIZE;a=a+1) begin
                host_read(a,observed);
                if(observed!==expected[a]) begin
                    $display("FAIL variant=%0d case=%0d addr=%03h expected=%02h observed=%02h initial=%02h",variant,case_id,a,expected[a],observed,initial_mem[a]);
                    $fatal(1);
                end
            end
        end
    end
    $display("PASS: both Thunder Cross programs, 160 fixtures, full RAM comparison");
    $finish;
end
endmodule
