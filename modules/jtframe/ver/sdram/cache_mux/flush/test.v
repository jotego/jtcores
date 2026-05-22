`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD   = 10;
localparam integer HF       = 1;
localparam integer SDRAM_AW = 23;
localparam integer WORDS    = 2048;
localparam [15:0] ORIGINAL  = 16'h35a7;
localparam [15:0] UPDATED   = 16'hcafe;
localparam [15:0] CONTENDED = 16'h5eed;

reg                 rst, clk, clk_sdram;
reg  [22:1]         addr0;
reg                 rd0, wr0, flush0;
reg  [15:0]         din0;
reg  [ 1:0]         wdsn0;
wire [15:0]         dout0;
wire                ok0, flushing0, flush_done0;

wire [22:1]         addr_zero = 22'd0;
wire                sig_zero  = 1'b0;
wire [15:0]         data_zero = 16'd0;
wire [ 1:0]         dsn_zero  = 2'b00;
wire [ 1:0]         dsn_mask  = 2'b11;

wire [15:0]         dout1, dout2, dout3, dout4, dout5, dout6, dout7;
wire                ok1, ok2, ok3, ok4, ok5, ok6, ok7;
wire                flushing1, flushing2, flushing3, flushing4;
wire                flushing5, flushing6, flushing7;
wire                flush_done1, flush_done2, flush_done3, flush_done4;
wire                flush_done5, flush_done6, flush_done7;

wire [SDRAM_AW-1:1] sdram_addr;
wire [SDRAM_AW-1:0] sdram_addr_full;
wire [ 1:0]         sdram_ba_mux;
wire                sdram_rd, sdram_wr, sdram_ack, sdram_dst, sdram_dok;
wire                sdram_rdy, init;
wire [15:0]         sdram_din_mux, sdram_dout_mux;
wire [15:0]         sdram_dq;
wire [12:0]         sdram_a;
wire [ 1:0]         sdram_dqm, sdram_ba;
wire                sdram_nwe, sdram_ncas, sdram_nras, sdram_ncs, sdram_cke;

reg  [15:0]         exp_mem [0:WORDS-1];
reg                 burst_busy, count_flush_active;
integer             flush_write_count;
integer             hcnt, idx;

wire rfsh = hcnt == 0;
assign sdram_addr_full = { 1'b0, sdram_addr };

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAM_AW ),
    .ENDIAN   ( 0        ),
    .AW0      ( 23       ),
    .BLOCKS0  ( 2        ),
    .BLKSIZE0 ( 1024     ),
    .DW0      ( 16       ),
    .AW1      ( 23       ),
    .BLOCKS1  ( 1        ),
    .BLKSIZE1 ( 1024     ),
    .DW1      ( 16       ),
    .AW2      ( 23       ),
    .BLOCKS2  ( 1        ),
    .BLKSIZE2 ( 1024     ),
    .DW2      ( 16       ),
    .AW3      ( 23       ),
    .BLOCKS3  ( 1        ),
    .BLKSIZE3 ( 1024     ),
    .DW3      ( 16       ),
    .AW4      ( 23       ),
    .BLOCKS4  ( 1        ),
    .BLKSIZE4 ( 1024     ),
    .DW4      ( 16       ),
    .AW5      ( 23       ),
    .BLOCKS5  ( 1        ),
    .BLKSIZE5 ( 1024     ),
    .DW5      ( 16       ),
    .AW6      ( 23       ),
    .BLOCKS6  ( 1        ),
    .BLKSIZE6 ( 1024     ),
    .DW6      ( 16       ),
    .AW7      ( 23       ),
    .BLOCKS7  ( 1        ),
    .BLKSIZE7 ( 1024     ),
    .DW7      ( 16       )
) uut (
    .rst         ( rst             ),
    .clk         ( clk             ),
    .addr0       ( addr0           ),
    .dout0       ( dout0           ),
    .rd0         ( rd0             ),
    .wr0         ( wr0             ),
    .din0        ( din0            ),
    .wdsn0       ( wdsn0           ),
    .ok0         ( ok0             ),
    .flush0      ( flush0          ),
    .flushing0   ( flushing0       ),
    .flush_done0 ( flush_done0     ),
    .addr1       ( addr_zero       ),
    .dout1       ( dout1           ),
    .rd1         ( sig_zero        ),
    .wr1         ( sig_zero        ),
    .din1        ( data_zero       ),
    .wdsn1       ( dsn_mask        ),
    .ok1         ( ok1             ),
    .flush1      ( sig_zero        ),
    .flushing1   ( flushing1       ),
    .flush_done1 ( flush_done1     ),
    .addr2       ( addr_zero       ),
    .dout2       ( dout2           ),
    .rd2         ( sig_zero        ),
    .wr2         ( sig_zero        ),
    .din2        ( data_zero       ),
    .wdsn2       ( dsn_mask        ),
    .ok2         ( ok2             ),
    .flush2      ( sig_zero        ),
    .flushing2   ( flushing2       ),
    .flush_done2 ( flush_done2     ),
    .addr3       ( addr_zero       ),
    .dout3       ( dout3           ),
    .rd3         ( sig_zero        ),
    .wr3         ( sig_zero        ),
    .din3        ( data_zero       ),
    .wdsn3       ( dsn_mask        ),
    .ok3         ( ok3             ),
    .flush3      ( sig_zero        ),
    .flushing3   ( flushing3       ),
    .flush_done3 ( flush_done3     ),
    .addr4       ( addr_zero       ),
    .dout4       ( dout4           ),
    .rd4         ( sig_zero        ),
    .ok4         ( ok4             ),
    .flush4      ( sig_zero        ),
    .flushing4   ( flushing4       ),
    .flush_done4 ( flush_done4     ),
    .addr5       ( addr_zero       ),
    .dout5       ( dout5           ),
    .rd5         ( sig_zero        ),
    .ok5         ( ok5             ),
    .flush5      ( sig_zero        ),
    .flushing5   ( flushing5       ),
    .flush_done5 ( flush_done5     ),
    .addr6       ( addr_zero       ),
    .dout6       ( dout6           ),
    .rd6         ( sig_zero        ),
    .ok6         ( ok6             ),
    .flush6      ( sig_zero        ),
    .flushing6   ( flushing6       ),
    .flush_done6 ( flush_done6     ),
    .addr7       ( addr_zero       ),
    .dout7       ( dout7           ),
    .rd7         ( sig_zero        ),
    .ok7         ( ok7             ),
    .flush7      ( sig_zero        ),
    .flushing7   ( flushing7       ),
    .flush_done7 ( flush_done7     ),
    .addr        ( sdram_addr      ),
    .ba          ( sdram_ba_mux    ),
    .rd          ( sdram_rd        ),
    .wr          ( sdram_wr        ),
    .din         ( sdram_dout_mux  ),
    .dout        ( sdram_din_mux   ),
    .ack         ( sdram_ack       ),
    .dst         ( sdram_dst       ),
    .dok         ( sdram_dok       ),
    .rdy         ( sdram_rdy       )
);

jtframe_burst_sdram #(
    .AW       ( SDRAM_AW ),
    .HF       ( HF       ),
    .MISTER   ( 0        ),
    .PROG_LEN ( 64       )
) u_sdram_ctrl (
    .rst        ( rst              ),
    .clk        ( clk              ),
    .init       ( init             ),
    .addr       ( sdram_addr_full  ),
    .ba         ( sdram_ba_mux     ),
    .rd         ( sdram_rd         ),
    .wr         ( sdram_wr         ),
    .din        ( sdram_din_mux    ),
    .dout       ( sdram_dout_mux   ),
    .ack        ( sdram_ack        ),
    .dst        ( sdram_dst        ),
    .dok        ( sdram_dok        ),
    .rdy        ( sdram_rdy        ),
    .prog_en    ( sig_zero         ),
    .prog_addr  ( {SDRAM_AW{1'b0}} ),
    .prog_rd    ( sig_zero         ),
    .prog_wr    ( sig_zero         ),
    .prog_din   ( data_zero        ),
    .prog_dsn   ( dsn_zero         ),
    .prog_ba    ( dsn_zero         ),
    .prog_dst   (                  ),
    .prog_dok   (                  ),
    .prog_rdy   (                  ),
    .prog_ack   (                  ),
    .rfsh       ( rfsh             ),
    .sdram_dq   ( sdram_dq         ),
    .sdram_a    ( sdram_a          ),
    .sdram_dqml ( sdram_dqm[0]     ),
    .sdram_dqmh ( sdram_dqm[1]     ),
    .sdram_ba   ( sdram_ba         ),
    .sdram_nwe  ( sdram_nwe        ),
    .sdram_ncas ( sdram_ncas       ),
    .sdram_nras ( sdram_nras       ),
    .sdram_ncs  ( sdram_ncs        ),
    .sdram_cke  ( sdram_cke        )
);

mt48lc16m16a2 #(
    .addr_bits ( 13 ),
    .col_bits  ( 10 )
) u_sdram (
    .Clk         ( clk_sdram ),
    .Cke         ( sdram_cke ),
    .Dq          ( sdram_dq  ),
    .Addr        ( sdram_a   ),
    .Ba          ( sdram_ba  ),
    .Cs_n        ( sdram_ncs ),
    .Ras_n       ( sdram_nras),
    .Cas_n       ( sdram_ncas),
    .We_n        ( sdram_nwe ),
    .Dqm         ( sdram_dqm ),
    .downloading ( sig_zero  ),
    .VS          ( sig_zero  ),
    .frame_cnt   ( 0         )
);

task wait_init_done;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<50_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( !init ) disable wait_loop;
        end
        $display("Timed out waiting for SDRAM init");
        fail();
    end
endtask

task wait_lane_ok;
    input [80*8-1:0] opname;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<20_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( ok0 ) disable wait_loop;
        end
        $display("Timed out waiting for lane 0 %0s", opname);
        fail();
    end
endtask

task lane0_read;
    input [22:1] local_addr;
    input [15:0] expected;
    begin
        while( ok0 ) @(posedge clk);
        @(negedge clk);
        addr0 = local_addr;
        rd0   = 1'b1;
        wait_lane_ok("read");
        if( dout0 !== expected ) begin
            $display("Read mismatch at %0d: got %04x expected %04x",
                local_addr, dout0, expected);
            fail();
        end
        @(negedge clk);
        rd0 = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task lane0_write;
    input [22:1] local_addr;
    input [15:0] value;
    begin
        while( ok0 ) @(posedge clk);
        @(negedge clk);
        addr0 = local_addr;
        din0  = value;
        wdsn0 = 2'b00;
        wr0   = 1'b1;
        wait_lane_ok("write");
        @(negedge clk);
        wr0   = 1'b0;
        din0  = 16'd0;
        wdsn0 = 2'b11;
        repeat (4) @(posedge clk);
    end
endtask

task wait_flush_done;
    integer timeout;
    reg saw_flushing;
    begin
        saw_flushing = 1'b0;
        flush_write_count = 0;
        count_flush_active = 1'b1;
        @(negedge clk);
        flush0 = 1'b1;
        @(negedge clk);
        flush0 = 1'b0;
        begin : wait_loop
            for( timeout=0; timeout<50_000; timeout=timeout+1 ) begin
                @(posedge clk);
                if( flushing0 ) saw_flushing = 1'b1;
                if( flush_done0 ) disable wait_loop;
            end
            $display("Timed out waiting for flush_done0");
            fail();
        end
        if( !saw_flushing ) begin
            $display("flush0 completed without observing flushing0");
            fail();
        end
        count_flush_active = 1'b0;
        repeat (8) @(posedge clk);
    end
endtask

task lane0_read_held_during_flush;
    input [22:1] local_addr;
    input [15:0] expected;
    integer timeout;
    reg saw_done;
    begin
        saw_done = 1'b0;
        while( ok0 ) @(posedge clk);
        @(negedge clk);
        flush0 = 1'b1;
        @(negedge clk);
        flush0 = 1'b0;

        begin : wait_flushing
            for( timeout=0; timeout<20_000; timeout=timeout+1 ) begin
                @(posedge clk);
                if( flushing0 ) disable wait_flushing;
            end
            $display("Timed out waiting for held-read flush to start");
            fail();
        end

        @(negedge clk);
        addr0 = local_addr;
        rd0   = 1'b1;

        begin : wait_read_ok
            for( timeout=0; timeout<60_000; timeout=timeout+1 ) begin
                @(posedge clk);
                if( flush_done0 ) saw_done = 1'b1;
                if( ok0 ) begin
                    if( !saw_done ) begin
                        $display("held read completed before flush_done0");
                        fail();
                    end
                    disable wait_read_ok;
                end
            end
            $display("Timed out waiting for held read after flush");
            fail();
        end

        if( dout0 !== expected ) begin
            $display("Held read mismatch after flush: got %04x expected %04x",
                dout0, expected);
            fail();
        end
        @(negedge clk);
        rd0 = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task lane0_read_contending_with_flush_start;
    input [22:1] local_addr;
    input [15:0] expected;
    integer timeout;
    reg saw_done;
    begin
        saw_done = 1'b0;
        while( ok0 ) @(posedge clk);
        @(negedge clk);
        addr0  = local_addr;
        rd0    = 1'b1;
        flush0 = 1'b1;
        @(negedge clk);
        flush0 = 1'b0;

        begin : wait_read_ok
            for( timeout=0; timeout<80_000; timeout=timeout+1 ) begin
                @(posedge clk);
                if( flush_done0 ) saw_done = 1'b1;
                if( ok0 ) begin
                    if( !saw_done ) begin
                        $display("contended read completed before flush_done0");
                        fail();
                    end
                    disable wait_read_ok;
                end
            end
            $display("Timed out waiting for contended read after flush");
            fail();
        end

        if( dout0 !== expected ) begin
            $display("Contended read mismatch after flush: got %04x expected %04x",
                dout0, expected);
            fail();
        end
        @(negedge clk);
        rd0 = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

initial begin
    clk = 0;
    clk_sdram = 0;
    forever begin
        #(PERIOD/2) clk_sdram = ~clk_sdram;
        #5 clk = clk_sdram;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
        burst_busy <= 1'b0;
        flush_write_count <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt + 1;
        if( u_sdram_ctrl.rfshing && burst_busy && !sdram_rdy ) begin
            $display("Refresh overlapped an acknowledged burst");
            fail();
        end
        if( count_flush_active && sdram_wr && sdram_ack )
            flush_write_count <= flush_write_count + 1;
        if( sdram_ack ) burst_busy <= 1'b1;
        if( sdram_rdy ) burst_busy <= 1'b0;
    end
end

initial begin
    for( idx=0; idx<WORDS; idx=idx+1 ) begin
        exp_mem[idx] = idx[15:0] ^ 16'h5281;
        u_sdram.Bank0[idx] = exp_mem[idx];
    end
    exp_mem[0] = ORIGINAL;
    u_sdram.Bank0[0] = ORIGINAL;

    rst    = 1'b1;
    addr0  = 22'd0;
    rd0    = 1'b0;
    wr0    = 1'b0;
    flush0 = 1'b0;
    din0   = 16'd0;
    wdsn0  = 2'b11;
    count_flush_active = 1'b0;

    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    lane0_read(22'd0, ORIGINAL);
    lane0_write(22'd0, UPDATED);
    lane0_read(22'd0, UPDATED);

    if( u_sdram.Bank0[0] !== ORIGINAL ) begin
        $display("SDRAM changed before flush: got %04x expected stale %04x",
            u_sdram.Bank0[0], ORIGINAL);
        fail();
    end

    wait_flush_done();

    if( flush_write_count == 0 ) begin
        $display("Dirty flush did not issue any SDRAM write requests");
        fail();
    end
    if( u_sdram.Bank0[0] !== UPDATED ) begin
        $display("SDRAM was not updated by flush: got %04x expected %04x",
            u_sdram.Bank0[0], UPDATED);
        fail();
    end

    flush_write_count = 0;
    wait_flush_done();
    if( flush_write_count != 0 ) begin
        $display("Clean flush issued %0d SDRAM write requests", flush_write_count);
        fail();
    end

    lane0_read_held_during_flush(22'd0, UPDATED);
    lane0_write(22'd0, CONTENDED);
    lane0_read_contending_with_flush_start(22'd0, CONTENDED);
    lane0_read(22'd0, CONTENDED);
    pass();
end

endmodule
