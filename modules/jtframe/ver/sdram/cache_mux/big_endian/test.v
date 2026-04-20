`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD     = 10;
localparam integer HF         = 1;
localparam integer SDRAM_AW   = 23;
localparam integer BLKSIZE    = 1024;
localparam integer LINE_UNITS = BLKSIZE / 4;
localparam integer WORDS      = 4096;
localparam integer OFFSET0_W  =    0;
localparam integer OFFSET4_W  = 1024;

reg                 rst;
reg                 clk;
reg                 clk_sdram;

reg  [22:2]         addr0, addr1, addr2, addr3, addr4, addr5, addr6, addr7;
reg                 rd0, rd1, rd2, rd3, rd4, rd5, rd6, rd7;
reg                 wr0, wr1, wr2, wr3;
reg  [31:0]         din0, din1, din2, din3;
reg  [ 3:0]         wdsn0, wdsn1, wdsn2, wdsn3;

wire [31:0]         dout0, dout1, dout2, dout3, dout4, dout5, dout6, dout7;
wire                ok0, ok1, ok2, ok3, ok4, ok5, ok6, ok7;

wire [SDRAM_AW-1:1] sdram_addr;
wire [SDRAM_AW-1:0] sdram_addr_full;
wire [ 1:0]         sdram_ba_mux;
wire                sdram_rd;
wire                sdram_wr;
wire [15:0]         sdram_din_mux;
wire [15:0]         sdram_dout_mux;
wire                sdram_ack;
wire                sdram_dst;
wire                sdram_dok;
wire                sdram_rdy;
wire                init;

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
integer             ack_count;
integer             hcnt;

wire rfsh = hcnt == 0;

assign sdram_addr_full = { 1'b0, sdram_addr };

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAM_AW ),
    .ENDIAN   ( 1        ),
    .AW0      ( 23       ),
    .BLOCKS0  ( 1        ),
    .BLKSIZE0 ( BLKSIZE  ),
    .DW0      ( 32       ),
    .OFFSET0  ( OFFSET0_W ),
    .AW1      ( 23       ),
    .BLOCKS1  ( 1        ),
    .BLKSIZE1 ( BLKSIZE  ),
    .DW1      ( 32       ),
    .AW2      ( 23       ),
    .BLOCKS2  ( 1        ),
    .BLKSIZE2 ( BLKSIZE  ),
    .DW2      ( 32       ),
    .AW3      ( 23       ),
    .BLOCKS3  ( 1        ),
    .BLKSIZE3 ( BLKSIZE  ),
    .DW3      ( 32       ),
    .AW4      ( 23       ),
    .BLOCKS4  ( 1        ),
    .BLKSIZE4 ( BLKSIZE  ),
    .DW4      ( 32       ),
    .OFFSET4  ( OFFSET4_W ),
    .AW5      ( 23       ),
    .BLOCKS5  ( 1        ),
    .BLKSIZE5 ( BLKSIZE  ),
    .DW5      ( 32       ),
    .AW6      ( 23       ),
    .BLOCKS6  ( 1        ),
    .BLKSIZE6 ( BLKSIZE  ),
    .DW6      ( 32       ),
    .AW7      ( 23       ),
    .BLOCKS7  ( 1        ),
    .BLKSIZE7 ( BLKSIZE  ),
    .DW7      ( 32       )
) u_mux (
    .rst    ( rst            ),
    .clk    ( clk            ),
    .addr0  ( addr0          ),
    .dout0  ( dout0          ),
    .rd0    ( rd0            ),
    .wr0    ( wr0            ),
    .din0   ( din0           ),
    .wdsn0  ( wdsn0          ),
    .ok0    ( ok0            ),
    .addr1  ( addr1          ),
    .dout1  ( dout1          ),
    .rd1    ( rd1            ),
    .wr1    ( wr1            ),
    .din1   ( din1           ),
    .wdsn1  ( wdsn1          ),
    .ok1    ( ok1            ),
    .addr2  ( addr2          ),
    .dout2  ( dout2          ),
    .rd2    ( rd2            ),
    .wr2    ( wr2            ),
    .din2   ( din2           ),
    .wdsn2  ( wdsn2          ),
    .ok2    ( ok2            ),
    .addr3  ( addr3          ),
    .dout3  ( dout3          ),
    .rd3    ( rd3            ),
    .wr3    ( wr3            ),
    .din3   ( din3           ),
    .wdsn3  ( wdsn3          ),
    .ok3    ( ok3            ),
    .addr4  ( addr4          ),
    .dout4  ( dout4          ),
    .rd4    ( rd4            ),
    .ok4    ( ok4            ),
    .addr5  ( addr5          ),
    .dout5  ( dout5          ),
    .rd5    ( rd5            ),
    .ok5    ( ok5            ),
    .addr6  ( addr6          ),
    .dout6  ( dout6          ),
    .rd6    ( rd6            ),
    .ok6    ( ok6            ),
    .addr7  ( addr7          ),
    .dout7  ( dout7          ),
    .rd7    ( rd7            ),
    .ok7    ( ok7            ),
    .addr   ( sdram_addr     ),
    .ba     ( sdram_ba_mux   ),
    .rd     ( sdram_rd       ),
    .wr     ( sdram_wr       ),
    .din    ( sdram_dout_mux ),
    .dout   ( sdram_din_mux  ),
    .ack    ( sdram_ack      ),
    .dst    ( sdram_dst      ),
    .dok    ( sdram_dok      ),
    .rdy    ( sdram_rdy      )
);

jtframe_burst_sdram #(
    .AW      ( SDRAM_AW ),
    .HF      ( HF       ),
    .MISTER  ( 0        ),
    .PROG_LEN( 64       )
) u_sdram_ctrl (
    .rst        ( rst            ),
    .clk        ( clk            ),
    .init       ( init           ),
    .addr       ( sdram_addr_full ),
    .ba         ( sdram_ba_mux   ),
    .rd         ( sdram_rd       ),
    .wr         ( sdram_wr       ),
    .din        ( sdram_din_mux  ),
    .dout       ( sdram_dout_mux ),
    .ack        ( sdram_ack      ),
    .dst        ( sdram_dst      ),
    .dok        ( sdram_dok      ),
    .rdy        ( sdram_rdy      ),
    .prog_en    ( 1'b0           ),
    .prog_addr  ( {SDRAM_AW{1'b0}} ),
    .prog_rd    ( 1'b0           ),
    .prog_wr    ( 1'b0           ),
    .prog_din   ( 16'd0          ),
    .prog_dsn   ( 2'b00          ),
    .prog_ba    ( 2'b00          ),
    .prog_dst   (                ),
    .prog_dok   (                ),
    .prog_rdy   (                ),
    .prog_ack   (                ),
    .rfsh       ( rfsh           ),
    .sdram_dq   ( sdram_dq       ),
    .sdram_a    ( sdram_a        ),
    .sdram_dqml ( sdram_dqm[0]   ),
    .sdram_dqmh ( sdram_dqm[1]   ),
    .sdram_ba   ( sdram_ba       ),
    .sdram_nwe  ( sdram_nwe      ),
    .sdram_ncas ( sdram_ncas     ),
    .sdram_nras ( sdram_nras     ),
    .sdram_ncs  ( sdram_ncs      ),
    .sdram_cke  ( sdram_cke      )
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

function automatic integer lane_offset(input integer lane);
    begin
        lane_offset = lane == 4 ? OFFSET4_W : OFFSET0_W;
    end
endfunction

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

function automatic [31:0] expected_at(input integer lane, input integer unit_addr);
    integer idx0, idx1;
    begin
        idx0 = lane_offset(lane) + (unit_addr << 1);
        idx1 = idx0 + 1;
        expected_at = { exp_mem[idx0], exp_mem[idx1] };
    end
endfunction

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt      <= 0;
        ack_count <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt+1;
        if( sdram_ack ) ack_count <= ack_count + 1;
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

task preload_byte(input integer lane, input integer byte_addr, input [7:0] value);
    integer word_idx;
    integer phys_word;
    begin
        word_idx  = byte_addr >> 1;
        phys_word = lane_offset(lane) + word_idx;
        if( byte_addr[0] ) exp_mem[phys_word][15:8] = value;
        else               exp_mem[phys_word][ 7:0] = value;
        u_sdram.Bank0[phys_word] = exp_mem[phys_word];
    end
endtask

task model_write(input integer lane, input integer unit_addr, input [31:0] wr_data, input [3:0] wr_dsn);
    integer idx0, idx1;
    begin
        idx0 = lane_offset(lane) + (unit_addr << 1);
        idx1 = idx0 + 1;
        exp_mem[idx0] = merge16_model(exp_mem[idx0], wr_data[31:16], wr_dsn[3:2]);
        exp_mem[idx1] = merge16_model(exp_mem[idx1], wr_data[15:0],  wr_dsn[1:0]);
    end
endtask

task assert_sdram_unit_equals(input integer lane, input integer unit_addr);
    integer idx0, idx1;
    begin
        idx0 = lane_offset(lane) + (unit_addr << 1);
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

task lane0_read_req(input integer unit_addr, input integer expect_bursts);
    integer cycles;
    integer ack_before;
    reg [31:0] expected;
    begin
        expected = expected_at(0, unit_addr);
        while( ok0 ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        addr0 = unit_addr;
        rd0   = 1'b1;

        cycles = 0;
        begin : wait_loop
            while( ok0 !== 1'b1 ) begin
                @(posedge clk);
                cycles = cycles + 1;
                assert_msg(cycles < 20_000, "Lane0 read timed out");
            end
        end

        if( dout0 !== expected ) begin
            $display("Lane0 read mismatch addr=%0d got=%08x expected=%08x", unit_addr, dout0, expected);
            fail();
        end
        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected burst count for lane0 read");

        @(negedge clk);
        rd0 = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task lane4_read_req(input integer unit_addr, input integer expect_bursts);
    integer cycles;
    integer ack_before;
    reg [31:0] expected;
    begin
        expected = expected_at(4, unit_addr);
        while( ok4 ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        addr4 = unit_addr;
        rd4   = 1'b1;

        cycles = 0;
        begin : wait_loop
            while( ok4 !== 1'b1 ) begin
                @(posedge clk);
                cycles = cycles + 1;
                assert_msg(cycles < 20_000, "Lane4 read timed out");
            end
        end

        if( dout4 !== expected ) begin
            $display("Lane4 read mismatch addr=%0d got=%08x expected=%08x", unit_addr, dout4, expected);
            fail();
        end
        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected burst count for lane4 read");

        @(negedge clk);
        rd4 = 1'b0;
        repeat (4) @(posedge clk);
    end
endtask

task lane0_write_req(
    input integer unit_addr,
    input [31:0] wr_data,
    input [ 3:0] wr_dsn,
    input integer expect_bursts
);
    integer cycles;
    integer ack_before;
    begin
        while( ok0 ) @(posedge clk);
        ack_before = ack_count;

        @(negedge clk);
        addr0 = unit_addr;
        din0  = wr_data;
        wdsn0 = wr_dsn;
        wr0   = 1'b1;

        cycles = 0;
        begin : wait_loop
            while( ok0 !== 1'b1 ) begin
                @(posedge clk);
                cycles = cycles + 1;
                assert_msg(cycles < 20_000, "Lane0 write timed out");
            end
        end

        assert_msg(ack_count == ack_before + expect_bursts, "Unexpected burst count for lane0 write");

        @(negedge clk);
        wr0   = 1'b0;
        din0  = 32'd0;
        wdsn0 = 4'hf;
        repeat (4) @(posedge clk);
    end
endtask

integer idx;
reg [15:0] before0, before1;

initial begin
    for( idx=0; idx<WORDS; idx=idx+1 ) exp_mem[idx] = 16'd0;

    preload_byte(0, 0, 8'h02);
    preload_byte(0, 1, 8'h01);
    preload_byte(0, 2, 8'h04);
    preload_byte(0, 3, 8'h03);
    for( idx=4; idx<(2*BLKSIZE); idx=idx+1 ) preload_byte(0, idx, pattern(idx));
    for( idx=0; idx<(2*BLKSIZE); idx=idx+1 ) preload_byte(4, idx, pattern(idx + 8'h40));

    rst   = 1'b1;
    addr0 = 21'd0; addr1 = 21'd0; addr2 = 21'd0; addr3 = 21'd0;
    addr4 = 21'd0; addr5 = 21'd0; addr6 = 21'd0; addr7 = 21'd0;
    rd0   = 1'b0;  rd1   = 1'b0;  rd2   = 1'b0;  rd3   = 1'b0;
    rd4   = 1'b0;  rd5   = 1'b0;  rd6   = 1'b0;  rd7   = 1'b0;
    wr0   = 1'b0;  wr1   = 1'b0;  wr2   = 1'b0;  wr3   = 1'b0;
    din0  = 32'd0; din1  = 32'd0; din2  = 32'd0; din3  = 32'd0;
    wdsn0 = 4'hf;  wdsn1 = 4'hf;  wdsn2 = 4'hf;  wdsn3 = 4'hf;

    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    lane0_read_req(0, 1);
    assert_msg(dout0 === 32'h01020304, "Lane0 must assemble big-endian data");

    before0 = u_sdram.Bank0[OFFSET0_W];
    before1 = u_sdram.Bank0[OFFSET0_W + 1];
    lane0_write_req(0, 32'ha1b2c3d4, 4'b0000, 0);
    assert_msg(u_sdram.Bank0[OFFSET0_W]     === before0, "Write hit must stay cached until eviction");
    assert_msg(u_sdram.Bank0[OFFSET0_W + 1] === before1, "Write hit must stay cached until eviction");
    model_write(0, 0, 32'ha1b2c3d4, 4'b0000);
    lane0_read_req(0, 0);

    lane0_write_req(0, 32'h11223344, 4'b1100, 0);
    assert_msg(u_sdram.Bank0[OFFSET0_W]     === before0, "Partial write must stay cached until eviction");
    assert_msg(u_sdram.Bank0[OFFSET0_W + 1] === before1, "Partial write must stay cached until eviction");
    model_write(0, 0, 32'h11223344, 4'b1100);
    lane0_read_req(0, 0);

    lane0_write_req(0, 32'h55667788, 4'b0011, 0);
    assert_msg(u_sdram.Bank0[OFFSET0_W]     === before0, "Upper-half write must stay cached until eviction");
    assert_msg(u_sdram.Bank0[OFFSET0_W + 1] === before1, "Upper-half write must stay cached until eviction");
    model_write(0, 0, 32'h55667788, 4'b0011);
    lane0_read_req(0, 0);

    lane4_read_req(0, 1);

    lane0_read_req(LINE_UNITS, 2);
    assert_sdram_unit_equals(0, 0);

    lane0_read_req(0, 1);
    assert_msg(dout0 === 32'h55663344, "Big-endian data must survive write-back and refill through the mux");

    pass();
end

endmodule
