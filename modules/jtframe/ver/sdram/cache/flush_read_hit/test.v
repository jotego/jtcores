`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD     = 10;
localparam integer CACHE_AW   = 23;
localparam integer BLKSIZE    = 1024;
localparam integer BLOCKS     = 2;
localparam integer DW         = 16;
localparam integer AW0        = 1;
localparam integer MW         = 2;
localparam integer WORDS      = 4096;
localparam integer LINE_UNITS = BLKSIZE / (DW >> 3);

reg                     rst;
reg                     clk;
reg                     clk_sdram;
reg  [CACHE_AW-1:AW0]   cache_addr;
reg  [DW-1:0]           cache_din;
reg                     cache_rd;
reg                     cache_wr;
reg  [MW-1:0]           cache_wdsn;
reg                     cache_flush;
wire [DW-1:0]           cache_dout;
wire                    cache_ok;
wire                    cache_flushing;
wire                    cache_flush_done;

wire [23:1]             ext_addr;
wire [15:0]             ext_din;
wire [15:0]             ext_dout;
wire                    ext_rd;
wire                    ext_wr;
wire                    ext_ack;
wire                    ext_dst;
wire                    ext_dok;
wire                    ext_rdy;
wire                    init;

wire [15:0]             sdram_dq;
wire [12:0]             sdram_a;
wire [ 1:0]             sdram_dqm;
wire [ 1:0]             sdram_ba;
wire                    sdram_nwe;
wire                    sdram_ncas;
wire                    sdram_nras;
wire                    sdram_ncs;
wire                    sdram_cke;

reg  [15:0]             exp_mem [0:WORDS-1];
integer                 hcnt;
integer                 ack_count;

wire rfsh = hcnt == 0;

jtframe_cache #(
    .BLOCKS     ( BLOCKS    ),
    .BLKSIZE    ( BLKSIZE   ),
    .AW         ( CACHE_AW  ),
    .DW         ( DW        ),
    .ENDIAN     ( 0         ),
    .EW         ( 24        )
) u_cache (
    .rst        ( rst              ),
    .clk        ( clk              ),
    .addr       ( cache_addr       ),
    .dout       ( cache_dout       ),
    .din        ( cache_din        ),
    .rd         ( cache_rd         ),
    .wr         ( cache_wr         ),
    .wdsn       ( cache_wdsn       ),
    .ok         ( cache_ok         ),
    .flush      ( cache_flush      ),
    .flushing   ( cache_flushing   ),
    .flush_done ( cache_flush_done ),
    .invalidate ( 1'b0             ),
    .invalidating(                 ),
    .invalidate_done(              ),
    .ext_addr   ( ext_addr         ),
    .ext_din    ( ext_din          ),
    .ext_dout   ( ext_dout         ),
    .ext_rd     ( ext_rd           ),
    .ext_wr     ( ext_wr           ),
    .ext_ack    ( ext_ack          ),
    .ext_dst    ( ext_dst          ),
    .ext_dok    ( ext_dok          ),
    .ext_rdy    ( ext_rdy          )
);

jtframe_burst_sdram #(
    .AW      ( 23 ),
    .HF      ( 1  ),
    .MISTER  ( 0  ),
    .PROG_LEN( 64 )
) u_sdram_ctrl (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( ext_addr     ),
    .ba         ( 2'd0         ),
    .rd         ( ext_rd       ),
    .wr         ( ext_wr       ),
    .din        ( ext_dout     ),
    .dout       ( ext_din      ),
    .ack        ( ext_ack      ),
    .dst        ( ext_dst      ),
    .dok        ( ext_dok      ),
    .rdy        ( ext_rdy      ),
    .prog_en    ( 1'b0         ),
    .prog_addr  ( 23'd0        ),
    .prog_rd    ( 1'b0         ),
    .prog_wr    ( 1'b0         ),
    .prog_din   ( 16'd0        ),
    .prog_dsn   ( 2'b00        ),
    .prog_ba    ( 2'b00        ),
    .prog_dst   (              ),
    .prog_dok   (              ),
    .prog_rdy   (              ),
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

mt48lc16m16a2 #(
    .addr_bits  ( 13 ),
    .col_bits   ( 10 )
) u_sdram (
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

function automatic [7:0] pattern(input integer byte_addr);
    begin
        pattern = (byte_addr[7:0] * 8'h31) ^ 8'h87;
    end
endfunction

function automatic [15:0] expected_at(input integer unit_addr);
    begin
        expected_at = exp_mem[unit_addr];
    end
endfunction

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt      <= 0;
        ack_count <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt+1;
        if( ext_ack ) ack_count <= ack_count + 1;
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

task preload_byte(input integer byte_addr, input [7:0] value);
    integer word_idx;
    begin
        word_idx = byte_addr >> 1;
        if( byte_addr[0] ) exp_mem[word_idx][15:8] = value;
        else               exp_mem[word_idx][ 7:0] = value;
        u_sdram.Bank0[word_idx] = exp_mem[word_idx];
    end
endtask

task read_req(input integer unit_addr, input integer expect_bursts);
    integer cycles;
    integer ack_before;
    begin
        while( cache_ok ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        cache_addr = unit_addr;
        cache_rd   = 1'b1;

        cycles = 0;
        while( cache_ok !== 1'b1 ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 20_000, "Cache read timed out");
        end
        assert_msg(cache_dout == expected_at(unit_addr), "Unexpected read data");
        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected read burst count");

        @(negedge clk);
        cache_rd = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task write_req(input integer unit_addr, input [15:0] wr_data, input integer expect_bursts);
    integer cycles;
    integer ack_before;
    begin
        while( cache_ok ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        cache_addr = unit_addr;
        cache_din  = wr_data;
        cache_wdsn = 2'b00;
        cache_wr   = 1'b1;

        cycles = 0;
        while( cache_ok !== 1'b1 ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 20_000, "Cache write timed out");
        end
        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected write burst count");

        exp_mem[unit_addr] = wr_data;
        @(negedge clk);
        cache_wr = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task assert_read_hit_during_flush(input integer unit_addr);
    integer cycles;
    begin
        @(negedge clk);
        cache_flush = 1'b1;
        @(negedge clk);
        cache_flush = 1'b0;

        cycles = 0;
        while( !cache_flushing ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 500, "Flush did not start");
        end

        cycles = 0;
        while( !ext_wr ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 20_000, "Dirty flush writeback did not start");
        end

        @(negedge clk);
        cache_addr = unit_addr;
        cache_rd   = 1'b1;

        cycles = 0;
        while( !cache_ok && !cache_flush_done ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 20_000, "Flush-time read did not complete");
        end

        assert_msg(cache_ok, "Read hit waited until flush_done");
        assert_msg(cache_flushing, "Read hit did not complete while flushing");
        assert_msg(cache_dout == expected_at(unit_addr), "Flush-time read returned wrong data");

        @(negedge clk);
        cache_rd = 1'b0;

        cycles = 0;
        while( !cache_flush_done ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 20_000, "Flush did not complete");
        end
    end
endtask

integer idx;

initial begin
    for( idx=0; idx<WORDS; idx=idx+1 ) exp_mem[idx] = 16'd0;

    rst         = 1'b1;
    cache_addr  = {CACHE_AW-AW0{1'b0}};
    cache_din   = {DW{1'b0}};
    cache_rd    = 1'b0;
    cache_wr    = 1'b0;
    cache_wdsn  = {MW{1'b1}};
    cache_flush = 1'b0;

    repeat (20) @(posedge clk);
    for( idx=0; idx<(2*BLKSIZE); idx=idx+1 ) begin
        preload_byte(idx, pattern(idx));
    end

    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    read_req(1, 1);
    write_req(LINE_UNITS + 3, 16'hcafe, 1);
    assert_read_hit_during_flush(1);

    $display("PASS");
    $finish;
end

endmodule
