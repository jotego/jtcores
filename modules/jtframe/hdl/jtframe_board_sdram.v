/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 20-3-2026 */

`ifndef JTFRAME_180SHIFT
`define JTFRAME_180SHIFT 0
`endif

`ifndef JTFRAME_SHIFT
`define JTFRAME_SHIFT 0
`endif

`ifndef JTFRAME_RFSH_WC
`define JTFRAME_RFSH_WC 11
`endif

`ifndef JTFRAME_RFSH_N
`define JTFRAME_RFSH_N 11'd1
`endif

`ifndef JTFRAME_RFSH_M
`define JTFRAME_RFSH_M 11'd1536
`endif

module jtframe_board_sdram #(
    parameter SDRAMW = 22,
              MISTER = 1
)(
    input                   rst,
    input                   clk,
    output                  init,
    input                   prog_en,

    input      [SDRAMW-1:0] ba0_addr,
    input      [SDRAMW-1:0] ba1_addr,
    input      [SDRAMW-1:0] ba2_addr,
    input      [SDRAMW-1:0] ba3_addr,
    input      [SDRAMW-1:0] burst_addr,
    input             [1:0] burst_ba,
    input                   burst_rd,
    input                   burst_wr,
    input             [3:0] ba_rd,
    input             [3:0] ba_wr,
    input            [15:0] ba0_din,
    input             [1:0] ba0_dsn,
    input            [15:0] ba1_din,
    input             [1:0] ba1_dsn,
    input            [15:0] ba2_din,
    input             [1:0] ba2_dsn,
    input            [15:0] ba3_din,
    input             [1:0] ba3_dsn,
    input            [15:0] burst_din,
    output                  burst_ack,
    output                  burst_rdy,
    output                  burst_dst,
    output                  burst_dok,
    output            [3:0] ba_ack,
    output            [3:0] ba_rdy,
    output            [3:0] ba_dst,
    output            [3:0] ba_dok,
    output           [15:0] dout,

    input      [SDRAMW-1:0] prog_addr,
    input            [15:0] prog_data,
    input             [1:0] prog_dsn,
    input             [1:0] prog_ba,
    input                   prog_we,
    input                   prog_rd,
    output                  prog_dok,
    output                  prog_rdy,
    output                  prog_dst,
    output                  prog_ack,

    inout           [15:0]  sdram_dq,
`ifdef VERILATOR
    output          [15:0]  din,
`endif
    output          [12:0]  sdram_a,
    output                  sdram_dqml,
    output                  sdram_dqmh,
    output                  sdram_nwe,
    output                  sdram_ncas,
    output                  sdram_nras,
    output                  sdram_ncs,
    output           [1:0]  sdram_ba,
    output                  sdram_cke
);

`ifdef JTFRAME_BA0_AUTOPRECH
    localparam BA0_AUTOPRECH = `JTFRAME_BA0_AUTOPRECH;
`else
    localparam BA0_AUTOPRECH = 0;
`endif

`ifdef JTFRAME_BA1_AUTOPRECH
    localparam BA1_AUTOPRECH = `JTFRAME_BA1_AUTOPRECH;
`else
    localparam BA1_AUTOPRECH = 0;
`endif

`ifdef JTFRAME_BA2_AUTOPRECH
    localparam BA2_AUTOPRECH = `JTFRAME_BA2_AUTOPRECH;
`else
    localparam BA2_AUTOPRECH = 0;
`endif

`ifdef JTFRAME_BA3_AUTOPRECH
    localparam BA3_AUTOPRECH = `JTFRAME_BA3_AUTOPRECH;
`else
    localparam BA3_AUTOPRECH = 0;
`endif

    localparam SDRAM_SHIFT = `JTFRAME_SHIFT ^^ `JTFRAME_180SHIFT;

// sdram bank lengths
localparam
`ifdef JTFRAME_BA0_LEN
    BA0_LEN                 = `JTFRAME_BA0_LEN,
`else
    BA0_LEN                 = 32,
`endif

`ifdef JTFRAME_BA1_LEN
    BA1_LEN                 = `JTFRAME_BA1_LEN,
`else
    BA1_LEN                 = 32,
