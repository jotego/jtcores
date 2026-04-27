`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD     = 10;
localparam integer HF         = 1;
localparam integer CACHE_AW   = 23;
localparam integer BLKSIZE    = 1024;
localparam integer LINE_UNITS = BLKSIZE / 4;
localparam integer WORDS      = 1024;

reg                 rst;
reg                 clk;
reg                 clk_sdram;
reg  [CACHE_AW-1:2] cache_addr;
reg  [31:0]         cache_din;
reg                 cache_rd;
reg                 cache_wr;
reg  [3:0]          cache_wdsn;
wire [31:0]         cache_dout;
wire                cache_ok;

wire [23:1]         ext_addr;
wire [15:0]         ext_din;
wire [15:0]         ext_dout;
wire                ext_rd;
wire                ext_wr;
wire                ext_ack;
wire                ext_dst;
wire                ext_dok;
wire                ext_rdy;

wire [15:0]         sdram_dq;
wire [12:0]         sdram_a;
wire [ 1:0]         sdram_dqm;
wire [ 1:0]         sdram_ba;
wire                sdram_nwe;
wire                sdram_ncas;
wire                sdram_nras;
wire                sdram_ncs;
wire                sdram_cke;

reg  [15:0]         exp_mem [0:WORDS-1];
integer             hcnt;
integer             ack_count;

wire rfsh = hcnt == 0;

jtframe_cache #(
    .BLOCKS     ( 1        ),
    .BLKSIZE    ( BLKSIZE  ),
    .AW         ( CACHE_AW ),
    .DW         ( 32       ),
    .ENDIAN     ( 1        ),
    .EW         ( 24       )
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
        pattern = (byte_addr[7:0] * 8'h47) ^ 8'h15;
    end
endfunction

function automatic [15:0] merge16_model(
    input [15:0] cur,
    input [15:0] nxt,
    input [ 1:0] dsn
);
    reg [15:0] tmp;
    begin
        tmp = cur;
        if( !dsn[1] ) tmp[15:8] = nxt[15:8];
        if( !dsn[0] ) tmp[ 7:0] = nxt[ 7:0];
        merge16_model = tmp;
    end
endfunction

function automatic [31:0] expected_at(input integer unit_addr);
    begin
        expected_at = { exp_mem[unit_addr << 1], exp_mem[(unit_addr << 1) + 1] };
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

task model_write(input integer unit_addr, input [31:0] wr_data, input [3:0] wr_dsn);
    integer idx0, idx1;
    begin
        idx0 = unit_addr << 1;
        idx1 = idx0 + 1;
        exp_mem[idx0] = merge16_model(exp_mem[idx0], wr_data[31:16], wr_dsn[3:2]);
        exp_mem[idx1] = merge16_model(exp_mem[idx1], wr_data[15:0],  wr_dsn[1:0]);
    end
endtask

task assert_sdram_unit_equals(input integer unit_addr);
    integer idx0, idx1;
    begin
        idx0 = unit_addr << 1;
        idx1 = idx0 + 1;
        if( u_sdram.Bank0[idx0] !== exp_mem[idx0] ) begin
            $display("SDRAM mismatch idx=%0d got=%04x expected=%04x",
                idx0, u_sdram.Bank0[idx0], exp_mem[idx0]);
            fail();
        end
        if( u_sdram.Bank0[idx1] !== exp_mem[idx1] ) begin
            $display("SDRAM mismatch idx=%0d got=%04x expected=%04x",
                idx1, u_sdram.Bank0[idx1], exp_mem[idx1]);
            fail();
        end
    end
endtask

task read_req(input integer unit_addr, input integer expect_bursts);
    integer cycles;
    integer ack_before;
    reg [31:0] expected;
    begin
        expected = expected_at(unit_addr);
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
                assert_msg(cycles < 20_000, "Big-endian cache read timed out");
            end
        end

        if( cache_dout !== expected ) begin
            $display("Read mismatch addr=%0d got=%08x expected=%08x",
                unit_addr, cache_dout, expected);
            $display("  st=%0d blk=%0d stream=%0d off=%0d req_q=%08x stream_q=%08x wb_q=%08x req_addr=%0h stream_addr=%0h",
                u_cache.st, u_cache.blk_l, u_cache.stream_word, u_cache.req_off_l,
                u_cache.req_q, u_cache.stream_q, u_cache.wb_q,
                u_cache.req_ram_addr_l, u_cache.stream_ram_addr_l);
            $display("  ext_addr=%0h ack=%b dst=%b dok=%b rdy=%b ext_din=%04x",
                ext_addr, ext_ack, ext_dst, ext_dok, ext_rdy, ext_din);
            fail();
        end
        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected burst count for read");

        @(negedge clk);
        cache_rd = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task write_req(
    input integer unit_addr,
    input [31:0] wr_data,
    input [ 3:0] wr_dsn,
    input integer expect_bursts
);
    integer cycles;
    integer ack_before;
    begin
        while( cache_ok ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        cache_addr = unit_addr;
        cache_din  = wr_data;
        cache_wdsn = wr_dsn;
        cache_wr   = 1'b1;

        cycles = 0;
        begin : wait_loop
            while( cache_ok !== 1'b1 ) begin
                @(posedge clk);
                cycles = cycles + 1;
                assert_msg(cycles < 20_000, "Big-endian cache write timed out");
            end
        end

        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected burst count for write");

        @(negedge clk);
        cache_wr = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

integer idx;
reg [15:0] before0, before1;

initial begin
    for( idx=0; idx<WORDS; idx=idx+1 ) exp_mem[idx] = 16'd0;

    preload_byte(0, 8'h02);
    preload_byte(1, 8'h01);
    preload_byte(2, 8'h04);
    preload_byte(3, 8'h03);
    for( idx=4; idx<(2*BLKSIZE); idx=idx+1 ) preload_byte(idx, pattern(idx));

    rst        = 1'b1;
    cache_addr = {CACHE_AW-2{1'b0}};
    cache_din  = 32'd0;
    cache_rd   = 1'b0;
    cache_wr   = 1'b0;
    cache_wdsn = 4'hf;

    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    read_req(0, 1);

    before0 = u_sdram.Bank0[0];
    before1 = u_sdram.Bank0[1];
    write_req(0, 32'ha1b2c3d4, 4'b0000, 0);
    assert_msg(u_sdram.Bank0[0] === before0, "Write hit must stay in cache until eviction");
    assert_msg(u_sdram.Bank0[1] === before1, "Write hit must stay in cache until eviction");
    model_write(0, 32'ha1b2c3d4, 4'b0000);
    read_req(0, 0);

    write_req(0, 32'h11223344, 4'b1100, 0);
    assert_msg(u_sdram.Bank0[0] === before0, "Partial write must stay cached until eviction");
    assert_msg(u_sdram.Bank0[1] === before1, "Partial write must stay cached until eviction");
    model_write(0, 32'h11223344, 4'b1100);
    read_req(0, 0);

    write_req(0, 32'h55667788, 4'b0011, 0);
    assert_msg(u_sdram.Bank0[0] === before0, "Upper-half write must stay cached until eviction");
    assert_msg(u_sdram.Bank0[1] === before1, "Upper-half write must stay cached until eviction");
    model_write(0, 32'h55667788, 4'b0011);
    read_req(0, 0);

    read_req(LINE_UNITS, 2);
    assert_sdram_unit_equals(0);

    read_req(0, 1);
    assert_msg(cache_dout === 32'h55663344, "Big-endian data must survive write-back and refill");

    $display("PASS");
    $finish;
end

endmodule
