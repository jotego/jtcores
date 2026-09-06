`timescale 1ns / 1ps

module test(
    input               clk,
    input               clk_sdram,
    input               rst,
    input               core_rst,

    input       [15:0]  chardma_src_lo,
    input       [ 5:0]  chardma_src_hi,
    input               chardma_go,

    input               verify_rd,
    input               verify_gfx_rd,
    input               verify_wr,
    input       [22:2]  verify_addr,
    input       [31:0]  verify_din,
    input       [ 3:0]  verify_dsn,
    output      [31:0]  verify_data,
    output              verify_ok,

    output              dma_busy,
    output              dma_done,
    output              init,

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
localparam integer BURST_AW      = SDRAMW-1;
localparam [22:0]  TILES         = 23'h2_00000;
localparam [12:0]  REFRESH_LAST  = 13'd6399;

wire        zipchar_rd;
wire [25:2] zipchar_addr;
wire [31:0] zipchar_data;
wire        zipchar_ok;

wire        tiles_rd;
wire [22:2] tiles_addr;
wire        tiles_we;
wire [31:0] tiles_din;
wire [ 3:0] tiles_dsn;
wire [31:0] tiles_data;
wire        tiles_ok;
wire [31:0] cache_tiles_wr_data;
wire        cache_tiles_wr_ok;
wire [127:0] cache_tiles_data;
wire        cache_tiles_ok;
wire        chardma_busy_raw, chardma_done_raw;
wire        tiles_wr_flushing, tiles_wr_flush_done;
reg         tiles_wr_flush, chardma_flush_pending;

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

wire [31:0] dummy_dout0, dummy_dout4, dummy_dout5;
wire [ 7:0] dummy_dout6, dummy_dout7;
wire        dummy_ok0, dummy_ok4, dummy_ok5, dummy_ok6, dummy_ok7;

reg  [12:0] hcnt;
wire        rfsh = hcnt == 13'd0;
wire        verify_tiles_wr_req = verify_rd | verify_wr;
wire [31:0] verify_gfx_word =
    verify_addr[3:2] == 2'd0 ? cache_tiles_data[ 31: 0] :
    verify_addr[3:2] == 2'd1 ? cache_tiles_data[ 63:32] :
    verify_addr[3:2] == 2'd2 ? cache_tiles_data[ 95:64] :
                                cache_tiles_data[127:96];

assign verify_data      = verify_gfx_rd ? verify_gfx_word : cache_tiles_wr_data;
assign verify_ok        = verify_gfx_rd ? cache_tiles_ok :
                          verify_tiles_wr_req & cache_tiles_wr_ok;
assign dma_busy         = chardma_busy_raw | chardma_flush_pending | tiles_wr_flushing;
assign dma_done         = chardma_flush_pending & tiles_wr_flush_done;

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        hcnt <= 13'd0;
    end else if( hcnt == REFRESH_LAST ) begin
        hcnt <= 13'd0;
    end else begin
        hcnt <= hcnt + 13'd1;
    end
end

always @(posedge clk or posedge rst) begin
    if( rst ) begin
        tiles_wr_flush         <= 1'b0;
        chardma_flush_pending  <= 1'b0;
    end else begin
        tiles_wr_flush <= 1'b0;
        if( chardma_done_raw ) begin
            tiles_wr_flush        <= 1'b1;
            chardma_flush_pending <= 1'b1;
        end else if( tiles_wr_flush_done ) begin
            chardma_flush_pending <= 1'b0;
        end
    end
end

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAMW    ),
    .ENDIAN   ( 0         ),
    .ENDIAN0  ( 1         ),
    .FULL0    ( 0         ),
    .AW0      ( 24        ),
    .BLOCKS0  ( 64        ),
    .BLKSIZE0 ( 256       ),
    .DW0      ( 32        ),
    .BA0      ( 0         ),
    .OFFSET0  ( 0         ),
    .INVAL_MASK0 ( 8'b00110000 ),
    .ENDIAN1  ( 1         ),
    .FULL1    ( 1         ),
    .AW1      ( 26        ),
    .BLOCKS1  ( 1         ),
    .BLKSIZE1 ( 512       ),
    .DW1      ( 32        ),
    .BA1      ( 0         ),
    .OFFSET1  ( 0         ),
    .INVAL_MASK1 ( 8'b00000000 ),
    .ENDIAN2  ( 1         ),
    .FULL2    ( 0         ),
    .AW2      ( 23        ),
    .BLOCKS2  ( 4         ),
    .BLKSIZE2 ( 512       ),
    .DW2      ( 32        ),
    .BA2      ( 3         ),
    .OFFSET2  ( TILES     ),
    .INVAL_MASK2 ( 8'b00001000 ),
    .ENDIAN3  ( 0         ),
    .FULL3    ( 0         ),
    .AW3      ( 23        ),
    .BLOCKS3  ( 512       ),
    .BLKSIZE3 ( 128       ),
    .DW3      ( 128       ),
    .BA3      ( 3         ),
    .OFFSET3  ( TILES     ),
    .INVAL_MASK3 ( 8'b00000000 ),
    .ENDIAN4  ( 1         ),
    .FULL4    ( 0         ),
    .AW4      ( 19        ),
    .BLOCKS4  ( 1         ),
    .BLKSIZE4 ( 1024      ),
    .DW4      ( 32        ),
    .BA4      ( 0         ),
    .OFFSET4  ( 23'h4_40000 ),
    .INVAL_MASK4 ( 8'b00000000 ),
    .ENDIAN5  ( 1         ),
    .FULL5    ( 0         ),
    .AW5      ( 19        ),
    .BLOCKS5  ( 8         ),
    .BLKSIZE5 ( 1024      ),
    .DW5      ( 32        ),
    .BA5      ( 0         ),
    .OFFSET5  ( 23'h4_40000 ),
    .INVAL_MASK5 ( 8'b00000000 ),
    .ENDIAN6  ( 0         ),
    .FULL6    ( 0         ),
    .AW6      ( 24        ),
    .BLOCKS6  ( 32        ),
    .BLKSIZE6 ( 32        ),
    .DW6      ( 8         ),
    .BA6      ( 1         ),
    .OFFSET6  ( 0         ),
    .INVAL_MASK6 ( 8'b00000000 )
) u_cache(
    .rst    ( rst             ),
    .clk    ( clk             ),

    .addr0  ( 22'd0           ),
    .dout0  ( dummy_dout0     ),
    .rd0    ( 1'b0            ),
    .wr0    ( 1'b0            ),
    .din0   ( 32'd0           ),
    .wdsn0  ( 4'b0000         ),
    .ok0    ( dummy_ok0       ),

    .addr1  ( zipchar_addr    ),
    .dout1  ( zipchar_data    ),
    .rd1    ( zipchar_rd      ),
    .wr1    ( 1'b0            ),
    .din1   ( 32'd0           ),
    .wdsn1  ( 4'b0000         ),
    .ok1    ( zipchar_ok      ),

    .addr2  ( verify_tiles_wr_req ? verify_addr : tiles_addr ),
    .dout2  ( cache_tiles_wr_data ),
    .rd2    ( verify_rd | (~verify_wr & tiles_rd & ~tiles_we) ),
    .wr2    ( verify_wr | (~verify_rd & tiles_rd & tiles_we) ),
    .din2   ( verify_wr ? verify_din : tiles_din ),
    .wdsn2  ( verify_wr ? verify_dsn : tiles_dsn ),
    .ok2    ( cache_tiles_wr_ok ),

    .addr3  ( verify_addr[22:4] ),
    .dout3  ( cache_tiles_data ),
    .rd3    ( verify_gfx_rd   ),
    .wr3    ( 1'b0            ),
    .din3   ( 128'd0          ),
    .wdsn3  ( 16'd0           ),
    .ok3    ( cache_tiles_ok  ),

    .addr4  ( 17'd0           ),
    .dout4  ( dummy_dout4     ),
    .rd4    ( 1'b0            ),
    .ok4    ( dummy_ok4       ),

    .addr5  ( 17'd0           ),
    .dout5  ( dummy_dout5     ),
    .rd5    ( 1'b0            ),
    .ok5    ( dummy_ok5       ),

    .addr6  ( 24'd0           ),
    .dout6  ( dummy_dout6     ),
    .rd6    ( 1'b0            ),
    .ok6    ( dummy_ok6       ),

    .addr7  ( 23'd0           ),
    .dout7  ( dummy_dout7     ),
    .rd7    ( 1'b0            ),
    .ok7    ( dummy_ok7       ),
    .flush0 ( 1'b0            ),
    .flush1 ( 1'b0            ),
    .flush2 ( tiles_wr_flush  ),
    .flush3 ( 1'b0            ),
    .flush4 ( 1'b0            ),
    .flush5 ( 1'b0            ),
    .flush6 ( 1'b0            ),
    .flush7 ( 1'b0            ),
    .flushing0   (             ),
    .flush_done0 (             ),
    .flushing1   (             ),
    .flush_done1 (             ),
    .flushing2   ( tiles_wr_flushing ),
    .flush_done2 ( tiles_wr_flush_done ),
    .flushing3   (             ),
    .flush_done3 (             ),
    .flushing4   (             ),
    .flush_done4 (             ),
    .flushing5   (             ),
    .flush_done5 (             ),
    .flushing6   (             ),
    .flush_done6 (             ),
    .flushing7   (             ),
    .flush_done7 (             ),

    .addr   ( ext_addr        ),
    .ba     ( ext_ba          ),
    .rd     ( ext_rd          ),
    .wr     ( ext_wr          ),
    .din    ( ext_din         ),
    .dout   ( ext_dout        ),
    .ack    ( ext_ack         ),
    .dst    ( ext_dst         ),
    .dok    ( ext_dok         ),
    .rdy    ( ext_rdy         )
);

// Match the pixel halfword order seen by the full core before chardma decodes
// command-list words from the tiles_wr lane.
assign tiles_data = { cache_tiles_wr_data[15: 8], cache_tiles_wr_data[ 7: 0],
                      cache_tiles_wr_data[31:24], cache_tiles_wr_data[23:16] };
assign tiles_ok   = ~verify_tiles_wr_req & cache_tiles_wr_ok;

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

jtcps3_chardma #(
    .DMA_XOR_K  ( 2'd0 )
) u_dma(
    .rst            ( rst | core_rst ),
    .clk            ( clk            ),
    .chardma_src_lo ( chardma_src_lo ),
    .chardma_src_hi ( chardma_src_hi ),
    .chardma_go     ( chardma_go     ),
    .zipchar_ok     ( zipchar_ok     ),
    .zipchar_data   ( zipchar_data   ),
    .zipchar_addr   ( zipchar_addr   ),
    .zipchar_rd     ( zipchar_rd     ),
    .tiles_ok       ( tiles_ok       ),
    .tiles_data     ( tiles_data     ),
    .tiles_rd       ( tiles_rd       ),
    .tiles_addr     ( tiles_addr     ),
    .tiles_we       ( tiles_we       ),
    .tiles_din      ( tiles_din      ),
    .tiles_dsn      ( tiles_dsn      ),
    .busy           ( chardma_busy_raw ),
    .done           ( chardma_done_raw )
);

endmodule