`endif

`ifdef JTFRAME_BA2_LEN
    BA2_LEN                 = `JTFRAME_BA2_LEN,
`else
    BA2_LEN                 = 32,
`endif

`ifdef JTFRAME_BA3_LEN
    BA3_LEN                 = `JTFRAME_BA3_LEN,
`else
    BA3_LEN                 = 32,
`endif
    PROG_LEN = 32,
`ifdef JTFRAME_SDRAM96
    HF = 1;
`else
    HF = 0;
`endif

wire [1:0] rfsh;
wire       rfsh_g;

// Automatic JTFRAME macros set a 64us refresh period
jtframe_frac_cen #(.WC(`JTFRAME_RFSH_WC)) u_rfsh(
    .clk    ( clk               ),
    .n      ( `JTFRAME_RFSH_N   ),
    .m      ( `JTFRAME_RFSH_M   ),
    .cen    ( rfsh              ),
    .cenb   (                   )
);

`ifdef SIMULATION
// ROM loading can drive the programmer path too quickly for refreshes.
assign rfsh_g = !prog_en & rfsh[0];
`else
assign rfsh_g = rfsh[0];
`endif

`ifdef JTFRAME_SDRAM_CACHE
    assign ba_ack    = 4'd0;
    assign ba_dst    = 4'd0;
    assign ba_dok    = 4'd0;
    assign ba_rdy    = 4'd0;

    jtframe_burst_sdram #(
        .AW         ( SDRAMW        ),
        .PROG_LEN   ( PROG_LEN      ),
        .MISTER     ( MISTER        ),
        .HF         ( HF            )
    ) u_sdram(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .init       ( init          ),

        .addr       ( burst_addr    ),
        .ba         ( burst_ba      ),
        .rd         ( burst_rd      ),
        .wr         ( burst_wr      ),
        .din        ( burst_din     ),
        .dout       ( dout          ),
        .ack        ( burst_ack     ),
        .dst        ( burst_dst     ),
        .dok        ( burst_dok     ),
        .rdy        ( burst_rdy     ),

        .prog_en    ( prog_en       ),
        .prog_addr  ( prog_addr     ),
        .prog_rd    ( prog_rd       ),
        .prog_wr    ( prog_we       ),
        .prog_din   ( prog_data     ),
        .prog_dsn   ( prog_dsn      ),
        .prog_ba    ( prog_ba       ),
        .prog_dst   ( prog_dst      ),
        .prog_dok   ( prog_dok      ),
        .prog_rdy   ( prog_rdy      ),
        .prog_ack   ( prog_ack      ),

        .rfsh       ( rfsh_g        ),

        .sdram_dq   ( sdram_dq      ),
`ifdef VERILATOR
        .sdram_din  ( din           ),
`endif
        .sdram_a    ( sdram_a       ),
        .sdram_dqml ( sdram_dqml    ),
        .sdram_dqmh ( sdram_dqmh    ),
        .sdram_ba   ( sdram_ba      ),
        .sdram_nwe  ( sdram_nwe     ),
        .sdram_ncas ( sdram_ncas    ),
        .sdram_nras ( sdram_nras    ),
        .sdram_ncs  ( sdram_ncs     ),
        .sdram_cke  ( sdram_cke     )
    );
