`timescale 1ns/1ps

module test;

reg         rst, clk, cen=0, nmi=0, irq=0;
reg  [ 7:0] mem[0:65535];
reg  [ 7:0] din;
wire        rd, wr;
wire [ 7:0] dout;
wire [15:0] addr;
reg  [39:0] vectors[0:255];
wire [39:0] state, cur;

integer f, rdcnt, opcnt=0;

assign state = {uut.u_regs.a,uut.u_regs.x,uut.u_regs.y,uut.u_regs.s,uut.u_regs.cc};
assign cur   = vectors[opcnt-2];

initial begin
    clk=0;
    forever #2.5 clk = ~clk;
end

initial begin
    rst = 1;
    #400;
    rst = 0;
    #10_000;
    $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

initial begin
    $readmemh("test.tv",vectors);
end

initial begin
    f=$fopen("mem.bin","rb");
    if(f==0) begin
        $display("Could not open mem.bin\nFAIL");
        $finish;
    end
    rdcnt=$fread(mem,f);
    if(rdcnt!='h10000) begin
        $display("Expecting 64kB of memory data for the test");
        $display("FAIL");
        $finish;
    end
    $fclose(f);
end

// finish once all expected instructions have been executed
reg check_at_cen;
integer OPCNT=`OPCNT;

always @(posedge uut.u_ctrl.next_instruction) begin
    opcnt <= opcnt+1;
    if(opcnt==(2+OPCNT)) begin
        $display("PASS");
        $finish;
    end
    if(opcnt>2 && state !== cur) begin
        check_at_cen <= 1;
    end else begin
        check_at_cen <= 0;
    end
end

always @(posedge clk) if(cen && check_at_cen) begin
    if(opcnt>2 && state !== cur) begin
        $display("Vector comparison failed at instruction %0d.\nFAIL",opcnt-2);
        #20 $finish;
    end
end

localparam [15:0] NMI_SET=16'h4000,
                  NMI_CLR=16'h4001,
                  IRQ_SET=16'h4010,
                  IRQ_CLR=16'h4011;

always @(posedge clk) if(cen) begin
    if( addr==NMI_SET && wr ) nmi <= 1;
    if( addr==NMI_CLR && wr ) nmi <= 0;
    if( addr==IRQ_SET && wr ) irq <= 1;
    if( addr==IRQ_CLR && wr ) irq <= 0;
end

always @(posedge clk) begin
    cen <= ~cen;
end

always @(posedge clk) begin
    if( rd ) din <= mem[addr];
    if( wr ) mem[addr] <= dout;
end

jt65c02 uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .irq        ( irq       ),
    .nmi        ( nmi       ),
    .wr         ( wr        ),
    .rd         ( rd        ),
    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( dout      )
);

endmodule