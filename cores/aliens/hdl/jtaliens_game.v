/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-2-2023 */

module jtaliens_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        snd_irq;

wire [ 7:0] snd_latch;
wire        cpu_cen;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
reg  [ 7:0] debug_mux;

wire [15:0] cpu_addr;
wire        pal_we=0, tilemap_we=0;
wire        cpu_rnw, cpu_irq_n, cpu_firq_n, cpu_nmi_n;
wire [ 7:0] tilemap_dout, tilerom_dout,
            obj_dout, pal_dout, cpu_dout, st_video;
wire [ 2:0] prio;
wire        rmrd, rst8;
// wire        buserror;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];
assign debug_view = debug_mux;
// assign ram_din    = cpu_dout;
assign cpu_dout   = 0;
assign cpu_addr   = 0;
assign pal_we     = 0;
assign prio       = 0;
assign tilemap_we = 0;
assign rmrd       = 0;
assign snd_addr   = 0;
assign snd_cs     = 0;
assign pcma_cs    = 0;
assign pcmb_cs    = 0;
assign pcma_addr  = 0;
assign pcmb_addr  = 0;
assign main_cs    = 0;
assign main_addr  = 0;
assign game_led   = 0;
assign sample     = 0;
assign snd        = 0;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_video;
        1: debug_mux <= dipsw_a;
        2: debug_mux <= dipsw_b;
        default: debug_mux <= 0;
        //3: debug_mux <= { dipsw_c, buserror, prio, video_bank };
    endcase
end

// always @(*) begin
//     post_addr = prog_addr;
//     if( prog_ba[1] ) begin
//         post_addr[]
//     end
// end

/* xxxverilator tracing_off */
jtaliens_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      (prog_addr[ 7:0]),
    .prog_data      ( prog_data[1:0]),
    // GFX - CPU interface
    .tilemap_we     ( tilemap_we    ),
    .pal_we         ( pal_we        ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .tilemap_dout   ( tilemap_dout  ),
    .tilerom_dout   ( tilerom_dout  ),
    // .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),
    .prio_cfg       ( prio          ),
    .rmrd           ( rmrd          ),
    .cpu_irq_n      ( cpu_irq_n     ),
    .cpu_firq_n     ( cpu_firq_n    ),
    .cpu_nmi_n      ( cpu_nmi_n     ),
    // SDRAM
    .lyra_addr      ( lyra_addr     ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_data      ( lyrb_data     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyra_cs        ( lyra_cs       ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyro_cs        ( lyro_cs       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .debug_bus      ( debug_bus     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

endmodule