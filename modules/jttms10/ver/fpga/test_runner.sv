// SPDX-License-Identifier: GPL-3.0-or-later
// Exercise the same Avalon window as the HPS transport; expectations stay in Python.
module test;
    reg clk=0;
    always #10 clk=~clk;
    reg reset_n=0;
    reg [3:0] avs_address=0;
    reg avs_read=0, avs_write=0;
    wire [31:0] avs_readdata;
    reg [31:0] avs_writedata=0;
    wire avs_waitrequest;
    reg [31:0] descriptor [0:255];
    reg [31:0] program_words [0:4095];
    string list_path, descriptor_path, program_path;
    integer file_handle, parsed, case_count, word_count, batch_index=0;
    integer polls, event_count;
    reg [31:0] timeout_clocks=4000000;
    reg [31:0] value, status;

    jttms10_fpga_runner u_runner(.*);

    task automatic write_register(input [3:0] address, input [31:0] data);
        @(negedge clk);
        avs_address=address; avs_writedata=data; avs_write=1;
        @(negedge clk);
        if(avs_waitrequest) $fatal(1,"unexpected Avalon waitrequest");
        avs_write=0;
    endtask

    task automatic read_register(input [3:0] address, output [31:0] data);
        @(negedge clk);
        avs_address=address; avs_read=1;
        @(negedge clk);
        if(avs_waitrequest) $fatal(1,"unexpected Avalon read waitrequest");
        data=avs_readdata; avs_read=0;
    endtask

    initial begin
        if(!$value$plusargs("BATCHES=%s",list_path)) $fatal(1,"missing batch list");
        if($value$plusargs("TIMEOUT=%d",timeout_clocks) && timeout_clocks<1000)
            $fatal(1,"invalid case timeout");
        file_handle=$fopen(list_path,"r");
        if(file_handle==0) $fatal(1,"could not open batch list");
        repeat(4) @(negedge clk);
        reset_n=1;
        read_register(0,value);
        if(value!=32'h4a545231) $fatal(1,"incorrect runner protocol identifier");
        while(!$feof(file_handle)) begin
            parsed=$fscanf(file_handle,"%d %d %s %s\n",case_count,word_count,descriptor_path,program_path);
            if(parsed!=4) $fatal(1,"malformed batch list");
            if(case_count<1 || case_count>32 || word_count<1 || word_count>4096)
                $fatal(1,"invalid staged batch bounds");
            $readmemh(descriptor_path,descriptor);
            $readmemh(program_path,program_words);
            // Zero acknowledges DONE, allowing a new payload without reset/programming.
            write_register(1,0);
            write_register(2,32'(case_count));
            write_register(3,0);
            for(integer q=0;q<case_count*8;q=q+1) write_register(4,descriptor[q]);
            write_register(5,0);
            for(integer q=0;q<word_count;q=q+1) write_register(6,program_words[q]);
            write_register(15,timeout_clocks);
            write_register(1,1);
            polls=0; status=1;
            while(status[0] && !status[31] && polls<200000) begin
                repeat(8) @(negedge clk);
                read_register(1,status);
                polls=polls+1;
            end
            if(status[0] && !status[31]) $fatal(1,"host wall-clock polling timeout");
            $display("CAPTURE_BEGIN %0d %08h",batch_index,status);
            for(integer q=0;q<case_count;q=q+1) begin
                $write("CAPTURE_RESULT %0d",q);
                for(integer r=0;r<72;r=r+1) begin
                    write_register(8,32'(q*72+r));
                    read_register(9,value);
                    $write(" %08h",value);
                end
                $write("\n");
            end
            read_register(7,value);
            $display("CAPTURE_COUNT %08h",value);
            event_count=int'(value & 32'h7fffffff);
            if(event_count>4096) $fatal(1,"invalid hardware event count");
            for(integer q=0;q<event_count;q=q+1) begin
                write_register(10,32'(q));
                $write("CAPTURE_EVENT");
                for(integer r=0;r<4;r=r+1) begin
                    read_register(4'(11+r),value);
                    $write(" %08h",value);
                end
                $write("\n");
            end
            $display("CAPTURE_END %0d",batch_index);
            batch_index=batch_index+1;
        end
        $fclose(file_handle);
        $finish;
    end
endmodule