`else
    assign burst_ack = 1'b0;
    assign burst_dst = 1'b0;
    assign burst_dok = 1'b0;
    assign burst_rdy = 1'b0;
    // Above 64MHz HF should be 1. SHIFTED depends on whether the SDRAM
    // clock is shifted or not.
    // Writting on each bank must be selectively enabled with macros
    // in order to ease the placing of the SDRAM data signals in pad registers
    // MiSTer can place them in the pads if only one bank is used for writting
    // Not placing them in pads may create timing problems, especially at 96MHz
    // ie, the core may compile correctly but data transfer may fail.
    jtframe_sdram64 #(
        .AW           ( SDRAMW        ),
        .BA0_LEN      ( BA0_LEN       ),
        .BA1_LEN      ( BA1_LEN       ),
        .BA2_LEN      ( BA2_LEN       ),
        .BA3_LEN      ( BA3_LEN       ),
        .BA0_AUTOPRECH( BA0_AUTOPRECH ),
        .BA1_AUTOPRECH( BA1_AUTOPRECH ),
        .BA2_AUTOPRECH( BA2_AUTOPRECH ),
        .BA3_AUTOPRECH( BA3_AUTOPRECH ),
`ifdef JTFRAME_BA1_WEN
        .BA1_WEN      ( 1             ), `endif
`ifdef JTFRAME_BA2_WEN
        .BA2_WEN      ( 1             ), `endif
`ifdef JTFRAME_BA3_WEN
        .BA3_WEN      ( 1             ), `endif
        .PROG_LEN     ( PROG_LEN      ),
        .MISTER       ( MISTER        ),
        .HF           ( HF            ),
`ifdef JTFRAME_SDRAM96
        .SHIFTED      ( 0             )
`else
        .SHIFTED      ( SDRAM_SHIFT   )
`endif
    ) u_sdram(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .init       ( init          ),

        .ba0_addr   ( ba0_addr      ),
        .ba1_addr   ( ba1_addr      ),
        .ba2_addr   ( ba2_addr      ),
        .ba3_addr   ( ba3_addr      ),

        .rd         ( ba_rd         ),
        .wr         ( ba_wr         ),
        .ba0_din    ( ba0_din       ),
        .ba0_dsn    ( ba0_dsn       ),
        .ba1_din    ( ba1_din       ),
        .ba1_dsn    ( ba1_dsn       ),
        .ba2_din    ( ba2_din       ),
        .ba2_dsn    ( ba2_dsn       ),
        .ba3_din    ( ba3_din       ),
        .ba3_dsn    ( ba3_dsn       ),

        .rdy        ( ba_rdy        ),
        .ack        ( ba_ack        ),
        .dok        ( ba_dok        ),
        .dst        ( ba_dst        ),

        .prog_en    ( prog_en       ),
        .prog_addr  ( prog_addr     ),
        .prog_ba    ( prog_ba       ),
        .prog_rd    ( prog_rd       ),
        .prog_wr    ( prog_we       ),
        .prog_din   ( prog_data     ),
        .prog_dsn   ( prog_dsn      ),
        .prog_rdy   ( prog_rdy      ),
        .prog_dst   ( prog_dst      ),
        .prog_dok   ( prog_dok      ),
        .prog_ack   ( prog_ack      ),

        .sdram_dq   ( sdram_dq      ),
`ifdef VERILATOR
        .sdram_din  ( din           ),
`endif
        .sdram_a    ( sdram_a       ),
        .sdram_dqml ( sdram_dqml    ),
        .sdram_dqmh ( sdram_dqmh    ),
        .sdram_nwe  ( sdram_nwe     ),
        .sdram_ncas ( sdram_ncas    ),
        .sdram_nras ( sdram_nras    ),
        .sdram_ncs  ( sdram_ncs     ),
        .sdram_ba   ( sdram_ba      ),
        .sdram_cke  ( sdram_cke     ),

        .dout       ( dout          ),
        .rfsh       ( rfsh_g        )
    );
`ifdef SIMULATION
    jtframe_romrq_rdy_check u_rdy_check(
        .rst       ( rst        ),
        .clk       ( clk        ),
        .ba_rd     ( ba_rd      ),
        .ba_wr     ( ba_wr      ),
        .ba_ack    ( ba_ack     ),
        .ba_rdy    ( ba_rdy     )
    );
`endif
`endif

`ifdef SIMULATION
`ifdef JTFRAME_SDRAM_STATS
    jtframe_sdram_stats_sim #(.AW(SDRAMW)) u_stats_sim(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .sdram_a    ( sdram_a       ),
        .sdram_ba   ( sdram_ba      ),
        .sdram_nwe  ( sdram_nwe     ),
        .sdram_ncas ( sdram_ncas    ),
        .sdram_nras ( sdram_nras    ),
        .sdram_ncs  ( sdram_ncs     )
    );
`endif
`endif

endmodule
