`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam PERIOD     = 10;
localparam HF         = 1;
localparam WORDS      = 2048;
localparam CACHE_AW   = 23;
localparam CACHE_BLKS = 1;
localparam BLKSIZE    = 16;
localparam SIM_TIMEOUT_NS        = 2_000_000;
localparam ZERO_TIME_EVT_LIMIT   = 100_000;

reg         rst;
reg         clk;
reg         clk_sdram;
reg  [22:1] cache_addr;
reg         cache_rd;
wire [15:0] cache_dout;
wire        cache_ok;

wire [22:1] ext_addr;
wire [15:0] ext_din;
wire        ext_rd;
wire        ext_ack;
wire        ext_dst;
wire        ext_dok;
wire        ext_rdy;

reg         ioctl_rom;
reg  [25:0] ioctl_addr;
reg  [ 7:0] ioctl_dout;
reg         ioctl_wr;
wire [22:1] prog_addr;
wire [15:0] prog_data;
wire [ 1:0] prog_mask;
wire        prog_we;
wire        prog_rd;
wire [ 1:0] prog_ba;
wire        prom_we;
wire        header;
wire        prog_ack;
wire        init;

wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_dqm;
wire [ 1:0] sdram_ba;
wire        sdram_nwe;
wire        sdram_ncas;
wire        sdram_nras;
wire        sdram_ncs;
wire        sdram_cke;
wire        cache_busy = u_cache.miss_busy;

reg [15:0] exp_mem [0:WORDS-1];
reg [15:0] expected;

integer hcnt;
integer ack_count;
integer req_count;
integer same_time_events;
time    last_watchdog_time;
wire rfsh = hcnt == 0;

jtframe_cache #(
    .BLOCKS     ( CACHE_BLKS ),
    .BLKSIZE    ( BLKSIZE    ),
    .AW         ( CACHE_AW   ),
    .DW         ( 16         ),
    .EW         ( CACHE_AW   )
) u_cache (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .addr       ( cache_addr ),
    .dout       ( cache_dout ),
    .rd         ( cache_rd   ),
    .ok         ( cache_ok   ),
    .ext_addr   ( ext_addr   ),
    .ext_din    ( ext_din    ),
    .ext_rd     ( ext_rd     ),
    .ext_ack    ( ext_ack    ),
    .ext_dst    ( ext_dst    ),
    .ext_dok    ( ext_dok    ),
    .ext_rdy    ( ext_rdy    )
);

jtframe_burst_sdram #(
    .AW      ( 22 ),
    .HF      ( HF ),
    .MISTER  ( 0  ),
    .PROG_LEN( 64 )
) u_sdram_ctrl (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( ext_addr     ),
    .ba         ( 2'd0         ),
    .rd         ( ext_rd       ),
    .wr         ( 1'b0         ),
    .din        ( 16'h0000     ),
    .dout       ( ext_din      ),
    .ack        ( ext_ack      ),
    .dst        ( ext_dst      ),
    .dok        ( ext_dok      ),
    .rdy        ( ext_rdy      ),
    .prog_en    ( ioctl_rom    ),
    .prog_addr  ( prog_addr    ),
    .prog_rd    ( prog_rd      ),
    .prog_wr    ( prog_we      ),
    .prog_din   ( prog_data    ),
    .prog_dsn   ( prog_mask    ),
    .prog_ba    ( prog_ba      ),
    .prog_dst   (              ),
    .prog_dok   (              ),
    .prog_rdy   ( prog_ack     ),
    .prog_ack   (              ),
    .rfsh       ( rfsh         ),
    .sdram_dq   ( sdram_dq     ),
    .sdram_a    ( sdram_a      ),
    .sdram_dqml ( sdram_dqm[0] ),
    .sdram_dqmh ( sdram_dqm[1] ),
    .sdram_ba   ( sdram_ba     ),
    .sdram_nwe  ( sdram_nwe    ),
    .sdram_ncas ( sdram_ncas   ),
    .sdram_nras ( sdram_nras   ),
    .sdram_ncs  ( sdram_ncs    ),
    .sdram_cke  ( sdram_cke    )
);

jtframe_dwnld #(
    .SWAB       ( 1'b1       )
) u_dwnld (
    .clk        ( clk        ),
    .ioctl_rom  ( ioctl_rom  ),
    .ioctl_addr ( ioctl_addr ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_wr   ( ioctl_wr   ),
    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_mask  ( prog_mask  ),
    .prog_we    ( prog_we    ),
    .prog_rd    ( prog_rd    ),
    .prog_ba    ( prog_ba    ),
    .gfx4_en    ( 1'b0       ),
    .gfx8_en    ( 1'b0       ),
    .gfx16_en   ( 1'b0       ),
    .gfx16b_en  ( 1'b0       ),
    .gfx16c_en  ( 1'b0       ),
    .prom_we    ( prom_we    ),
    .header     ( header     ),
    .sdram_ack  ( prog_ack   )
);

mt48lc16m16a2 u_sdram (
    .Clk        ( clk_sdram   ),
    .Cke        ( sdram_cke   ),
    .Dq         ( sdram_dq    ),
    .Addr       ( sdram_a     ),
    .Ba         ( sdram_ba    ),
    .Cs_n       ( sdram_ncs   ),
    .Ras_n      ( sdram_nras  ),
    .Cas_n      ( sdram_ncas  ),
    .We_n       ( sdram_nwe   ),
    .Dqm        ( sdram_dqm   ),
    .downloading( 1'b0        ),
    .VS         ( 1'b0        ),
    .frame_cnt  ( 0           )
);

`ifdef DEBUG
always @(negedge clk) begin
    if( cache_rd || cache_ok || ext_rd || ext_ack || ext_dok || ext_rdy ) begin
        $display("%t rd=%b ok=%b addr=%0d dout=%04x busy=%b st=%0d tail=%b stream=%0d ext_rd=%b ack=%b dst=%b dok=%b rdy=%b din=%04x",
            $time, cache_rd, cache_ok, cache_addr, cache_dout, cache_busy, u_cache.st, u_cache.fill_tail_seen, u_cache.stream_word,
            ext_rd, ext_ack, ext_dst, ext_dok, ext_rdy, ext_din);
    end
