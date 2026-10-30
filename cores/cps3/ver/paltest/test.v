`timescale 1ns / 1ps

module test(
    input               clk,
    input               clk_sdram,
    input               rst,

    input       [31:0]  paldma_src,
    input       [16:0]  paldma_dst,
    input       [31:0]  paldma_fade,
    input       [15:0]  paldma_len,
    input               paldma_len_hi,
    input               paldma_go,

    input       [17:1]  pal_rd_addr,
    output      [15:0]  pal_rd_data,

    output              paldma_busy,
    output              paldma_done,
    output              init,
    output              dbg_src_rd,
    output      [25:1]  dbg_src_addr,
    output      [15:0]  dbg_src_dout,
    output              dbg_src_ok,

    inout       [15:0]  sdram_dq,
    output      [15:0]  sdram_din,
    output      [12:0]  sdram_a,
    output      [ 1:0]  sdram_dqm,
    output      [ 1:0]  sdram_ba,
    output              sdram_nwe,
    output              sdram_ncas,
    output              sdram_nras,
    output              sdram_ncs,
    output              sdram_cke
);

localparam integer SDRAMW        = 24;
localparam integer CACHE_AW      = 26;
localparam integer BURST_AW      = SDRAMW-1;
localparam [12:0]  REFRESH_LAST = 13'd6399;

wire        src_rd;
wire [25:1] src_addr;
wire [15:0] src_dout;
wire        src_ok;

wire [17:1] dst_addr;
wire [15:0] dst_din;
wire [ 1:0] dst_we;

wire [BURST_AW-1:0] ext_addr;
wire [ 1:0] ext_ba;
wire [15:0] ext_din;
wire [15:0] ext_dout;
wire        ext_rd;
wire        ext_wr;
wire        ext_ack;
wire        ext_dst;
wire        ext_dok;
wire        ext_rdy;
wire [15:0] dummy_dout1, dummy_dout2, dummy_dout3;
wire [15:0] dummy_dout4, dummy_dout5, dummy_dout6, dummy_dout7;
wire        dummy_ok1, dummy_ok2, dummy_ok3;
wire        dummy_ok4, dummy_ok5, dummy_ok6, dummy_ok7;

reg  [12:0] hcnt;
wire        rfsh = hcnt == 13'd0;

assign dbg_src_rd   = src_rd;
assign dbg_src_addr = src_addr;
assign dbg_src_dout = src_dout;
assign dbg_src_ok   = src_ok;

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 13'd0;
    end else if( hcnt == REFRESH_LAST ) begin
        hcnt <= 13'd0;
    end else begin
        hcnt <= hcnt + 13'd1;
    end
end

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAMW    ),
    .ENDIAN   ( 0        ),
    .FULL0    ( 1        ),
    .AW0      ( CACHE_AW ),
    .BLOCKS0  ( 2        ),
    .BLKSIZE0 ( 512      ),
    .DW0      ( 16       ),
    .FULL1    ( 1        ),
    .AW1      ( CACHE_AW ),
    .BLOCKS1  ( 1        ),
    .BLKSIZE1 ( 32       ),
    .DW1      ( 16       ),
    .FULL2    ( 1        ),
    .AW2      ( CACHE_AW ),
    .BLOCKS2  ( 1        ),
    .BLKSIZE2 ( 32       ),
    .DW2      ( 16       ),
    .FULL3    ( 1        ),
    .AW3      ( CACHE_AW ),
    .BLOCKS3  ( 1        ),
    .BLKSIZE3 ( 32       ),
    .DW3      ( 16       ),
    .FULL4    ( 1        ),
    .AW4      ( CACHE_AW ),
    .BLOCKS4  ( 1        ),
    .BLKSIZE4 ( 32       ),
    .DW4      ( 16       ),
    .FULL5    ( 1        ),
    .AW5      ( CACHE_AW ),
    .BLOCKS5  ( 1        ),
    .BLKSIZE5 ( 32       ),
    .DW5      ( 16       ),
    .FULL6    ( 1        ),
    .AW6      ( CACHE_AW ),
    .BLOCKS6  ( 1        ),
    .BLKSIZE6 ( 32       ),
    .DW6      ( 16       ),
    .FULL7    ( 1        ),
    .AW7      ( CACHE_AW ),
    .BLOCKS7  ( 1        ),
    .BLKSIZE7 ( 32       ),
    .DW7      ( 16       )
) u_cache(
    .rst    ( rst         ),
    .clk    ( clk         ),

    .addr0  ( src_addr    ),
    .dout0  ( src_dout    ),
    .rd0    ( src_rd      ),
    .wr0    ( 1'b0        ),
    .din0   ( 16'd0       ),
    .wdsn0  ( 2'b00       ),
    .ok0    ( src_ok      ),

    .addr1  ( {(CACHE_AW-1){1'b0}} ),
    .dout1  ( dummy_dout1 ),
    .rd1    ( 1'b0        ),
    .wr1    ( 1'b0        ),
    .din1   ( 16'd0       ),
    .wdsn1  ( 2'b00       ),
    .ok1    ( dummy_ok1   ),

    .addr2  ( {(CACHE_AW-1){1'b0}} ),
    .dout2  ( dummy_dout2 ),
    .rd2    ( 1'b0        ),
    .wr2    ( 1'b0        ),
    .din2   ( 16'd0       ),
    .wdsn2  ( 2'b00       ),
    .ok2    ( dummy_ok2   ),

    .addr3  ( {(CACHE_AW-1){1'b0}} ),
    .dout3  ( dummy_dout3 ),
    .rd3    ( 1'b0        ),
    .wr3    ( 1'b0        ),
    .din3   ( 16'd0       ),
    .wdsn3  ( 2'b00       ),
    .ok3    ( dummy_ok3   ),

    .addr4  ( {(CACHE_AW-1){1'b0}} ),
    .dout4  ( dummy_dout4 ),
    .rd4    ( 1'b0        ),
    .ok4    ( dummy_ok4   ),

    .addr5  ( {(CACHE_AW-1){1'b0}} ),
    .dout5  ( dummy_dout5 ),
    .rd5    ( 1'b0        ),
    .ok5    ( dummy_ok5   ),

    .addr6  ( {(CACHE_AW-1){1'b0}} ),
    .dout6  ( dummy_dout6 ),
    .rd6    ( 1'b0        ),
    .ok6    ( dummy_ok6   ),

    .addr7  ( {(CACHE_AW-1){1'b0}} ),
    .dout7  ( dummy_dout7 ),
    .rd7    ( 1'b0        ),
    .ok7    ( dummy_ok7   ),
    .flush0 ( 1'b0        ),
    .flush1 ( 1'b0        ),
    .flush2 ( 1'b0        ),
    .flush3 ( 1'b0        ),
    .flush4 ( 1'b0        ),
    .flush5 ( 1'b0        ),
    .flush6 ( 1'b0        ),
    .flush7 ( 1'b0        ),
    .flushing0   (         ),
    .flush_done0 (         ),
    .flushing1   (         ),
    .flush_done1 (         ),
    .flushing2   (         ),
    .flush_done2 (         ),
    .flushing3   (         ),
    .flush_done3 (         ),
    .flushing4   (         ),
    .flush_done4 (         ),
    .flushing5   (         ),
    .flush_done5 (         ),
    .flushing6   (         ),
    .flush_done6 (         ),
    .flushing7   (         ),
    .flush_done7 (         ),

    .addr   ( ext_addr    ),
    .ba     ( ext_ba      ),
    .rd     ( ext_rd      ),
    .wr     ( ext_wr      ),
    .din    ( ext_din     ),
    .dout   ( ext_dout    ),
    .ack    ( ext_ack     ),
    .dst    ( ext_dst     ),
    .dok    ( ext_dok     ),
    .rdy    ( ext_rdy     )
);

jtframe_burst_sdram #(
    .AW      ( BURST_AW ),
    .HF      ( 1        ),
    .MISTER  ( 0        ),
    .PROG_LEN( 64       )
) u_sdram_ctrl (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( ext_addr     ),
    .ba         ( ext_ba       ),
    .rd         ( ext_rd       ),
    .wr         ( ext_wr       ),
    .din        ( ext_dout     ),
    .dout       ( ext_din      ),
    .ack        ( ext_ack      ),
    .dst        ( ext_dst      ),
    .dok        ( ext_dok      ),
    .rdy        ( ext_rdy      ),
    .prog_en    ( 1'b0         ),
    .prog_addr  ( {BURST_AW{1'b0}} ),
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
    .sdram_din  ( sdram_din    ),
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

jtframe_dual_ram16 #(
    .AW      ( 17 ),
    .SIMFILE ( "" )
) u_pal (
    .clk0    ( clk         ),
    .addr0   ( dst_addr    ),
    .data0   ( dst_din     ),
    .we0     ( dst_we      ),
    .q0      (             ),
    .clk1    ( clk         ),
    .addr1   ( pal_rd_addr ),
    .data1   ( 16'd0       ),
    .we1     ( 2'b00       ),
    .q1      ( pal_rd_data )
);

jtcps3_paldma u_paldma(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .src        ( paldma_src    ),
    .dst        ( paldma_dst    ),
    .fade       ( paldma_fade   ),
    .len        ( paldma_len    ),
    .len_hi     ( paldma_len_hi ),
    .go         ( paldma_go     ),
    .src_rd     ( src_rd        ),
    .src_addr   ( src_addr      ),
    .src_dout   ( src_dout      ),
    .src_ok     ( src_ok        ),
    .dst_addr   ( dst_addr      ),
    .dst_din    ( dst_din       ),
    .dst_we     ( dst_we        ),
    .busy       ( paldma_busy   ),
    .done       ( paldma_done   )
);

endmodule
