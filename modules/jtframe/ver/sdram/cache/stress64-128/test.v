`timescale 1ns / 1ps

module cache_wide_stress_env #(parameter
    DW = 64
);

`include "test_tasks.vh"

localparam integer CACHE_AW            = 23;
localparam integer BLKSIZE             = 1024;
localparam integer BLOCKS              = 32;
localparam integer AW0                 = DW==128 ? 4 : DW==64 ? 3 : 2;
localparam integer MW                  = DW >> 3;
localparam integer FILE_BYTES          = 512*1024;
localparam integer FILE_WORDS          = FILE_BYTES/(DW/8);
localparam integer SDRAM_HALFWORDS     = FILE_BYTES/2;
localparam integer LINE_UNITS          = BLKSIZE/(DW/8);
localparam integer LINES               = FILE_BYTES/BLKSIZE;
localparam integer EXPECTED_WRITE_ACKS = LINES <= BLOCKS ? LINES :
                                         BLOCKS + 2*(LINES-BLOCKS);
localparam integer WORD_PROGRESS       = FILE_WORDS/8;
localparam integer HALF_PROGRESS       = SDRAM_HALFWORDS/4;
localparam real    CLK_PERIOD_NS       = 1000.0 / 85.909;
localparam real    RFSH_PERIOD_NS      = 64_000.0;
localparam [3:0]   CMD_REFRESH         = 4'b0001;

reg                 rst;
reg                 clk;
reg                 clk_sdram;
reg  [CACHE_AW-1:AW0] cache_addr;
reg  [DW-1:0]       cache_din;
reg                  cache_rd;
reg                  cache_wr;
reg  [MW-1:0]        cache_wdsn;
wire [DW-1:0]        cache_dout;
wire                 cache_ok;

wire [23:1]          ext_addr;
wire [15:0]          ext_din;
wire [15:0]          ext_dout;
wire                 ext_rd;
wire                 ext_wr;
wire                 ext_ack;
wire                 ext_dst;
wire                 ext_dok;
wire                 ext_rdy;
wire                 init;

reg                  rfsh;

wire [15:0]          sdram_dq;
wire [12:0]          sdram_a;
wire [ 1:0]          sdram_dqm;
wire [ 1:0]          sdram_ba;
wire                 sdram_nwe;
wire                 sdram_ncas;
wire                 sdram_nras;
wire                 sdram_ncs;
wire                 sdram_cke;

reg  [7:0]           payload [0:FILE_BYTES-1];

integer              ack_count;
integer              rfsh_count;
integer              rfsh_req_count;
integer              load_file;
integer              load_count;
integer              idx;
integer              write_cold_lines;
integer              write_dirty_lines;
integer              read_line_hits;
integer              read_line_refills;
integer              read_line_writebacks;
integer              write_phase_acks;
realtime             next_rfsh_at;

