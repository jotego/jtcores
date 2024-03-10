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
    Version: 1.0
    Date: 13-4-2022 */

`ifndef JTFRAME_BUTTONS
`define JTFRAME_BUTTONS 2
`endif

// Top level for verilator simulations

module game_test(
    input           sdram_rst,

    // Clocks and resets, depending on the JTFRAME_CLK macros
    // some of these inputs will be used
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    input           rst48,
    input           clk48,
    input           rst96,
    input           clk96,

    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [7:0]  red,
    output   [7:0]  green,
    output   [7:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 3:0]  cab_1p,
    input   [ 3:0]  coin,
    input   [ 9:0]  joystick1,
    input   [ 9:0]  joystick2,
    input   [ 9:0]  joystick3,
    input   [ 9:0]  joystick4,

    // Analog inputs
    input   [15:0]  joyana_l1,
    input   [15:0]  joyana_l2,
    input   [15:0]  joyana_l3,
    input   [15:0]  joyana_l4,
    input   [15:0]  joyana_r1,
    input   [15:0]  joyana_r2,
    input   [15:0]  joyana_r3,
    input   [15:0]  joyana_r4,

    // SDRAM interface
    input           ioctl_rom,
    input           ioctl_cart,
    output          dwnld_busy,

    // ROM LOAD
    input   [25:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    input           ioctl_ram,
    output  [ 7:0]  ioctl_din,

    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
    input           tilt,
    input           dip_test,
    input           dip_pause,
`ifdef JTFRAME_OSD_FLIP
    input           dip_flip,
`else
    output          dip_flip,
`endif
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,

    // SDRAM interface
    output          sdram_init,
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [15:0]   SDRAM_DIN,      // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output [ 1:0]   SDRAM_DQM,      // SDRAM Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable
    // input  [21:0]   SDRAM_BA_ADDR0,
    // input  [21:0]   SDRAM_BA_ADDR1,
    // input  [21:0]   SDRAM_BA_ADDR2,
    // input  [21:0]   SDRAM_BA_ADDR3,

    // JTFRAME_LF_BUFFER
    // output   [ 7:0] game_vrender,
    // output   [ 8:0] game_hdump,
    // output   [ 8:0] ln_addr,
    // output   [15:0] ln_data,
    // output          ln_done,
    // input           ln_hs,
    // input    [15:0] ln_pxl,
    // input    [ 7:0] ln_v,
    // output          ln_we,

    // Debug
    input   [3:0]   gfx_en,
    input   [7:0]   st_addr,
    output  [7:0]   st_dout,
    input   [7:0]   debug_bus,
    output  [7:0]   debug_view
);

`ifdef JTFRAME_SDRAM_LARGE
    localparam SDRAMW=23; // 64 MB
`else
    localparam SDRAMW=22; // 32 MB
`endif

`ifdef JTFRAME_BA0_AUTOPRECH
    localparam BA0_AUTOPRECH = `JTFRAME_BA0_AUTOPRECH;
`elsif JTFRAME_SDRAM_BANKS
    localparam BA0_AUTOPRECH = 0;
`else
    // if only one bank is used, it makes to precharge as default option
    localparam BA0_AUTOPRECH = 1;
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

`ifdef JTFRAME_COLORW
    localparam COLORW=`JTFRAME_COLORW;
`else
    localparam COLORW=4;
