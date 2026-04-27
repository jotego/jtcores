`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

localparam integer PERIOD        = 10;
localparam integer HF            = 1;
localparam integer SDRAM_AW      = 23;
localparam integer WORDS         = 8192;
localparam integer LOCAL_WORDS   = 64;
localparam integer STRESS_CYCLES = 2_000_000;
localparam integer OFFSET0_W     =    0;
localparam integer OFFSET1_W     = 1024;
localparam integer OFFSET2_W     = 2048;
localparam integer OFFSET3_W     = 3072;
localparam integer OFFSET4_W     = 4096;
localparam integer OFFSET5_W     = 5120;
localparam integer OFFSET6_W     = 6144;
localparam integer OFFSET7_W     = 7168;

reg                 rst;
reg                 clk;
reg                 clk_sdram;

reg  [22:1]         addr0, addr1, addr2, addr3, addr4, addr5;
reg  [22:3]         addr6;
reg  [22:4]         addr7;
reg                 rd0, rd1, rd2, rd3, rd4, rd5, rd6, rd7;
reg                 wr0, wr1, wr2, wr3;
reg  [15:0]         din0, din1, din2, din3;
reg  [ 1:0]         wdsn0, wdsn1, wdsn2, wdsn3;

wire [15:0]         dout0, dout1, dout2, dout3, dout4, dout5;
wire [63:0]         dout6;
wire [127:0]        dout7;
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
reg  [127:0]        lane_exp [0:7];
reg                 lane_pending [0:7];
reg                 lane_got_ok [0:7];
integer             lane_addr [0:7];
integer             lane_hold [0:7];
integer             lane_served [0:7];
reg  [15:0]         lfsr;
integer             hcnt;
integer             cycle;
integer             lane;
integer             idx;
reg                 burst_busy;

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
    .DW6      ( 64       ),
    .OFFSET6  ( OFFSET6_W ),
    .AW7      ( 23       ),
    .BLOCKS7  ( 1        ),
    .BLKSIZE7 ( 1024     ),
    .DW7      ( 128      ),
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

function automatic integer lane_offset(input integer n);
    begin
        case( n )
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
        pattern = (tmp * 16'h0013) ^ 16'h7c35;
    end
endfunction

function automatic integer lane_halfwords(input integer n);
    begin
        case( n )
            6: lane_halfwords = 4;
            7: lane_halfwords = 8;
            default: lane_halfwords = 1;
        endcase
    end
endfunction

function automatic [127:0] expected_word(input integer n, input integer local_addr);
    integer base;
    integer ofs;
    begin
        expected_word = 128'd0;
        base = lane_offset(n) + local_addr*lane_halfwords(n);
        for( ofs=0; ofs<lane_halfwords(n); ofs=ofs+1 ) begin
            expected_word[(ofs*16) +: 16] = exp_mem[base + ofs];
        end
    end
endfunction

function automatic lane_ok(input integer n);
    begin
        case( n )
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

function automatic [127:0] lane_dout(input integer n);
    begin
        case( n )
            0: lane_dout = { 112'd0, dout0 };
            1: lane_dout = { 112'd0, dout1 };
            2: lane_dout = { 112'd0, dout2 };
            3: lane_dout = { 112'd0, dout3 };
            4: lane_dout = { 112'd0, dout4 };
            5: lane_dout = { 112'd0, dout5 };
            6: lane_dout = {  64'd0, dout6 };
            default: lane_dout = dout7;
        endcase
    end
endfunction

task set_lane_addr(input integer n, input [22:1] value);
    begin
        case( n )
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

task set_lane_rd(input integer n, input value);
    begin
        case( n )
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

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 0;
        burst_busy <= 1'b0;
    end else begin
        hcnt <= hcnt == (64_000/PERIOD)-1 ? 0 : hcnt + 1;
        if( u_sdram_ctrl.rfshing && burst_busy && !sdram_rdy ) begin
            $display("Refresh overlapped an acknowledged burst");
            fail();
        end
        if( sdram_ack ) burst_busy <= 1'b1;
        if( sdram_rdy ) burst_busy <= 1'b0;
    end
end

initial begin
    for( idx=0; idx<WORDS; idx=idx+1 ) begin
        exp_mem[idx] = pattern(idx);
        u_sdram.Bank0[idx] = exp_mem[idx];
    end
    for( idx=0; idx<8; idx=idx+1 ) begin
        lane_pending[idx] = 1'b0;
        lane_got_ok[idx]  = 1'b0;
        lane_addr[idx]    = 0;
        lane_hold[idx]    = 0;
        lane_served[idx]  = 0;
        lane_exp[idx]     = 128'd0;
    end

    rst   = 1'b1;
    addr0 = 22'd0; addr1 = 22'd0; addr2 = 22'd0; addr3 = 22'd0;
    addr4 = 22'd0; addr5 = 22'd0; addr6 = 'd0;   addr7 = 'd0;
    rd0   = 1'b0;  rd1   = 1'b0;  rd2   = 1'b0;  rd3   = 1'b0;
    rd4   = 1'b0;  rd5   = 1'b0;  rd6   = 1'b0;  rd7   = 1'b0;
    wr0   = 1'b0;  wr1   = 1'b0;  wr2   = 1'b0;  wr3   = 1'b0;
    din0  = 16'd0; din1  = 16'd0; din2  = 16'd0; din3  = 16'd0;
    wdsn0 = 2'b11; wdsn1 = 2'b11; wdsn2 = 2'b11; wdsn3 = 2'b11;
    lfsr  = 16'h1;

    repeat (20) @(posedge clk);
    rst = 1'b0;
    wait_init_done();
    repeat (16) @(posedge clk);

    for( cycle=0; cycle<STRESS_CYCLES; cycle=cycle+1 ) begin
        @(posedge clk);
        lfsr <= { lfsr[14:0], lfsr[15]^lfsr[13]^lfsr[12]^lfsr[10] };
        for( lane=0; lane<8; lane=lane+1 ) begin
            if( lane_pending[lane] && lane_ok(lane) && !lane_got_ok[lane] ) begin
                if( lane_dout(lane) !== lane_exp[lane] ) begin
                    $display("Lane %0d mismatch at local addr %0d: got %h expected %h",
                        lane, lane_addr[lane], lane_dout(lane), lane_exp[lane]);
                    fail();
                end
                lane_got_ok[lane] = 1'b1;
                lane_hold[lane]   = { 1'b0, lfsr[lane], lfsr[lane+4] };
                lane_served[lane] = lane_served[lane] + 1;
            end
        end

        @(negedge clk);
        for( lane=0; lane<8; lane=lane+1 ) begin
            if( lane_pending[lane] ) begin
                if( lane_got_ok[lane] ) begin
                    if( lane_hold[lane] == 0 ) begin
                        set_lane_rd(lane, 1'b0);
                        lane_pending[lane] = 1'b0;
                        lane_got_ok[lane]  = 1'b0;
                    end else begin
                        lane_hold[lane] = lane_hold[lane] - 1;
                    end
                end
            end else if( !lane_ok(lane) &&
                          &{ lfsr[(lane+0)%16], lfsr[(lane+5)%16], lfsr[(lane+9)%16], lfsr[(lane+12)%16] } ) begin
                lane_addr[lane] = { lfsr[6:0] } % LOCAL_WORDS;
                lane_exp[lane]  = expected_word(lane, lane_addr[lane]);
                set_lane_addr(lane, lane_addr[lane]);
                set_lane_rd(lane, 1'b1);
                lane_pending[lane] = 1'b1;
                lane_got_ok[lane]  = 1'b0;
            end
        end
    end

    begin : drain_loop
        for( cycle=0; cycle<200_000; cycle=cycle+1 ) begin
            if( !lane_pending[0] && !lane_pending[1] && !lane_pending[2] && !lane_pending[3] &&
                !lane_pending[4] && !lane_pending[5] && !lane_pending[6] && !lane_pending[7] ) begin
                disable drain_loop;
            end
            @(posedge clk);
            for( lane=0; lane<8; lane=lane+1 ) begin
                if( lane_pending[lane] && lane_ok(lane) && !lane_got_ok[lane] ) begin
                    if( lane_dout(lane) !== lane_exp[lane] ) begin
                        $display("Lane %0d mismatch while draining: got %h expected %h",
                            lane, lane_dout(lane), lane_exp[lane]);
                        fail();
                    end
                    lane_got_ok[lane] = 1'b1;
                    lane_hold[lane]   = 0;
                    lane_served[lane] = lane_served[lane] + 1;
                end
            end
            @(negedge clk);
            for( lane=0; lane<8; lane=lane+1 ) begin
                if( lane_pending[lane] && lane_got_ok[lane] ) begin
                    set_lane_rd(lane, 1'b0);
                    lane_pending[lane] = 1'b0;
                    lane_got_ok[lane]  = 1'b0;
                end
            end
        end
        $display("Timed out draining pending stress requests");
        fail();
    end

    for( lane=0; lane<8; lane=lane+1 ) begin
        assert_msg(lane_served[lane] > 0, "Every lane must complete at least one request");
    end

    pass();
end

endmodule
