`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg rst=1;
reg [2:0] divider=0;
wire ce=divider==7;
always @(posedge clk) divider<=divider+1'b1;
wire [31:0] addr,wdata;
wire [3:0] sel;
wire we,cyc,stb,tga;
reg [31:0] mem[0:255];
reg [7:0] latency=0;
integer delay_cycles=1;
integer clocks=0, ticks=0, advances=0, transfers=0, writes=0;
integer index, lane;
integer runs=0;
integer words=50, expected_writes=7;
reg [2047:0] program_file;
wire req=cyc&&stb;
wire ack=req&&(latency>=delay_cycles);
wire [31:0] rdata=ack ? mem[addr[9:2]] : 32'hffffffff;
a23_core cpu(.i_clk(clk),.i_reset(rst),.i_irq(1'b0),.i_firq(1'b0),
    .i_system_rdy(ce),.o_wb_adr(addr),.o_wb_sel(sel),.o_wb_we(we),
    .i_wb_dat(rdata),.o_wb_dat(wdata),.o_wb_cyc(cyc),.o_wb_stb(stb),
    .i_wb_ack(ack),.i_wb_err(1'b0),.o_wb_tga(tga));
initial begin
    if (!$value$plusargs("delay=%d",delay_cycles)) delay_cycles=1;
    if (!$value$plusargs("words=%d",words)) words=50;
    if (!$value$plusargs("writes=%d",expected_writes)) expected_writes=7;
    if (!$value$plusargs("rom=%s",program_file)) program_file="program.hex";
    for(index=0;index<256;index=index+1) mem[index]=0;
    $readmemh(program_file,mem,0,words-1);
    repeat(16) @(negedge clk);
    rst=0;
end
always @(posedge clk) begin
    if(rst || !req) latency<=0;
    else if(!ack) latency<=latency+1'b1;
    if(!rst) begin
        clocks=clocks+1;
        if(ce) begin
            ticks=ticks+1;
            if(!cpu.fetch_stall) advances=advances+1;
        end
        if(ack) begin
            transfers=transfers+1;
            if(we) begin
                writes=writes+1;
                for(lane=0;lane<4;lane=lane+1)
                    if(sel[lane]) mem[addr[9:2]][lane*8+:8]<=wdata[lane*8+:8];
                if(addr==32'h200) begin
                    $display("MEASURE delay=%0d clocks=%0d ticks=%0d advances=%0d transfers=%0d writes=%0d",delay_cycles,clocks,ticks,advances,transfers,writes);
                    if(wdata!=32'h5a) $fatal(1,"ARM instruction test failed at PC=%08x",cpu.u_execute.o_address);
                    // Each architectural write must reach the target once.
                    if(writes!=expected_writes) $fatal(1,"Repeated/lost writes: %0d (expected %0d)",writes,expected_writes);
                    $display("PASS delay=%0d clocks=%0d ticks=%0d advances=%0d transfers=%0d writes=%0d",delay_cycles,clocks,ticks,advances,transfers,writes);
                    if(runs==1) begin
                        $display("PASS instruction program after warm reset");
                        $finish;
                    end
                    // Exercise warm reset after status changes: SVC, masks,
                    // flags and bank-selection state must be reset too.
                    @(negedge clk);
                    cpu.u_execute.status_bits_flags=4'ha;
                    cpu.u_execute.status_bits_mode=2'd0;
                    cpu.u_execute.status_bits_irq_mask=0;
                    cpu.u_execute.status_bits_firq_mask=0;
                    rst=1;
                    repeat(3) @(negedge clk);
                    if(cpu.u_execute.o_status_bits!==32'h0c000003)
                        $fatal(1,"Warm reset status wrong: %08x",cpu.u_execute.o_status_bits);
                    $display("PASS warm reset: SVC, IRQ/FIRQ masked, flags cleared");
                    runs=1;
                    clocks=0; ticks=0; advances=0; transfers=0; writes=0;
                    rst=0;
                end
            end
        end
        if(clocks>40000) $fatal(1,"Timeout PC=%08x advances=%0d ticks=%0d",cpu.u_execute.o_address,advances,ticks);
    end
end
endmodule
