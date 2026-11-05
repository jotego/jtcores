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
reg [7:0] irq_data=8'hff;
wire [7:0] di;
wire [7:0] ram_dout;
wire m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n;
wire [15:0] addr;
wire [7:0] dout;
integer io_write_count;
integer irq_ack_count;
integer stack_write_count;
reg stack_write_active;
integer master_edge_count;
integer cen_edge_count;
integer m1_start_serial;
integer last_m1_start_cen;
reg [15:0] last_m1_start_addr;
reg [7:0] io_last_data;
integer trace_fd, trace_cycle;
reg trace_enable=0;
reg [1023:0] trace_path;
reg [7:0] trace_reset_n,trace_cen,trace_wait_n,trace_int_n,trace_nmi_n;
reg [7:0] trace_busrq_n,trace_out0,trace_di;
integer i;

`include "test_tasks.vh"

// The falling-edge RAM read makes data available half a master clock after
// the CPU presents an address, before its next rising-edge sample.
assign di = (!iorq_n && !m1_n) ? irq_data : ram_dout;

jtframe_ram #(.DW(8),.AW(16)) program_ram(
    .clk(~clk), .cen(1'b1), .data(dout), .addr(addr),
    .we(reset_n && !mreq_n && !wr_n), .q(ram_dout)
);

T80s uut(
    .RESET_n ( reset_n ), .CLK ( clk ), .CEN ( cen ), .WAIT_n ( wait_n ),
    .INT_n ( int_n ), .NMI_n ( nmi_n ), .BUSRQ_n ( busrq_n ), .OUT0 ( out0 ),
    .DI ( di ), .M1_n ( m1_n ), .MREQ_n ( mreq_n ), .IORQ_n ( iorq_n ),
    .RD_n ( rd_n ), .WR_n ( wr_n ), .RFSH_n ( rfsh_n ), .HALT_n ( halt_n ),
    .BUSAK_n ( busak_n ), .A ( addr ), .DOUT ( dout )
);

always @(negedge iorq_n) begin
    if (reset_n && !m1_n) irq_ack_count = irq_ack_count + 1;
end

always @(negedge m1_n) begin
    if(reset_n) begin
        m1_start_serial=m1_start_serial+1;
        last_m1_start_cen=cen_edge_count;
        last_m1_start_addr=addr;
    end
end

always @(negedge wr_n) begin
    if (reset_n && !iorq_n) io_write_count = io_write_count + 1;
end

always @(negedge clk) begin
    if (reset_n && !wr_n && !mreq_n) begin
        if(addr>=16'hff00 && !stack_write_active) stack_write_count=stack_write_count+1;
        stack_write_active = addr>=16'hff00;
    end else begin
        stack_write_active = 0;
    end
    if (reset_n && !wr_n && !iorq_n) io_last_data = dout;
end

always @(posedge clk) begin
    master_edge_count=master_edge_count+1;
    if (cen) cen_edge_count=cen_edge_count+1;
    if(trace_enable) begin
        trace_reset_n=reset_n; trace_cen=cen; trace_wait_n=wait_n;
        trace_int_n=int_n; trace_nmi_n=nmi_n; trace_busrq_n=busrq_n;
        trace_out0=out0; trace_di=di;
        #1;
        $fwrite(trace_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%02x,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%04x,%02x\n",
            trace_cycle,trace_reset_n,trace_cen,trace_wait_n,trace_int_n,trace_nmi_n,
            trace_busrq_n,trace_out0,trace_di,m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,
            halt_n,busak_n,addr,dout);
        trace_cycle=trace_cycle+1;
    end
end

task fail_msg(input [255:0] message);
    begin
        $display("FAIL: %0s",message);
        fail();
    end
endtask

task clear_machine;
    integer k;
    begin
        reset_n=0; cen=1; wait_n=1; int_n=1; nmi_n=1; busrq_n=1;
        irq_data=8'hff; io_write_count=0; irq_ack_count=0; stack_write_count=0; stack_write_active=0; io_last_data=0;
        for(k=0;k<65536;k=k+1) program_ram.mem[k]=8'h00;
        repeat(6) @(posedge clk);
        @(negedge clk); reset_n=1;
    end
endtask

task wait_fetch(input [15:0] target, input integer limit, input [255:0] label);
    integer n;
    reg found;
    begin
        found=0;
        for(n=0;n<limit && !found;n=n+1) begin
            @(posedge clk); #2;
            if(!m1_n && !mreq_n && !rd_n && addr==target) found=1;
        end
        if(!found) begin
            $display("FAIL: timed out waiting for fetch %04x (%0s)",target,label);
            fail();
        end
    end
endtask

task wait_m1_cen(input [15:0] target, input integer limit,
                 input [255:0] label, output integer at_cen_edge);
    integer n, seen_serial;
    reg found;
    begin
        found=0;
        at_cen_edge=-1;
        seen_serial=m1_start_serial;
        for(n=0;n<limit && !found;n=n+1) begin
            @(posedge clk); #2;
            if(m1_start_serial!=seen_serial && last_m1_start_addr==target) begin
                found=1;
                at_cen_edge=last_m1_start_cen;
            end
            seen_serial=m1_start_serial;
        end
        if(!found) begin
            $display("FAIL: timed out waiting for fetch %04x (%0s)",target,label);
            fail();
        end
    end
endtask

task wait_halt(input integer limit, input [255:0] label);
    integer n;
    reg found;
    begin
        found=0;
        for(n=0;n<limit && !found;n=n+1) begin
            @(posedge clk); #2;
            if(!halt_n) found=1;
        end
        if(!found) begin
            $display("FAIL: timed out waiting for HALT (%0s)",label);
            fail();
        end
    end
endtask

task irq_on;
    begin
        @(negedge clk); int_n=0;
    end
endtask

task run_im0_rst;
    integer n, ack_cen_edge, target_cen_edge;
    reg saw_ack;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h46; // IM 0
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76;
        program_ram.mem[8]=8'h76;
        irq_data=8'hcf; // RST 08h
        irq_on();
        saw_ack=0;
        for(n=0;n<300 && !saw_ack;n=n+1) begin
            @(posedge clk); #2;
            if(!m1_n && !iorq_n) saw_ack=1;
        end
        if(!saw_ack) fail_msg("IM0 RST acknowledge was not observed");
        ack_cen_edge=last_m1_start_cen;
        wait_m1_cen(16'h0008,200,"IM0 RST vector M1 start",target_cen_edge);
        if(target_cen_edge-ack_cen_edge!=13)
            fail_msg("IM0 injected RST M1 start to vector M1 start was not 13 enabled clocks");
        if(program_ram.mem[16'hfffd]!==8'h04 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("IM0 RST did not push the post-NOP PC");
        @(negedge clk); int_n=1;
    end
endtask

task run_im0_nonrst;
    integer n, ack_cen_edge, target_cen_edge;
    reg saw_ack;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h46; // IM 0
        program_ram.mem[2]=8'h3e; program_ram.mem[3]=8'h55; // LD A,55h
        program_ram.mem[4]=8'hfb; program_ram.mem[5]=8'h00; // EI; one following instruction
        program_ram.mem[6]=8'h70;               // operand fetched from memory after ack
        program_ram.mem[7]=8'h76;
        irq_data=8'hd3; // OUT (n),A supplied by interrupting device
        irq_on();
        saw_ack=0;
        for(n=0;n<300 && !saw_ack;n=n+1) begin
            @(posedge clk); #2;
            if(!m1_n && !iorq_n) saw_ack=1;
        end
        if(!saw_ack) fail_msg("IM0 non-RST acknowledge was not observed");
        ack_cen_edge=last_m1_start_cen;
        wait_m1_cen(16'h0007,240,"IM0 non-RST continuation M1 start",target_cen_edge);
        if(target_cen_edge-ack_cen_edge!=13)
            fail_msg("IM0 injected OUT M1 start to continuation M1 start was not 13 enabled clocks");
        if(io_write_count==0 || io_last_data!==8'h55)
            fail_msg("IM0 non-RST opcode did not execute with the expected accumulator");
        @(negedge clk); int_n=1;
    end
endtask

task run_im1;
    integer ack_count;
    integer ack_cen_edge, vector_cen_edge;
    reg saw_ack;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76;
        program_ram.mem[16'h0038]=8'h76;
        irq_on();
        saw_ack=0; ack_count=0;
        while(!saw_ack && ack_count<300) begin
            @(posedge clk); #2;
            ack_count=ack_count+1;
            if(!m1_n && !iorq_n) saw_ack=1;
        end
        if(!saw_ack) fail_msg("IM1 acknowledge was not observed");
        ack_cen_edge=last_m1_start_cen;
        wait_m1_cen(16'h0038,100,"IM1 vector M1 start",vector_cen_edge);
        if(vector_cen_edge-ack_cen_edge!=13)
            fail_msg("IM1 ACK M1 falling edge to vector M1 falling edge was not 13 enabled clocks");
        if(program_ram.mem[16'hfffd]!==8'h04 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("IM1 did not push the post-NOP PC");
        if(ack_count<1) fail_msg("IM1 acknowledge counter invalid");
        @(negedge clk); int_n=1;
    end
endtask

task run_im2;
    integer ack_cen_edge, vector_cen_edge, n;
    reg saw_ack;
    begin
        clear_machine();
        program_ram.mem[0]=8'h3e; program_ram.mem[1]=8'h80; // LD A,80h
        program_ram.mem[2]=8'hed; program_ram.mem[3]=8'h47; // LD I,A
        program_ram.mem[4]=8'hed; program_ram.mem[5]=8'h5e; // IM 2
        program_ram.mem[6]=8'hfb; program_ram.mem[7]=8'h00; program_ram.mem[8]=8'h76;
        program_ram.mem[16'h80ff]=8'h34; program_ram.mem[16'h8100]=8'h12;
        program_ram.mem[16'h1234]=8'h76;
        irq_data=8'hff;
        irq_on();
        saw_ack=0;
        for(n=0;n<400 && !saw_ack;n=n+1) begin
            @(posedge clk); #2;
            if(!m1_n && !iorq_n) saw_ack=1;
        end
        if(!saw_ack) fail_msg("IM2 acknowledge was not observed");
        ack_cen_edge=last_m1_start_cen;
        wait_m1_cen(16'h1234,500,"IM2 handler M1 start",vector_cen_edge);
        if(vector_cen_edge-ack_cen_edge!=19)
            fail_msg("IM2 ACK M1 falling edge to handler M1 falling edge was not 19 enabled clocks");
        if(program_ram.mem[16'hfffd]!==8'h08 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("IM2 did not push the post-NOP PC");
        @(negedge clk); int_n=1;
    end
endtask

task run_nmi_halt;
    integer n, halt_exit_cen_edge, vector_cen_edge;
    reg exited_halt;
    begin
        clear_machine();
        program_ram.mem[0]=8'hfb; program_ram.mem[1]=8'h00; program_ram.mem[2]=8'h76; program_ram.mem[3]=8'h3e; program_ram.mem[4]=8'h66;
        program_ram.mem[16'h0066]=8'hed; program_ram.mem[16'h0067]=8'h45; // RETN
        wait_fetch(16'h0002,100,"HALT entry");
        wait_halt(120,"HALT after EI/NOP");
        @(negedge clk); nmi_n=0;
        exited_halt=0;
        for(n=0;n<120 && !exited_halt;n=n+1) begin
            @(posedge clk); #2;
            if(halt_n) begin exited_halt=1; halt_exit_cen_edge=last_m1_start_cen; end
        end
        if(!exited_halt) fail_msg("NMI did not exit HALT");
        wait_m1_cen(16'h0066,200,"NMI vector M1 start",vector_cen_edge);
        if(vector_cen_edge-halt_exit_cen_edge!=11)
            fail_msg("NMI HALT exit M1 start to vector M1 start was not 11 enabled clocks");
        @(negedge clk); nmi_n=1;
        wait_fetch(16'h0003,200,"NMI return from HALT");
        if(program_ram.mem[16'hfffd]!==8'h03 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("NMI from HALT pushed the wrong return PC");
    end
endtask

task run_ei_di;
    begin
        clear_machine();
        program_ram.mem[0]=8'hfb; program_ram.mem[1]=8'hf3; program_ram.mem[2]=8'h76; // EI; DI; HALT
        program_ram.mem[16'h0038]=8'h76;
        irq_on();
        wait_fetch(16'h0002,150,"EI followed by DI");
        wait_halt(120,"HALT after RETI");
        repeat(24) @(posedge clk);
        #2;
        if(irq_ack_count!=0) fail_msg("EI followed by DI incorrectly acknowledged INT");
    end
endtask

task run_ei_ei;
    begin
        clear_machine();
        program_ram.mem[0]=8'hfb; program_ram.mem[1]=8'hfb; program_ram.mem[2]=8'h00; program_ram.mem[3]=8'h76;
        program_ram.mem[16'h0038]=8'h76;
        irq_on();
        wait_fetch(16'h0038,200,"EI followed by EI");
        if(program_ram.mem[16'hfffd]!==8'h03 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("EI/EI did not defer INT through the following NOP");
    end
endtask

task run_ei_halt;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h76; program_ram.mem[4]=8'h00;
        program_ram.mem[16'h0038]=8'h76;
        irq_on();
        wait_fetch(16'h0038,220,"EI followed by HALT");
        if(program_ram.mem[16'hfffd]!==8'h04 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("EI/HALT interrupt did not return after HALT");
    end
endtask

task run_ei_nmi;
    begin
        clear_machine();
        program_ram.mem[0]=8'hfb; program_ram.mem[1]=8'h00; program_ram.mem[2]=8'h76;
        program_ram.mem[16'h0066]=8'h76;
        @(negedge clk); nmi_n=0;
        wait_fetch(16'h0066,160,"NMI immediately after EI");
        if(program_ram.mem[16'hfffd]!==8'h01 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("NMI after EI stacked an unexpected PC");
        @(negedge clk); nmi_n=1;
    end
endtask

task run_nmi_restores_iff;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76; program_ram.mem[5]=8'h00;
        program_ram.mem[16'h0066]=8'hed; program_ram.mem[16'h0067]=8'h45; // RETN
        program_ram.mem[16'h0038]=8'h76;
        wait_fetch(16'h0004,200,"before NMI with IFF set");
        @(negedge clk); nmi_n=0; int_n=0;
        wait_fetch(16'h0066,200,"NMI before pending INT");
        @(negedge clk); nmi_n=1;
        wait_fetch(16'h0038,300,"INT after RETN restores IFF1");
        if(program_ram.mem[16'hfffd]!==8'h05 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("INT after RETN did not save the resumed PC");
    end
endtask

task run_reti;
    integer before_ack;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76;
        program_ram.mem[16'h0038]=8'hed; program_ram.mem[16'h0039]=8'h4d; // RETI
        int_n=0;
        wait_fetch(16'h0038,240,"IM1 service for RETI");
        before_ack=irq_ack_count;
        wait_fetch(16'h0004,220,"RETI return address");
        wait_halt(120,"HALT after nested RETN");
        repeat(24) @(posedge clk);
        #2;
        if(irq_ack_count!=before_ack)
            fail_msg("RETI incorrectly re-enabled maskable interrupts");
        if(program_ram.mem[16'hfffd]!==8'h04 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("RETI did not return from the saved PC");
    end
endtask

task run_ld_air_iff(input integer opcode, input integer jump_opcode, input integer iff_enabled);
    integer first_cen_edge;
    begin
        clear_machine();
        program_ram.mem[0]=iff_enabled ? 8'hfb : 8'hf3;
        program_ram.mem[1]=iff_enabled ? 8'h00 : 8'h76;
        program_ram.mem[2]=iff_enabled ? 8'h76 : 8'h00;
        program_ram.mem[3]=8'h76;
        program_ram.mem[4]=8'h76;
        program_ram.mem[16'h0066]=8'hed; program_ram.mem[16'h0067]=opcode[7:0]; // LD A,I/R
        program_ram.mem[16'h0068]=jump_opcode[7:0]; // JP PE when enabled, JP PO when disabled
        program_ram.mem[16'h0069]=8'h6c; program_ram.mem[16'h006a]=8'h00;
        program_ram.mem[16'h006b]=8'h76; // wrong P/V state
        program_ram.mem[16'h006c]=8'h3e; program_ram.mem[16'h006d]=8'ha5;
        program_ram.mem[16'h006e]=8'hd3; program_ram.mem[16'h006f]=8'h01;
        program_ram.mem[16'h0070]=8'hed; program_ram.mem[16'h0071]=8'h45; // RETN
        if(iff_enabled) begin
            wait_m1_cen(16'h0002,120,"LD A,I NMI case HALT",first_cen_edge);
        end else begin
            wait_m1_cen(16'h0001,120,"LD A,R NMI case HALT after DI",first_cen_edge);
        end
        wait_halt(120,"HALT before LD A,I/R NMI probe");
        @(negedge clk); nmi_n=0;
        wait_fetch(16'h0066,180,"LD A,I/R NMI handler");
        @(negedge clk); nmi_n=1;
        wait_halt(240,"HALT after LD A,I/R NMI handler");
        if(io_write_count!=1 || io_last_data!==8'ha5)
            fail_msg("LD A,I/R did not copy preserved IFF2 into P/V");
    end
endtask

task run_sustained_nmi;
    begin
        clear_machine();
        program_ram.mem[0]=8'hfb; program_ram.mem[1]=8'h00; program_ram.mem[2]=8'h76; program_ram.mem[3]=8'h76;
        program_ram.mem[16'h0066]=8'hed; program_ram.mem[16'h0067]=8'h45; // RETN
        wait_fetch(16'h0002,120,"HALT before sustained NMI");
        @(negedge clk); nmi_n=0;
        wait_fetch(16'h0066,200,"first NMI edge");
        wait_fetch(16'h0003,220,"RETN under sustained NMI low");
        repeat(20) @(posedge clk);
        #2;
        if(stack_write_count!=2)
            fail_msg("sustained NMI low retriggered without a new falling edge");
        @(negedge clk); nmi_n=1;
        wait_halt(120,"HALT before rearmed NMI edge");
        repeat(4) @(posedge clk);
        @(negedge clk); nmi_n=0;
        wait_fetch(16'h0066,200,"second NMI edge after rearm");
        if(stack_write_count!=4)
            fail_msg("new NMI edge did not create a stack frame");
        @(negedge clk); nmi_n=1;
    end
endtask

task run_nested_nmi;
    integer n;
    reg resumed_main;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76; program_ram.mem[5]=8'h76;
        program_ram.mem[16'h0038]=8'h76;
        program_ram.mem[16'h0066]=8'hc3; program_ram.mem[16'h0067]=8'h66; program_ram.mem[16'h0068]=8'h00; // hold in handler
        wait_fetch(16'h0004,200,"HALT before nested NMI");
        @(negedge clk); nmi_n=0;
        wait_fetch(16'h0066,200,"outer NMI handler");
        @(negedge clk); nmi_n=1;
        repeat(5) @(posedge clk);
        @(negedge clk); nmi_n=0;
        for(n=0;n<220 && stack_write_count<4;n=n+1) begin
            @(posedge clk); #2;
        end
        if(stack_write_count<4) fail_msg("nested NMI did not create a second stack frame");
        @(negedge clk); nmi_n=1;
        // Both levels now return through RETN. NMI clears IFF1 but preserves
        // IFF2; therefore RETN restores the pre-outer-NMI enable state even
        // after a nested NMI (UM008011-0816 p. 19, Table 1).
        program_ram.mem[16'h0066]=8'hed; program_ram.mem[16'h0067]=8'h45;
        int_n=0;
        resumed_main=0;
        for(n=0;n<400 && !resumed_main && irq_ack_count==0;n=n+1) begin
            @(posedge clk); #2;
            if(!m1_n && !mreq_n && !rd_n && addr==16'h0005) resumed_main=1;
        end
        if(irq_ack_count==0 && !resumed_main) begin
            fail_msg("timed out waiting for nested NMI RETN");
        end
        if(irq_ack_count==0)
            fail_msg("nested NMI RETN did not restore the preserved IFF2 enable");
        wait_fetch(16'h0038,120,"INT after nested RETN restores preserved IFF2");
        repeat(24) @(posedge clk);
        #2;
        if(program_ram.mem[16'hfffd]!==8'h05 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("outer NMI stack return PC was incorrect");
    end
endtask

task run_im0_call;
    integer n, ack_cen_edge, target_cen_edge;
    reg saw_ack;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h46; // IM 0
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h34; program_ram.mem[5]=8'h12;
        program_ram.mem[16'h1234]=8'h76;
        irq_data=8'hcd; // CALL nn supplied on the acknowledge data bus
        irq_on();
        saw_ack=0;
        for(n=0;n<300 && !saw_ack;n=n+1) begin
            @(posedge clk); #2;
            if(!m1_n && !iorq_n) saw_ack=1;
        end
        if(!saw_ack) fail_msg("IM0 CALL acknowledge was not observed");
        ack_cen_edge=last_m1_start_cen;
        wait_m1_cen(16'h1234,260,"IM0 multibyte CALL target M1 start",target_cen_edge);
        if(target_cen_edge-ack_cen_edge!=19)
            fail_msg("IM0 injected CALL M1 start to target M1 start was not 19 enabled clocks");
        if(program_ram.mem[16'hfffd]!==8'h06 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("IM0 CALL did not fetch its operands from memory and push the return PC");
        @(negedge clk); int_n=1;
    end
endtask

task run_prefix_irq;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'hdd; program_ram.mem[4]=8'h21; program_ram.mem[5]=8'h34; program_ram.mem[6]=8'h12;
        program_ram.mem[7]=8'h76; program_ram.mem[16'h0038]=8'h76;
        irq_on();
        wait_fetch(16'h0038,300,"INT after indexed instruction");
        if(program_ram.mem[16'hfffd]!==8'h07 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("INT during indexed instruction did not wait for its final byte");
    end
endtask

task run_indexed_irq_phase(input integer phase, input integer use_nmi);
    integer first_cen_edge, vector_cen_edge, k;
    reg [7:0] expected_return_pc;
    reg [15:0] vector_addr;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; // enable INT before indexed instruction
        program_ram.mem[4]=8'hdd; program_ram.mem[5]=8'h21;
        program_ram.mem[6]=8'h34; program_ram.mem[7]=8'h12; program_ram.mem[8]=8'h76;
        program_ram.mem[16'h0038]=8'h76; program_ram.mem[16'h0066]=8'h76;
        wait_m1_cen(16'h0004,200,"indexed DD prefix M1",first_cen_edge);
        for(k=0;k<phase;k=k+1) begin @(posedge clk); #2; end
        @(negedge clk);
        if(use_nmi) nmi_n=0; else int_n=0;
        // Offsets 0..12 arrive during DD 21 and must save its following PC.
        // Offset 13 is at the instruction boundary: INT is accepted before
        // HALT, while edge-sampled NMI may enter and leave HALT first.
        expected_return_pc=(phase==13 && use_nmi) ? 8'h09 : 8'h08;
        vector_addr=use_nmi ? 16'h0066 : 16'h0038;
        wait_m1_cen(vector_addr,240,"indexed interrupt vector M1",vector_cen_edge);
        if(program_ram.mem[16'hfffd]!==expected_return_pc || program_ram.mem[16'hfffe]!==8'h00) begin
            $display("indexed phase mismatch: source=%s phase=%0d stacked bytes=%02x%02x",
                use_nmi ? "NMI" : "INT",phase,program_ram.mem[16'hfffd],program_ram.mem[16'hfffe]);
            fail_msg("interrupt did not wait for all DD 21 operands");
        end
    end
endtask

task run_otir_irq;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'h01; program_ram.mem[3]=8'h01; program_ram.mem[4]=8'h02; // LD BC,0201h
        program_ram.mem[5]=8'h21; program_ram.mem[6]=8'h00; program_ram.mem[7]=8'h40; // LD HL,4000h
        program_ram.mem[8]=8'hfb; program_ram.mem[9]=8'hed; program_ram.mem[10]=8'hb3; program_ram.mem[11]=8'h76; // EI; OTIR; HALT
        program_ram.mem[16'h4000]=8'haa; program_ram.mem[16'h4001]=8'hbb;
        program_ram.mem[16'h0038]=8'h76;
        irq_on();
        wait_fetch(16'h0038,500,"INT between OTIR iterations");
        if(io_write_count!=1)
            fail_msg("EI deferral did not cover exactly one full OTIR instruction before INT acknowledge");
        if(program_ram.mem[16'hfffd]!==8'h09 || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("OTIR interrupt return PC did not identify the repeating instruction");
    end
endtask

task run_otir_irq_enabled;
    integer n;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; // EI; NOP enables INT
        program_ram.mem[4]=8'h01; program_ram.mem[5]=8'h01; program_ram.mem[6]=8'h02; // LD BC,0201h
        program_ram.mem[7]=8'h21; program_ram.mem[8]=8'h00; program_ram.mem[9]=8'h40; // LD HL,4000h
        program_ram.mem[10]=8'hed; program_ram.mem[11]=8'hb3; program_ram.mem[12]=8'h76; // OTIR; HALT
        program_ram.mem[16'h4000]=8'haa; program_ram.mem[16'h4001]=8'hbb;
        program_ram.mem[16'h0038]=8'h76;
        wait_fetch(16'h000a,240,"enabled OTIR start");
        // Let the first block transfer complete, then assert INT during the
        // repeating instruction's next iteration.
        for(n=0;n<180 && io_write_count<1;n=n+1) begin @(posedge clk); #2; end
        if(io_write_count!=1) fail_msg("OTIR did not complete its first transfer");
        @(negedge clk); int_n=0;
        wait_fetch(16'h0038,300,"enabled INT between OTIR iterations");
        if(io_write_count!=1)
            fail_msg("already-enabled INT was not accepted between OTIR iterations");
        if(program_ram.mem[16'hfffd]!==8'h0a || program_ram.mem[16'hfffe]!==8'h00)
            fail_msg("enabled OTIR interrupt return PC did not identify the repeating instruction");
    end
endtask

task run_cen_wait_busrq;
    reg [15:0] held_addr;
    reg held_mreq, held_rd;
    integer k, cen_before;
    begin
        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56; // IM 1
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76; program_ram.mem[16'h0038]=8'h76;
        wait_fetch(16'h0003,160,"CEN hold while INT eligible");
        held_addr=addr; held_mreq=mreq_n; held_rd=rd_n;
        cen_before=cen_edge_count;
        @(negedge clk); cen=0; int_n=0;
        repeat(5) begin
            @(posedge clk); #2;
            if(addr!==held_addr || mreq_n!==held_mreq || rd_n!==held_rd)
                fail_msg("CEN-low changed the active public bus cycle");
        end
        if(cen_edge_count!=cen_before)
            fail_msg("CEN-low advanced an enabled CPU clock");
        if(irq_ack_count!=0) fail_msg("INT was acknowledged while CEN was low");
        @(negedge clk); cen=1;
        wait_fetch(16'h0038,240,"INT after CEN release");

        clear_machine();
        program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56;
        program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76;
        program_ram.mem[16'h0038]=8'h76;
        wait_fetch(16'h0002,100,"WAIT hold start");
        held_addr=addr; held_mreq=mreq_n; held_rd=rd_n;
        cen_before=cen_edge_count;
        @(negedge clk); wait_n=0; int_n=0;
        repeat(4) begin
            @(posedge clk); #2;
            if(addr!==held_addr || mreq_n!==held_mreq || rd_n!==held_rd)
                fail_msg("WAIT-low did not hold the active read cycle");
        end
        if(cen_edge_count-cen_before!=4)
            fail_msg("four WAIT edges did not consume four enabled master clocks");
        if(irq_ack_count!=0) fail_msg("INT was acknowledged while WAIT was active");
        @(negedge clk); wait_n=1;
		wait_fetch(16'h0038,240,"INT after WAIT release and EI delay");

		clear_machine();
		program_ram.mem[0]=8'hed; program_ram.mem[1]=8'h56;
		program_ram.mem[2]=8'hfb; program_ram.mem[3]=8'h00; program_ram.mem[4]=8'h76;
		program_ram.mem[16'h0038]=8'h76;
		wait_fetch(16'h0003,200,"INT pending before BUSRQ");
        @(negedge clk); busrq_n=0; int_n=0;
        for(k=0;k<80 && busak_n;k=k+1) begin @(posedge clk); #2; end
        if(busak_n) fail_msg("BUSRQ did not receive BUSAK");
        if(irq_ack_count!=0) fail_msg("INT was acknowledged while BUSAK was active");
        if(!mreq_n || !iorq_n || !rd_n || !wr_n || !rfsh_n)
            fail_msg("public bus controls were active while BUSAK was asserted");
        repeat(4) @(posedge clk);
        #2;
        if(irq_ack_count!=0)
            fail_msg("INT was acknowledged during BUSAK hold");
        @(negedge clk); busrq_n=1;
        wait_fetch(16'h0038,240,"INT after BUSRQ release");
    end
endtask

task run_wait_lengths;
    integer waits, k, first_cen_edge, next_cen_edge, base_length, measured_length;
    reg read_active;
    begin
        clear_machine();
        program_ram.mem[0]=8'h00; program_ram.mem[1]=8'h00; program_ram.mem[2]=8'h76;
        wait_m1_cen(16'h0000,100,"no-WAIT baseline fetch 0",first_cen_edge);
        wait_m1_cen(16'h0001,100,"no-WAIT baseline fetch 1",next_cen_edge);
        base_length=next_cen_edge-first_cen_edge;
        for(waits=1;waits<=2;waits=waits+1) begin
            clear_machine();
            program_ram.mem[0]=8'h00; program_ram.mem[1]=8'h00; program_ram.mem[2]=8'h76;
            wait_m1_cen(16'h0000,100,"manual WAIT insertion start",first_cen_edge);
            read_active=0;
            for(k=0;k<20 && !read_active;k=k+1) begin
                @(posedge clk); #2;
                if(!m1_n && !mreq_n && !rd_n && addr==16'h0000) read_active=1;
            end
            if(!read_active) fail_msg("opcode memory read did not assert before manual WAIT");
            @(negedge clk); wait_n=0;
            for(k=0;k<waits;k=k+1) begin
                @(posedge clk); #2;
                if(m1_n || addr!=16'h0000 || mreq_n || rd_n)
                    fail_msg("manual WAIT changed the active opcode-read cycle");
            end
            @(negedge clk); wait_n=1;
            wait_m1_cen(16'h0001,100,"next fetch after manual WAIT",next_cen_edge);
            measured_length=next_cen_edge-first_cen_edge;
            if(measured_length!=base_length+waits)
                fail_msg("one/two WAIT clocks did not extend fetch-to-fetch length exactly");
        end
    end
endtask

initial begin
    trace_fd=0; trace_cycle=0; io_write_count=0; irq_ack_count=0; stack_write_count=0; stack_write_active=0;
    master_edge_count=0; cen_edge_count=0; m1_start_serial=0; last_m1_start_cen=0; last_m1_start_addr=0; io_last_data=0;
    $dumpfile("test.lxt");
    $dumpvars(0,clk,reset_n,cen,wait_n,int_n,nmi_n,busrq_n,di,m1_n,mreq_n,iorq_n,rd_n,wr_n,rfsh_n,halt_n,busak_n,addr,dout,ram_dout);
    if($value$plusargs("TRACE=%s",trace_path)) begin
        trace_fd=$fopen(trace_path,"w");
        if(trace_fd==0) $fatal(1,"cannot open trace output");
        trace_enable=1;
        $fwrite(trace_fd,"master_edge,RESET_n,CEN,WAIT_n,INT_n,NMI_n,BUSRQ_n,OUT0,DI,M1_n,MREQ_n,IORQ_n,RD_n,WR_n,RFSH_n,HALT_n,BUSAK_n,A,DOUT\n");
    end
    run_im0_rst();
    run_im0_nonrst();
    run_im1();
    run_im2();
    run_im0_call();
    run_nmi_halt();
    run_ei_di();
    run_ei_ei();
    run_ei_halt();
    run_ei_nmi();
    run_nmi_restores_iff();
    run_reti();
    run_ld_air_iff(8'h57,8'hea,1);
    run_ld_air_iff(8'h5f,8'he2,0);
    run_sustained_nmi();
    run_nested_nmi();
    run_prefix_irq();
    for(i=0;i<=13;i=i+1) run_indexed_irq_phase(i,0);
    for(i=0;i<=13;i=i+1) run_indexed_irq_phase(i,1);
    run_otir_irq();
    run_otir_irq_enabled();
    run_wait_lengths();
    run_cen_wait_busrq();
    if(trace_fd!=0) begin $fclose(trace_fd); trace_enable=0; end
    pass();
end

endmodule
