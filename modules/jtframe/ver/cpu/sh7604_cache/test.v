`timescale 1ns / 1ps

module test(
    input               clk,
    input               clk_sdram,
    input               rst,

    input       [31:0]  cpu_din_ext,
    output      [31:0]  cpu_dout,
    output      [26:0]  A,
    output              BS_N,
    output              CS0_N,
    output              CS1_N,
    output              CS2_N,
    output              CS3_N,
    output              RD_WR_N,
    output              CE_N,
    output              OE_N,
    output      [3:0]   WE_N,
    output              RD_N,
    output              IVECF_N,
    output              RFS,
    output              BGR_N,
    output              WAIT_N,

    output              cache_cs,
    output              cache_we,
    output              cache_rd,
    output              cache_wr,
    output      [26:1]  cache_addr,
    output      [31:0]  cache_din,
    output      [3:0]   cache_dsn,
    output      [31:0]  cache_dout,
    output              cache_ok,

    output reg          ce_r,
    output reg          ce_f,
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

localparam integer SDRAMW   = 24;
localparam integer CACHE_AW = 24;
localparam integer BURST_AW = SDRAMW - 1;
localparam [12:0]  REFRESH_LAST = 13'd6399;

wire [26:0] cpu_a;
wire [31:0] cpu_do;
wire [31:0] cache_dout0;
wire        cache_ok_mux;
wire        cache_area0 = cpu_a[26:25] == 2'b00;
wire [31:0] dummy_dout1, dummy_dout2, dummy_dout3;
wire [31:0] dummy_dout4, dummy_dout5, dummy_dout6, dummy_dout7;
wire        dummy_ok1, dummy_ok2, dummy_ok3;
wire        dummy_ok4, dummy_ok5, dummy_ok6, dummy_ok7;
wire        ext_dst;
wire        ext_dok;
wire        ext_rdy;
wire [BURST_AW-1:0] ext_addr;
wire [ 1:0] ext_ba;
wire [15:0] ext_din;
wire [15:0] ext_dout;
wire        ext_rd;
wire        ext_wr;
wire        ext_ack;
wire        ext_dummy_dst;
wire        ext_dummy_dok;
wire        ext_dummy_rdy;
reg  [31:0] cache_dout_latch;
reg         cache_ok_latch;

reg         ce_phase;
reg  [12:0] hcnt;

wire        rfsh = hcnt == 13'd0;
wire        cache_req_area0 = cache_addr[26:25] == 2'b00;
wire        cache_rd_area0 = cache_rd & cache_req_area0;
wire        cache_wr_area0 = cache_wr & cache_req_area0;
wire        cpu_bus_area0 = cache_cs ? cache_req_area0 : cache_area0;
wire [31:0] cpu_din_i = cpu_bus_area0 ? cache_dout_latch : cpu_din_ext;
wire        cpu_cache_ok = cpu_bus_area0 ? cache_ok_latch : 1'b1;

assign cache_dout = cache_dout0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ce_phase  <= 1'b0;
        ce_r      <= 1'b0;
        ce_f      <= 1'b0;
        hcnt      <= 13'd0;
        cache_dout_latch <= 32'd0;
        cache_ok_latch <= 1'b0;
    end else begin
        ce_r <= !ce_phase;
        ce_f <=  ce_phase;
        ce_phase <= ~ce_phase;
        cache_ok_latch <= cache_ok_mux;
        if (cache_ok_mux) begin
            cache_dout_latch <= cache_dout0;
        end
        if (hcnt == REFRESH_LAST) begin
            hcnt <= 13'd0;
        end else begin
            hcnt <= hcnt + 13'd1;
        end
    end
end

jtsh7604 u_cpu(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .ce_r       ( ce_r        ),
    .ce_f       ( ce_f        ),
    .nmi_n      ( 1'b1        ),
    .irl_n      ( 4'hf        ),
    .cpu_din    ( cpu_din_i   ),
    .cps3_key1  ( 32'd0       ),
    .cps3_key2  ( 32'd0       ),
    .cache_ok   ( cpu_cache_ok ),

    .A          ( cpu_a       ),
    .cpu_dout   ( cpu_do      ),
    .BS_N       ( BS_N        ),
    .CS0_N      ( CS0_N       ),
    .CS1_N      ( CS1_N       ),
    .CS2_N      ( CS2_N       ),
    .CS3_N      ( CS3_N       ),
    .RD_WR_N    ( RD_WR_N     ),
    .CE_N       ( CE_N        ),
    .OE_N       ( OE_N        ),
    .WE_N       ( WE_N        ),
    .RD_N       ( RD_N        ),
    .IVECF_N    ( IVECF_N     ),
    .RFS        ( RFS         ),
    .BGR_N      ( BGR_N       ),
    .WAIT_N     ( WAIT_N      ),

    .cache_cs   ( cache_cs    ),
    .cache_we   ( cache_we    ),
    .cache_rd   ( cache_rd    ),
    .cache_wr   ( cache_wr    ),
    .cache_addr ( cache_addr  ),
    .cache_din  ( cache_din   ),
    .cache_dsn  ( cache_dsn   )
);

assign A        = cpu_a;
assign cpu_dout = cpu_do;
assign cache_ok  = cpu_cache_ok;

jtframe_cache_mux #(
    .SDRAM_AW ( SDRAMW ),
    .ENDIAN   ( 0      ),
    .AW0      ( CACHE_AW ),
    .ENDIAN0  ( 1      ),
    .FULL0    ( 1      ),
    .BLOCKS0  ( 1      ),
    .BLKSIZE0 ( 16     ),
    .DW0      ( 32     ),
    .FULL1    ( 0      ),
    .AW1      ( CACHE_AW ),
    .BLOCKS1  ( 1      ),
    .BLKSIZE1 ( 32     ),
    .DW1      ( 16     ),
    .FULL2    ( 0      ),
    .AW2      ( CACHE_AW ),
    .BLOCKS2  ( 1      ),
    .BLKSIZE2 ( 32     ),
    .DW2      ( 16     ),
    .FULL3    ( 0      ),
    .AW3      ( CACHE_AW ),
    .BLOCKS3  ( 1      ),
    .BLKSIZE3 ( 32     ),
    .DW3      ( 16     ),
    .FULL4    ( 0      ),
    .AW4      ( CACHE_AW ),
    .BLOCKS4  ( 1      ),
    .BLKSIZE4 ( 32     ),
    .DW4      ( 16     ),
    .FULL5    ( 0      ),
    .AW5      ( CACHE_AW ),
    .BLOCKS5  ( 1      ),
    .BLKSIZE5 ( 32     ),
    .DW5      ( 16     ),
    .FULL6    ( 0      ),
    .AW6      ( CACHE_AW ),
    .BLOCKS6  ( 1      ),
    .BLKSIZE6 ( 32     ),
    .DW6      ( 16     ),
    .FULL7    ( 0      ),
    .AW7      ( CACHE_AW ),
    .BLOCKS7  ( 1      ),
    .BLKSIZE7 ( 32     ),
    .DW7      ( 16     )
) u_cache(
    .rst    ( rst          ),
    .clk    ( clk          ),

    .addr0  ( cache_addr[23:2] ),
    .dout0  ( cache_dout0  ),
    .rd0    ( cache_rd_area0 ),
    .wr0    ( cache_wr_area0 ),
    .din0   ( cache_din    ),
    .wdsn0  ( cache_dsn    ),
    .ok0    ( cache_ok_mux  ),

    .addr1  ( {CACHE_AW{1'b0}} ),
    .dout1  ( dummy_dout1  ),
    .rd1    ( 1'b0         ),
    .wr1    ( 1'b0         ),
    .din1   ( 16'd0        ),
    .wdsn1  ( 2'b00        ),
    .ok1    ( dummy_ok1    ),

    .addr2  ( {CACHE_AW{1'b0}} ),
    .dout2  ( dummy_dout2  ),
    .rd2    ( 1'b0         ),
    .wr2    ( 1'b0         ),
    .din2   ( 16'd0        ),
    .wdsn2  ( 2'b00        ),
    .ok2    ( dummy_ok2    ),

    .addr3  ( {CACHE_AW{1'b0}} ),
    .dout3  ( dummy_dout3  ),
    .rd3    ( 1'b0         ),
    .wr3    ( 1'b0         ),
    .din3   ( 16'd0        ),
    .wdsn3  ( 2'b00        ),
    .ok3    ( dummy_ok3    ),

    .addr4  ( {CACHE_AW{1'b0}} ),
    .dout4  ( dummy_dout4  ),
    .rd4    ( 1'b0         ),
    .ok4    ( dummy_ok4    ),

    .addr5  ( {CACHE_AW{1'b0}} ),
    .dout5  ( dummy_dout5  ),
    .rd5    ( 1'b0         ),
    .ok5    ( dummy_ok5    ),

    .addr6  ( {CACHE_AW{1'b0}} ),
    .dout6  ( dummy_dout6  ),
    .rd6    ( 1'b0         ),
    .ok6    ( dummy_ok6    ),

    .addr7  ( {CACHE_AW{1'b0}} ),
    .dout7  ( dummy_dout7  ),
    .rd7    ( 1'b0         ),
    .ok7    ( dummy_ok7    ),
    .flush0 ( 1'b0         ),
    .flush1 ( 1'b0         ),
    .flush2 ( 1'b0         ),
    .flush3 ( 1'b0         ),
    .flush4 ( 1'b0         ),
    .flush5 ( 1'b0         ),
    .flush6 ( 1'b0         ),
    .flush7 ( 1'b0         ),
    .flushing0   (          ),
    .flush_done0 (          ),
    .flushing1   (          ),
    .flush_done1 (          ),
    .flushing2   (          ),
    .flush_done2 (          ),
    .flushing3   (          ),
    .flush_done3 (          ),
    .flushing4   (          ),
    .flush_done4 (          ),
    .flushing5   (          ),
    .flush_done5 (          ),
    .flushing6   (          ),
    .flush_done6 (          ),
    .flushing7   (          ),
    .flush_done7 (          ),

    .addr   ( ext_addr     ),
    .ba     ( ext_ba       ),
    .rd     ( ext_rd       ),
    .wr     ( ext_wr       ),
    .din    ( ext_dout     ),
    .dout   ( ext_din      ),
    .ack    ( ext_ack      ),
    .dst    ( ext_dst      ),
    .dok    ( ext_dok      ),
    .rdy    ( ext_rdy      )
);

jtframe_burst_sdram #(
    .AW       ( BURST_AW ),
    .HF       ( 1        ),
    .MISTER   ( 0        ),
    .PROG_LEN ( 64       )
) u_sdram_ctrl (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .init       ( init         ),
    .addr       ( ext_addr     ),
    .ba         ( ext_ba       ),
    .rd         ( ext_rd       ),
    .wr         ( ext_wr       ),
    .din        ( ext_din      ),
    .dout       ( ext_dout     ),
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
    .prog_dst   ( ext_dummy_dst ),
    .prog_dok   ( ext_dummy_dok ),
    .prog_rdy   ( ext_dummy_rdy ),
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

`ifdef SIMULATION
reg        cache_cs_l;
reg [26:1] cache_addr_l;
reg [31:0] cache_din_l;
reg [ 3:0] cache_dsn_l;
reg        cache_wr_l;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cache_cs_l   <= 1'b0;
        cache_addr_l <= '0;
        cache_din_l  <= '0;
        cache_dsn_l  <= 4'hf;
        cache_wr_l   <= 1'b0;
    end else begin
        cache_cs_l <= cache_cs;
        if (cache_cs && !cache_cs_l) begin
            if (cache_addr != cpu_a[26:1] || cache_din != cpu_do ||
                cache_dsn != WE_N || cache_wr != !RD_WR_N) begin
                $display("ERROR: cache bus does not match native SH7604 bus");
                $finish;
            end
            cache_addr_l <= cache_addr;
            cache_din_l  <= cache_din;
            cache_dsn_l  <= cache_dsn;
            cache_wr_l   <= cache_wr;
        end else if (cache_cs && !cache_ok) begin
            if (cache_addr != cache_addr_l || cache_din != cache_din_l ||
                cache_dsn != cache_dsn_l || cache_wr != cache_wr_l) begin
                $display("ERROR: cache request changed before acknowledge");
                $finish;
            end
        end
    end
end
`endif

endmodule
