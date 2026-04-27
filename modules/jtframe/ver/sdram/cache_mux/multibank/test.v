`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD       = 10;
localparam integer HF           = 1;
localparam integer SDRAM_AW     = 24;
localparam integer BANK_WORDS   = 8_388_608;
localparam integer INIT_WORDS   = 2048;
localparam integer BLOCK_WORDS  = 512;
localparam integer LANE1_BANK   = 2;
localparam integer LANE1_OFFSET = 64;
localparam integer LANE2_BANK   = 3;
localparam integer LANE2_OFFSET = 128;

reg                 rst;
reg                 clk;
reg                 clk_sdram;

reg  [25:1]         addr0;
reg  [22:1]         addr1, addr2, addr3, addr4, addr5, addr6, addr7;
reg                 rd0, rd1, rd2, rd3, rd4, rd5, rd6, rd7;
reg                 wr0, wr1, wr2, wr3;
reg  [15:0]         din0, din1, din2, din3;
reg  [ 1:0]         wdsn0, wdsn1, wdsn2, wdsn3;

wire [15:0]         dout0, dout1, dout2, dout3, dout4, dout5, dout6, dout7;
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

integer             hcnt;
integer             ack_count;
reg [ 1:0]          ack_ba_log   [0:31];
reg [SDRAM_AW-1:1]  ack_addr_log [0:31];

wire rfsh = hcnt == 0;

assign sdram_addr_full = { 1'b0, sdram_addr };

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAM_AW    ),
    .ENDIAN   ( 0           ),
    .FULL0    ( 1           ),
    .AW0      ( 26          ),
    .BLOCKS0  ( 1           ),
    .BLKSIZE0 ( 1024        ),
    .DW0      ( 16          ),
    .BA0      ( 0           ),
    .OFFSET0  ( 0           ),
    .FULL1    ( 0           ),
    .AW1      ( 23          ),
    .BLOCKS1  ( 1           ),
    .BLKSIZE1 ( 1024        ),
    .DW1      ( 16          ),
    .BA1      ( LANE1_BANK  ),
    .OFFSET1  ( LANE1_OFFSET ),
    .FULL2    ( 0           ),
    .AW2      ( 23          ),
    .BLOCKS2  ( 1           ),
    .BLKSIZE2 ( 1024        ),
    .DW2      ( 16          ),
    .BA2      ( LANE2_BANK  ),
    .OFFSET2  ( LANE2_OFFSET ),
    .FULL3    ( 0           ),
    .AW3      ( 23          ),
    .BLOCKS3  ( 1           ),
    .BLKSIZE3 ( 1024        ),
    .DW3      ( 16          ),
    .FULL4    ( 0           ),
    .AW4      ( 23          ),
    .BLOCKS4  ( 1           ),
    .BLKSIZE4 ( 1024        ),
    .DW4      ( 16          ),
    .FULL5    ( 0           ),
    .AW5      ( 23          ),
    .BLOCKS5  ( 1           ),
    .BLKSIZE5 ( 1024        ),
    .DW5      ( 16          ),
    .FULL6    ( 0           ),
    .AW6      ( 23          ),
    .BLOCKS6  ( 1           ),
    .BLKSIZE6 ( 1024        ),
    .DW6      ( 16          ),
    .FULL7    ( 0           ),
    .AW7      ( 23          ),
    .BLOCKS7  ( 1           ),
    .BLKSIZE7 ( 1024        ),
    .DW7      ( 16          )
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
    .rst        ( rst             ),
    .clk        ( clk             ),
    .init       ( init            ),
    .addr       ( sdram_addr_full ),
    .ba         ( sdram_ba_mux    ),
    .rd         ( sdram_rd        ),
    .wr         ( sdram_wr        ),
    .din        ( sdram_din_mux   ),
    .dout       ( sdram_dout_mux  ),
    .ack        ( sdram_ack       ),
    .dst        ( sdram_dst       ),
    .dok        ( sdram_dok       ),
    .rdy        ( sdram_rdy       ),
    .prog_en    ( 1'b0            ),
    .prog_addr  ( {SDRAM_AW{1'b0}} ),
    .prog_rd    ( 1'b0            ),
    .prog_wr    ( 1'b0            ),
    .prog_din   ( 16'd0           ),
    .prog_dsn   ( 2'b00           ),
    .prog_ba    ( 2'b00           ),
    .prog_dst   (                 ),
    .prog_dok   (                 ),
    .prog_rdy   (                 ),
    .prog_ack   (                 ),
    .rfsh       ( rfsh            ),
    .sdram_dq   ( sdram_dq        ),
    .sdram_a    ( sdram_a         ),
    .sdram_dqml ( sdram_dqm[0]    ),
    .sdram_dqmh ( sdram_dqm[1]    ),
    .sdram_ba   ( sdram_ba        ),
    .sdram_nwe  ( sdram_nwe       ),
    .sdram_ncas ( sdram_ncas      ),
    .sdram_nras ( sdram_nras      ),
    .sdram_ncs  ( sdram_ncs       ),
    .sdram_cke  ( sdram_cke       )
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

function automatic integer line_base(input integer word_addr);
    begin
        line_base = (word_addr / BLOCK_WORDS) * BLOCK_WORDS;
    end
endfunction

function automatic [15:0] pattern(input integer bank, input integer local_addr);
    reg [15:0] tmp;
    begin
        tmp = local_addr[15:0];
        pattern = ((bank + 1) * 16'h1111) ^ (tmp * 16'h0031) ^ 16'h5a17;
    end
endfunction

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

task wait_ok0;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<20_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( ok0 ) disable wait_loop;
        end
        $display("Timed out waiting for ok0");
        fail();
    end
endtask

task wait_ok1;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<20_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( ok1 ) disable wait_loop;
        end
        $display("Timed out waiting for ok1");
        fail();
    end
endtask

task wait_ok2;
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<20_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( ok2 ) disable wait_loop;
        end
        $display("Timed out waiting for ok2");
        fail();
    end
endtask

task check_full_lane_read;
    input [25:1] req_addr;
    input integer exp_bank;
    input integer exp_local_addr;
    integer ack_before;
    reg [15:0] expected;
    begin
        ack_before = ack_count;
        @(negedge clk);
        addr0 = req_addr;
        rd0 = 1'b1;
        wait_ok0();
        expected = pattern(exp_bank, exp_local_addr);
        if( ack_count != ack_before + 1 ) begin
            $display("full lane expected one SDRAM burst, saw %0d new bursts", ack_count - ack_before);
            fail();
        end
        if( ack_ba_log[ack_before] !== exp_bank[1:0] ) begin
            $display("full lane bank mismatch: got %0d expected %0d", ack_ba_log[ack_before], exp_bank);
            fail();
        end
        if( ack_addr_log[ack_before] !== line_base(exp_local_addr) ) begin
            $display("full lane burst addr mismatch: got %0d expected %0d", ack_addr_log[ack_before], line_base(exp_local_addr));
            fail();
        end
        if( dout0 !== expected ) begin
            $display("full lane data mismatch: got %04x expected %04x", dout0, expected);
            fail();
        end
        @(negedge clk);
        rd0 = 1'b0;
        repeat (2) @(posedge clk);
        assert_msg(!ok0, "ok0 must clear once rd0 is released");
    end
endtask

task check_banked_lane_read;
    input [22:1] req_addr;
    input integer exp_local_addr;
    integer ack_before;
    reg [15:0] expected;
    begin
        ack_before = ack_count;
        @(negedge clk);
        addr1 = req_addr;
        rd1 = 1'b1;
        wait_ok1();
        expected = pattern(LANE1_BANK, exp_local_addr);
        if( ack_count != ack_before + 1 ) begin
            $display("banked lane expected one SDRAM burst, saw %0d new bursts", ack_count - ack_before);
            fail();
        end
        if( ack_ba_log[ack_before] !== LANE1_BANK[1:0] ) begin
            $display("banked lane bank mismatch: got %0d expected %0d", ack_ba_log[ack_before], LANE1_BANK);
            fail();
        end
        if( ack_addr_log[ack_before] !== LANE1_OFFSET + line_base(req_addr) ) begin
            $display("banked lane burst addr mismatch: got %0d expected %0d", ack_addr_log[ack_before], LANE1_OFFSET + line_base(req_addr));
            fail();
        end
        if( dout1 !== expected ) begin
            $display("banked lane data mismatch: got %04x expected %04x", dout1, expected);
            fail();
        end
        @(negedge clk);
        rd1 = 1'b0;
        repeat (2) @(posedge clk);
        assert_msg(!ok1, "ok1 must clear once rd1 is released");
    end
endtask

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
        ack_count <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt + 1;
        if( sdram_ack ) begin
            ack_ba_log[ack_count] <= sdram_ba_mux;
            ack_addr_log[ack_count] <= sdram_addr;
            ack_count <= ack_count + 1;
        end
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

integer i;
integer ack_before;

initial begin
    for( i=0; i<INIT_WORDS; i=i+1 ) begin
        u_sdram.Bank0[i] = pattern(0, i);
        u_sdram.Bank1[i] = pattern(1, i);
        u_sdram.Bank2[i] = pattern(2, i);
        u_sdram.Bank3[i] = pattern(3, i);
    end
    for( i=0; i<32; i=i+1 ) begin
        ack_ba_log[i] = 0;
        ack_addr_log[i] = 0;
    end

    rst   = 1'b1;
    addr0 = 0;
    addr1 = 0; addr2 = 0; addr3 = 0; addr4 = 0; addr5 = 0; addr6 = 0; addr7 = 0;
    rd0   = 0; rd1   = 0; rd2   = 0; rd3   = 0; rd4   = 0; rd5   = 0; rd6   = 0; rd7   = 0;
    wr0   = 0; wr1   = 0; wr2   = 0; wr3   = 0;
    din0  = 0; din1  = 0; din2  = 0; din3  = 0;
    wdsn0 = 2'b11; wdsn1 = 2'b11; wdsn2 = 2'b11; wdsn3 = 2'b11;

    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    check_full_lane_read(26'd3, 0, 3);
    check_full_lane_read(BANK_WORDS + 26'd7, 1, 7);
    check_full_lane_read((2*BANK_WORDS) + 26'd19, 2, 19);
    check_full_lane_read((3*BANK_WORDS) + 26'd33, 3, 33);

    check_banked_lane_read(23'd5, LANE1_OFFSET + 5);

    ack_before = ack_count;
    @(negedge clk);
    addr2 = 23'd5;
    rd2 = 1'b1;
    addr0 = BANK_WORDS + 26'd9;
    rd0 = 1'b1;

    wait_ok0();
    if( ack_count != ack_before + 1 ) begin
        $display("mixed request should launch the full lane first");
        fail();
    end
    if( ack_ba_log[ack_before] !== 2'd1 ) begin
        $display("mixed request first bank mismatch: got %0d expected 1", ack_ba_log[ack_before]);
        fail();
    end
    if( ack_addr_log[ack_before] !== line_base(9) ) begin
        $display("mixed request first burst addr mismatch: got %0d expected %0d", ack_addr_log[ack_before], line_base(9));
        fail();
    end
    if( dout0 !== pattern(1, 9) ) begin
        $display("mixed request full-lane data mismatch: got %04x expected %04x", dout0, pattern(1, 9));
        fail();
    end
    assert_msg(!ok2, "banked lane must still be pending while lane0 owns the burst");

    wait_ok2();
    if( ack_count != ack_before + 2 ) begin
        $display("mixed request should produce two SDRAM bursts");
        fail();
    end
    if( ack_ba_log[ack_before + 1] !== LANE2_BANK[1:0] ) begin
        $display("mixed request second bank mismatch: got %0d expected %0d", ack_ba_log[ack_before + 1], LANE2_BANK);
        fail();
    end
    if( ack_addr_log[ack_before + 1] !== LANE2_OFFSET ) begin
        $display("mixed request second burst addr mismatch: got %0d expected %0d", ack_addr_log[ack_before + 1], LANE2_OFFSET);
        fail();
    end
    if( dout2 !== pattern(LANE2_BANK, LANE2_OFFSET + 5) ) begin
        $display("mixed request banked-lane data mismatch: got %04x expected %04x", dout2, pattern(LANE2_BANK, LANE2_OFFSET + 5));
        fail();
    end

    @(negedge clk);
    rd0 = 1'b0;
    rd2 = 1'b0;
    repeat (2) @(posedge clk);
    assert_msg(!ok0, "ok0 must clear after the mixed request is released");
    assert_msg(!ok2, "ok2 must clear after the mixed request is released");

    pass();
end

endmodule