end
`endif

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt+1;
    end
end

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        ack_count <= 0;
    end else if( ext_ack ) begin
        ack_count <= ack_count + 1;
    end
end

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

initial begin
    #(SIM_TIMEOUT_NS);
    $display("%t cache_burst_sdram: simulation timeout st=%0d busy=%0b req_count=%0d ack=%0d ext_rd=%0b ext_ack=%0b ext_dst=%0b ext_dok=%0b ext_rdy=%0b stream=%0d",
        $time, u_cache.st, cache_busy, req_count, ack_count, ext_rd, ext_ack, ext_dst, ext_dok, ext_rdy, u_cache.stream_word);
    $fflush();
    $display("FAIL");
    $fflush();
    $finish;
end

always @(cache_addr or cache_rd or cache_ok or cache_busy or
         ext_addr or ext_din or ext_rd or ext_ack or ext_dst or ext_dok or ext_rdy or
         u_cache.st or u_cache.stream_word) begin
    if( $time != last_watchdog_time ) begin
        last_watchdog_time = $time;
        same_time_events   = 0;
    end else begin
        same_time_events = same_time_events + 1;
        if( same_time_events > ZERO_TIME_EVT_LIMIT ) begin
            $display("%t cache_burst_sdram: zero-time activity watchdog fired st=%0d busy=%0b req_count=%0d ack=%0d ext_rd=%0b ext_ack=%0b ext_dst=%0b ext_dok=%0b ext_rdy=%0b stream=%0d",
                $time, u_cache.st, cache_busy, req_count, ack_count, ext_rd, ext_ack, ext_dst, ext_dok, ext_rdy, u_cache.stream_word);
            $fflush();
            $display("FAIL");
            $fflush();
            $finish;
        end
    end
end

task wait_prog_ready;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<500; timeout=timeout+1 ) begin
            @(posedge clk);
            if( prog_ack ) disable wait_loop;
            if( timeout != 0 && timeout % 100 == 0 ) begin
                $display("%t cache_burst_sdram: still waiting for downloader ack (timeout=%0d)", $time, timeout);
                $fflush();
            end
        end
        $display("Timed out waiting for programming ready");
        $fflush();
        fail();
    end
endtask

task download_byte(input [25:0] byte_addr, input [7:0] value);
    integer word_idx;
    begin
        word_idx = byte_addr >> 1;
        if( byte_addr[0] ) exp_mem[word_idx][15:8] = value;
        else exp_mem[word_idx][7:0] = value;

        @(negedge clk);
        ioctl_rom  = 1'b1;
        ioctl_addr = byte_addr;
        ioctl_dout = value;
        ioctl_wr   = 1'b1;
        @(negedge clk);
        ioctl_wr   = 1'b0;
        wait_prog_ready();
    end
endtask

task cache_request(
    input [21:0] req_addr,
    input [15:0] exp_word,
    input        expect_miss
);
    integer cycles;
    integer ack_before;
    begin
        req_count = req_count + 1;
        $display("%t cache_burst_sdram: request %0d addr=%0d expect=%04x miss=%0b",
            $time, req_count, req_addr, exp_word, expect_miss);
        $fflush();
        while( cache_ok || cache_busy ) @(negedge clk);
        ack_before = ack_count;
        @(negedge clk);
        cache_addr <= req_addr;
        cache_rd   <= 1'b1;
        cycles     = 1;
        @(negedge clk);
        begin : wait_loop
            while( cache_ok !== 1'b1 ) begin
                @(negedge clk);
                cycles = cycles + 1;
                if( cycles != 0 && cycles % 32 == 0 ) begin
                    $display("%t cache_burst_sdram: request %0d waiting cycle=%0d st=%0d busy=%0b ack=%0b dst=%0b dok=%0b rdy=%0b stream=%0d",
                        $time, req_count, cycles, u_cache.st, cache_busy, ext_ack, ext_dst, ext_dok, ext_rdy, u_cache.stream_word);
                    $fflush();
                end
                assert_msg(cycles < 256, "Cache request timed out");
            end
        end
        cache_rd <= 1'b0;
        $display("%t cache_burst_sdram: request %0d done cycles=%0d dout=%04x ack_count=%0d",
            $time, req_count, cycles, cache_dout, ack_count);
        $fflush();
        if( cache_dout !== exp_word ) begin
            $display("Cache returned %04X instead of %04X at word %0d", cache_dout, exp_word, req_addr);
            $display("  ack=%b dst=%b dok=%b rdy=%b ext_din=%04x stream=%0d busy=%b st=%0d ok=%b",
                ext_ack, ext_dst, ext_dok, ext_rdy, ext_din, u_cache.stream_word, cache_busy, u_cache.st, cache_ok);
            $fflush();
            fail();
        end
        if( expect_miss ) begin
            assert_msg(ack_count == ack_before + 1, "Cache miss must trigger one SDRAM burst request");
            assert_msg(cycles > 4, "Cache miss completed too quickly");
        end else begin
            assert_msg(ack_count == ack_before, "Cache hit must not trigger a new SDRAM burst request");
            assert_msg(cycles <= 3, "Cache hit should complete within three cycles");
        end
        while( cache_ok || cache_busy ) @(negedge clk);
        repeat (2) @(negedge clk);
    end
endtask

integer i;

initial begin
    for( i=0; i<WORDS; i=i+1 ) exp_mem[i] = 16'h0000;
    req_count = 0;
    same_time_events = 0;
    last_watchdog_time = 0;

    rst = 1'b1;
    cache_addr = 22'd0;
    cache_rd = 1'b0;
    ioctl_rom = 1'b0;
    ioctl_addr = 26'd0;
    ioctl_dout = 8'd0;
    ioctl_wr = 1'b0;

    $display("%t cache_burst_sdram: reset asserted", $time);
    $fflush();
    repeat (20) @(posedge clk);
    rst = 1'b0;
    $display("%t cache_burst_sdram: waiting for SDRAM init", $time);
    $fflush();

    begin : wait_init_done
        for( i=0; i<20_000; i=i+1 ) begin
            @(posedge clk);
            if( !init ) disable wait_init_done;
            if( i != 0 && i % 2000 == 0 ) begin
                $display("%t cache_burst_sdram: still waiting for init (cycles=%0d)", $time, i);
                $fflush();
            end
        end
        $display("Timed out waiting for SDRAM init");
        $fflush();
        fail();
    end
    $display("%t cache_burst_sdram: SDRAM init complete", $time);
    $fflush();

    $display("%t cache_burst_sdram: downloading preload bytes", $time);
    $fflush();
    for( i=0; i<128; i=i+1 ) begin
        if( i != 0 && i % 32 == 0 ) begin
            $display("%t cache_burst_sdram: downloaded %0d/128 bytes", $time, i);
            $fflush();
        end
        download_byte(i[25:0], i[7:0] ^ 8'h5a);
    end
    @(negedge clk);
    ioctl_rom = 1'b0;
    $display("%t cache_burst_sdram: preload complete", $time);
    $fflush();

    repeat (20) @(posedge clk);
    $display("%t cache_burst_sdram: starting cache request sequence", $time);
    $fflush();

    cache_request(22'd2,  exp_mem[2],  1'b1);
    cache_request(22'd6,  exp_mem[6],  1'b0);
    cache_request(22'd10, exp_mem[10], 1'b1);
    cache_request(22'd15, exp_mem[15], 1'b0);
    cache_request(22'd18, exp_mem[18], 1'b1);
    cache_request(22'd3,  exp_mem[3],  1'b1);
    cache_request(22'd4,  exp_mem[4],  1'b0);

    $display("%t cache_burst_sdram: test completed", $time);
    $fflush();
    pass();
end

endmodule
