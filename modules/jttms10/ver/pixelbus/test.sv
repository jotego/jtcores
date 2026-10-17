`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,cen=0,pixel_srt=0;
    reg logical_req=0,logical_we=0,logical_pixel=0;
    reg [31:0] logical_addr=0,logical_data=0;
    reg [5:0] logical_size=0;
    wire word_req,word_we,word_iaq,word_lock,word_pixel,word_ack,word_restart;
    wire [31:0] word_addr,pc,st;
    wire [15:0] word_wdata,word_rdata,ir;
    wire retire,fault,logical_ack;
    wire [31:0] logical_rdata;
    wire cyc_req,cyc_iaq,cyc_org;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata,cyc_io_rdata,cyc_dpytap;
    wire [13:0] cyc_srfaddr;
    wire [7:0] cyc_dram_row;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0,stall=0;
    jttms10_word dut(
        .rst(rst),.clk(clk),.cen(cen),
        .irq_req(1'b0),.irq_vector(32'd0),.nmi_req(1'b0),
        .nmi_nostack(1'b0),.halt_req(1'b0),.emu_run(1'b1),
        .psize(16'd4),.convdp(16'd0),.pixel_srt(pixel_srt),
        .cache_flush(1'b0),
        .nmi_clear(),.emu_ack(),
        .word_req(word_req),.word_we(word_we),.word_addr(word_addr),
        .word_wdata(word_wdata),.word_iaq(word_iaq),.word_pixel(word_pixel),
        .word_lock(word_lock),.word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),.pc(pc),.st(st),.ir(ir),
        .retire(retire),.fault(fault)
    );
    // Override only the logical CPU request in this focused word-boundary
    // test. The production field adapter and NARC arbiter run unchanged.
    initial begin
        force dut.field_req=logical_req;
        force dut.field_we=logical_we;
        force dut.field_iaq=1'b0;
        force dut.field_program=1'b0;
        force dut.field_pixel=logical_pixel;
        force dut.field_addr=logical_addr;
        force dut.field_wdata=logical_data;
        force dut.field_size=logical_size;
    end
    assign logical_ack=dut.field_ack;
    assign logical_rdata=dut.field_rdata;
    jttms10_bus u_bus(
        .clk(clk),.rst(rst),.hold_req(1'b0),.hold_ack(),
        .screen_req(1'b0),.screen_srfaddr(14'd0),
        .screen_dpytap(16'd0),.screen_org(1'b0),.screen_ack(),
        .refresh_req(1'b0),.refresh_row(8'd0),.refresh_cbr(1'b0),
        .host_mem_req(1'b0),.host_mem_we(1'b0),
        .host_mem_addr(32'd0),.host_mem_wdata(16'd0),
        .host_mem_is_io(1'b0),.host_mem_io_rdata(16'd0),
        .host_mem_rdata(),.host_mem_ack(),
        .word_req(word_req),.word_we(word_we),.word_iaq(word_iaq),
        .word_lock(word_lock),.word_pixel(word_pixel),
        .word_addr(word_addr),.word_wdata(word_wdata),
        .is_io(1'b0),.pixel_srt(pixel_srt),.io_rdata(16'd0),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack)
    );
    reg [15:0] mem [0:255];
    integer i;
    initial for(i=0;i<256;i=i+1) mem[i]=0;
    localparam [1:0] IDLE=0,WAIT=1,ACK=2;
    reg [1:0] state=IDLE;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q;
    integer delay_q=0,count=0;
    reg [3:0] kinds [0:31];
    reg [31:0] addrs [0:31];
    reg [15:0] datas [0:31];
    always @(posedge clk) begin
        if(rst) begin state<=IDLE; cyc_ack<=0; cyc_rdata<=0; end
        else case(state)
            IDLE: if(cyc_req) begin
                kind_q<=cyc_kind; addr_q<=cyc_addr; data_q<=cyc_wdata;
                kinds[count]<=cyc_kind; addrs[count]<=cyc_addr;
                datas[count]<=cyc_wdata; count<=count+1;
                delay_q<=3; state<=WAIT;
            end
            WAIT: begin
                if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q ||
                   cyc_wdata!==data_q || cyc_iaq)
                    $fatal(1,"pixel NARC payload changed during wait");
                if(!stall) begin
                    if(delay_q!=0) delay_q<=delay_q-1;
                    else begin
                        cyc_ack<=1; state<=ACK;
                        case(kind_q)
                            0: cyc_rdata<=mem[addr_q[11:4]];
                            1: mem[addr_q[11:4]]<=data_q;
                            7: cyc_rdata<=16'hffff; // MTR has no LAD pixel data
                            8: ; // RTM uses VRAM serial register, not LAD data
                            default: $fatal(1,"unexpected cycle kind %0d",kind_q);
                        endcase
                    end
                end
            end
            ACK: if(!cyc_req) begin cyc_ack<=0; state<=IDLE; end
        endcase
    end
    task tick; begin @(posedge clk); #1; end endtask
    task transaction(input pix,input srt,input wr,input [31:0] a,
                     input [5:0] size,input [31:0] d,input [31:0] expected);
        integer guard;
        begin
            @(negedge clk);
            pixel_srt=srt; logical_pixel=pix; logical_we=wr;
            logical_addr=a; logical_size=size; logical_data=d; logical_req=1;
            guard=0;
            while(!logical_ack && guard<300) begin tick(); guard=guard+1; end
            if(!logical_ack) $fatal(1,"logical request timeout");
            if(!wr && logical_rdata!==expected)
                $fatal(1,"pixel read expected=%08x got=%08x",expected,logical_rdata);
            @(negedge clk); logical_req=0;
            repeat(3) tick();
        end
    endtask
    initial begin
        mem['h10]=16'h1234; mem['h20]=16'habcd; mem['h30]=16'h0f0f;
        repeat(5) @(negedge clk); rst=0;
        transaction(1,0,1,32'h00000104,6'd4,32'ha,0);
        if(count!=2 || kinds[0]!=0 || kinds[1]!=1 ||
           addrs[0]!=32'h100 || addrs[1]!=32'h100 || mem['h10]!=16'h12a4)
            $fatal(1,"non-SRT pixel partial RMW/tag failed");
        transaction(1,1,1,32'h00000204,6'd4,32'h5,0);
        if(count!=4 || kinds[2]!=7 || kinds[3]!=8 ||
           addrs[2]!=32'h200 || addrs[3]!=32'h200 ||
           mem['h20]!=16'habcd)
            $fatal(1,"SRT partial write must be one MTR plus one RTM");
        transaction(1,1,0,32'h00000308,6'd4,0,0);
        if(count!=5 || kinds[4]!=7 || addrs[4]!=32'h300)
            $fatal(1,"SRT pixel read classification/zero failed");
        transaction(1,0,0,32'h00000308,6'd4,0,32'h0000000f);
        if(count!=6 || kinds[5]!=0)
            $fatal(1,"non-SRT tagged pixel read lost LAD data");
        transaction(0,1,0,32'h00000104,6'd4,0,32'h0000000a);
        if(count!=7 || kinds[6]!=0)
            $fatal(1,"SRT converted non-pixel data read");
        // Reset cancels a held transfer without a late architectural ack.
        @(negedge clk); pixel_srt=1; logical_pixel=1;
        logical_we=0; logical_addr=32'h00000300;
        logical_size=6'd16; logical_req=1; stall=1;
        wait(cyc_req); tick();
        @(negedge clk); rst=1; logical_req=0;
        tick(); @(negedge clk); rst=0; stall=0;
        repeat(8) tick();
        if(logical_ack || cyc_req || word_pixel)
            $fatal(1,"reset left a stale pixel request/tag");
        $display("jttms10_pixelbus PASS (%0d cycles)",count); $finish;
    end
    initial begin #1000000; $fatal(1,"pixelbus timeout"); end
endmodule
