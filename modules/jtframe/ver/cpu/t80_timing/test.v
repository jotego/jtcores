`timescale 1ns/1ps
module test;

reg clk=0;
always #5 clk=~clk;

reg reset_n=0;
reg cen=1;
reg wait_n=1;
reg int_n=1;
reg nmi_n=1;
reg busrq_n=1;
reg out0=0;
reg [7:0] io_data=8'h5a;
wire [7:0] di;
wire m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n;
wire [15:0] addr;
wire [7:0] dout;
reg [7:0] vectors[0:8191];
wire [7:0] ram_q;
wire mem_we=reset_n && !mreq_n && !wr_n;
integer i, j, base, count, step, start_idx, end_idx, found;
integer edge_count, fetch_count, trace_fd, trace_edge;
integer io_read_count, io_write_count;
reg [15:0] last_io_write_addr;
reg [7:0] last_io_write_data;
reg [15:0] last_io_read_addr;
reg [7:0] last_io_read_data;
reg prev_io_read,prev_io_write;
reg prev_m1_n=1;
reg [15:0] fetch_pc[0:1023];
integer fetch_edge[0:1023];
reg trace_enable=0;
reg [1023:0] trace_path;
reg [7:0] trace_reset_n,trace_cen,trace_wait_n,trace_int_n,trace_nmi_n;
reg [7:0] trace_busrq_n,trace_out0,trace_di;

T80s uut(
    .RESET_n ( reset_n ), .CLK ( clk ), .CEN ( cen ), .WAIT_n ( wait_n ),
    .INT_n ( int_n ), .NMI_n ( nmi_n ), .BUSRQ_n ( busrq_n ), .OUT0 ( out0 ),
    .DI ( di ), .M1_n ( m1_n ), .MREQ_n ( mreq_n ), .IORQ_n ( iorq_n ),
    .RD_n ( rd_n ), .WR_n ( wr_n ), .RFSH_n ( rfsh_n ), .HALT_n ( halt_n ),
    .BUSAK_n ( busak_n ), .A ( addr ), .DOUT ( dout )
);

assign di=reset_n ? (iorq_n ? ram_q : io_data) : 8'h00;

jtframe_ram #(.DW(8),.AW(16)) u_mem (
    // The helper is synchronous; the falling edge gives the CPU's input
    // data half a master-clock to settle before T80 samples it on rising.
    .clk(~clk), .cen(1'b1), .data(dout), .addr(addr), .we(mem_we), .q(ram_q)
);

always @(posedge clk) begin
    if(trace_enable) begin
        trace_reset_n=reset_n; trace_cen=cen; trace_wait_n=wait_n;
        trace_int_n=int_n; trace_nmi_n=nmi_n; trace_busrq_n=busrq_n;
        trace_out0=out0; trace_di=di;
        #1;
        $fwrite(trace_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%02x,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%04x,%02x\n",
            trace_edge,trace_reset_n,trace_cen,trace_wait_n,trace_int_n,trace_nmi_n,
            trace_busrq_n,trace_out0,trace_di,m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,
            halt_n,busak_n,addr,dout);
        trace_edge=trace_edge+1;
    end
end

always @(posedge clk) begin
    #1;
    if(!reset_n) begin
        edge_count=0;
        fetch_count=0;
        prev_m1_n=1;
    end else begin
        edge_count=edge_count+1;
        if(prev_m1_n && !m1_n && fetch_count<1024) begin
            fetch_pc[fetch_count]=addr;
            fetch_edge[fetch_count]=edge_count;
            fetch_count=fetch_count+1;
        end
        prev_m1_n=m1_n;
    end
end

always @(posedge clk) begin
    #1;
    if(!reset_n) begin
        io_read_count=0; io_write_count=0; prev_io_read=0; prev_io_write=0;
        last_io_read_addr=0; last_io_read_data=0;
    end
    else begin
        if(!iorq_n && !rd_n && !prev_io_read) begin
            io_read_count=io_read_count+1;
            last_io_read_addr=addr;
            last_io_read_data=di;
        end
        if(!iorq_n && !wr_n && !prev_io_write) begin
            io_write_count=io_write_count+1;
            last_io_write_addr=addr;
            last_io_write_data=dout;
        end
        prev_io_read=!iorq_n && !rd_n;
        prev_io_write=!iorq_n && !wr_n;
    end
end

task set_prelude;
    begin
        u_mem.mem[16'h0000]=8'h31; u_mem.mem[16'h0001]=8'h00; u_mem.mem[16'h0002]=8'h60; // LD SP,$6000
        u_mem.mem[16'h0003]=8'h21; u_mem.mem[16'h0004]=8'h00; u_mem.mem[16'h0005]=8'h50; // LD HL,$5000
        u_mem.mem[16'h0006]=8'h11; u_mem.mem[16'h0007]=8'h00; u_mem.mem[16'h0008]=8'h51; // LD DE,$5100
        u_mem.mem[16'h0009]=8'h01; u_mem.mem[16'h000a]=8'h02; u_mem.mem[16'h000b]=8'h00; // LD BC,2
        u_mem.mem[16'h000c]=8'hdd; u_mem.mem[16'h000d]=8'h21; u_mem.mem[16'h000e]=8'h00; u_mem.mem[16'h000f]=8'h50;
        u_mem.mem[16'h0010]=8'hfd; u_mem.mem[16'h0011]=8'h21; u_mem.mem[16'h0012]=8'h00; u_mem.mem[16'h0013]=8'h50;
        u_mem.mem[16'h0014]=8'h3e; u_mem.mem[16'h0015]=8'h01; // LD A,1
        u_mem.mem[16'h0016]=8'hb7; // OR A establishes known flags for directed effects
        u_mem.mem[16'h0017]=8'hc3; u_mem.mem[16'h0018]=8'h00; u_mem.mem[16'h0019]=8'h02; // JP $0200
        u_mem.mem[16'h0200]=8'h76;
        u_mem.mem[16'h5000]=8'h11; u_mem.mem[16'h5010]=8'h22; u_mem.mem[16'h5100]=8'h33; u_mem.mem[16'h5200]=8'h44;
    end
endtask

task reset_cpu;
    begin
        @(negedge clk) reset_n=0;
        repeat(5) @(posedge clk);
        @(negedge clk) reset_n=1;
    end
endtask

task wait_halt;
    integer watchdog;
    begin
        watchdog=0;
        while(halt_n!==0 && watchdog<2000) begin @(posedge clk); watchdog=watchdog+1; end
        if(halt_n!==0) $fatal(1,"program did not reach HALT within 2000 clocks");
        repeat(2) @(posedge clk);
    end
endtask

task run_vector(input integer vector_base, input integer vector_number);
    integer length, expected, target, timeout, k;
    begin
        length=vectors[vector_base];
        expected=vectors[vector_base+1];
        target=16'h0200;
        set_prelude();
        for(k=0;k<4;k=k+1) u_mem.mem[target+k]=vectors[vector_base+2+k];
        u_mem.mem[target+length]=8'h76;
        reset_cpu();
        start_idx=-1; end_idx=-1; timeout=0;
        while(end_idx<0 && timeout<400) begin
            @(posedge clk); #2;
            for(k=0;k<fetch_count;k=k+1) begin
                if(start_idx<0 && fetch_pc[k]==target) start_idx=k;
                if(start_idx>=0 && fetch_pc[k]==target+length) begin end_idx=k; end
            end
            timeout=timeout+1;
        end
        if(start_idx<0 || end_idx<0) begin
            $display("FAIL vector %0d bytes=%02x %02x %02x %02x did not reach closing fetch; PC=%04x HALT_n=%b",
                vector_number,vectors[vector_base+2],vectors[vector_base+3],
                vectors[vector_base+4],vectors[vector_base+5],addr,halt_n);
            $fatal(1);
        end
        if(fetch_edge[end_idx]-fetch_edge[start_idx] != expected) begin
            $display("FAIL vector %0d bytes=%02x %02x %02x %02x expected %0d T, got %0d T",
                vector_number,vectors[vector_base+2],vectors[vector_base+3],
                vectors[vector_base+4],vectors[vector_base+5],expected,
                fetch_edge[end_idx]-fetch_edge[start_idx]);
            $fatal(1);
        end
    end
endtask

task measure_pair(input [15:0] first_pc, input [15:0] next_pc,
                  input integer expected, input [8*24-1:0] case_name);
    integer k, timeout;
    begin
        start_idx=-1; end_idx=-1; timeout=0;
        while(end_idx<0 && timeout<400) begin
            @(posedge clk); #2;
            for(k=0;k<fetch_count;k=k+1) begin
                if(start_idx<0 && fetch_pc[k]==first_pc) start_idx=k;
                if(start_idx>=0 && k>start_idx && fetch_pc[k]==next_pc) end_idx=k;
            end
            timeout=timeout+1;
        end
        if(start_idx<0 || end_idx<0) begin
            $display("FAIL %0s: fetch %04x -> %04x not observed; PC=%04x",
                case_name,first_pc,next_pc,addr);
            $fatal(1);
        end
        if(fetch_edge[end_idx]-fetch_edge[start_idx] != expected) begin
            $display("FAIL %0s: %04x -> %04x expected %0d T, got %0d T",
                case_name,first_pc,next_pc,expected,
                fetch_edge[end_idx]-fetch_edge[start_idx]);
            $fatal(1);
        end
    end
endtask

task condition_flags(input integer condition, input integer taken);
    integer pos;
    reg desired;
    begin
        pos=0;
        u_mem.mem[pos]=8'h31; u_mem.mem[pos+1]=8'h00; u_mem.mem[pos+2]=8'h60; pos=pos+3; // LD SP,$6000
        case(condition)
            0,1: begin
                desired=(condition==1)?taken:!taken;
                if(desired) begin u_mem.mem[pos]=8'haf; pos=pos+1; end
                else begin u_mem.mem[pos]=8'h3e; u_mem.mem[pos+1]=8'h01; pos=pos+2; u_mem.mem[pos]=8'hb7; pos=pos+1; end
            end
            2,3: begin
                desired=(condition==3)?taken:!taken;
                if(desired) begin u_mem.mem[pos]=8'h37; pos=pos+1; end
                else begin u_mem.mem[pos]=8'haf; pos=pos+1; end
            end
            4,5: begin
                desired=(condition==5)?taken:!taken;
                if(desired) begin u_mem.mem[pos]=8'haf; pos=pos+1; end
                else begin u_mem.mem[pos]=8'h3e; u_mem.mem[pos+1]=8'h01; pos=pos+2; u_mem.mem[pos]=8'hb7; pos=pos+1; end
            end
            default: begin
                desired=(condition==7)?taken:!taken;
                if(desired) begin u_mem.mem[pos]=8'h3e; u_mem.mem[pos+1]=8'h80; pos=pos+2; u_mem.mem[pos]=8'hb7; pos=pos+1; end
                else begin u_mem.mem[pos]=8'haf; pos=pos+1; end
            end
        endcase
        u_mem.mem[pos]=8'hc3; u_mem.mem[pos+1]=8'h10; u_mem.mem[pos+2]=8'h00;
        u_mem.mem[16'h6000]=8'h40; u_mem.mem[16'h6001]=8'h00;
    end
endtask

task run_condition_case(input integer family, input integer condition, input integer taken);
    integer opcode, next_pc, expected, length;
    reg [8*24-1:0] case_name;
    begin
        condition_flags(condition,taken);
        case(family)
            0: begin opcode=8'h20+(condition<<3); length=2; expected=taken?12:7; end // JR
            1: begin opcode=8'hc2+(condition<<3); length=3; expected=10; end // JP
            2: begin opcode=8'hc4+(condition<<3); length=3; expected=taken?17:10; end // CALL
            default: begin opcode=8'hc0+(condition<<3); length=1; expected=taken?11:5; end // RET
        endcase
        u_mem.mem[16'h0010]=opcode[7:0];
        if(family==0) begin u_mem.mem[16'h0011]=8'h1e; next_pc=taken?16'h0030:16'h0012; end
        else if(family==1 || family==2) begin
            u_mem.mem[16'h0011]=8'h30; u_mem.mem[16'h0012]=8'h00;
            next_pc=taken?16'h0030:16'h0013;
        end else next_pc=taken?16'h0040:16'h0011;
        u_mem.mem[next_pc]=8'h76;
        reset_cpu();
        $sformat(case_name,"family %0d cc %0d taken %0d",family,condition,taken);
        measure_pair(16'h0010,next_pc,expected,case_name);
        if(family==2 && taken) begin
            if(u_mem.mem[16'h5ffe]!==8'h13 || u_mem.mem[16'h5fff]!==8'h00)
                $fatal(1,"CALL stack bytes wrong for cc=%0d: %02x %02x",condition,u_mem.mem[16'h5fff],u_mem.mem[16'h5ffe]);
        end
    end
endtask

task run_flow_case(input [7:0] opcode, input [15:0] target_pc,
                   input integer expected, input integer kind);
    integer return_pc;
    begin
        u_mem.mem[0]=8'h31; u_mem.mem[1]=8'h00; u_mem.mem[2]=8'h60; // LD SP,$6000
        if(kind==4) begin
            u_mem.mem[3]=8'hc3; u_mem.mem[4]=8'h00; u_mem.mem[5]=8'h01;
            u_mem.mem[16'h0100]=opcode;
        end
        if(kind==3) begin
            u_mem.mem[3]=8'h21; u_mem.mem[4]=target_pc[7:0]; u_mem.mem[5]=target_pc[15:8];
            u_mem.mem[6]=8'hc3; u_mem.mem[7]=8'h10; u_mem.mem[8]=8'h00;
        end else if(kind!=4) begin
            u_mem.mem[3]=8'hc3; u_mem.mem[4]=8'h10; u_mem.mem[5]=8'h00;
        end
        if(kind!=4) u_mem.mem[16'h0010]=opcode;
        if(kind==0 || kind==1) begin
            u_mem.mem[16'h0011]=target_pc[7:0]; u_mem.mem[16'h0012]=target_pc[15:8];
            return_pc=16'h0013;
        end else if(kind==2) begin
            u_mem.mem[16'h6000]=target_pc[7:0]; u_mem.mem[16'h6001]=target_pc[15:8];
            return_pc=0;
        end else if(kind==4) begin
            return_pc=16'h0101;
        end else return_pc=0;
        // RST $00 re-enters the reset vector; preserve its JP-to-test setup
        // instruction so the return fetch remains observable.
        if(target_pc!=0 && target_pc!=16'h0100) u_mem.mem[target_pc]=8'h76;
        reset_cpu();
        measure_pair(kind==4?16'h0100:16'h0010,target_pc,expected,"unconditional control transfer");
        if(kind==1 || kind==4) begin
            if(u_mem.mem[16'h5ffe]!==return_pc[7:0] || u_mem.mem[16'h5fff]!==return_pc[15:8])
                $fatal(1,"control-transfer stack bytes wrong for opcode %02x",opcode);
        end
    end
endtask

task run_jr_unconditional;
    begin
        set_prelude();
        u_mem.mem[16'h0010]=8'h18; u_mem.mem[16'h0011]=8'h1e;
        u_mem.mem[16'h0030]=8'h76;
        reset_cpu();
        measure_pair(16'h0010,16'h0030,12,"JR e taken");
    end
endtask

task run_halt;
    integer timeout,k,first_fetch;
    begin
        set_prelude();
        u_mem.mem[16'h0200]=8'h76;
        reset_cpu();
        timeout=0; first_fetch=-1;
        while(halt_n && timeout<100) begin
            @(posedge clk); #2;
            for(k=0;k<fetch_count;k=k+1)
                if(first_fetch<0 && fetch_pc[k]==16'h0200) first_fetch=k;
            timeout=timeout+1;
        end
        if(halt_n) $fatal(1,"HALT did not assert HALT_n");
        if(first_fetch<0 || edge_count-fetch_edge[first_fetch]!=4)
            $fatal(1,"HALT entry expected 4 T, got %0d",edge_count-fetch_edge[first_fetch]);
    end
endtask

task run_return_from_nmi(input [7:0] opcode);
    begin
        set_prelude();
        u_mem.mem[16'h0010]=8'hed; u_mem.mem[16'h0011]=opcode;
        u_mem.mem[16'h6000]=8'h40; u_mem.mem[16'h6001]=8'h00;
        u_mem.mem[16'h0040]=8'h76;
        reset_cpu();
        measure_pair(16'h0010,16'h0040,14,"RETN/RETI");
    end
endtask

task run_alu_effect(input integer alu, input [7:0] initial_a,
                    input [7:0] operand, input integer set_carry,
                    input [7:0] expected_a, input [7:0] expected_f);
    begin
        set_prelude();
        u_mem.mem[16'h0200]=8'h3e; u_mem.mem[16'h0201]=initial_a;
        if(set_carry) begin u_mem.mem[16'h0202]=8'h37; u_mem.mem[16'h0203]=8'hc6+(alu<<3);
                            u_mem.mem[16'h0204]=operand; end
        else begin u_mem.mem[16'h0202]=8'hc6+(alu<<3); u_mem.mem[16'h0203]=operand; u_mem.mem[16'h0204]=8'h00; end
        u_mem.mem[16'h0205]=8'hf5; // PUSH AF
        u_mem.mem[16'h0206]=8'hc1; // POP BC: B=result A, C=flags
        u_mem.mem[16'h0207]=8'h78; u_mem.mem[16'h0208]=8'h32; u_mem.mem[16'h0209]=8'h00; u_mem.mem[16'h020a]=8'h52;
        u_mem.mem[16'h020b]=8'h79; u_mem.mem[16'h020c]=8'h32; u_mem.mem[16'h020d]=8'h01; u_mem.mem[16'h020e]=8'h52;
        u_mem.mem[16'h020f]=8'h76;
        reset_cpu();
        wait_halt();
        if(u_mem.mem[16'h5200]!==expected_a || (u_mem.mem[16'h5201]&8'hd7)!==(expected_f&8'hd7))
            $fatal(1,"ALU%0d effect A/F expected %02x/%02x got %02x/%02x",alu,expected_a,expected_f,
                   u_mem.mem[16'h5200],u_mem.mem[16'h5201]);
    end
endtask

task run_daa_effect;
    begin
        set_prelude();
        u_mem.mem[16'h0200]=8'h3e; u_mem.mem[16'h0201]=8'h09;
        u_mem.mem[16'h0202]=8'hc6; u_mem.mem[16'h0203]=8'h01; u_mem.mem[16'h0204]=8'h27;
        u_mem.mem[16'h0205]=8'hf5; u_mem.mem[16'h0206]=8'hc1;
        u_mem.mem[16'h0207]=8'h78; u_mem.mem[16'h0208]=8'h32; u_mem.mem[16'h0209]=8'h00; u_mem.mem[16'h020a]=8'h52;
        u_mem.mem[16'h020b]=8'h79; u_mem.mem[16'h020c]=8'h32; u_mem.mem[16'h020d]=8'h01; u_mem.mem[16'h020e]=8'h52;
        u_mem.mem[16'h020f]=8'h76;
        reset_cpu(); wait_halt();
        if(u_mem.mem[16'h5200]!==8'h10 || (u_mem.mem[16'h5201]&8'hd7)!==8'h10)
            $fatal(1,"DAA result/flags expected 10/10 got %02x/%02x",u_mem.mem[16'h5200],u_mem.mem[16'h5201]);
    end
endtask

task run_cb_effect(input [7:0] opcode, input [7:0] initial_b,
                   input [7:0] expected_b, input [7:0] expected_f,
                   input [7:0] flag_mask);
    begin
        set_prelude();
        u_mem.mem[16'h0200]=8'h06; u_mem.mem[16'h0201]=initial_b;
        u_mem.mem[16'h0202]=8'hcb; u_mem.mem[16'h0203]=opcode;
        u_mem.mem[16'h0204]=8'h78; // LD A,B preserves the operation flags
        u_mem.mem[16'h0205]=8'h32; u_mem.mem[16'h0206]=8'h00; u_mem.mem[16'h0207]=8'h52;
        u_mem.mem[16'h0208]=8'hf5; u_mem.mem[16'h0209]=8'hd1; // PUSH AF / POP DE
        u_mem.mem[16'h020a]=8'h7b; u_mem.mem[16'h020b]=8'h32; u_mem.mem[16'h020c]=8'h01; u_mem.mem[16'h020d]=8'h52;
        u_mem.mem[16'h020e]=8'h76;
        reset_cpu(); wait_halt();
        if(u_mem.mem[16'h5200]!==expected_b || (u_mem.mem[16'h5201]&flag_mask)!==(expected_f&flag_mask))
            $fatal(1,"CB %02x result/flags expected %02x/%02x got %02x/%02x",opcode,expected_b,expected_f,u_mem.mem[16'h5200],u_mem.mem[16'h5201]);
    end
endtask

task run_nibble_effect(input [7:0] opcode, input [7:0] expected_a,
                       input [7:0] expected_mem, input [7:0] expected_f);
    begin
        set_prelude(); u_mem.mem[16'h5000]=8'h34;
        u_mem.mem[16'h0200]=8'h3e; u_mem.mem[16'h0201]=8'h12;
        u_mem.mem[16'h0202]=8'hed; u_mem.mem[16'h0203]=opcode;
        u_mem.mem[16'h0204]=8'hf5; u_mem.mem[16'h0205]=8'hd1;
        u_mem.mem[16'h0206]=8'h32; u_mem.mem[16'h0207]=8'h00; u_mem.mem[16'h0208]=8'h52;
        u_mem.mem[16'h0209]=8'h7b; u_mem.mem[16'h020a]=8'h32; u_mem.mem[16'h020b]=8'h01; u_mem.mem[16'h020c]=8'h52;
        u_mem.mem[16'h020d]=8'h7e; u_mem.mem[16'h020e]=8'h32; u_mem.mem[16'h020f]=8'h02; u_mem.mem[16'h0210]=8'h52;
        u_mem.mem[16'h0211]=8'h76;
        reset_cpu(); wait_halt();
        if(u_mem.mem[16'h5200]!==expected_a || u_mem.mem[16'h5202]!==expected_mem ||
           (u_mem.mem[16'h5201]&8'hd7)!==(expected_f&8'hd7))
            $fatal(1,"ED %02x nibble result A/M/F expected %02x/%02x/%02x got %02x/%02x/%02x",opcode,
                expected_a,expected_mem,expected_f,u_mem.mem[16'h5200],u_mem.mem[16'h5202],u_mem.mem[16'h5201]);
    end
endtask

task run_exchange_effect;
    begin
        set_prelude();
        u_mem.mem[16'h0200]=8'heb;
        u_mem.mem[16'h0201]=8'h7c; u_mem.mem[16'h0202]=8'h32; u_mem.mem[16'h0203]=8'h00; u_mem.mem[16'h0204]=8'h52;
        u_mem.mem[16'h0205]=8'h7d; u_mem.mem[16'h0206]=8'h32; u_mem.mem[16'h0207]=8'h01; u_mem.mem[16'h0208]=8'h52;
        u_mem.mem[16'h0209]=8'h7a; u_mem.mem[16'h020a]=8'h32; u_mem.mem[16'h020b]=8'h02; u_mem.mem[16'h020c]=8'h52;
        u_mem.mem[16'h020d]=8'h7b; u_mem.mem[16'h020e]=8'h32; u_mem.mem[16'h020f]=8'h03; u_mem.mem[16'h0210]=8'h52;
        u_mem.mem[16'h0211]=8'h76;
        reset_cpu(); wait_halt();
        if(u_mem.mem[16'h5200]!==8'h51 || u_mem.mem[16'h5201]!==8'h00 ||
           u_mem.mem[16'h5202]!==8'h50 || u_mem.mem[16'h5203]!==8'h00)
            $fatal(1,"EX DE,HL state mismatch");
    end
endtask

task run_indexed_effect(input integer write_indexed);
    begin
        set_prelude();
        u_mem.mem[16'h5010]=8'h22;
        if(write_indexed) begin
            u_mem.mem[16'h0200]=8'hdd; u_mem.mem[16'h0201]=8'h36; u_mem.mem[16'h0202]=8'h10; u_mem.mem[16'h0203]=8'h5a;
            u_mem.mem[16'h0204]=8'h76;
        end else begin
            u_mem.mem[16'h0200]=8'hdd; u_mem.mem[16'h0201]=8'h7e; u_mem.mem[16'h0202]=8'h10;
            u_mem.mem[16'h0203]=8'h32; u_mem.mem[16'h0204]=8'h00; u_mem.mem[16'h0205]=8'h52; u_mem.mem[16'h0206]=8'h76;
        end
        reset_cpu(); wait_halt();
        if(write_indexed ? (u_mem.mem[16'h5010]!==8'h5a) : (u_mem.mem[16'h5200]!==8'h22))
            $fatal(1,"indexed memory %s result mismatch",write_indexed?"write":"read");
    end
endtask

task run_index_jump(input [7:0] prefix);
    begin
        set_prelude();
        u_mem.mem[16'h0200]=prefix; u_mem.mem[16'h0201]=8'h21;
        u_mem.mem[16'h0202]=8'h30; u_mem.mem[16'h0203]=8'h00;
        u_mem.mem[16'h0204]=prefix; u_mem.mem[16'h0205]=8'he9;
        u_mem.mem[16'h0030]=8'h76;
        reset_cpu();
        measure_pair(16'h0204,16'h0030,8,"JP (IX/IY)");
    end
endtask

task run_djnz(input [7:0] initial_b, input integer taken, input [7:0] final_b);
    integer expected, next_pc;
    begin
        u_mem.mem[0]=8'h06; u_mem.mem[1]=initial_b; // LD B,n
        u_mem.mem[2]=8'hc3; u_mem.mem[3]=8'h10; u_mem.mem[4]=8'h00;
        u_mem.mem[16'h0010]=8'h10; u_mem.mem[16'h0011]=8'h0e;
        u_mem.mem[16'h0012]=8'hc3; u_mem.mem[16'h0013]=8'h20; u_mem.mem[16'h0014]=8'h00;
        u_mem.mem[16'h0020]=8'h78; // LD A,B
        u_mem.mem[16'h0021]=8'h32; u_mem.mem[16'h0022]=8'h00; u_mem.mem[16'h0023]=8'h52; // save B
        u_mem.mem[16'h0024]=8'h76;
        reset_cpu();
        next_pc=taken?16'h0020:16'h0012;
        expected=taken?13:8;
        measure_pair(16'h0010,next_pc,expected,"DJNZ counter transition");
        wait_halt();
        if(u_mem.mem[16'h5200]!==final_b)
            $fatal(1,"DJNZ B result expected %02x, got %02x",final_b,u_mem.mem[16'h5200]);
    end
endtask

task set_block_program(input [7:0] opcode, input [15:0] initial_bc,
                       input [7:0] accumulator, input integer decrement);
    reg block_io;
    reg [15:0] bc_value;
    begin
        block_io=(opcode==8'hb2 || opcode==8'hba || opcode==8'hb3 || opcode==8'hbb);
        bc_value=block_io?{initial_bc[7:0],8'h02}:initial_bc;
        u_mem.mem[0]=8'h31; u_mem.mem[1]=8'h00; u_mem.mem[2]=8'h60; // LD SP,$6000
        u_mem.mem[3]=8'h21; u_mem.mem[4]=decrement?8'h01:8'h00; u_mem.mem[5]=8'h50; // LD HL
        u_mem.mem[6]=8'h11; u_mem.mem[7]=decrement?8'h01:8'h00; u_mem.mem[8]=8'h51; // LD DE
        u_mem.mem[9]=8'h01; u_mem.mem[10]=bc_value[7:0]; u_mem.mem[11]=bc_value[15:8];
        u_mem.mem[12]=8'h3e; u_mem.mem[13]=accumulator;
        u_mem.mem[14]=8'hc3; u_mem.mem[15]=8'h20; u_mem.mem[16]=8'h00; // JP $0020
        u_mem.mem[16'h0020]=8'hed; u_mem.mem[16'h0021]=opcode;
        u_mem.mem[16'h0022]=8'h78; u_mem.mem[16'h0023]=8'h32; u_mem.mem[16'h0024]=8'h00; u_mem.mem[16'h0025]=8'h52; // save B
        u_mem.mem[16'h0026]=8'h79; u_mem.mem[16'h0027]=8'h32; u_mem.mem[16'h0028]=8'h01; u_mem.mem[16'h0029]=8'h52; // save C
        u_mem.mem[16'h002a]=8'h7c; u_mem.mem[16'h002b]=8'h32; u_mem.mem[16'h002c]=8'h02; u_mem.mem[16'h002d]=8'h52; // save H
        u_mem.mem[16'h002e]=8'h7d; u_mem.mem[16'h002f]=8'h32; u_mem.mem[16'h0030]=8'h03; u_mem.mem[16'h0031]=8'h52; // save L
        u_mem.mem[16'h0032]=8'h7a; u_mem.mem[16'h0033]=8'h32; u_mem.mem[16'h0034]=8'h04; u_mem.mem[16'h0035]=8'h52; // save D
        u_mem.mem[16'h0036]=8'h7b; u_mem.mem[16'h0037]=8'h32; u_mem.mem[16'h0038]=8'h05; u_mem.mem[16'h0039]=8'h52; // save E
        u_mem.mem[16'h003a]=8'h76;
        u_mem.mem[16'h5000]=8'h55; u_mem.mem[16'h5001]=8'h66;
        u_mem.mem[16'h4fff]=8'h77;
        u_mem.mem[16'h5100]=0; u_mem.mem[16'h5101]=0; u_mem.mem[16'h50ff]=0;
        io_read_count=0; io_write_count=0;
    end
endtask

task observe_repeat(input [7:0] opcode, input [15:0] initial_bc,
                    input [7:0] accumulator, input integer stop_after_one);
    integer first, repeat_fetch, close_fetch, timeout, k, iterations;
    reg [15:0] expected_hl,expected_de;
    integer decrement;
    reg match_first;
    begin
        decrement=(opcode==8'hb8 || opcode==8'hb9 || opcode==8'hba || opcode==8'hbb);
        match_first=((opcode==8'hb1 && accumulator==8'h55) || (opcode==8'hb9 && accumulator==8'h66));
        iterations=(initial_bc==0)?0:(match_first?1:initial_bc);
        set_block_program(opcode,initial_bc,accumulator,decrement);
        reset_cpu();
        first=-1; repeat_fetch=-1; close_fetch=-1; timeout=0;
        while(close_fetch<0 && timeout<500) begin
            @(posedge clk); #2;
            for(k=0;k<fetch_count;k=k+1) begin
                if(first<0 && fetch_pc[k]==16'h0020) first=k;
                if(first>=0 && k>first && repeat_fetch<0 && fetch_pc[k]==16'h0020) repeat_fetch=k;
                if(first>=0 && k>first && fetch_pc[k]==16'h0022) close_fetch=k;
            end
            if(stop_after_one && repeat_fetch>=0) close_fetch=repeat_fetch;
            timeout=timeout+1;
        end
        if(first<0) $fatal(1,"block %02x did not fetch",opcode);
        if(initial_bc==0 || (initial_bc>1 && !match_first)) begin
            if(repeat_fetch<0) $fatal(1,"block %02x missing repeat iteration",opcode);
            if(fetch_edge[repeat_fetch]-fetch_edge[first]!=21)
                $fatal(1,"block %02x repeat count expected 21 T, got %0d",opcode,fetch_edge[repeat_fetch]-fetch_edge[first]);
        end
        if(stop_after_one) begin
            if(repeat_fetch<0) $fatal(1,"block %02x zero-count wrap did not repeat",opcode);
            if(uut.BC !== ((opcode==8'hb2 || opcode==8'hba || opcode==8'hb3 || opcode==8'hbb)?16'hff02:16'hffff))
                $fatal(1,"block %02x zero count did not wrap BC after one iteration: %04x",opcode,uut.BC);
            if(uut.HL !== (decrement?16'h5000:16'h5001))
                $fatal(1,"block %02x zero-count HL update wrong: %04x",opcode,uut.HL);
            if((opcode==8'hb0 || opcode==8'hb8) && uut.DE !== (decrement?16'h5100:16'h5101))
                $fatal(1,"block %02x zero-count DE update wrong: %04x",opcode,uut.DE);
        end else begin
            if(close_fetch<0) $fatal(1,"block %02x did not reach closing fetch",opcode);
            if(fetch_edge[close_fetch]-fetch_edge[repeat_fetch>=0?repeat_fetch:first]!=16)
                $fatal(1,"block %02x terminal iteration expected 16 T, got %0d",opcode,
                    fetch_edge[close_fetch]-fetch_edge[repeat_fetch>=0?repeat_fetch:first]);
            if(halt_n!==0) wait_halt();
            else repeat(2) @(posedge clk);
            if(u_mem.mem[16'h5200]!==8'h00 ||
               u_mem.mem[16'h5201]!==((opcode==8'hb2 || opcode==8'hba || opcode==8'hb3 || opcode==8'hbb)?8'h02:((match_first && initial_bc>1)?8'h01:8'h00)))
                $fatal(1,"block %02x BC result mismatch %02x:%02x",opcode,u_mem.mem[16'h5200],u_mem.mem[16'h5201]);
            expected_hl=decrement?(16'h5001-iterations):(16'h5000+iterations);
            if(u_mem.mem[16'h5202]!==expected_hl[15:8] || u_mem.mem[16'h5203]!==expected_hl[7:0])
                $fatal(1,"block %02x HL result expected %04x got %02x%02x",opcode,expected_hl,u_mem.mem[16'h5202],u_mem.mem[16'h5203]);
            expected_de=(opcode==8'hb0 || opcode==8'hb8)?
                (decrement?(16'h5101-iterations):(16'h5100+iterations)):
                (decrement?16'h5101:16'h5100);
            if(u_mem.mem[16'h5204]!==expected_de[15:8] || u_mem.mem[16'h5205]!==expected_de[7:0])
                $fatal(1,"block %02x DE result expected %04x got %02x%02x",opcode,expected_de,u_mem.mem[16'h5204],u_mem.mem[16'h5205]);
            if(opcode==8'hb0 || opcode==8'hb8) begin
                if(u_mem.mem[decrement?16'h5101:16'h5100]!== (decrement?8'h66:8'h55))
                    $fatal(1,"block %02x transfer data missing: %02x",opcode,u_mem.mem[decrement?16'h5101:16'h5100]);
                if(initial_bc>1 && (u_mem.mem[decrement?16'h5100:16'h5101]!== (decrement?8'h55:8'h66)))
                    $fatal(1,"block %02x second transfer byte missing",opcode);
            end
            if(opcode==8'hb2 || opcode==8'hba) begin
                if(io_read_count!=initial_bc || last_io_read_addr[7:0]!=8'h02 || last_io_read_data!=io_data)
                    $fatal(1,"block %02x I/O read result count=%0d port=%04x data=%02x",opcode,io_read_count,last_io_read_addr,last_io_read_data);
            end
            if(opcode==8'hb3 || opcode==8'hbb) begin
                if(io_write_count!=initial_bc || last_io_write_addr[7:0]!=8'h02 ||
                   last_io_write_data!=(decrement?(initial_bc>1?8'h55:8'h66):(initial_bc>1?8'h66:8'h55)))
                    $fatal(1,"block %02x I/O write result count=%0d port=%04x data=%02x",opcode,io_write_count,last_io_write_addr,last_io_write_data);
            end
        end
    end
endtask

initial begin
    trace_fd=0; trace_edge=0;
    if($value$plusargs("TRACE=%s",trace_path)) begin
        trace_fd=$fopen(trace_path,"w");
        if(trace_fd==0) $fatal(1,"cannot open trace output");
        trace_enable=1;
        $fwrite(trace_fd,"master_edge,RESET_n,CEN,WAIT_n,INT_n,NMI_n,BUSRQ_n,OUT0,DI,M1_n,MREQ_n,IORQ_n,RD_n,WR_n,RFSH_n,HALT_n,BUSAK_n,A,DOUT\n");
    end
    for(i=0;i<65536;i=i+1) u_mem.mem[i]=8'h00;
    $readmemh("vectors.hex",vectors);
    count=0;
    while(vectors[count*6]!=0) count=count+1;
    if(count<100) $fatal(1,"manifest vector generation returned only %0d rows",count);
    for(i=0;i<count;i=i+1) run_vector(i*6,i);
    for(j=0;j<4;j=j+1) begin
        run_condition_case(0,j,0);
        run_condition_case(0,j,1);
    end
    for(i=1;i<4;i=i+1) begin
        for(j=0;j<8;j=j+1) begin
            run_condition_case(i,j,0);
            run_condition_case(i,j,1);
        end
    end
    run_jr_unconditional();
    run_halt();
    run_return_from_nmi(8'h45);
    run_return_from_nmi(8'h4d);
    run_alu_effect(0,8'h7f,8'h01,0,8'h80,8'h94); // ADD
    run_alu_effect(1,8'h7f,8'h00,1,8'h80,8'h94); // ADC with carry
    run_alu_effect(2,8'h00,8'h01,0,8'hff,8'h93); // SUB
    run_alu_effect(3,8'h00,8'h00,1,8'hff,8'h93); // SBC with carry
    run_alu_effect(4,8'h0f,8'hf0,0,8'h00,8'h54); // AND
    run_alu_effect(5,8'h80,8'h01,0,8'h81,8'h84); // XOR
    run_alu_effect(6,8'h80,8'h01,0,8'h81,8'h84); // OR
    run_alu_effect(7,8'h80,8'h01,0,8'h80,8'h16); // CP retains A
    run_daa_effect();
    run_cb_effect(8'h00,8'h81,8'h03,8'h05,8'hd7); // RLC B
    run_cb_effect(8'h38,8'h81,8'h40,8'h01,8'hd7); // SRL B
    run_cb_effect(8'h78,8'h80,8'h80,8'h10,8'h53); // BIT 7,B (S/PV undefined)
    run_nibble_effect(8'h6f,8'h13,8'h42,8'h00); // RLD
    run_nibble_effect(8'h67,8'h14,8'h23,8'h04); // RRD
    run_exchange_effect();
    run_indexed_effect(0);
    run_indexed_effect(1);
    run_index_jump(8'hdd);
    run_index_jump(8'hfd);
    run_flow_case(8'hc3,16'h0030,10,0); // JP nn
    run_flow_case(8'hcd,16'h0030,17,1); // CALL nn
    run_flow_case(8'hc9,16'h0040,10,2); // RET
    run_flow_case(8'he9,16'h0030,4,3);  // JP (HL)
    for(j=0;j<8;j=j+1) run_flow_case(8'hc7+(j<<3),j*8,11,4);
    run_djnz(8'h00,1,8'hff); // 0 -> 255 wraps and branches
    run_djnz(8'h01,0,8'h00); // 1 -> 0 falls through
    run_djnz(8'h02,1,8'h01); // 2 -> 1 branches
    observe_repeat(8'hb0,16'h0001,8'h00,0); observe_repeat(8'hb0,16'h0002,8'h00,0); observe_repeat(8'hb0,16'h0000,8'h00,1);
    observe_repeat(8'hb8,16'h0001,8'h00,0); observe_repeat(8'hb8,16'h0002,8'h00,0); observe_repeat(8'hb8,16'h0000,8'h00,1);
    observe_repeat(8'hb1,16'h0001,8'h00,0); observe_repeat(8'hb1,16'h0001,8'h55,0); observe_repeat(8'hb1,16'h0002,8'h00,0); observe_repeat(8'hb1,16'h0002,8'h55,0); observe_repeat(8'hb1,16'h0000,8'h00,1);
    observe_repeat(8'hb9,16'h0001,8'h00,0); observe_repeat(8'hb9,16'h0001,8'h66,0); observe_repeat(8'hb9,16'h0002,8'h00,0); observe_repeat(8'hb9,16'h0002,8'h66,0); observe_repeat(8'hb9,16'h0000,8'h00,1);
    observe_repeat(8'hb2,16'h0001,8'h00,0); observe_repeat(8'hb2,16'h0002,8'h00,0); observe_repeat(8'hb2,16'h0000,8'h00,1);
    observe_repeat(8'hba,16'h0001,8'h00,0); observe_repeat(8'hba,16'h0002,8'h00,0); observe_repeat(8'hba,16'h0000,8'h00,1);
    observe_repeat(8'hb3,16'h0001,8'h00,0); observe_repeat(8'hb3,16'h0002,8'h00,0); observe_repeat(8'hb3,16'h0000,8'h00,1);
    observe_repeat(8'hbb,16'h0001,8'h00,0); observe_repeat(8'hbb,16'h0002,8'h00,0); observe_repeat(8'hbb,16'h0000,8'h00,1);
    if(trace_fd!=0) begin $fclose(trace_fd); trace_enable=0; end
    $display("PASS: %0d vector rows; 56 branch outcomes; 3 DJNZ transitions; 13 base + 2 indexed unconditional transfers; 8 repeating block opcodes; arithmetic/DAA/CB/BIT/RLD/RRD/exchange/indexed effects",count);
    $finish;
end

endmodule
