`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,cache_disable=0,cache_flush=0;
    reg c_req=0,c_we=0,c_iaq=0,c_program=0,c_pixel=0,c_lock=0;
    reg [31:0] c_addr=0;
    reg [15:0] c_wdata=0;
    wire [15:0] c_rdata,m_wdata;
    wire c_ack,c_restart,m_req,m_we,m_iaq,m_pixel,m_lock;
    wire [31:0] m_addr;
    reg [15:0] m_rdata=0;
    reg m_ack=0,stall=0;
    jttms10_cache dut(.c_hit(),
        .clk(clk),.rst(rst),.cache_disable(cache_disable),
        .cache_flush(cache_flush),
        .c_req(c_req),.c_we(c_we),.c_iaq(c_iaq),.c_program(c_program),
        .c_pixel(c_pixel),.c_lock(c_lock),.c_addr(c_addr),
        .c_wdata(c_wdata),.c_rdata(c_rdata),.c_ack(c_ack),
        .c_restart(c_restart),
        .m_req(m_req),.m_we(m_we),.m_iaq(m_iaq),.m_pixel(m_pixel),
        .m_lock(m_lock),.m_addr(m_addr),.m_wdata(m_wdata),
        .m_rdata(m_rdata),.m_ack(m_ack),.m_restart(1'b0)
    );
    reg [15:0] mem [0:4095];
    integer i;
    initial for(i=0;i<4096;i=i+1) mem[i]=16'h6000 ^ i[15:0];
    localparam [1:0] IDLE=0,WAIT=1,ACK=2;
    reg [1:0] state=IDLE;
    reg held_we,held_iaq,held_pixel,held_lock;
    reg [31:0] held_addr;
    reg [15:0] held_data;
    integer delay_q=0,requests=0,reads=0,writes=0;
    reg [31:0] trace_addr [0:255];
    reg trace_iaq [0:255];
    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; m_ack<=0; m_rdata<=0;
        end else case(state)
            IDLE: if(m_req) begin
                if(m_addr[3:0]!=0) $fatal(1,"unaligned cache word request");
                held_addr<=m_addr; held_data<=m_wdata;
                held_we<=m_we; held_iaq<=m_iaq;
                held_pixel<=m_pixel; held_lock<=m_lock;
                trace_addr[requests]<=m_addr;
                trace_iaq[requests]<=m_iaq;
                requests<=requests+1;
                delay_q<=3; state<=WAIT;
            end
            WAIT: begin
                if(!m_req || m_addr!==held_addr || m_wdata!==held_data ||
                   m_we!==held_we || m_iaq!==held_iaq ||
                   m_pixel!==held_pixel || m_lock!==held_lock)
                    $fatal(1,"cache downstream payload changed during wait");
                if(!stall) begin
                    if(delay_q!=0) delay_q<=delay_q-1;
                    else begin
                        m_ack<=1; state<=ACK;
                        if(held_we) begin
                            mem[held_addr[15:4]]<=held_data;
                            writes<=writes+1;
                        end else begin
                            m_rdata<=mem[held_addr[15:4]];
                            reads<=reads+1;
                        end
                    end
                end
            end
            ACK: begin m_ack<=0; state<=IDLE; end
            default: $fatal(1,"invalid target state");
        endcase
    end
    task tick; begin @(posedge clk); #1; end endtask
    task access(input prog,input iaq,input wr,input pix,input lock,
                input [31:0] addr,input [15:0] data,
                input [15:0] expected);
        integer guard,old_count;
        begin
            @(negedge clk);
            c_program=prog; c_iaq=iaq; c_we=wr;
            c_pixel=pix; c_lock=lock;
            c_addr=addr; c_wdata=data; c_req=1;
            guard=0;
            while(!c_ack && guard<400) begin tick(); guard=guard+1; end
            if(!c_ack) $fatal(1,"cache request timed out addr=%08x",addr);
            if(!wr && c_rdata!==expected)
                $fatal(1,"cache read addr=%08x expected=%04x got=%04x",addr,expected,c_rdata);
            old_count=requests;
            repeat(3) begin
                tick();
                if(c_ack || requests!=old_count)
                    $fatal(1,"held request repeated addr=%08x",addr);
            end
            @(negedge clk); c_req=0;
            repeat(2) tick();
        end
    endtask
    task check_fill(input integer first,input [31:0] base);
        integer k;
        begin
            for(k=0;k<4;k=k+1)
                if(trace_addr[first+k]!==base+16*k || !trace_iaq[first+k])
                    $fatal(1,"four-word fill order/IAQ wrong at %0d got=%08x",k,trace_addr[first+k]);
        end
    endtask
    integer before_count;
    initial begin
        repeat(5) @(negedge clk); rst=0;
        access(1,1,0,0,0,32'h1020,0,mem['h102]);
        if(requests!=4) $fatal(1,"segment miss did not fetch four words");
        check_fill(0,32'h1000);
        access(1,0,0,0,0,32'h1010,0,mem['h101]); // PC extension, IAQ=0
        if(requests!=4) $fatal(1,"extension cache hit missed");
        access(1,1,0,0,0,32'h1040,0,mem['h104]); // subsegment miss
        if(requests!=8) $fatal(1,"subsegment miss did not fill four words");
        check_fill(4,32'h1040);
        access(1,1,0,0,0,32'h1200,0,mem['h120]);
        access(1,1,0,0,0,32'h1400,0,mem['h140]);
        access(1,1,0,0,0,32'h1600,0,mem['h160]);
        if(requests!=20) $fatal(1,"four segment fills missing");
        access(1,1,0,0,0,32'h1000,0,mem['h100]); // make first segment MRU
        access(1,1,0,0,0,32'h1800,0,mem['h180]); // evict 0x1200
        if(requests!=24) $fatal(1,"fifth segment fill missing");
        access(1,1,0,0,0,32'h1000,0,mem['h100]);
        if(requests!=24) $fatal(1,"MRU segment was evicted");
        access(1,1,0,0,0,32'h1200,0,mem['h120]);
        if(requests!=28) $fatal(1,"LRU segment was not evicted");
        // A data write changes RAM but not the resident instruction copy.
        access(0,0,1,0,1,32'h1000,16'hbeef,0);
        if(requests!=29 || writes!=1) $fatal(1,"data write did not bypass");
        access(1,1,0,0,0,32'h1000,0,16'h6100);
        if(requests!=29) $fatal(1,"self-modifying data write updated cache");
        // CD=1 preserves cache and reads just one requested word.
        cache_disable=1;
        access(1,1,0,0,0,32'h1000,0,16'hbeef);
        if(requests!=30 || trace_addr[29]!=32'h1000)
            $fatal(1,"CD did not bypass single requested word");
        cache_disable=0;
        access(1,1,0,0,0,32'h1000,0,16'h6100);
        if(requests!=30) $fatal(1,"CD damaged protected cache contents");
        // CF=1 empties cache continuously. CD=0 still fetches four words,
        // discards them, and repeats the fill for the next request.
        cache_flush=1;
        repeat(2) tick();
        if(dut.lru[0]!=0 || dut.lru[1]!=1 ||
           dut.lru[2]!=2 || dut.lru[3]!=3)
            $fatal(1,"CF did not reset numerical LRU order");
        access(1,0,0,0,0,32'h1000,0,16'hbeef);
        if(requests!=34) $fatal(1,"CF did not read four words");
        check_fill(30,32'h1000);
        access(1,1,0,0,0,32'h1000,0,16'hbeef);
        if(requests!=38) $fatal(1,"CF reused discarded fill");
        cache_flush=0;
        access(1,1,0,0,0,32'h1000,0,16'hbeef);
        if(requests!=42) $fatal(1,"post-CF cache did not refill");
        access(1,1,0,0,0,32'h1000,0,16'hbeef);
        if(requests!=42) $fatal(1,"post-CF cache hit missed");
        // IAQ alone does not imply cacheability; pixel and all ordinary data
        // traffic bypass, retaining their physical sidebands.
        access(0,1,0,0,0,32'h2000,0,mem['h200]);
        access(1,0,0,1,0,32'h2010,0,mem['h201]);
        if(requests!=44 || trace_addr[42]!=32'h2000 ||
           trace_addr[43]!=32'h2010 || trace_iaq[43])
            $fatal(1,"vector/pixel bypass classification failed");
        // CD takes the one-word path even while held CF clears the cache.
        cache_flush=1; cache_disable=1;
        repeat(2) tick();
        before_count=requests;
        access(1,1,0,0,0,32'h1010,0,mem['h101]);
        if(requests!=before_count+1 || trace_addr[before_count]!=32'h1010)
            $fatal(1,"simultaneous CF/CD did not fetch exactly one word");
        cache_flush=0; cache_disable=0;
        // Reset during a stalled fill must discard P flags and stop m_req.
        @(negedge clk); c_program=1; c_pixel=0; c_iaq=1;
        c_we=0; c_addr=32'h3000; c_req=1; stall=1;
        wait(m_req); tick();
        @(negedge clk); rst=1; c_req=0;
        tick(); @(negedge clk); rst=0; stall=0;
        repeat(6) tick();
        if(m_req || c_ack || dut.present[0]!=0 || dut.present[1]!=0 ||
           dut.present[2]!=0 || dut.present[3]!=0)
            $fatal(1,"reset left a cached/in-flight request");
        before_count=requests;
        access(1,1,0,0,0,32'h1000,0,16'hbeef);
        if(requests!=before_count+4) $fatal(1,"reset did not invalidate cache");
        $display("jttms10_cache PASS (%0d physical requests)",requests); $finish;
    end
    initial begin #1000000; $fatal(1,"cache test timeout"); end
endmodule
