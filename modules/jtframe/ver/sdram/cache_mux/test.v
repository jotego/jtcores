`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam PERIOD        = 10;
localparam HF            = 1;
localparam SDRAM_AW      = 23;
localparam CTRL_AW       = SDRAM_AW-1;
localparam BANK1_START   = 26'd4096;
localparam BANK2_START   = 26'd8192;
localparam OFFSET1_WORDS = 22'd16;
localparam OFFSET2_WORDS = 22'd32;

reg                 rst;
reg                 clk;
reg                 clk_sdram;

reg  [22:1]         addr0;
reg                 rd0;
wire [15:0]         dout0;
wire                ok0;

reg  [22:0]         addr1;
reg                 rd1;
wire [7:0]          dout1;
wire                ok1;

reg  [22:2]         addr2;
reg                 rd2;
wire [31:0]         dout2;
wire                ok2;

wire [22:1]         ctl_addr;
wire [1:0]          ctl_ba;
wire                ctl_rd;
wire [15:0]         ctl_dout;
wire                ctl_ack;
wire                ctl_dst;
wire                ctl_rdy;
wire                init;

reg                 ioctl_rom;
reg  [25:0]         ioctl_addr;
reg  [7:0]          ioctl_dout;
reg                 ioctl_wr;
wire [22:1]         prog_addr;
wire [15:0]         prog_data;
wire [1:0]          prog_mask;
wire                prog_we;
wire                prog_rd;
wire [1:0]          prog_ba;
wire                prom_we;
wire                header;
wire                prog_ack;

wire [15:0]         sdram_dq;
wire [12:0]         sdram_a;
wire [1:0]          sdram_dqm;
wire [1:0]          sdram_ba;
wire                sdram_nwe;
wire                sdram_ncas;
wire                sdram_nras;
wire                sdram_ncs;
wire                sdram_cke;

integer hcnt;

wire rfsh = hcnt == 0;

function [7:0] byte_pattern;
    input [1:0] bank;
    input [15:0] local_byte_addr;
    begin
        byte_pattern = 8'h5a ^ { 6'd0, bank } ^ local_byte_addr[7:0];
    end
endfunction

function [15:0] expected16;
    input [1:0] bank;
    input [21:0] word_addr;
    begin
        expected16 = {
            byte_pattern(bank, { word_addr, 1'b1 }),
            byte_pattern(bank, { word_addr, 1'b0 })
        };
    end
endfunction

function [31:0] expected32;
    input [1:0] bank;
    input [20:0] dword_addr;
    reg [21:0] base_word;
    begin
        base_word  = { dword_addr, 1'b0 };
        expected32 = {
            byte_pattern(bank, { base_word,          1'b1 }),
            byte_pattern(bank, { base_word,          1'b0 }),
            byte_pattern(bank, { base_word + 22'd1, 1'b1 }),
            byte_pattern(bank, { base_word + 22'd1, 1'b0 })
        };
    end
endfunction

jtframe_cache_mux #(
    .SDRAM_AW   ( SDRAM_AW       ),
    .ENDIAN     ( 1              ),
    .AW0        ( 23             ),
    .BLOCKS0    ( 1              ),
    .BLKSIZE0   ( 16             ),
    .DW0        ( 16             ),
    .BA0        ( 2'd0           ),
    .OFFSET0    ( 22'd0          ),
    .AW1        ( 23             ),
    .BLOCKS1    ( 1              ),
    .BLKSIZE1   ( 16             ),
    .DW1        ( 8              ),
    .BA1        ( 2'd1           ),
    .OFFSET1    ( OFFSET1_WORDS  ),
    .AW2        ( 23             ),
    .BLOCKS2    ( 1              ),
    .BLKSIZE2   ( 16             ),
    .DW2        ( 32             ),
    .BA2        ( 2'd2           ),
    .OFFSET2    ( OFFSET2_WORDS  ),
    .AW3        ( 23             ),
    .BLOCKS3    ( 1              ),
    .BLKSIZE3   ( 16             ),
    .DW3        ( 16             ),
    .BA3        ( 2'd3           ),
    .OFFSET3    ( 22'd0          ),
    .AW4        ( 23             ),
    .BLOCKS4    ( 1              ),
    .BLKSIZE4   ( 16             ),
    .DW4        ( 16             ),
    .BA4        ( 2'd0           ),
    .OFFSET4    ( 22'd0          ),
    .AW5        ( 23             ),
    .BLOCKS5    ( 1              ),
    .BLKSIZE5   ( 16             ),
    .DW5        ( 16             ),
    .BA5        ( 2'd0           ),
    .OFFSET5    ( 22'd0          ),
    .AW6        ( 23             ),
    .BLOCKS6    ( 1              ),
    .BLKSIZE6   ( 16             ),
    .DW6        ( 16             ),
    .BA6        ( 2'd0           ),
    .OFFSET6    ( 22'd0          ),
    .AW7        ( 23             ),
    .BLOCKS7    ( 1              ),
    .BLKSIZE7   ( 16             ),
    .DW7        ( 16             ),
    .BA7        ( 2'd0           ),
    .OFFSET7    ( 22'd0          )
) uut (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .addr0      ( addr0     ),
    .dout0      ( dout0     ),
    .rd0        ( rd0       ),
    .ok0        ( ok0       ),
    .addr1      ( addr1     ),
    .dout1      ( dout1     ),
    .rd1        ( rd1       ),
    .ok1        ( ok1       ),
    .addr2      ( addr2     ),
    .dout2      ( dout2     ),
    .rd2        ( rd2       ),
    .ok2        ( ok2       ),
    .addr3      ( 22'd0     ),
    .dout3      (           ),
    .rd3        ( 1'b0      ),
    .ok3        (           ),
    .addr4      ( 22'd0     ),
    .dout4      (           ),
    .rd4        ( 1'b0      ),
    .ok4        (           ),
    .addr5      ( 22'd0     ),
    .dout5      (           ),
    .rd5        ( 1'b0      ),
    .ok5        (           ),
    .addr6      ( 22'd0     ),
    .dout6      (           ),
    .rd6        ( 1'b0      ),
    .ok6        (           ),
    .addr7      ( 22'd0     ),
    .dout7      (           ),
    .rd7        ( 1'b0      ),
    .ok7        (           ),
    .addr       ( ctl_addr  ),
    .ba         ( ctl_ba    ),
    .rd         ( ctl_rd    ),
    .din        ( ctl_dout  ),
    .ack        ( ctl_ack   ),
    .dst        ( ctl_dst   ),
    .rdy        ( ctl_rdy   )
);

jtframe_burst_sdram #(
    .AW      ( CTRL_AW ),
    .HF      ( HF      ),
    .MISTER  ( 0       ),
    .PROG_LEN( 64      )
) u_sdram_ctrl (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( ctl_addr     ),
    .ba         ( ctl_ba       ),
    .rd         ( ctl_rd       ),
    .wr         ( 1'b0         ),
    .din        ( 16'h0000     ),
    .dout       ( ctl_dout     ),
    .ack        ( ctl_ack      ),
    .dst        ( ctl_dst      ),
    .dok        (              ),
    .rdy        ( ctl_rdy      ),
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
    .SWAB      ( 1'b1        ),
    .SDRAMW    ( SDRAM_AW    ),
    .BA1_START ( BANK1_START ),
    .BA2_START ( BANK2_START )
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

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt + 1;
    end
end

initial begin
    clk = 1'b0;
    clk_sdram = 1'b0;
    forever begin
        #(PERIOD/2) clk = ~clk;
        #1 clk_sdram = clk;
    end
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

task wait_prog_ready;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<500; timeout=timeout+1 ) begin
            @(posedge clk);
            if( prog_ack ) disable wait_loop;
        end
        $display("Timed out waiting for programming ready");
        fail();
    end
endtask

task download_byte;
    input [25:0] byte_addr;
    input [7:0] value;
    begin
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

task preload_bank;
    input [1:0] bank;
    input [25:0] base_byte_addr;
    input [15:0] local_byte_count;
    integer n;
    begin
        for( n=0; n<local_byte_count; n=n+1 ) begin
            download_byte(base_byte_addr + n[25:0], byte_pattern(bank, n[15:0]));
        end
    end
endtask

task request_cache0;
    input [21:0] req_addr;
    input [15:0] expected;
    input expect_miss;
    integer cycles;
    begin
        if( ok0 ) @(posedge clk);
        @(negedge clk);
        addr0 <= req_addr;
        rd0   <= 1'b1;
        cycles = 0;
        while( !ok0 ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 256, "Cache0 request timed out");
        end
        assert_msg(dout0 == expected, $sformatf("Cache0[%0d] returned unexpected data: got %04x expected %04x", req_addr, dout0, expected));
        if( expect_miss ) begin
            assert_msg(cycles > 4, "Cache0 miss completed too quickly");
        end
        @(negedge clk);
        rd0 <= 1'b0;
        @(posedge clk);
    end
endtask

task request_cache1;
    input [22:0] req_addr;
    input [7:0] expected;
    input expect_miss;
    integer cycles;
    begin
        if( ok1 ) @(posedge clk);
        @(negedge clk);
        addr1 <= req_addr;
        rd1   <= 1'b1;
        cycles = 0;
        while( !ok1 ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 256, "Cache1 request timed out");
        end
        assert_msg(dout1 == expected, "Cache1 returned unexpected data");
        if( expect_miss ) begin
            assert_msg(cycles > 4, "Cache1 miss completed too quickly");
        end
        @(negedge clk);
        rd1 <= 1'b0;
        @(posedge clk);
    end
endtask

task request_cache2;
    input [20:0] req_addr;
    input [31:0] expected;
    input expect_miss;
    integer cycles;
    begin
        if( ok2 ) @(posedge clk);
        @(negedge clk);
        addr2 <= req_addr;
        rd2   <= 1'b1;
        cycles = 0;
        while( !ok2 ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 256, "Cache2 request timed out");
        end
        assert_msg(dout2 == expected, "Cache2 returned unexpected data");
        if( expect_miss ) begin
            assert_msg(cycles > 4, "Cache2 miss completed too quickly");
        end
        @(negedge clk);
        rd2 <= 1'b0;
        @(posedge clk);
    end
endtask

task concurrent_misses;
    integer cycles;
    begin
        if( ok0 ) @(posedge clk);
        if( ok1 ) @(posedge clk);
        @(negedge clk);
        addr0 <= 22'd10;
        addr1 <= 23'd28;
        rd0   <= 1'b1;
        rd1   <= 1'b1;
        cycles = 0;
        while( !ok0 || !ok1 ) begin
            @(posedge clk);
            cycles = cycles + 1;
            assert_msg(cycles < 512, "Concurrent miss sequence timed out");
        end
        assert_msg(dout0 == expected16(2'd0, 22'd10), "Concurrent miss returned wrong cache0 data");
        assert_msg(dout1 == byte_pattern(2'd1, { OFFSET1_WORDS, 1'b0 } + 16'd28), "Concurrent miss returned wrong cache1 data");
        @(negedge clk);
        rd0 <= 1'b0;
        rd1 <= 1'b0;
        @(posedge clk);
    end
endtask

integer i;

initial begin
    rst       = 1'b1;
    addr0     = 22'd0;
    addr1     = 23'd0;
    addr2     = 21'd0;
    rd0       = 1'b0;
    rd1       = 1'b0;
    rd2       = 1'b0;
    ioctl_rom = 1'b0;
    ioctl_addr= 26'd0;
    ioctl_dout= 8'd0;
    ioctl_wr  = 1'b0;

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

    preload_bank(2'd0, 26'd0,       128);
    preload_bank(2'd1, BANK1_START, 128);
    preload_bank(2'd2, BANK2_START, 192);

    @(negedge clk);
    ioctl_rom = 1'b0;

    repeat (20) @(posedge clk);

    request_cache0(22'd2, expected16(2'd0, 22'd2), 1'b1);

    request_cache1(23'd3, byte_pattern(2'd1, { OFFSET1_WORDS, 1'b0 } + 16'd3), 1'b1);

    request_cache2(21'd4, expected32(2'd2, OFFSET2_WORDS[21:1] + 21'd4), 1'b1);

    concurrent_misses();

    pass();
end

endmodule
