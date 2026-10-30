/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module cpu_test;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [1:0] phase=0;
always @(posedge clk) phase<=phase+1'd1;
wire cen=phase==0, cenb=phase==2;
reg int_n=1, nmi_n=1, poll_n=1;
wire [19:0] A;
wire [2:0] bs;
wire [1:0] qs;
wire rd_n, wr_n, buslock_n;
reg ready=0;
reg [19:0] held_addr=0;
reg [2:0] held_kind=7;
reg [7:0] mem[0:1048575];
reg [7:0] ports[0:65535];
integer cycles=0, delay_count=0, irq_count=0, nmi_count=0;
integer max_wait=8, io_reads=0, poll_timer=0;
reg seen_poll=0;
integer reads=0, writes=0, ack_count=0, io_writes=0;
integer irq_timer=0, nmi_timer=0;
reg seen_irq=0, seen_nmi=0;
reg [31:0] seed=32'h12345678;
`ifdef V30_REGRESSION
wire [15:0] dout;
reg [15:0] din;
wire ube_n;
wire req=!rd_n || !wr_n;
jtframe_v30 #(
    .HEXDIR       ( "" )
) dut (
`else
wire [7:0] dout;
reg [7:0] din;
wire req;
jtframe_v20 #(
    .HEXDIR       ( "" )
) dut (
`endif
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cen          ( cen          ),
    .cenb         ( cenb         ),
    .ready        ( ready        ),
    .int_n        ( int_n        ),
    .nmi_n        ( nmi_n        ),
    .poll_n       ( poll_n       ),
    .A            ( A            ),
    .din          ( din          ),
    .dout         ( dout         ),
    .bs           ( bs           ),
    .qs           ( qs           ),
    .rd_n         ( rd_n         ),
    .wr_n         ( wr_n         ),
    .buslock_n    ( buslock_n    ),
`ifdef V30_REGRESSION
    .ube_n        ( ube_n        )
`else
    .req          ( req          )
`endif
);
function automatic [7:0] read_byte(input [19:0] addr, input [2:0] kind);
    if(kind==0) read_byte=8'h20;
    else if(kind==1) read_byte=ports[addr[15:0]];
    else read_byte=mem[addr];
    if($test$plusargs("corrupt") && addr==20'h203 && kind==5)
        read_byte=mem[addr]^8'h01;
endfunction
always @* begin
`ifdef V30_REGRESSION
    din={read_byte({held_addr[19:1],1'b1},held_kind),read_byte({held_addr[19:1],1'b0},held_kind)};
`else
    din=read_byte(A,bs);
`endif
end
reg accepted=0;
// Respond at falling fabric edges, sample transfers only on CPU enables.
always @(negedge clk) begin
    if(rst || !req) begin
        ready=!rst; delay_count=0; accepted=0;
    end else if(!accepted) begin
        if(delay_count==0) begin
            ready=0;
            held_addr=A; held_kind=bs;
            seed={seed[30:0],seed[31]^seed[21]^seed[1]^seed[0]};
            delay_count=1+int'(seed[7:0])%(max_wait+1);
        end
        if(cen) begin
            delay_count=delay_count-1;
            if(delay_count==0) ready=1;
        end
    end
end
task write_byte(input [19:0] addr, input [7:0] value, input [2:0] kind);
    if(kind==2) begin
        ports[addr[15:0]]=value;
        io_writes=io_writes+1;
        case(io_writes)
            1: if(addr!=20'h40 || value!=8'h34) $fatal(1,"OUT even low");
            2: if(addr!=20'h41 || value!=8'h12) $fatal(1,"OUT even high");
            3: if(addr!=20'h43 || value!=8'h34) $fatal(1,"OUT odd low");
            4: if(addr!=20'h44 || value!=8'h12) $fatal(1,"OUT odd high");
            default: $fatal(1,"duplicate IO write");
        endcase
    end else mem[addr]=value;
endtask
always @(posedge clk) if(cen && !rst) begin
    cycles<=cycles+1;
    if(req && ready && !accepted) begin
        accepted=1;
        if($test$plusargs("trace")) $display("BUS %0d bs=%0d A=%h wr=%b d=%h r=%h irq=%b",cycles,bs,A,!wr_n,dout,din,int_n);
        if(bs==0) begin
            ack_count=ack_count+1;
            if(ack_count==2) int_n=1;
        end
        if(!rd_n) begin
            reads=reads+1;
            if(bs==1) begin
`ifdef V30_REGRESSION
                io_reads=io_reads+(!A[0] && !ube_n ? 2 : 1);
`else
                io_reads=io_reads+1;
`endif
            end
        end
        if(!wr_n) begin
            writes=writes+1;
`ifdef V30_REGRESSION
            if(!A[0]) write_byte(A,dout[7:0],bs);
            if(!ube_n) write_byte({A[19:1],1'b1},dout[15:8],bs);
`else
            write_byte(A,dout,bs);
`endif
        end
    end
    if(mem[20'h220]==1 && !seen_irq) begin seen_irq=1; irq_timer=200; end
    if(irq_timer>0) begin
        irq_timer=irq_timer-1;
        if(irq_timer==1) begin int_n=0; irq_count=irq_count+1; end
    end
    if(mem[20'h220]==2 && !seen_nmi) begin seen_nmi=1; nmi_timer=200; end
    if(nmi_timer>0) begin
        nmi_timer=nmi_timer-1;
        if(nmi_timer==1) begin nmi_n=0; nmi_count=nmi_count+1; end
    end
    if(mem[20'h220]==3 && !seen_poll) begin seen_poll=1; poll_timer=200; end
    if(poll_timer>0) begin
        poll_timer=poll_timer-1;
        if(poll_timer==1) poll_n=0;
    end
    if(mem[20'h22f]==8'h5a) begin
        if({mem[20'h201],mem[20'h200]}!=16'ha55a) $fatal(1,"even word");
        if({mem[20'h204],mem[20'h203]}!=16'h1234) $fatal(1,"odd word");
        if({mem[20'h207],mem[20'h206]}!=16'h1236) $fatal(1,"read/add/LOCK");
        if({mem[20'h209],mem[20'h208]}!=16'h1234) $fatal(1,"IN word");
        if({mem[20'h20b],mem[20'h20a]}!=16'h1234) $fatal(1,"odd IN word");
        if({mem[20'h20f],mem[20'h20e]}!=16'h89ab) $fatal(1,"20-bit wrap");
        if({mem[20'h211],mem[20'h210]}!=16'hcdef) $fatal(1,"segment offset wrap");
        if({mem[20'h244],mem[20'h243],mem[20'h242],mem[20'h241],mem[20'h240]}!=40'h123400a55a) $fatal(1,"REP MOVSB");
        if(mem[20'h20c]!=8'h80) $fatal(1,"NEC SET1");
        if(mem[20'h221]!=1 || mem[20'h222]!=1 || mem[20'h223]!=1) $fatal(1,"interrupt handlers");
        if(ack_count!=2 || irq_count!=1 || nmi_count!=1) $fatal(1,"interrupt ack sequence");
        if(io_writes!=4 || io_reads!=4 || poll_n!=0) $fatal(1,"bus coverage");
        $display("PASS CPU: cycles=%0d reads=%0d writes=%0d INTA=%0d",cycles,reads,writes,ack_count);
        $finish;
    end
    if(cycles>50000) $fatal(1,"CPU timeout A=%h bs=%h marker=%h irq=%b ack=%0d handlers=%h/%h/%h",A,bs,mem[20'h220],int_n,ack_count,mem[20'h221],mem[20'h222],mem[20'h223]);
end
initial begin
    if($value$plusargs("wait=%d",max_wait)) begin end
    if($value$plusargs("seed=%h",seed)) begin end
    if(max_wait<0 || max_wait>64) $fatal(1,"wait must be in 0..64");
    for(integer i=0;i<1048576;i=i+1) mem[i]=0;
    for(integer i=0;i<65536;i=i+1) ports[i]=0;
    $readmemh("program.hex",mem);
    repeat(8) @(negedge clk);
    rst=0;
end
endmodule