jtframe_cache #(
    .BLOCKS     ( BLOCKS    ),
    .BLKSIZE    ( BLKSIZE   ),
    .AW         ( CACHE_AW  ),
    .DW         ( DW        ),
    .ENDIAN     ( 0         ),
    .EW         ( 24        )
) u_cache (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .addr       ( cache_addr ),
    .dout       ( cache_dout ),
    .din        ( cache_din  ),
    .rd         ( cache_rd   ),
    .wr         ( cache_wr   ),
    .wdsn       ( cache_wdsn ),
    .ok         ( cache_ok   ),
    .ext_addr   ( ext_addr   ),
    .ext_din    ( ext_din    ),
    .ext_dout   ( ext_dout   ),
    .ext_rd     ( ext_rd     ),
    .ext_wr     ( ext_wr     ),
    .ext_ack    ( ext_ack    ),
    .ext_dst    ( ext_dst    ),
    .ext_dok    ( ext_dok    ),
    .ext_rdy    ( ext_rdy    )
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

function automatic [DW-1:0] expected_word(input integer unit_addr);
    integer base;
    integer bidx;
    begin
        expected_word = {DW{1'b0}};
        base = unit_addr * (DW/8);
        for( bidx=0; bidx<(DW/8); bidx=bidx+1 ) begin
            expected_word[bidx*8 +: 8] = payload[base + bidx];
        end
    end
endfunction

function automatic [15:0] expected_halfword(input integer half_idx);
    integer base;
    begin
        base = half_idx << 1;
        expected_halfword = { payload[base + 1], payload[base + 0] };
    end
endfunction

function automatic integer line_start(input integer unit_addr);
    begin
        line_start = (unit_addr % LINE_UNITS) == 0;
    end
endfunction

function automatic integer write_expect_bursts(input integer unit_addr);
    integer line_idx;
    begin
        if( !line_start(unit_addr) ) begin
            write_expect_bursts = 0;
        end else begin
            line_idx = unit_addr / LINE_UNITS;
            if( line_idx < BLOCKS )
                write_expect_bursts = 1;
            else
                write_expect_bursts = 2;
        end
    end
endfunction

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        ack_count <= 0;
    end else if( ext_ack ) begin
        ack_count <= ack_count + 1;
    end
end

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        rfsh_count <= 0;
    end else if( {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe} == CMD_REFRESH ) begin
        rfsh_count <= rfsh_count + 1;
    end
end

initial begin
    clk = 1'b0;
    clk_sdram = 1'b0;
    forever begin
        #(CLK_PERIOD_NS/2.0) clk_sdram = ~clk_sdram;
        #5 clk = clk_sdram;
    end
end

initial begin
    rfsh = 1'b0;
    rfsh_req_count = 0;
    wait( rst == 1'b0 );
    next_rfsh_at = $realtime + RFSH_PERIOD_NS;
    forever begin
        #(next_rfsh_at - $realtime);
        rfsh = 1'b1;
        rfsh_req_count = rfsh_req_count + 1;
        @(posedge clk);
        rfsh = 1'b0;
        next_rfsh_at = next_rfsh_at + RFSH_PERIOD_NS;
    end
end

task load_payload_and_clear_sdram;
    begin
        load_file = $fopen("payload.bin", "rb");
        if( load_file == 0 ) begin
            $display("Could not open payload.bin for DW=%0d", DW);
            fail();
        end
        load_count = $fread(payload, load_file);
        $fclose(load_file);
        if( load_count != FILE_BYTES ) begin
            $display("Expected %0d bytes in payload.bin for DW=%0d, got %0d", FILE_BYTES, DW, load_count);
            fail();
        end
        $display("DW=%0d loaded payload.bin: %0d bytes (%0d words)", DW, FILE_BYTES, FILE_WORDS);
        for( idx=0; idx<SDRAM_HALFWORDS; idx=idx+1 ) begin
            u_sdram.Bank0[idx] = 16'd0;
        end
        $display("DW=%0d cleared SDRAM Bank0 halfwords: %0d", DW, SDRAM_HALFWORDS);
    end
endtask

task wait_init_done;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<200_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( !init ) disable wait_loop;
        end
        $display("Timed out waiting for SDRAM init for DW=%0d", DW);
        fail();
    end
endtask

task record_read_line_bursts(
    input integer unit_addr,
    input integer bursts_seen
);
    begin
        if( !line_start(unit_addr) ) begin
            if( bursts_seen != 0 ) begin
                $display("DW=%0d read within a cached line must not trigger bursts: addr=%0d bursts=%0d",
                    DW, unit_addr, bursts_seen);
                fail();
            end
        end else begin
            case( bursts_seen )
                0: read_line_hits       = read_line_hits + 1;
                1: read_line_refills    = read_line_refills + 1;
                2: read_line_writebacks = read_line_writebacks + 1;
                default: begin
                    $display("DW=%0d read line start can only cause 0, 1 or 2 bursts: addr=%0d bursts=%0d",
                        DW, unit_addr, bursts_seen);
                    fail();
                end
            endcase
        end
    end
endtask

task record_write_line_bursts(
    input integer unit_addr,
    input integer bursts_seen
);
    begin
        if( line_start(unit_addr) ) begin
            case( bursts_seen )
                1: write_cold_lines  = write_cold_lines + 1;
                2: write_dirty_lines = write_dirty_lines + 1;
                default: begin
                    $display("DW=%0d write line start must cause 1 or 2 bursts: addr=%0d bursts=%0d",
                        DW, unit_addr, bursts_seen);
                    fail();
                end
            endcase
        end else if( bursts_seen != 0 ) begin
            $display("DW=%0d write within a cached line must not trigger bursts: addr=%0d bursts=%0d",
                DW, unit_addr, bursts_seen);
            fail();
        end
    end
endtask

task write_req(
    input integer unit_addr,
    input [DW-1:0] wr_data,
    input integer expect_bursts
);
    integer cycles;
    integer ack_before;
    integer bursts_seen;
    begin
        while( cache_ok ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        cache_addr = unit_addr;
        cache_din  = wr_data;
        cache_wdsn = {MW{1'b0}};
        cache_wr   = 1'b1;

        cycles = 0;
        begin : wait_loop
            while( cache_ok !== 1'b1 ) begin
                @(posedge clk);
                cycles = cycles + 1;
                assert_msg(cycles < 100_000, "Wide stress cache write timed out");
            end
        end

        bursts_seen = ack_count - ack_before;
        if( bursts_seen !== expect_bursts ) begin
            $display("DW=%0d unexpected burst count for write addr=%0d got=%0d expected=%0d",
                DW, unit_addr, bursts_seen, expect_bursts);
            fail();
        end
        record_write_line_bursts(unit_addr, bursts_seen);

        @(negedge clk);
        cache_wr = 1'b0;
        repeat (1) @(posedge clk);
    end
endtask

task read_req(input integer unit_addr);
    integer cycles;
    integer ack_before;
    integer bursts_seen;
    reg [DW-1:0] expected;
    begin
        expected = expected_word(unit_addr);
        while( cache_ok ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        cache_addr = unit_addr;
        cache_rd   = 1'b1;

        cycles = 0;
        begin : wait_loop
            while( cache_ok !== 1'b1 ) begin
                @(posedge clk);
                cycles = cycles + 1;
                assert_msg(cycles < 100_000, "Wide stress cache read timed out");
            end
        end

        if( cache_dout !== expected ) begin
            $display("DW=%0d read mismatch addr=%0d got=%h expected=%h",
                DW, unit_addr, cache_dout, expected);
            $display("  st=%0d blk=%0d stream=%0d off=%0d req_q=%h stream_q=%h wb_q=%h req_addr=%0h stream_addr=%0h ext_addr=%0h ack=%b dst=%b dok=%b rdy=%b ext_din=%04x",
                u_cache.st, u_cache.blk_l, u_cache.stream_word, u_cache.req_off_l,
                u_cache.req_q, u_cache.stream_q, u_cache.wb_q,
                u_cache.req_ram_addr_l, u_cache.stream_ram_addr_l,
                ext_addr, ext_ack, ext_dst, ext_dok, ext_rdy, ext_din);
            fail();
        end

        bursts_seen = ack_count - ack_before;
        record_read_line_bursts(unit_addr, bursts_seen);

        @(negedge clk);
        cache_rd = 1'b0;
        repeat (1) @(posedge clk);
    end
endtask

task verify_sdram_contents;
    integer half_idx;
    reg [15:0] expected;
    begin
        $display("DW=%0d checking SDRAM half-word contents", DW);
        for( half_idx=0; half_idx<SDRAM_HALFWORDS; half_idx=half_idx+1 ) begin
            expected = expected_halfword(half_idx);
            if( u_sdram.Bank0[half_idx] !== expected ) begin
                $display("DW=%0d SDRAM halfword mismatch idx=%0d got=%04x expected=%04x",
                    DW, half_idx, u_sdram.Bank0[half_idx], expected);
                fail();
            end
            if( (half_idx != 0) && ((half_idx % HALF_PROGRESS) == 0) ) begin
                $display("DW=%0d verified SDRAM halfwords: %0d / %0d", DW, half_idx, SDRAM_HALFWORDS);
            end
        end
    end
endtask

task run;
    begin
        load_payload_and_clear_sdram();
        rst        = 1'b1;
        cache_addr = {CACHE_AW-AW0{1'b0}};
        cache_din  = {DW{1'b0}};
        cache_rd   = 1'b0;
        cache_wr   = 1'b0;
        cache_wdsn = {MW{1'b1}};
        write_cold_lines      = 0;
        write_dirty_lines     = 0;
        read_line_hits        = 0;
        read_line_refills     = 0;
        read_line_writebacks  = 0;
        write_phase_acks      = 0;
        ack_count             = 0;
        rfsh_count            = 0;
        rfsh_req_count        = 0;

        repeat (20) @(posedge clk);
        rst = 1'b0;
        $display("DW=%0d waiting for SDRAM init at 85.909 MHz with 64 us refresh requests", DW);
        wait_init_done();
        repeat (16) @(posedge clk);

        $display("DW=%0d starting sequential write phase: %0d words across %0d cache lines", DW, FILE_WORDS, LINES);
        for( idx=0; idx<FILE_WORDS; idx=idx+1 ) begin
            if( (idx != 0) && ((idx % WORD_PROGRESS) == 0) ) begin
                $display("DW=%0d write progress: %0d / %0d words", DW, idx, FILE_WORDS);
            end
            write_req(idx, expected_word(idx), write_expect_bursts(idx));
        end

        write_phase_acks = ack_count;
        assert_msg(write_phase_acks == EXPECTED_WRITE_ACKS, "Unexpected total write-phase burst count");
        assert_msg(write_cold_lines == (LINES < BLOCKS ? LINES : BLOCKS),
            "Unexpected number of cold write line fills");
        assert_msg(write_dirty_lines == (LINES > BLOCKS ? LINES-BLOCKS : 0),
            "Unexpected number of dirty write line fills");

        $display("DW=%0d write phase complete: ext_ack=%0d cold_lines=%0d dirty_lines=%0d refresh_cmd=%0d refresh_req=%0d",
            DW, ack_count, write_cold_lines, write_dirty_lines, rfsh_count, rfsh_req_count);
        $display("DW=%0d starting sequential readback phase", DW);
        for( idx=0; idx<FILE_WORDS; idx=idx+1 ) begin
            if( (idx != 0) && ((idx % WORD_PROGRESS) == 0) ) begin
                $display("DW=%0d read progress: %0d / %0d words", DW, idx, FILE_WORDS);
            end
            read_req(idx);
        end

        assert_msg(read_line_hits + read_line_refills + read_line_writebacks == LINES,
            "Every cache line must be classified exactly once during readback");
        $display("DW=%0d readback complete: ext_ack=%0d line_hits=%0d refill_only=%0d writeback_refill=%0d refresh_cmd=%0d refresh_req=%0d",
            DW, ack_count, read_line_hits, read_line_refills, read_line_writebacks, rfsh_count, rfsh_req_count);
        verify_sdram_contents();

        assert_msg(rfsh_count > 0, "Refresh must trigger during stress run");

        $display("DW=%0d final counts: write_phase_acks=%0d total_acks=%0d line_hits=%0d refill_only=%0d writeback_refill=%0d refresh_cmd=%0d refresh_req=%0d",
            DW, write_phase_acks, ack_count, read_line_hits, read_line_refills, read_line_writebacks, rfsh_count, rfsh_req_count);
    end
endtask

endmodule

module test;

cache_wide_stress_env #(.DW(64 )) u64();
cache_wide_stress_env #(.DW(128)) u128();

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

initial begin
    u64.run();
    u128.run();
    $display("PASS");
    $finish;
end

endmodule
