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
    input   [ 3:0]  start_button,
    input   [ 3:0]  coin_input,
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
    input           downloading,
    output          dwnld_busy,

    // ROM LOAD
    input   [25:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,

    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
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

    // Debug
    input   [3:0]   gfx_en,
    input   [7:0]   st_addr,
    output  [7:0]   st_dout,
    input   [7:0]   debug_bus,
    output  [7:0]   debug_view
    `ifdef JTFRAME_IOCTL_RD
    ,input           ioctl_ram
    ,output  [ 7:0]  ioctl_din
    `endif
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
wire [15:0] ba0_din;
wire [ 1:0] ba0_din_m;  // write mask
wire [ 3:0] ba_rd;
wire        ba_wr;
wire [ 3:0] ba_ack;
wire [ 3:0] ba_dst;
wire [ 3:0] ba_dok;
wire [ 3:0] ba_rdy;

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
    assign ba0_din_m  = 3;
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
reg LVBLl;

always @(posedge clk) begin
    LVBLl <= LVBL;
    if( !LVBL && LVBLl ) frame_cnt<=frame_cnt+1;
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
/* verilator tracing_off */
wire prog_en = downloading | dwnld_busy;

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
`ifdef JTFRAME_SDRAM96
    .HF(1),
    .SHIFTED(0)
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
    .wr         ( {3'b0,ba_wr}  ),
    .din        ( ba0_din       ),
    .din_m      ( ba0_din_m     ),  // write mask

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
    .prog_din_m ( prog_mask     ),
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

`ifdef SIMULATION
    // jtframe_romrq_rdy_check u_rdy_check(
    //     .rst       ( rst        ),
    //     .clk       ( clk_rom    ),
    //     .ba_rd     ( ba_rd      ),
    //     .ba_wr     ( ba_wr      ),
    //     .ba_ack    ( ba_ack     ),
    //     .ba_rdy    ( ba_rdy     )
    // );

    `ifdef JTFRAME_SDRAM_STATS
    jtframe_sdram_stats #(.AW(SDRAMW)) u_stats(
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
`endif
/* verilator tracing_on */

`GAMETOP
u_game(
    .rst         ( rst            ),
    // The main clock is always the same one as the SDRAM
    .clk         ( clk_rom        ),
`ifdef JTFRAME_CLK96
    .clk96       ( clk96          ),
    .rst96       ( rst96          ),
`endif
`ifdef JTFRAME_CLK48
    .clk48       ( clk48          ),
    .rst48       ( rst48          ),
`endif
`ifdef JTFRAME_CLK24
    .clk24       ( clk24          ),
    .rst24       ( rst24          ),
`endif
`ifdef JTFRAME_CLK6
    .clk6        ( clk6           ),
    .rst6        ( rst6           ),
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

    .start_button( start_button[STARTW-1:0] ),
    .coin_input  ( coin_input[STARTW-1:0]  ),
    // Joysticks
    .joystick1    ( joystick1[GAME_BUTTONS+3:0]   ),
    .joystick2    ( joystick2[GAME_BUTTONS+3:0]   ),
    `ifdef JTFRAME_4PLAYERS
    .joystick3    ( joystick3[GAME_BUTTONS+3:0]   ),
    .joystick4    ( joystick4[GAME_BUTTONS+3:0]   ),
    `endif

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

    // Sound control
    .enable_fm   ( enable_fm      ),
    .enable_psg  ( enable_psg     ),
    // PROM programming
    .ioctl_addr  ( ioctl_addr[SDRAMW+2:0] ),
    .ioctl_dout  ( ioctl_dout     ),
    .ioctl_wr    ( ioctl_wr       ),
`ifdef JTFRAME_IOCTL_RD
    .ioctl_ram   ( ioctl_ram      ),
    .ioctl_din   ( ioctl_din      ),
`endif
    // ROM load
    .downloading ( downloading    ),
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
    .ba0_din_m  ( ba0_din_m     ),  // write mask

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
    .dipsw       ( dipsw          ),

`ifdef JTFRAME_GAME_UART
    .uart_tx     ( UART_TX        ),
    .uart_rx     ( UART_RX        ),
`endif

    // sound
`ifndef JTFRAME_STEREO
    .snd         ( snd_left       ),
`else
    .snd_left    ( snd_left       ),
    .snd_right   ( snd_right      ),
    `endif
    .sample      ( sample         ),
    // Debug
`ifdef JTFRAME_STATUS
    .st_addr     ( st_addr        ),
    .st_dout     ( st_dout        ),
`endif
    .gfx_en      ( gfx_en         )
`ifdef JTFRAME_DEBUG
   ,.debug_bus   ( debug_bus      )
   ,.debug_view  ( debug_view     )
`endif
);

`ifndef JTFRAME_DEBUG
    assign debug_view = 0;
`endif

endmodule
