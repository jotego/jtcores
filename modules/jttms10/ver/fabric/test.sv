`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, video_run=0;
    reg [2:0] vphase=0;
    always @(posedge clk) if (rst) vphase<=0;
                       else vphase<=vphase==5 ? 0 : vphase+1'b1;
    wire vclk_cen=video_run && vphase==2;
    reg hold_req=0;
    wire hold_ack;
    reg req=0,we=0,iaq=0;
    reg [31:0] addr=0,wdata=0;
    reg [5:0] size=0;
    wire ack,word_req,word_we,word_lock;
    wire [31:0] rdata,word_addr;
    wire [15:0] word_wdata,word_rdata;
    wire word_ack,word_restart;
    wire [15:0] psize,convsp,convdp,control,pmask,intenb,intpend;
    wire [15:0] hcount,vcount,dpyadr,refcnt;
    wire [31:0] irq_vector;
    wire pixel_srt,irq_pending,nmi_pending,nmi_nmim,halt,hint_n;
    wire hs,vs,hblank,vblank,blank;
    wire cyc_req,cyc_iaq,cyc_org;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata,cyc_io_rdata,cyc_dpytap;
    wire [13:0] cyc_srfaddr;
    wire [7:0] cyc_dram_row;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0;
    jttms10_field u_field(
        .clk(clk),.rst(rst),.req(req),.we(we),.addr(addr),
        .wdata(wdata),.size(size),.ack(ack),.rdata(rdata),
        .word_req(word_req),.word_we(word_we),.word_addr(word_addr),
        .word_wdata(word_wdata),.word_lock(word_lock),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart)
    );
    jttms10_fabric #(.BUS_TIMING(0)) dut(
        .clk(clk),.rst(rst),.vclk_cen(vclk_cen),
        .hcs_n(1'b0),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(1'b1),.lint2_n(1'b1),
        .hold_req(hold_req),.hold_ack(hold_ack),
        .host_req(1'b0),.host_we(1'b0),.host_reg(2'b00),
        .host_be(2'b00),.host_wdata(16'd0),
        .host_rdata(),.host_ack(),.host_busy(),
        .word_req(word_req),.word_pending(word_req),.word_we(word_we),.word_iaq(iaq),
        .word_lock(word_lock),.word_pixel(1'b0),
        .word_addr(word_addr),.word_wdata(word_wdata),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),
        .nmi_clear(1'b0),.wvp_set(1'b0),
        .psize(psize),.convsp(convsp),.convdp(convdp),
        .control(control),.pmask(pmask),.pixel_srt(pixel_srt),
        .intenb(intenb),.intpend(intpend),.hstctlh(),
        .irq_pending(irq_pending),.irq_vector(irq_vector),
        .nmi_pending(nmi_pending),.nmi_nmim(nmi_nmim),
        .halt(halt),.hint_n(hint_n),
        .hcount(hcount),.vcount(vcount),.dpyadr(dpyadr),
        .refcnt(refcnt),.hs(hs),.vs(vs),
        .hblank(hblank),.vblank(vblank),.blank(blank),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack)
    );
    reg [15:0] mem [0:255];
    integer n;
    initial for (n=0;n<256;n=n+1) mem[n]=0;
    localparam [1:0] T_IDLE=0,T_WAIT=1,T_ACK=2;
    reg [1:0] tstate=0;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] wdata_q,io_q;
    reg [13:0] srf_q;
    reg [2:0] delay_q;
    integer io_reads=0,io_writes=0,screen_count=0,dram_count=0;
    integer rmw_reads=0,word_writes=0,restart_count=0;
    reg inject_hold=0;
    reg [15:0] first_screen_dpyadr;
    always @(posedge clk) begin
        if (rst) begin
            tstate<=T_IDLE; cyc_ack<=0; cyc_rdata<=0;
            io_reads<=0; io_writes<=0; screen_count<=0; dram_count<=0;
            rmw_reads<=0; word_writes<=0; restart_count<=0;
            inject_hold<=0; hold_req<=0;
        end else begin
            if (word_restart) restart_count<=restart_count+1;
            if (inject_hold && word_ack && word_lock && !word_we) begin
                hold_req<=1;
                inject_hold<=0;
            end
            case (tstate)
                T_IDLE: if (cyc_req) begin
                    kind_q<=cyc_kind; addr_q<=cyc_addr;
                    wdata_q<=cyc_wdata; io_q<=cyc_io_rdata;
                    srf_q<=cyc_srfaddr;
                    delay_q<=cyc_kind==4'd2 ? 3'd5 : 3'd2;
                    tstate<=T_WAIT;
                    case (cyc_kind)
                        4'd5: io_reads<=io_reads+1;
                        4'd6: io_writes<=io_writes+1;
                        4'd2: begin
                            screen_count<=screen_count+1;
                            first_screen_dpyadr<=dpyadr;
                            video_run<=0;
                        end
                        4'd3,4'd4: dram_count<=dram_count+1;
                        4'd0: if (cyc_addr==32'h00000000)
                                  rmw_reads<=rmw_reads+1;
                        4'd1: word_writes<=word_writes+1;
                    endcase
                end
                T_WAIT: begin
                    if (!cyc_req || cyc_kind!==kind_q ||
                        cyc_addr!==addr_q || cyc_wdata!==wdata_q ||
                        cyc_io_rdata!==io_q || cyc_srfaddr!==srf_q)
                        $fatal(1,"NARC payload not stable through wait");
                    if (delay_q!=0) delay_q<=delay_q-1'b1;
                    else begin
                        cyc_ack<=1;
                        case (kind_q)
                            4'd0: cyc_rdata<=mem[addr_q[11:4]];
                            4'd1: mem[addr_q[11:4]]<=wdata_q;
                            4'd5: cyc_rdata<=io_q;
                            default: cyc_rdata<=0;
                        endcase
                        tstate<=T_ACK;
                    end
                end
                T_ACK: if (!cyc_req) begin
                    cyc_ack<=0;
                    tstate<=T_IDLE;
                end
            endcase
        end
    end
    task tick; begin @(posedge clk); #1; end endtask
    task write_field(input [31:0] a,input [5:0] s,input [31:0] d);
        integer guard;
        begin
            @(negedge clk); addr=a; size=s; wdata=d; we=1; req=1;
            guard=0;
            while (!ack && guard<1000) begin tick(); guard=guard+1; end
            if (!ack) $fatal(1,"field write timeout at %08x",a);
            @(negedge clk); req=0; we=0;
            tick();
        end
    endtask
    task read_field(input [31:0] a,input [5:0] s,input [31:0] expected);
        integer guard;
        begin
            @(negedge clk); addr=a; size=s; we=0; req=1;
            guard=0;
            while (!ack && guard<1000) begin tick(); guard=guard+1; end
            if (!ack) $fatal(1,"field read timeout at %08x",a);
            if (rdata!==expected)
                $fatal(1,"field %08x expected %08x got %08x",a,expected,rdata);
            @(negedge clk); req=0; tick();
        end
    endtask
    integer guard,dram_before;
    initial begin
        mem[0]=16'ha50f;
        tick(); @(negedge clk); rst=0;
        // A 24-bit field spans CONVSP high byte and all of CONVDP. Its
        // first physical word is an I/O read-modify-write pair.
        write_field(32'hc0000130,6'd16,32'h55aa);
        write_field(32'hc0000138,6'd24,32'h123456);
        if (convsp!==16'h56aa || convdp!==16'h1234)
            $fatal(1,"cross-word I/O write or RMW merge failed");
        read_field(32'hc0000138,6'd24,32'h123456);
        if (io_writes!==3 || io_reads<3)
            $fatal(1,"I/O cycles/commit count wrong: W=%0d R=%0d",io_writes,io_reads);
        // Normal memory partial write; HOLD arrives after its read, then an
        // external owner changes unprotected high bits before retry.
        @(negedge clk); inject_hold=1;
        addr=32'h00000003; size=6'd8; wdata=32'h5a; we=1; req=1;
        guard=0;
        while (!hold_ack && guard<500) begin tick(); guard=guard+1; end
        if (!hold_ack || restart_count!=1)
            $fatal(1,"HOLD did not restart partial RMW");
        @(negedge clk); mem[0]=16'h550f; hold_req=0;
        guard=0;
        while (!ack && guard<500) begin tick(); guard=guard+1; end
        if (!ack || mem[0]!==16'h52d7 || rmw_reads<2 || word_writes!=1)
            $fatal(1,"HOLD reread/merge failed: mem=%04x reads=%0d writes=%0d",
                mem[0],rmw_reads,word_writes);
        @(negedge clk); req=0; we=0; tick();
        // Program a short display while VCLK is stopped; enable it only
        // after all registers are set, then freeze on the first screen cycle.
        write_field(32'hc0000010,6'd16,0); // HEBLNK
        write_field(32'hc0000020,6'd16,1); // HSBLNK
        write_field(32'hc0000030,6'd16,3); // HTOTAL
        write_field(32'hc0000050,6'd16,0); // VEBLNK
        write_field(32'hc0000060,6'd16,3); // VSBLNK
        write_field(32'hc0000070,6'd16,4); // VTOTAL
        write_field(32'hc0000090,6'd16,32'h2800); // DPYSTRT
        write_field(32'hc00001e0,6'd16,32'h2800); // DPYADR
        write_field(32'hc0000080,6'd16,32'hf004); // SRE, ORG0, DUDATE1
        @(negedge clk); video_run=1;
        guard=0;
        while (screen_count==0 && guard<500) begin tick(); guard=guard+1; end
        if (screen_count!=1 || cyc_kind!==4'd2 || cyc_srfaddr!==14'h0a00)
            $fatal(1,"first integrated screen request missing");
        guard=0;
        while (cyc_req && guard<100) begin tick(); guard=guard+1; end
        if (cyc_req || dpyadr!==first_screen_dpyadr-16'd4)
            $fatal(1,"delayed screen ack did not advance DPYADR once");
        repeat (12) tick();
        if (screen_count!=1) $fatal(1,"screen request duplicated");
        // REFCNT produces an actual DRAM cycle through the same fabric.
        write_field(32'hc00000b0,6'd16,32'h0018); // RR=11 disabled
        write_field(32'hc00001f0,6'd16,32'h0100);
        dram_before=dram_count;
        write_field(32'hc00000b0,6'd16,32'h0008); // RR=01
        guard=0;
        while (dram_count==dram_before && guard<200) begin tick(); guard=guard+1; end
        if (dram_count==dram_before) $fatal(1,"refresh event not serviced");
        $display("jttms10_fabric PASS"); $finish;
    end
endmodule
