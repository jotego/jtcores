// SPDX-License-Identifier: GPL-3.0-or-later
`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg rst=1, clear=1, armed=0, measuring=0;
reg [31:0] relative_clock=0;
reg cfg_write=0;
reg [3:0] cfg_index=0;
reg [63:0] cfg_data=0;
reg [4:0] cfg_count=0;
reg write_complete=0, decode=0, hold_ack=0;
reg [31:0] decode_pc=0;
wire lint1_n,lint2_n,hold_req,emu_run,cen_enable,host_req;
wire [15:0] host_wdata;
wire event_valid,error;
wire [4:0] event_index,applied_count;
wire [31:0] event_clock,write_count,hold_count,host_count;
wire [63:0] event_data;
reg host_ack=0, host_seen=0, reject_host=0;
integer mode=0,i;

jttms10_fpga_stimulus u_stimulus(
    .clk(clk),.rst(rst),.clear(clear),.armed(armed),.measuring(measuring),
    .relative_clock(relative_clock),.cfg_write(cfg_write),.cfg_index(cfg_index),
    .cfg_data(cfg_data),.cfg_count(cfg_count),.write_complete(write_complete),
    .decode(decode),.decode_pc(decode_pc),.hold_ack(hold_ack),.host_ack(host_ack),
    .lint1_n(lint1_n),.lint2_n(lint2_n),.hold_req(hold_req),.emu_run(emu_run),
    .cen_enable(cen_enable),.host_req(host_req),.host_wdata(host_wdata),
    .event_valid(event_valid),.event_index(event_index),.event_clock(event_clock),
    .event_data(event_data),.applied_count(applied_count),.write_count(write_count),
    .hold_count(hold_count),.host_count(host_count),.error(error)
);

// Match the real registered HSTCTL handshake, including its low-request rearm.
always @(posedge clk) begin
    if(rst || clear) begin host_seen<=0; host_ack<=0; end
    else begin
        host_ack<=host_req && !host_seen && !reject_host;
        if(!host_req) host_seen<=0;
        else if(!host_seen && !reject_host) host_seen<=1;
    end
end

task automatic load(input integer index,input [2:0] trigger,input [31:0] argument,input [15:0] control);
    begin
        @(negedge clk); #1;
        cfg_write=1;cfg_index=4'(index);cfg_data={13'd0,trigger,control,argument};
        @(negedge clk); #1;cfg_write=0;
    end
endtask

task automatic start(input integer count);
    begin
        cfg_count=5'(count);
        repeat(2) @(negedge clk);
        #1;clear=0;armed=1;measuring=1;relative_clock=0;
    end
endtask

// Each call exposes a full rising edge and the following output-update edge.
// The clock argument is an instruction-relative input clock, not wall time.
task automatic tick(input integer clock_number,input integer writes,input bit decoded,input [31:0] address,input bit held);
    begin
        relative_clock=32'(clock_number);write_complete=writes!=0;
        decode=decoded;decode_pc=address;hold_ack=held;
        @(negedge clk); #1;
        write_complete=0;decode=0;hold_ack=0;
    end
endtask

task automatic expect_event(input integer index,input integer clock_number,input [15:0] control);
    begin
        if(error || !event_valid || event_index!=5'(index) ||
           event_clock!=32'(clock_number) || event_data[47:32]!==control)
            $fatal(1,"event expected index%0d clock%0d control%h; got error%b valid%b index%0d clock%0d data%h",index,clock_number,control,error,event_valid,event_index,event_clock,event_data);
    end
endtask

task automatic reset_case;
    begin
        @(negedge clk);#1;armed=0;clear=1;measuring=0;cfg_write=0;reject_host=0;
        write_complete=0;decode=0;hold_ack=0;
        repeat(3) @(negedge clk);#1;
        if(error || applied_count!=0 || write_count!=0 || hold_count!=0 || host_count!=0 ||
           !lint1_n || !lint2_n || hold_req || !emu_run || !cen_enable || host_req)
            $fatal(1,"case reset leaked stimulus");
    end
endtask

initial begin
    if($value$plusargs("MODE=%d",mode)) begin end
    repeat(3) @(negedge clk);#1;rst=0;
    case(mode)
    0: begin
        load(0,0,2,16'h0001); // external IRQ at exact clock2
        load(1,3,3,16'h0026); // three clocks later: LINT2/HOLD/CEN low
        load(2,2,32'h1600,16'h8310); // NMI+NMIM+HLT via real host-control byte
        load(3,3,2,16'h0008); // clear pins, pause emulation
        load(4,3,2,16'h0010); // clear HSTCTL, resume emulation
        start(5);
        for(i=0;i<10;i=i+1) begin
            tick(i,0,i==6,32'h1600,0);
            if(i==2) begin expect_event(0,2,16'h0001);if(lint1_n) $fatal(1,"IRQ not asserted");end
            if(i==5) begin expect_event(1,5,16'h0026);if(!lint1_n || lint2_n || !hold_req || cen_enable) $fatal(1,"pin controls wrong");end
            if(i==6) begin expect_event(2,6,16'h8310);if(!host_req || host_wdata!==16'h8300) $fatal(1,"HSTCTL data wrong");end
            if(i==8) begin expect_event(3,8,16'h0008);if(emu_run || host_req || hold_req || !cen_enable) $fatal(1,"release wrong");end
        end
        tick(10,0,0,0,0);expect_event(4,10,16'h0010);
        tick(11,0,0,0,0);tick(12,0,0,0,0);
        if(error || applied_count!=5 || host_count!=2) $fatal(1,"host handshake/count wrong");
        armed=0;tick(13,0,0,0,0);
        if(applied_count!=5 || host_count!=2) $fatal(1,"disarm erased observations");
        reset_case();
    end
    1: begin
        load(0,1,2,16'h0004); // hold after second physical write
        load(1,4,2,16'h0000); // release after two acknowledged HOLD clocks
        load(2,5,1,16'h0001); // IRQ only after a host ack
        start(3);
        tick(0,1,0,0,0);if(event_valid || write_count!=1) $fatal(1,"early write trigger");
        tick(1,0,0,0,0);if(event_valid) $fatal(1,"early write trigger");
        tick(2,1,0,0,0);expect_event(0,2,16'h0004);
        tick(3,0,0,0,1);if(event_valid || hold_count!=1) $fatal(1,"early HOLD trigger");
        tick(4,0,0,0,1);expect_event(1,4,16'h0000);
        tick(5,0,0,0,0);if(event_valid) $fatal(1,"early host trigger");
        // This branch deliberately has no host command; a missing trigger
        // stays pending for the runner's explicit case timeout, not auto-pass.
        if(applied_count!=2 || host_count!=0 || error) $fatal(1,"unmet trigger was lost");
        reset_case();
    end
    2: begin
        load(0,0,0,16'h0040);start(1);tick(0,0,0,0,0);
        if(!error || event_valid || applied_count!=0) $fatal(1,"reserved control accepted");
        reset_case();load(0,0,0,16'h0000);start(1);tick(0,0,0,0,0);expect_event(0,0,0);
    end
    3: begin
        load(0,0,2,16'h0000);load(1,0,1,16'h0000);start(2);
        tick(0,0,0,0,0);tick(1,0,0,0,0);tick(2,0,0,0,0);expect_event(0,2,0);
        tick(3,0,0,0,0);if(!error || event_valid || applied_count!=1) $fatal(1,"late clock event accepted");
    end
    4: begin
        load(0,0,0,16'h0110);load(1,3,1,16'h0010);start(2);
        tick(0,0,0,0,0);expect_event(0,0,16'h0110);
        tick(1,0,0,0,0);if(!error || event_valid || applied_count!=1) $fatal(1,"consecutive host writes accepted");
    end
    5: begin
        load(0,0,0,16'h0110);start(1);reject_host=1;
        tick(0,0,0,0,0);expect_event(0,0,16'h0110);
        tick(1,0,0,0,0);if(!error) $fatal(1,"missing host ACK accepted");
    end
    6: begin
        load(0,3,0,16'h0000);start(1);tick(0,0,0,0,0);
        if(!error || event_valid) $fatal(1,"zero delay accepted");
    end
    7: begin
        load(0,2,32'h1601,16'h0000);start(1);tick(0,0,1,32'h1601,0);
        if(!error || event_valid) $fatal(1,"unaligned decode accepted");
    end
    8: begin
        load(0,0,0,16'h0000);start(17);tick(0,0,0,0,0);
        if(!error || event_valid) $fatal(1,"oversize table accepted");
    end
    9: begin
        load(0,0,0,16'h0001);start(1);
        // Preloaded entries may not be overwritten while the case is armed.
        cfg_write=1;tick(0,0,0,0,0);cfg_write=0;
        if(!error || event_valid) $fatal(1,"live host table change accepted");
    end
    10: begin
        for(i=0;i<16;i=i+1) load(i,0,32'(i),i%2==0 ? 16'h0001 : 16'h0002);
        start(16);
        for(i=0;i<16;i=i+1) begin
            tick(i,0,0,0,0);expect_event(i,i,i%2==0 ? 16'h0001 : 16'h0002);
        end
        tick(16,0,0,0,0);
        if(error || event_valid || applied_count!=16) $fatal(1,"table boundary overrun");
    end
    11: begin
        load(0,6,0,0);start(1);tick(0,0,0,0,0);
        if(!error || event_valid) $fatal(1,"unknown trigger accepted");
    end
    12: begin
        load(0,0,0,16'h0100);start(1);tick(0,0,0,0,0);
        if(!error || event_valid) $fatal(1,"NMI data without host strobe accepted");
    end
    13: begin
        load(0,0,2,0);load(1,1,1,16'h0001);start(2);
        tick(0,1,0,0,0);tick(1,1,0,0,0);tick(2,0,0,0,0);expect_event(0,2,0);
        tick(3,0,0,0,0);if(!error || event_valid || applied_count!=1) $fatal(1,"expired write trigger accepted");
    end
    14: begin
        load(0,0,0,16'h0110);load(1,5,1,16'h0001);start(2);
        tick(0,0,0,0,0);expect_event(0,0,16'h0110);
        tick(1,0,0,0,0);if(event_valid) $fatal(1,"host ACK counted before edge");
        tick(2,0,0,0,0);expect_event(1,2,16'h0001);
        if(host_count!=1 || host_wdata!==16'h0000) $fatal(1,"host ACK event wrong");
    end
    15: begin
        start(0);
        for(i=0;i<3;i=i+1) tick(i,0,1,32'h1600,0);
        if(error || event_valid || applied_count!=0 || !lint1_n || !lint2_n ||
           hold_req || !emu_run || !cen_enable || host_req) $fatal(1,"empty table active");
    end
    16: begin
        load(0,0,0,16'h0004);load(1,0,2,16'h0040);start(2);
        tick(0,0,0,0,0);expect_event(0,0,16'h0004);
        tick(1,0,0,0,0);tick(2,0,0,0,0);
        if(!error || hold_req || !emu_run || !cen_enable || !lint1_n || !lint2_n)
            $fatal(1,"malformed table kept external pins asserted");
    end
    17: begin
        load(0,0,0,16'h0001);load(1,0,2,16'h0000);start(2);
        tick(0,0,0,0,0);expect_event(0,0,16'h0001);
        cfg_count=0; // Configuration changes cannot alter an armed table.
        tick(1,0,0,0,0);tick(2,0,0,0,0);expect_event(1,2,16'h0000);
        if(applied_count!=2 || !lint1_n) $fatal(1,"live count changed the case");
    end
    default:$fatal(1,"unknown test mode");
    endcase
    $display("PASS stimulus mode%0d",mode);$finish;
end
endmodule