`endif

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
    PROG_LEN = 32;

wire [SDRAMW-1:0] ba0_addr;
wire [SDRAMW-1:0] ba1_addr;
wire [SDRAMW-1:0] ba2_addr;
wire [SDRAMW-1:0] ba3_addr;
wire [SDRAMW-1:0] prog_addr;
wire [15:0] ba0_din, ba1_din, ba2_din, ba3_din;
wire [ 1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn;
wire [ 3:0] ba_rd, ba_wr, ba_ack, ba_dst, ba_dok, ba_rdy;

wire [15:0] prog_data;
wire [ 1:0] prog_mask;
wire [ 1:0] prog_ba;
wire        prog_we;
wire        prog_rd;
wire        prog_ack;
wire        prog_dst;
wire        prog_dok;
wire        prog_rdy;
wire [15:0] data_read;
wire        SDRAM_DQML;     // SDRAM Low-byte Data Mask
wire        SDRAM_DQMH;     // SDRAM High-byte Data Mask

assign SDRAM_DQM= { SDRAM_DQMH, SDRAM_DQML };

`ifndef JTFRAME_IOCTL_RD
    assign ioctl_din = 0;
`endif

`ifndef JTFRAME_SDRAM_BANKS
    wire [ 7:0] prog_data8;
    assign prog_data = {2{prog_data8}};
    assign ba_rd[3:1] = 0;
    assign ba_wr      = 0;
    assign prog_ba    = 0;
    // tie down unused bank signals
    assign ba1_addr   = 0;
    assign ba2_addr   = 0;
    assign ba3_addr   = 0;
    assign ba0_din    = 0;
    assign ba0_dsn    = 3;
    assign ba1_din    = 0;
    assign ba1_dsn    = 3;
    assign ba2_din    = 0;
    assign ba2_dsn    = 3;
    assign ba3_din    = 0;
    assign ba3_dsn    = 3;
`endif

localparam GAME_BUTTONS=`JTFRAME_BUTTONS;

`ifdef JTFRAME_4PLAYERS
localparam STARTW=4;
`else
localparam STARTW=2;
`endif

`ifndef JTFRAME_STEREO
assign snd_right = snd_left;
`endif

`ifndef JTFRAME_STATUS
assign st_dout = 0;
`endif

integer frame_cnt=0;
reg VSl;

always @(posedge clk) begin
    VSl <= VS;
    if( VS && !VSl ) frame_cnt<=frame_cnt+1;
end

wire clk_rom = clk;
assign SDRAM_CLK = clk_rom;

generate
    genvar i;
    for(i=7;i>COLORW-1;i=i-1) begin
        assign red[i]=0;
        assign green[i]=0;
        assign blue[i]=0;
    end
endgenerate

// support for 48MHz
// Above 64MHz HF should be 1. SHIFTED depends on whether the SDRAM
// clock is shifted or not.
`ifdef VERILATOR_KEEP_SDRAM /* verilator tracing_on */ `else /* verilator tracing_off */ `endif
wire prog_en = ioctl_rom | dwnld_busy;

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
    .PROG_LEN     ( PROG_LEN      ),
    .MISTER       ( 0             ),
`ifdef JTFRAME_BA1_WEN
    .BA1_WEN      ( 1             ), `endif
`ifdef JTFRAME_BA2_WEN
    .BA2_WEN      ( 1             ), `endif
`ifdef JTFRAME_BA3_WEN
    .BA3_WEN      ( 1             ), `endif
