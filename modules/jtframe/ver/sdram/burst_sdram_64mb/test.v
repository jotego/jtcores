`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD          = 10;
localparam integer HF              = 1;
localparam integer AW              = 23;
localparam integer PAGE_WORDS      = 512;
localparam integer FILE_BYTES      = 16*1024*1024;
localparam integer WORDS           = FILE_BYTES/2;
localparam integer RANDOM_BURSTS   = 96;
localparam integer MAX_BURST_WORDS = 32;

reg               rst;
reg               clk;
reg               clk_sdram;
reg  [AW-1:0]     addr;
reg  [1:0]        ba;
reg               rd;
wire [15:0]       dout;
wire              ack;
wire              dst;
wire              dok;
wire              rdy;
wire              init;

wire [15:0]       sdram_dq;
wire [12:0]       sdram_a;
wire [1:0]        sdram_dqm;
wire [1:0]        sdram_ba;
wire              sdram_nwe;
wire              sdram_ncas;
wire              sdram_nras;
wire              sdram_ncs;
wire              sdram_cke;

reg  [15:0]       exp_mem [0:WORDS-1];

integer           hcnt;
integer           i;
integer           load_file;
integer           load_count;
wire              rfsh = hcnt == 0;

jtframe_burst_sdram #(
    .AW      ( AW ),
    .HF      ( HF ),
    .MISTER  ( 0  ),
    .PROG_LEN( 64 )
) uut (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( addr         ),
    .ba         ( ba           ),
    .rd         ( rd           ),
    .wr         ( 1'b0         ),
    .din        ( 16'h0000     ),
    .dout       ( dout         ),
    .ack        ( ack          ),
    .dst        ( dst          ),
    .dok        ( dok          ),
    .rdy        ( rdy          ),
    .prog_en    ( 1'b0         ),
    .prog_addr  ( {AW{1'b0}}   ),
    .prog_rd    ( 1'b0         ),
    .prog_wr    ( 1'b0         ),
    .prog_din   ( 16'h0000     ),
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

function [31:0] next_rand;
    input [31:0] cur;
    begin
        next_rand = cur * 32'h41c64e6d + 32'h00003039;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt+1;
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
    load_file = $fopen("sdram_bank3.bin","rb");
    if( load_file == 0 ) begin
        $display("Could not open sdram_bank3.bin");
        fail();
    end
    load_count = $fread(exp_mem, load_file);
    $fclose(load_file);
    if( load_count != FILE_BYTES ) begin
        $display("Expected %0d bytes in sdram_bank3.bin, got %0d", FILE_BYTES, load_count);
        fail();
    end
end

task wait_consumer_ack;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<500; timeout=timeout+1 ) begin
            @(posedge clk);
            if( ack ) disable wait_loop;
        end
        $display("Timed out waiting for burst ack");
        fail();
    end
endtask

task burst_read_words;
    input integer base_addr;
    input integer count;
    integer seen;
    integer timeout;
    reg [15:0] expected;
    reg done;
    begin
        if( count <= 0 ) begin
            $display("Invalid burst length %0d at base address %0d", count, base_addr);
            fail();
        end
        @(negedge clk);
        addr = base_addr[AW-1:0];
        ba   = 2'd3;
        rd   = 1'b1;
        wait_consumer_ack();
        seen = 0;
        done = 1'b0;
        while( seen < count ) begin
            @(posedge clk);
            if( dok ) begin
                expected = exp_mem[base_addr + seen];
                if( dout !== expected ) begin
                    $display("Read mismatch at word %0d: got %04x expected %04x", base_addr + seen, dout, expected);
                    fail();
                end
                if( seen == 0 ) assert_msg(dst, "dst must mark the first returned word");
                else assert_msg(!dst, "dst must only pulse for the first returned word");
                seen = seen + 1;
                if( rdy ) done = 1'b1;
                if( seen == count ) begin
                    @(negedge clk);
                    rd = 1'b0;
                end
            end
        end
        if( !done ) begin
            begin : wait_done
                for( timeout=0; timeout<16; timeout=timeout+1 ) begin
                    @(posedge clk);
                    if( rdy ) disable wait_done;
                end
                $display("Timed out waiting for burst completion at word %0d", base_addr);
                fail();
            end
        end
        repeat (4) @(posedge clk);
    end
endtask

task run_random_reads;
    integer burst_idx;
    integer base_addr;
    integer count;
    integer page_remaining;
    integer bank_remaining;
    reg [31:0] rng;
    begin
        rng = 32'h64ab0001;
        for( burst_idx=0; burst_idx<RANDOM_BURSTS; burst_idx=burst_idx+1 ) begin
            rng = next_rand(rng);
            base_addr = rng % WORDS;
            rng = next_rand(rng);
            count = (rng % MAX_BURST_WORDS) + 1;
            page_remaining = PAGE_WORDS - (base_addr % PAGE_WORDS);
            bank_remaining = WORDS - base_addr;
            if( count > page_remaining ) count = page_remaining;
            if( count > bank_remaining ) count = bank_remaining;
            burst_read_words(base_addr, count);
        end
    end
endtask

initial begin
    rst  = 1'b1;
    addr = {AW{1'b0}};
    ba   = 2'd0;
    rd   = 1'b0;

    repeat (20) @(posedge clk);
    rst = 1'b0;

    begin : wait_init_done
        for( i=0; i<20_000; i=i+1 ) begin
            @(posedge clk);
            if( !init ) disable wait_init_done;
        end
        $display("Timed out waiting for SDRAM init");
        fail();
    end

    burst_read_words(0, 16);
    burst_read_words(PAGE_WORDS-8, 8);
    burst_read_words(PAGE_WORDS, 16);
    burst_read_words((WORDS/2)-16, 16);
    burst_read_words(WORDS-PAGE_WORDS, 32);
    burst_read_words(WORDS-16, 16);

    run_random_reads();

    pass();
end

endmodule
