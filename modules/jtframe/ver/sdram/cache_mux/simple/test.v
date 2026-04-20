`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD     = 10;
localparam integer HF         = 1;
localparam integer SDRAM_AW   = 23;
localparam integer WORDS      = 8192;
localparam integer OFFSET0_W  =    0;
localparam integer OFFSET1_W  = 1024;
localparam integer OFFSET2_W  = 2048;
localparam integer OFFSET3_W  = 3072;
localparam integer OFFSET4_W  = 4096;
localparam integer OFFSET5_W  = 5120;
localparam integer OFFSET6_W  = 6144;
localparam integer OFFSET7_W  = 7168;

reg                 rst;
reg                 clk;
reg                 clk_sdram;

reg  [22:1]         addr0, addr1, addr2, addr3, addr4, addr5, addr6, addr7;
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

reg  [15:0]         exp_mem [0:WORDS-1];
integer             ack_lane_log [0:63];
integer             ack_count;
integer             hcnt;

wire rfsh = hcnt == 0;

assign sdram_addr_full = { 1'b0, sdram_addr };

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAM_AW ),
    .ENDIAN   ( 0        ),
    .AW0      ( 23       ),
    .BLOCKS0  ( 1        ),
    .BLKSIZE0 ( 1024     ),
    .DW0      ( 16       ),
    .OFFSET0  ( OFFSET0_W ),
    .AW1      ( 23       ),
    .BLOCKS1  ( 1        ),
    .BLKSIZE1 ( 1024     ),
    .DW1      ( 16       ),
    .OFFSET1  ( OFFSET1_W ),
    .AW2      ( 23       ),
    .BLOCKS2  ( 1        ),
    .BLKSIZE2 ( 1024     ),
    .DW2      ( 16       ),
    .OFFSET2  ( OFFSET2_W ),
    .AW3      ( 23       ),
    .BLOCKS3  ( 1        ),
    .BLKSIZE3 ( 1024     ),
    .DW3      ( 16       ),
    .OFFSET3  ( OFFSET3_W ),
    .AW4      ( 23       ),
    .BLOCKS4  ( 1        ),
    .BLKSIZE4 ( 1024     ),
    .DW4      ( 16       ),
    .OFFSET4  ( OFFSET4_W ),
    .AW5      ( 23       ),
    .BLOCKS5  ( 1        ),
    .BLKSIZE5 ( 1024     ),
    .DW5      ( 16       ),
    .OFFSET5  ( OFFSET5_W ),
    .AW6      ( 23       ),
    .BLOCKS6  ( 1        ),
    .BLKSIZE6 ( 1024     ),
    .DW6      ( 16       ),
    .OFFSET6  ( OFFSET6_W ),
    .AW7      ( 23       ),
    .BLOCKS7  ( 1        ),
    .BLKSIZE7 ( 1024     ),
    .DW7      ( 16       ),
    .OFFSET7  ( OFFSET7_W )
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
        case( lane )
            0: lane_offset = OFFSET0_W;
            1: lane_offset = OFFSET1_W;
            2: lane_offset = OFFSET2_W;
            3: lane_offset = OFFSET3_W;
            4: lane_offset = OFFSET4_W;
            5: lane_offset = OFFSET5_W;
            6: lane_offset = OFFSET6_W;
            default: lane_offset = OFFSET7_W;
        endcase
    end
endfunction

function automatic [15:0] pattern(input integer phys_addr);
    reg [15:0] tmp;
    begin
        tmp = phys_addr[15:0];
        pattern = (tmp * 16'h0031) ^ 16'h5a17;
    end
endfunction

function automatic [15:0] expected_word(input integer lane, input integer local_addr);
    begin
        expected_word = exp_mem[lane_offset(lane) + local_addr];
    end
endfunction

function automatic lane_ok(input integer lane);
    begin
        case( lane )
            0: lane_ok = ok0;
            1: lane_ok = ok1;
            2: lane_ok = ok2;
            3: lane_ok = ok3;
            4: lane_ok = ok4;
            5: lane_ok = ok5;
            6: lane_ok = ok6;
            default: lane_ok = ok7;
        endcase
    end
endfunction

function automatic [15:0] lane_dout(input integer lane);
    begin
        case( lane )
            0: lane_dout = dout0;
            1: lane_dout = dout1;
            2: lane_dout = dout2;
            3: lane_dout = dout3;
            4: lane_dout = dout4;
            5: lane_dout = dout5;
            6: lane_dout = dout6;
            default: lane_dout = dout7;
        endcase
    end
endfunction

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt      <= 0;
        ack_count <= 0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt + 1;
        if( sdram_ack ) begin
            ack_lane_log[ack_count] <= u_mux.active_sel;
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

task set_lane_addr(input integer lane, input [22:1] value);
    begin
        case( lane )
            0: addr0 = value;
            1: addr1 = value;
            2: addr2 = value;
            3: addr3 = value;
            4: addr4 = value;
            5: addr5 = value;
            6: addr6 = value;
            default: addr7 = value;
        endcase
    end
endtask

task set_lane_rd(input integer lane, input value);
    begin
        case( lane )
            0: rd0 = value;
            1: rd1 = value;
            2: rd2 = value;
            3: rd3 = value;
            4: rd4 = value;
            5: rd5 = value;
            6: rd6 = value;
            default: rd7 = value;
        endcase
    end
endtask

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

task wait_lane_ok(input integer lane);
    integer timeout;
    begin : wait_loop
        for( timeout=0; timeout<20_000; timeout=timeout+1 ) begin
            @(posedge clk);
            if( lane_ok(lane) ) disable wait_loop;
        end
        $display("Timed out waiting for ok on lane %0d", lane);
        fail();
    end
endtask

task assert_lane_word(input integer lane, input integer local_addr);
    reg [15:0] expected;
    begin
        expected = expected_word(lane, local_addr);
        if( lane_dout(lane) !== expected ) begin
            $display("Lane %0d read mismatch at %0d: got %04x expected %04x",
                lane, local_addr, lane_dout(lane), expected);
            fail();
        end
    end
endtask

integer i;
integer ack_before;

initial begin
    for( i=0; i<WORDS; i=i+1 ) begin
        exp_mem[i] = pattern(i);
        u_sdram.Bank0[i] = exp_mem[i];
    end
    for( i=0; i<64; i=i+1 ) ack_lane_log[i] = -1;

    rst   = 1'b1;
    addr0 = 22'd0; addr1 = 22'd0; addr2 = 22'd0; addr3 = 22'd0;
    addr4 = 22'd0; addr5 = 22'd0; addr6 = 22'd0; addr7 = 22'd0;
    rd0   = 1'b0;  rd1   = 1'b0;  rd2   = 1'b0;  rd3   = 1'b0;
    rd4   = 1'b0;  rd5   = 1'b0;  rd6   = 1'b0;  rd7   = 1'b0;
    wr0   = 1'b0;  wr1   = 1'b0;  wr2   = 1'b0;  wr3   = 1'b0;
    din0  = 16'd0; din1  = 16'd0; din2  = 16'd0; din3  = 16'd0;
    wdsn0 = 2'b11; wdsn1 = 2'b11; wdsn2 = 2'b11; wdsn3 = 2'b11;

    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    ack_before = ack_count;
    @(negedge clk);
    set_lane_addr(1, 22'd0);
    set_lane_addr(0, 22'd1);
    set_lane_rd(1, 1'b1);
    set_lane_rd(0, 1'b1);

    wait_lane_ok(0);
    assert_msg(ack_count == ack_before + 1, "lane0 should issue the first burst");
    assert_msg(ack_lane_log[ack_before] == 0, "lane0 must win simultaneous miss arbitration");
    assert_lane_word(0, 1);
    assert_msg(!lane_ok(1), "lane1 must still be pending while lane0 is first");

    @(negedge clk);
    set_lane_addr(0, 22'd4);
    repeat (4) @(posedge clk);
    assert_msg(lane_ok(0), "ok0 must stay high while rd0 is held");
    assert_msg(lane_dout(0) === expected_word(0, 1), "addr0 must stay latched until rd0 toggles");

    wait_lane_ok(1);
    assert_msg(ack_count == ack_before + 2, "lane1 should issue the second burst");
    assert_msg(ack_lane_log[ack_before + 1] == 1, "lane1 must run after lane0");
    assert_lane_word(1, 0);
    assert_msg(lane_ok(0), "lane0 ok must remain held while lane1 completes");

    ack_before = ack_count;
    @(negedge clk);
    set_lane_addr(4, 22'd2);
    set_lane_rd(4, 1'b1);

    wait_lane_ok(4);
    assert_msg(ack_lane_log[ack_before] == 4, "read-only lane must arbitrate correctly");
    assert_lane_word(4, 2);
    assert_msg(lane_ok(0), "lane0 ok must remain held while another lane completes");

    @(negedge clk);
    set_lane_rd(4, 1'b0);
    set_lane_rd(1, 1'b0);
    repeat (2) @(posedge clk);
    assert_msg(!lane_ok(1), "ok1 must clear once rd1 is released");
    assert_msg(lane_ok(0), "ok0 must remain set until rd0 is released");

    @(negedge clk);
    set_lane_rd(0, 1'b0);
    repeat (2) @(posedge clk);
    assert_msg(!lane_ok(0), "ok0 must clear once rd0 is released");

    ack_before = ack_count;
    @(negedge clk);
    set_lane_addr(0, 22'd4);
    set_lane_rd(0, 1'b1);

    wait_lane_ok(0);
    assert_lane_word(0, 4);
    assert_msg(ack_count == ack_before, "same-line hit must not start a new SDRAM burst");

    @(negedge clk);
    set_lane_rd(0, 1'b0);
    repeat (2) @(posedge clk);

    ack_before = ack_count;
    @(negedge clk);
    set_lane_addr(3, 22'd3);
    set_lane_rd(3, 1'b1);
    @(negedge clk);
    set_lane_rd(3, 1'b0);
    @(negedge clk);
    set_lane_addr(5, 22'd1);
    set_lane_rd(5, 1'b1);

    wait_lane_ok(5);
    assert_msg(ack_count == ack_before + 2, "dropped in-flight request must still complete before the next miss");
    assert_msg(ack_lane_log[ack_before] == 3, "lane3 must keep ownership after its request drops");
    assert_msg(ack_lane_log[ack_before + 1] == 5, "lane5 must wait until lane3 finishes");
    assert_lane_word(5, 1);

    @(negedge clk);
    set_lane_rd(5, 1'b0);
    repeat (4) @(posedge clk);

    pass();
end

endmodule