`ifdef JTFRAME_SDRAM96
    .HF(1),
    .SHIFTED(1)     // This is different from jtframe_board's in order to work
                    // in the verilator test bench
`else
    .HF(0),
    `ifdef JTFRAME_180SHIFT
        .SHIFTED(0)
    `else
        .SHIFTED(1)
    `endif
`endif
) u_sdram(
    .rst        ( sdram_rst     ),
    .clk        ( clk_rom       ), // 96MHz = 32 * 6 MHz -> CL=2
    .init       ( sdram_init    ),

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

    // ROM-load interface
    .prog_en    ( prog_en       ),
    .prog_addr  ( prog_addr     ),
    .prog_ba    ( prog_ba       ),
    .prog_rd    ( prog_rd       ),
    .prog_wr    ( prog_we       ),
    .prog_din   ( prog_data     ),
    .prog_dsn   ( prog_mask     ),
    .prog_rdy   ( prog_rdy      ),
    .prog_dst   ( prog_dst      ),
    .prog_dok   ( prog_dok      ),
    .prog_ack   ( prog_ack      ),
    // SDRAM interface
    .sdram_dq   ( SDRAM_DQ      ),
    .sdram_din  ( SDRAM_DIN     ),
    .sdram_a    ( SDRAM_A       ),
    .sdram_dqml ( SDRAM_DQML    ),
    .sdram_dqmh ( SDRAM_DQMH    ),
    .sdram_nwe  ( SDRAM_nWE     ),
    .sdram_ncas ( SDRAM_nCAS    ),
    .sdram_nras ( SDRAM_nRAS    ),
    .sdram_ncs  ( SDRAM_nCS     ),
    .sdram_ba   ( SDRAM_BA      ),
    .sdram_cke  ( SDRAM_CKE     ),

    // Common signals
    .dout       ( data_read     ),
    .rfsh       ( !prog_en & ~LHBL ) // Do not refresh during programming
                                     // the verilator code sends the data too fast
);
/* verilator tracing_off */

`ifdef JTFRAME_SDRAM_STATS
jtframe_sdram_stats_sim #(.AW(SDRAMW)) u_stats(
    .rst        ( sdram_rst     ),
    .clk        ( clk_rom       ),
    // SDRAM interface
    .sdram_a    ( SDRAM_A       ),
    .sdram_ba   ( SDRAM_BA      ),
    .sdram_nwe  ( SDRAM_nWE     ),
    .sdram_ncas ( SDRAM_nCAS    ),
    .sdram_nras ( SDRAM_nRAS    ),
    .sdram_ncs  ( SDRAM_nCS     )
);
`endif

