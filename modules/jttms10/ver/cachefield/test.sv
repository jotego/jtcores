`timescale 1ns/1ps
// Field -> cache -> arbiter HOLD regression. A stale partial write can be
// buffered in the cache before the arbiter revokes the field's RMW pair.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1,req=0,we=1,hold_req=0;
    reg [31:0] addr=32'h1000,wdata=32'h000b;
    reg [5:0] size=6'd4;
    wire ack;
    wire [31:0] rdata;
    wire f_req,f_we,f_lock,f_ack,f_restart;
    wire [31:0] f_addr;
    wire [15:0] f_wdata,f_rdata;
    jttms10_field field_u(
        .clk(clk),.rst(rst),.req(req),.we(we),.addr(addr),
        .wdata(wdata),.size(size),.ack(ack),.rdata(rdata),
        .word_req(f_req),.word_we(f_we),.word_lock(f_lock),
        .word_addr(f_addr),.word_wdata(f_wdata),
        .word_rdata(f_rdata),.word_ack(f_ack),.word_restart(f_restart)
    );
    wire m_req,m_we,m_iaq,m_pixel,m_lock,m_ack,m_restart;
    wire [31:0] m_addr;
    wire [15:0] m_wdata,m_rdata;
    jttms10_cache cache_u(
        .clk(clk),.rst(rst),.cache_disable(1'b0),.cache_flush(1'b0),
        .c_req(f_req),.c_we(f_we),.c_iaq(1'b0),.c_program(1'b0),
        .c_pixel(1'b0),.c_lock(f_lock),.c_addr(f_addr),
        .c_wdata(f_wdata),.c_rdata(f_rdata),.c_ack(f_ack),
        .c_restart(f_restart),.m_req(m_req),.m_we(m_we),
        .m_iaq(m_iaq),.m_pixel(m_pixel),.m_lock(m_lock),
        .m_addr(m_addr),.m_wdata(m_wdata),.m_rdata(m_rdata),
        .m_ack(m_ack),.m_restart(m_restart)
    );
    wire hold_ack,cyc_req,cyc_iaq,cyc_org;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata,cyc_io_rdata,cyc_dpytap;
    wire [13:0] cyc_srfaddr;
    wire [7:0] cyc_dram_row;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0;
    jttms10_bus bus_u(
        .clk(clk),.rst(rst),.hold_req(hold_req),.hold_ack(hold_ack),
        .screen_req(1'b0),.screen_srfaddr(14'd0),
        .screen_dpytap(16'd0),.screen_org(1'b0),.screen_ack(),
        .refresh_req(1'b0),.refresh_row(8'd0),.refresh_cbr(1'b0),
        .host_mem_req(1'b0),.host_mem_we(1'b0),
        .host_mem_addr(32'd0),.host_mem_wdata(16'd0),
        .host_mem_is_io(1'b0),.host_mem_io_rdata(16'd0),
        .host_mem_rdata(),.host_mem_ack(),
        .word_req(m_req),.word_we(m_we),.word_iaq(m_iaq),
        .word_lock(m_lock),.word_pixel(m_pixel),.word_addr(m_addr),
        .word_wdata(m_wdata),.is_io(1'b0),.pixel_srt(1'b0),
        .io_rdata(16'd0),.word_rdata(m_rdata),.word_ack(m_ack),
        .word_restart(m_restart),.cyc_req(cyc_req),
        .cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),.cyc_rdata(cyc_rdata),
        .cyc_ack(cyc_ack)
    );

    reg [15:0] external_word=16'h1234;
    integer reads=0,writes=0,trace_count=0;
    reg [3:0] trace_kind [0:7];
    localparam IDLE=0,WAIT=1,ACK=2;
    reg [1:0] target_state=IDLE;
    integer delay_q=0;
    reg [3:0] held_kind;
    reg [31:0] held_addr;
    reg [15:0] held_data;
    always @(posedge clk) begin
        if(rst) begin
            target_state<=IDLE; cyc_ack<=0; cyc_rdata<=0;
        end else case(target_state)
            IDLE: if(cyc_req) begin
                if(cyc_kind!=4'd0 && cyc_kind!=4'd1)
                    $fatal(1,"unexpected local cycle kind %0d",cyc_kind);
                if(cyc_addr!=32'h1000)
                    $fatal(1,"unexpected local address %08x",cyc_addr);
                held_kind<=cyc_kind; held_addr<=cyc_addr;
                held_data<=cyc_wdata;
                trace_kind[trace_count]<=cyc_kind;
                trace_count<=trace_count+1;
                delay_q<=2; target_state<=WAIT;
            end
            WAIT: begin
                if(!cyc_req || cyc_kind!==held_kind ||
                   cyc_addr!==held_addr || cyc_wdata!==held_data)
                    $fatal(1,"cycle payload changed during wait");
                if(delay_q!=0) delay_q<=delay_q-1;
                else begin
                    cyc_ack<=1;
                    if(held_kind==4'd0) begin
                        cyc_rdata<=external_word;
                        reads<=reads+1;
                    end else begin
                        external_word<=held_data;
                        writes<=writes+1;
                    end
                    target_state<=ACK;
                end
            end
            ACK: begin cyc_ack<=0; target_state<=IDLE; end
        endcase
    end
    task tick; begin @(posedge clk); #1; end endtask
    integer guard;
    initial begin
        repeat(3) @(negedge clk);
        rst=0; req=1;
        // Wait for cache to capture the stale write, before the arbiter can
        // grant it. Its payload must be the first merge of 0x1234 and 0xB.
        guard=0;
        while(!(m_req && m_we && !cyc_req) && guard<80) begin
            tick(); guard=guard+1;
        end
        if(guard>=80 || m_wdata!==16'h123b || trace_count!=1 || writes!=0)
            $fatal(1,"did not reach buffered stale RMW write");
        @(negedge clk); hold_req=1;
        #1;
        if(!m_restart || m_req || f_req || cyc_req)
            $fatal(1,"HOLD restart did not suppress stale write immediately");
        tick();
        if(!hold_ack || m_req || writes!=0)
            $fatal(1,"stale write escaped during HOLD grant");
        // External owner changes the bits outside the four-bit field.
        @(negedge clk); external_word=16'ha5c0;
        repeat(3) tick();
        if(cyc_req || trace_count!=1 || writes!=0)
            $fatal(1,"local cycle ran while HOLD was active cyc=%b trace=%0d writes=%0d",
                   cyc_req,trace_count,writes);
        @(negedge clk); hold_req=0;
        guard=0;
        while(!ack && guard<100) begin tick(); guard=guard+1; end
        if(!ack) $fatal(1,"field write did not complete after HOLD");
        if(external_word!==16'ha5cb || reads!=2 || writes!=1 ||
           trace_count!=3 || trace_kind[0]!=4'd0 ||
           trace_kind[1]!=4'd0 || trace_kind[2]!=4'd1)
            $fatal(1,"restart trace/merge wrong: value=%04x r=%0d w=%0d cycles=%0d",
                   external_word,reads,writes,trace_count);
        repeat(4) tick();
        if(writes!=1 || trace_count!=3)
            $fatal(1,"held architectural request reissued");
        $display("jttms10_cachefield PASS"); $finish;
    end
    initial begin #200000; $fatal(1,"cachefield test timeout"); end
endmodule
