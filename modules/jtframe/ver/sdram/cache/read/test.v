`timescale 1ns / 1ps

module cache_read_env #(parameter
    DW       = 16,
    ENDIAN   = 0,
    BLKSIZE  = 1024,
    BLOCKS   = 8,
    CACHE_AW = 23,
    WORDS    = 4096
);

`include "test_tasks.vh"

localparam integer PERIOD     = 10;
localparam integer HF         = 1;
localparam integer AW0        = DW==128 ? 4 : DW==64 ? 3 : DW==32 ? 2 : DW==16 ? 1 : 0;
localparam integer MW         = DW >> 3;
localparam integer LINE_UNITS = BLKSIZE / (DW>>3);

reg                     rst;
reg                     clk;
reg                     clk_sdram;
reg  [CACHE_AW-1:AW0]   cache_addr;
reg  [DW-1:0]           cache_din;
reg                     cache_rd;
reg                     cache_wr;
reg  [MW-1:0]           cache_wdsn;
wire [DW-1:0]           cache_dout;
wire                    cache_ok;

wire [23:1]             ext_addr;
wire [15:0]             ext_din;
wire [15:0]             ext_dout;
wire                    ext_rd;
wire                    ext_wr;
wire                    ext_ack;
wire                    ext_dst;
wire                    ext_dok;
wire                    ext_rdy;

reg                     ioctl_rom;
reg  [25:0]             ioctl_addr;
reg  [ 7:0]             ioctl_dout;
reg                     ioctl_wr;
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
    .ENDIAN     ( ENDIAN    ),
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
        pattern = (byte_addr[7:0] * 8'h3d) ^ 8'h5a;
    end
endfunction

function automatic [31:0] expected_at(input integer unit_addr);
    reg [15:0] w0, w1;
    begin
        if( DW == 8 ) begin
            w0 = exp_mem[unit_addr >> 1];
            expected_at = unit_addr[0] ? { 24'd0, w0[15:8] } : { 24'd0, w0[7:0] };
        end else if( DW == 16 ) begin
            expected_at = { 16'd0, exp_mem[unit_addr] };
        end else begin
            w0 = exp_mem[unit_addr << 1];
            w1 = exp_mem[(unit_addr << 1) + 1];
            expected_at = ENDIAN ? { w0, w1 } : { w1, w0 };
        end
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
        $display("Timed out waiting for SDRAM init (DW=%0d ENDIAN=%0d)", DW, ENDIAN);
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

task read_req(input integer unit_addr, input integer expect_miss);
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
                assert_msg(cycles < 20000, "Cache read timed out");
            end
        end

        if( cache_dout !== expected[DW-1:0] ) begin
            $display("Read mismatch DW=%0d ENDIAN=%0d addr=%0d got=%h expected=%h",
                DW, ENDIAN, unit_addr, cache_dout, expected[DW-1:0]);
            $display("  cache st=%0d blk=%0d stream=%0d off=%0d req_q=%08x stream_q=%08x wb_q=%08x req_addr=%0h stream_addr=%0h",
                u_cache.st, u_cache.blk_l, u_cache.stream_word, u_cache.req_off_l,
                u_cache.req_q, u_cache.stream_q, u_cache.wb_q,
                u_cache.req_ram_addr_l, u_cache.stream_ram_addr_l);
            $display("  sdram bank0[0]=%04x bank0[1]=%04x ext_addr=%0h ack=%b dok=%b rdy=%b",
                u_sdram.Bank0[0], u_sdram.Bank0[1], ext_addr, ext_ack, ext_dok, ext_rdy);
            fail();
        end
        if( expect_miss ) begin
            assert_msg(ack_count == ack_before + 1, "Cache miss must trigger one SDRAM burst");
        end else begin
            assert_msg(ack_count == ack_before, "Cache hit must not trigger a new SDRAM burst");
        end

        @(negedge clk);
        cache_rd = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task run;
    integer idx;
    begin
        for( idx=0; idx<WORDS; idx=idx+1 ) exp_mem[idx] = 16'd0;

        rst        = 1'b1;
        cache_addr = {CACHE_AW-AW0{1'b0}};
        cache_din  = {DW{1'b0}};
        cache_rd   = 1'b0;
        cache_wr   = 1'b0;
        cache_wdsn = {MW{1'b1}};

        repeat (20) @(posedge clk);

        for( idx=0; idx<(8*BLKSIZE); idx=idx+1 ) begin
            preload_byte(idx, pattern(idx));
        end

        rst = 1'b0;
        wait_init_done();

        repeat (16) @(posedge clk);

        read_req(0,             1);
        read_req(1,             0);
        read_req(LINE_UNITS-1,  0);
        read_req(LINE_UNITS,    1);
        read_req(LINE_UNITS+1,  0);
        read_req((2*LINE_UNITS)-1, 0);
        read_req(2*LINE_UNITS,  1);
        read_req(4*LINE_UNITS,  1);
        read_req(6*LINE_UNITS,  1);
        read_req(0,             0);
    end
endtask

endmodule

module test;

cache_read_env #(.DW(8),  .ENDIAN(0)) u8();
cache_read_env #(.DW(16), .ENDIAN(0)) u16();
cache_read_env #(.DW(32), .ENDIAN(0)) u32();

initial begin
    u8.run();
    u16.run();
    u32.run();
    $display("PASS");
    $finish;
end

endmodule