/* verilator tracing_on */
`ifdef JTFRAME_LF_BUFFER
        wire  [ 7:0] game_vrender;
        wire  [ 8:0] game_hdump;
        wire  [ 8:0] ln_addr;
        wire  [15:0] ln_data;
        wire         ln_done;
        wire         ln_hs;
        wire  [15:0] ln_pxl;
        wire  [ 7:0] ln_v;
        wire         ln_we;

    `ifdef POCKET
        wire [21:16] cr_addr;
        wire [ 15:0] cr_adq;
        wire         cr_advn;
        wire [  1:0] cr_cen;
        wire         cr_clk;
        wire         cr_cre;
        wire [  1:0] cr_dsn;
        wire         cr_oen;
        wire         cr_wait;
        wire         cr_wen;

        jtframe_lfbuf_cram u_lf_buf(
            .rst        ( rst           ),
            .clk        ( clk_rom       ),
            .pxl_cen    ( pxl_cen       ),

            .vs         ( VS            ),
            .lvbl       ( LVBL          ),
            .lhbl       ( LHBL          ),
            .vrender    ( game_vrender  ),
            .hdump      ( game_hdump    ),

            // interface with the game core
            .ln_addr    ( ln_addr       ),
            .ln_data    ( ln_data       ),
            .ln_done    ( ln_done       ),
            .ln_hs      ( ln_hs         ),
            .ln_pxl     ( ln_pxl        ),
            .ln_v       ( ln_v          ),
            .ln_we      ( ln_we         ),

            // PSRAM chip 0
            .cr_addr    ( cr_addr       ),
            .cr_adq     ( cr_adq        ),
            .cr_advn    ( cr_advn       ),
            .cr_cen     ( cr_cen        ),
            .cr_clk     ( cr_clk        ),
            .cr_cre     ( cr_cre        ),
            .cr_dsn     ( cr_dsn        ),
            .cr_oen     ( cr_oen        ),
            .cr_wait    ( cr_wait       ),
            .cr_wen     ( cr_wen        )
        );

        psram128 u_cram0(
            .a      ( cr_addr        ),
            .adq    ( cr_adq         ),
            .advn   ( cr_advn        ),
            .cen    ( cr_cen         ),
            .clk    ( cr_clk         ),
            .cre    ( cr_cre         ),
            .lbn    ( cr_dsn[0]      ),
            .ubn    ( cr_dsn[1]      ),
            .oen    ( cr_oen         ),
            .wt     ( cr_wait        ),
            .wen    ( cr_wen         )
        );
    `else // MiSTer family
        wire          DDRAM_CLK, DDRAM_BUSY, DDRAM_RD, DDRAM_WE, DDRAM_DOUT_READY;
        wire    [7:0] DDRAM_BURSTCNT, DDRAM_BE;
        wire   [28:0] DDRAM_ADDR;
        wire   [63:0] DDRAM_DOUT, DDRAM_DIN;

        jtframe_ddr_model u_ddr(
            .clk          ( DDRAM_CLK     ),
            .busy         ( DDRAM_BUSY    ),
            .burstcnt     ( DDRAM_BURSTCNT),
            .addr         ( DDRAM_ADDR    ),
            .dout         ( DDRAM_DOUT    ),
            .dout_ready   ( DDRAM_DOUT_READY ),
            .rd           ( DDRAM_RD      ),
            .din          ( DDRAM_DIN     ),
            .be           ( DDRAM_BE      ),
            .we           ( DDRAM_WE      )
        );

        jtframe_lfbuf_ddr u_lf_buf(
            .rst        ( rst           ),
            .clk        ( clk_rom       ),
            .pxl_cen    ( pxl_cen       ),

            .vs         ( VS            ),
            .lvbl       ( LVBL          ),
            .lhbl       ( LHBL          ),
            .vrender    ( game_vrender  ),
            .hdump      ( game_hdump    ),

            // interface with the game core
            .ln_addr    ( ln_addr       ),
            .ln_data    ( ln_data       ),
            .ln_done    ( ln_done       ),
            .ln_hs      ( ln_hs         ),
            .ln_pxl     ( ln_pxl        ),
            .ln_v       ( ln_v          ),
            .ln_we      ( ln_we         ),

            .ddram_clk  ( DDRAM_CLK     ),
            .ddram_busy ( DDRAM_BUSY    ),
            .ddram_addr ( DDRAM_ADDR    ),
            .ddram_dout ( DDRAM_DOUT    ),
            .ddram_rd   ( DDRAM_RD      ),
            .ddram_din  ( DDRAM_DIN     ),
            .ddram_be   ( DDRAM_BE      ),
            .ddram_we   ( DDRAM_WE      ),
            .ddram_burstcnt  ( DDRAM_BURSTCNT    ),
            .ddram_dout_ready( DDRAM_DOUT_READY  ),
            .st_addr    ( 8'd0 ),
            .st_dout    (      )
        );
    `endif
