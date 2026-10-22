`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,hold_req=0,host_req=0,host_we=0;
    reg [1:0] host_reg=0,host_be=0;
    reg [15:0] host_wdata=0;
    wire [15:0] host_rdata;
    wire host_ack,host_busy;
    reg word_req=0,word_we=0,word_iaq=0,word_lock=0,word_pixel=0;
    reg [31:0] word_addr=0;
    reg [15:0] word_wdata=0;
    wire [15:0] word_rdata;
    wire word_ack,word_restart;
    wire [15:0] intpend,hstctlh;
    wire hint_n,halt,cyc_req,cyc_iaq,cyc_org;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata,cyc_io_rdata,cyc_dpytap;
    wire [13:0] cyc_srfaddr;
    wire [7:0] cyc_dram_row;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0,stall_local=0;
    jttms10_fabric dut(
        .clk(clk),.rst(rst),.vclk_cen(1'b0),
        .hcs_n(1'b0),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(1'b1),.lint2_n(1'b1),
        .hold_req(hold_req),.hold_ack(),
        .host_req(host_req),.host_we(host_we),
        .host_reg(host_reg),.host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),.host_busy(host_busy),
        .word_req(word_req),.word_we(word_we),.word_iaq(word_iaq),
        .word_lock(word_lock),.word_pixel(word_pixel),
        .word_addr(word_addr),.word_wdata(word_wdata),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),
        .nmi_clear(1'b0),.wvp_set(1'b0),
        .psize(),.convsp(),.convdp(),.control(),.pmask(),
        .pixel_srt(),.intenb(),.intpend(intpend),.hstctlh(hstctlh),
        .irq_pending(),.irq_vector(),.nmi_pending(),.nmi_nmim(),
        .halt(halt),.hint_n(hint_n),
        .hcount(),.vcount(),.dpyadr(),.refcnt(),
        .hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),.cyc_rdata(cyc_rdata),
        .cyc_ack(cyc_ack)
    );
    reg [15:0] mem [0:255];
    integer i;
    initial for (i=0;i<256;i=i+1) mem[i]=0;
    localparam [1:0] T_IDLE=0,T_WAIT=1,T_ACK=2;
    reg [1:0] tstate=0;
    reg [2:0] delay_q;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q,io_q;
    integer local_count=0,io_read_count=0,io_write_count=0;
    always @(posedge clk) begin
        if (rst) begin
            tstate<=T_IDLE; cyc_ack<=0; cyc_rdata<=0;
            local_count<=0; io_read_count<=0; io_write_count<=0;
        end else case (tstate)
            T_IDLE: if (cyc_req) begin
                tstate<=T_WAIT; delay_q<=3;
                kind_q<=cyc_kind; addr_q<=cyc_addr;
                data_q<=cyc_wdata; io_q<=cyc_io_rdata;
                if (cyc_kind==0 || cyc_kind==1) local_count<=local_count+1;
                if (cyc_kind==5) io_read_count<=io_read_count+1;
                if (cyc_kind==6) io_write_count<=io_write_count+1;
            end
            T_WAIT: begin
                if (!cyc_req || cyc_kind!==kind_q ||
                    cyc_addr!==addr_q || cyc_wdata!==data_q ||
                    cyc_io_rdata!==io_q)
                    $fatal(1,"host local payload changed during wait");
                if (stall_local) begin end
                else if (delay_q!=0) delay_q<=delay_q-1'b1;
                else begin
                    cyc_ack<=1;
                    case (kind_q)
                        0: cyc_rdata<=mem[addr_q[11:4]];
                        1: mem[addr_q[11:4]]<=data_q;
                        5: cyc_rdata<=io_q;
                        default: cyc_rdata<=0;
                    endcase
                    tstate<=T_ACK;
                end
            end
            T_ACK: if (!cyc_req) begin cyc_ack<=0; tstate<=T_IDLE; end
        endcase
    end
    task tick; begin @(posedge clk); #1; end endtask
    task cpu_write(input [31:0] a,input [15:0] d);
        integer guard;
        begin
            @(negedge clk); word_addr=a; word_wdata=d;
            word_req=1; word_we=1;
            guard=0;
            while (!word_ack && guard<200) begin @(negedge clk); guard=guard+1; end
            if (!word_ack) $fatal(1,"CPU write timeout %08x",a);
            tick(); @(negedge clk); word_req=0; word_we=0;
            tick();
        end
    endtask
    task cpu_read(input [31:0] a,input [15:0] expected);
        integer guard;
        begin
            @(negedge clk); word_addr=a; word_req=1; word_we=0;
            guard=0;
            while (!word_ack && guard<200) begin @(negedge clk); guard=guard+1; end
            if (!word_ack) $fatal(1,"CPU read timeout %08x",a);
            if (word_rdata!==expected)
                $fatal(1,"CPU read %08x expected %04x got %04x",a,expected,word_rdata);
            tick(); @(negedge clk); word_req=0;
            tick();
        end
    endtask
    task host_access(input wr,input [1:0] sel,input [1:0] be,
                     input [15:0] d,input [15:0] expected);
        integer guard;
        begin
            @(negedge clk); host_reg=sel; host_be=be;
            host_wdata=d; host_we=wr; host_req=1;
            guard=0;
            while (!host_ack && guard<100) begin tick(); guard=guard+1; end
            if (!host_ack) $fatal(1,"host register ack timeout");
            if (!wr && host_rdata!==expected)
                $fatal(1,"host read reg %0d expected %04x got %04x",
                    sel,expected,host_rdata);
            @(negedge clk); host_req=0; host_we=0;
            tick();
        end
    endtask
    task wait_host;
        integer guard;
        begin
            guard=0;
            while (host_busy && guard<300) begin tick(); guard=guard+1; end
            if (host_busy) $fatal(1,"host indirect cycle timeout");
            repeat (2) tick();
        end
    endtask
    integer before_count;
    initial begin
        mem[8'h10]=16'h1111; mem[8'h11]=16'h2222;
        mem[8'h20]=16'h3333;
        tick(); @(negedge clk); rst=0;
        cpu_write(32'hc00000b0,16'h0018); // disable DRAM refresh
        before_count=local_count;
        cpu_write(32'hc00000d0,16'h0100);
        cpu_write(32'hc00000e0,16'h0000);
        cpu_write(32'hc00000c0,16'hbeef);
        if (local_count!=before_count)
            $fatal(1,"CPU HSTADR/HSTDATA writes caused host cycles");
        cpu_read(32'hc00000d0,16'h0100);
        cpu_read(32'hc00000c0,16'hbeef);
        host_access(1,2'd3,2'b10,16'h1800,0); // INCR + INCW, LBL=0
        host_access(0,2'd3,2'b11,0,16'h1800);
        // Upper byte of ADRH is last for LBL=0. Its write prefetched mem[10].
        host_access(1,2'd1,2'b10,16'h0000,0);
        if (!host_busy) $fatal(1,"ADRH last byte did not prefetch");
        wait_host();
        if (local_count!=before_count+1)
            $fatal(1,"address completion prefetch count");
        host_access(0,2'd2,2'b11,0,16'h1111); // returns old buffer
        wait_host();
        cpu_read(32'hc00000d0,16'h0110); // INCR before next read
        cpu_read(32'hc00000c0,16'h2222);
        host_access(1,2'd2,2'b11,16'habcd,0);
        wait_host();
        if (mem[8'h11]!==16'habcd) $fatal(1,"HSTDATA indirect write");
        cpu_read(32'hc00000d0,16'h0120); // INCW after completion
        // Host's low-byte HSTCTL owns MSGIN/INTIN and may clear INTOUT.
        cpu_write(32'hc00000f0,16'h00b0); // MSGOUT=3, INTOUT=1
        if (hint_n!==0) $fatal(1,"CPU INTOUT did not assert HINT");
        host_access(1,2'd3,2'b01,16'h000d,0); // MSGIN=5, INTIN=1, INTOUT=0
        cpu_read(32'hc00000f0,16'h003d);
        if (!hint_n || !intpend[9]) $fatal(1,"host HSTCTLL ownership/HIP");
        cpu_write(32'hc00000f0,16'h0000);
        cpu_read(32'hc00000f0,16'h0005);
        // LBL=1: high-byte address write does not prefetch, low-byte write does.
        host_access(1,2'd3,2'b10,16'h3800,0);
        host_access(1,2'd1,2'b11,16'h0000,0);
        host_access(1,2'd0,2'b10,16'h0200,0);
        wait_host();
        before_count=local_count;
        host_access(1,2'd0,2'b01,16'h0000,0);
        wait_host();
        if (local_count!=before_count+1)
            $fatal(1,"LBL=1 last low byte did not prefetch");
        host_access(0,2'd2,2'b10,0,16'h3333);
        if (host_busy) $fatal(1,"LBL=1 upper data byte incorrectly launched read");
        host_access(0,2'd2,2'b01,0,16'h3333);
        wait_host();
        // Indirect I/O write to HSTCTLL uses host-side ownership, once.
        host_access(1,2'd3,2'b10,16'h0000,0); // LBL=0, INCW/INCR off
        cpu_write(32'hc00000d0,16'h00f0);
        cpu_write(32'hc00000e0,16'hc000);
        before_count=io_write_count;
        host_access(1,2'd2,2'b11,16'h000b,0);
        wait_host();
        if (io_write_count!=before_count+1 || !intpend[9])
            $fatal(1,"host indirect HSTCTLL commit/INTIN");
        cpu_read(32'hc00000f0,16'h000b);
        // Indirect I/O write to HSTADRL updates pointer, without recursion.
        cpu_write(32'hc00000d0,16'h00d0);
        before_count=io_write_count;
        host_access(1,2'd2,2'b11,16'h0123,0);
        wait_host();
        if (io_write_count!=before_count+1)
            $fatal(1,"indirect HSTADRL generated recursive cycle");
        cpu_read(32'hc00000d0,16'h0120);
        // Indirect I/O write to HSTDATA also terminates after one cycle.
        cpu_write(32'hc00000d0,16'h00c0);
        before_count=io_write_count;
        host_access(1,2'd2,2'b11,16'hface,0);
        wait_host();
        if (io_write_count!=before_count+1)
            $fatal(1,"indirect HSTDATA generated recursive cycle");
        cpu_read(32'hc00000c0,16'hface);
        // Indirect read of a host register uses the same shared I/O view.
        cpu_write(32'hc00000d0,16'h00d0);
        before_count=io_read_count;
        host_access(0,2'd2,2'b11,0,16'hface);
        wait_host();
        if (io_read_count!=before_count+1)
            $fatal(1,"indirect HSTADRL read missing");
        cpu_read(32'hc00000c0,16'h00d0);
        // Host-indirect access to HSTCTLH writes its shared high byte once.
        cpu_write(32'hc00000d0,16'h0100);
        before_count=io_write_count;
        host_access(1,2'd2,2'b11,16'h8100,0);
        wait_host();
        if (io_write_count!=before_count+1 || hstctlh!==16'h8100 || !halt)
            $fatal(1,"indirect HSTCTLH write/mask");
        host_access(0,2'd3,2'b11,0,16'h810b);
        host_access(1,2'd3,2'b10,16'h0000,0); // clear HLT/NMI
        // Host client has priority over a simultaneously pending CPU word.
        cpu_write(32'hc00000d0,16'h0300);
        cpu_write(32'hc00000e0,16'h0000);
        @(negedge clk); host_reg=2'd2; host_be=2'b11;
        host_wdata=16'h8ace; host_we=1; host_req=1;
        tick();
        if (!host_ack || !host_busy) $fatal(1,"host request not accepted");
        @(negedge clk); host_req=0; host_we=0;
        word_req=1; word_we=0; word_addr=32'h00000400;
        before_count=0;
        while(!cyc_req && before_count<64) begin
            tick(); before_count=before_count+1;
        end
        if (!cyc_req || cyc_kind!==4'd1 || cyc_addr!==32'h00000300 ||
            cyc_wdata!==16'h8ace)
            $fatal(1,"first local grant was not the pending host write");
        wait_host();
        if (mem[8'h30]!==16'h8ace) $fatal(1,"host priority write lost");
        before_count=0;
        while (!word_ack && before_count<100) begin tick(); before_count=before_count+1; end
        if (!word_ack) $fatal(1,"pending CPU did not run after host");
        @(negedge clk); word_req=0; tick();
        // TI §10.3.2: HSTCTL stays accessible during a stalled indirect
        // cycle, but HSTADR and HSTDATA requests wait for local completion.
        host_access(1,2'd3,2'b10,16'h0000,0); // INCW clear at launch
        cpu_write(32'hc00000d0,16'h0300);
        cpu_write(32'hc00000e0,16'h0000);
        @(negedge clk); stall_local=1;
        host_access(1,2'd2,2'b11,16'hbabe,0);
        if (!host_busy) $fatal(1,"stalled indirect write not busy");
        before_count=0;
        while ((!cyc_req || cyc_kind!=4'd1 || cyc_addr!=32'h00000300)
               && before_count<30) begin tick(); before_count=before_count+1; end
        if (before_count==30 || cyc_ack)
            $fatal(1,"indirect write was not stalled at target");
        host_access(0,2'd3,2'b11,0,16'h000b);
        if (!host_busy || cyc_ack) $fatal(1,"HSTCTL read waited for local ack");
        host_access(1,2'd3,2'b10,16'h0800,0); // INCW change must not alter captured write
        if (!host_busy || cyc_ack || cyc_addr!==32'h00000300 ||
            cyc_wdata!==16'hbabe)
            $fatal(1,"HSTCTL write disturbed pending local payload");
        host_access(0,2'd3,2'b11,0,16'h080b);
        if (!host_busy || cyc_ack) $fatal(1,"HSTCTL update waited for local ack");
        @(negedge clk); host_reg=2'd0; host_be=2'b11;
        host_we=0; host_req=1;
        repeat (4) begin tick(); if (host_ack) $fatal(1,"HSTADR accepted while busy"); end
        @(negedge clk); host_req=0; tick();
        @(negedge clk); host_reg=2'd2; host_req=1;
        repeat (4) begin tick(); if (host_ack) $fatal(1,"HSTDATA accepted while busy"); end
        @(negedge clk); host_req=0; tick();
        if (!host_busy || cyc_ack) $fatal(1,"indirect cycle completed while stalled");
        @(negedge clk); stall_local=0;
        wait_host();
        if (mem[8'h30]!==16'hbabe) $fatal(1,"stalled indirect write lost");
        cpu_read(32'hc00000d0,16'h0300); // captured INCW was clear
        $display("jttms10_host PASS"); $finish;
    end
endmodule