`endif

//////// GAME MODULE
`GAMETOP
u_game(
    .rst         ( rst            ),
    // The main clock is always the same one as the SDRAM
    .clk         ( clk_rom        ),
`ifdef JTFRAME_CLK96
    .clk96       ( clk96          ),
    .rst96       ( rst            ),
`endif
`ifdef JTFRAME_CLK48
    .clk48       ( clk48          ),
    .rst48       ( rst            ),
`endif
`ifdef JTFRAME_CLK24
    .clk24       ( clk24          ),
    .rst24       ( rst            ),
`endif
`ifdef JTFRAME_CLK6
    .clk6        ( clk6           ),
    .rst6        ( rst            ),
`endif
    // Video
    .pxl2_cen    ( pxl2_cen       ),
    .pxl_cen     ( pxl_cen        ),
    .red         ( red[COLORW-1:0]   ),
    .green       ( green[COLORW-1:0] ),
    .blue        ( blue[COLORW-1:0]  ),
    .LHBL        ( LHBL           ),
    .LVBL        ( LVBL           ),
    .HS          ( HS             ),
    .VS          ( VS             ),
    // LED
    .game_led    ( game_led       ),

    .cab_1p( cab_1p[STARTW-1:0] ),
    .coin  ( coin[STARTW-1:0]  ),
    // Joysticks
    .joystick1    ( joystick1[GAME_BUTTONS+3:0]   ),
    .joystick2    ( joystick2[GAME_BUTTONS+3:0]   ),
    `ifdef JTFRAME_4PLAYERS
    .joystick3    ( joystick3[GAME_BUTTONS+3:0]   ),
    .joystick4    ( joystick4[GAME_BUTTONS+3:0]   ),
    `endif

`ifdef JTFRAME_DIAL
    .dial_x (2'd0), .dial_y(2'd0), `endif

`ifdef JTFRAME_ANALOG
    .joyana_l1    ( joyana_l1        ),
    .joyana_l2    ( joyana_l2        ),
    `ifdef JTFRAME_ANALOG_DUAL
        .joyana_r1    ( joyana_r1        ),
        .joyana_r2    ( joyana_r2        ),
    `endif
    `ifdef JTFRAME_4PLAYERS
        .joyana_l3( joyana_l3        ),
        .joyana_l4( joyana_l4        ),
        `ifdef JTFRAME_ANALOG_DUAL
            .joyana_r3( joyana_r3        ),
            .joyana_r4( joyana_r4        ),
        `endif
    `endif
`endif

`ifdef JTFRAME_MOUSE
    .mouse_1p( 16'd0 ), .mouse_2p( 16'd0 ), `endif

    // Sound control
    .enable_fm   ( enable_fm      ),
    .enable_psg  ( enable_psg     ),
    // PROM programming
    .ioctl_addr  ( ioctl_addr     ),
    .ioctl_dout  ( ioctl_dout     ),
    .ioctl_wr    ( ioctl_wr       ), `ifdef JTFRAME_IOCTL_RD
    .ioctl_ram   ( ioctl_ram      ),
    .ioctl_din   ( ioctl_din      ), `endif
    // ROM load
    .ioctl_rom   ( ioctl_rom      ),
    .ioctl_cart  ( ioctl_cart     ),
    .dwnld_busy  ( dwnld_busy     ),
    .data_read   ( data_read      ),

`ifdef JTFRAME_SDRAM_BANKS
    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ),
    .ba3_addr   ( ba3_addr      ),
    .ba_rd      ( ba_rd         ),
    .ba_wr      ( ba_wr         ),
    .ba_dst     ( ba_dst        ),
    .ba_dok     ( ba_dok        ),
    .ba_rdy     ( ba_rdy        ),
    .ba_ack     ( ba_ack        ),
    .ba0_din    ( ba0_din       ),
    .ba0_dsn    ( ba0_dsn       ),
    .ba1_din    ( ba1_din       ),
    .ba1_dsn    ( ba1_dsn       ),
    .ba2_din    ( ba2_din       ),
    .ba2_dsn    ( ba2_dsn       ),
    .ba3_din    ( ba3_din       ),
    .ba3_dsn    ( ba3_dsn       ),

    .prog_ba    ( prog_ba       ),
    .prog_rdy   ( prog_rdy      ),
    .prog_ack   ( prog_ack      ),
    .prog_dok   ( prog_dok      ),
    .prog_dst   ( prog_dst      ),
    .prog_data  ( prog_data     ),
`else
    .sdram_req  ( ba_rd[0]      ),
    .sdram_addr ( ba0_addr      ),
    .data_dst   ( ba_dst[0] | prog_dst ),
    .data_rdy   ( ba_rdy[0] | prog_rdy ),
    .sdram_ack  ( ba_ack[0] | prog_ack ),

    .prog_data  ( prog_data8    ),
`endif

    // common ROM-load interface
    .prog_addr  ( prog_addr     ),
    .prog_rd    ( prog_rd       ),
    .prog_we    ( prog_we       ),
    .prog_mask  ( prog_mask     ),

    // DIP switches
    .status      ( status[31:0]   ),
    .dip_pause   ( dip_pause      ),
    .dip_flip    ( dip_flip       ),
    .dip_test    ( dip_test       ),
    .dip_fxlevel ( dip_fxlevel    ),
    .service     ( service        ),
    .tilt        ( tilt           ),
    .dipsw       ( dipsw          ),

`ifdef JTFRAME_GAME_UART
    .uart_tx     ( UART_TX        ),
    .uart_rx     ( UART_RX        ),
`endif

`ifdef JTFRAME_LF_BUFFER
    .game_vrender( game_vrender   ),
    .game_hdump  ( game_hdump     ),
    .ln_addr     ( ln_addr        ),
    .ln_data     ( ln_data        ),
    .ln_done     ( ln_done        ),
    .ln_hs       ( ln_hs          ),
    .ln_pxl      ( ln_pxl         ),
    .ln_v        ( ln_v           ),
    .ln_we       ( ln_we          ),
`endif

    // sound
`ifndef JTFRAME_STEREO
    .snd         ( snd_left       ),
`else
    .snd_left    ( snd_left       ),
    .snd_right   ( snd_right      ),
    `endif
    .sample      ( sample         ),
    .snd_en      ( 5'h1f          ),
    // Debug
`ifdef JTFRAME_STATUS
    .st_addr     ( st_addr        ),
    .st_dout     ( st_dout        ),
`endif
    .gfx_en      ( gfx_en         ),
    .debug_bus   ( debug_bus      ),
    .debug_view  ( debug_view     )
);

`ifdef JTFRAME_PXLCLK
    /* verilator tracing_off */
    jtframe_pxlcen u_pxlcen(
        .clk        ( clk_rom   ),
        .pxl_cen    ( pxl_cen   ),
        .pxl2_cen   ( pxl2_cen  )
    );
`endif

endmodule

module jtframe_ddr_model(
    input         clk,
    output reg    busy,
    input   [7:0] burstcnt,
    input  [28:0] addr,
    output [63:0] dout,
    output reg    dout_ready,
    input         rd,
    input  [63:0] din,
    input   [7:0] be,
    input         we
);

    localparam SW=20, SIZE=2**SW;

    reg [63:0] mem[0:SIZE-1]; // only the first 8MB are modelled
    reg [ 4:0] busy_cnt;
    reg [ 7:0] cnt;
    reg [ 3:0] dout_cnt;
    reg [SW-1:0] areg;
    reg        rding, wring;

    assign dout       = mem[areg];

    integer aux;
    initial begin
        busy       = 1;
        busy_cnt   = 0;
        dout_cnt   = 0;
        cnt        = 0;
        dout_ready = 0;
        rding      = 0;
        wring      = 0;
        for( aux=0; aux<SIZE; aux=aux+1 ) begin
            mem[aux] = 0;
        end
    end

    assign busy = busy_cnt!=0 && !(rding || wring);

    always @(posedge clk) begin
        busy_cnt <= busy_cnt+1'd1;
        dout_cnt <= dout_cnt-1'd1;
        if( cnt==0 ) begin
            rding <= 0;
            wring <= 0;
            dout_ready <= 0;
        end
        if( (rd || we) && !busy ) begin
            cnt      <= burstcnt;
            areg     <= addr[SW-1:0];
            rding    <= rd;
            wring    <= we;
            dout_cnt <= 15;
        end
        if( dout_cnt==0 ) begin
            dout_ready <= 1;
        end
        if( wring ) begin
            for( aux=0;aux<8;aux=aux+1)
                if( be[aux] ) mem[areg][8*aux+:8] <= din[8*aux+:8];
        end
        if( (wring || dout_ready) && cnt != 0 ) begin
            cnt <= cnt-8'd1;
            areg <= areg + 1'd1;
        end
    end

endmodule