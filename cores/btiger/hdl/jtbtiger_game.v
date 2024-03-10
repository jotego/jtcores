/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-11-2019 */

module jtbtiger_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam [25:0]   OBJ_START  = `JTFRAME_BA3_START,
                    PROM_START = `JTFRAME_PROM_START,
                    MCUOVER    = PROM_START+26'h1000;

wire [12:0] cpu_AB;
wire [10:0] scr_hpos, scr_vpos;
wire [ 8:0] obj_AB, V, H;
wire [ 7:0] mcu_din, mcu_dout, cpu_dout, char_dout, scr_dout, snd_latch, main_ram;
wire [ 4:0] prom;
wire [ 1:0] scr_bank;
wire        mcu_wr, mcu_rd, preLHBL, preLVBL, sres_b,
            cen12, cen6, cen3, cen1p5, cenfm,
            cen8, RnW, blue_cs, redgreen_cs, CHRON, SCRON, OBJON,
            OKOUT, blcnten, bus_req, bus_ack, LHBL_obj, LVBL_obj,
            rd, cpu_cen, char_busy, scr_busy, mcuover,
            scr_layout, HINIT, char_cs, flip, scr_cs;
reg         pause;
wire        prom_prior_we = prom[0];
wire        prom_mcu      = prom[4];

assign debug_view  = { 5'd0, OBJON, SCRON, CHRON };
assign dip_flip    = ~dipsw[6];
assign pxl2_cen    = cen12;
assign pxl_cen     = cen6;
assign mcuover     = ioctl_addr>=MCUOVER;
assign prom[0] = prom_we &&  mcuover && ioctl_addr[10:8]==0;
assign prom[1] = prom_we &&  mcuover && ioctl_addr[10:8]==1;
assign prom[2] = prom_we &&  mcuover && ioctl_addr[10:8]==2;
assign prom[3] = prom_we &&  mcuover && ioctl_addr[10:8]==3;
assign prom[4] = prom_we && !mcuover;
/* verilator tracing_off */
always @(posedge clk) pause <= ~dip_pause;

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr >= OBJ_START ) begin
        post_addr[5:1] = {prog_addr[4:1],prog_addr[5]};
    end
end
/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen12b (           ),
    .cen8   ( cen8      ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

jtframe_cen3p57 u_cen3p57(
    .clk      ( clk       ),
    .cen_3p57 ( cenfm     ),
    .cen_1p78 (           )     // unused
);/* verilator lint_on PINMISSING */

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

`ifndef NOMAIN
jtbtiger_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // Palette
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // security
    .mcu_din    ( mcu_din       ),
    .mcu_dout   ( mcu_dout      ),
    .mcu_wr     ( mcu_wr        ),
    .mcu_rd     ( mcu_rd        ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .CHRON      ( CHRON         ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .SCRON      ( SCRON         ),
    .scr_bank   ( scr_bank      ),
    .scr_layout ( scr_layout    ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .OBJON      ( OBJON         ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[15:8]   ),
    .dipsw_b    ( dipsw[ 7:0]   )
);
`else
assign main_addr   = 19'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 9'd0;
assign scr_vpos    = 9'd0;
assign cpu_cen     = cen3;
assign scr_layout  = 1'b0;
assign scr_bank    = 2'b0;
`endif

`ifndef NOMCU
jtbtiger_mcu u_mcu(
    .rst        (  rst24      ),
    .clk        (  clk24      ),
    .clk_rom    (  clk        ),
    .LVBL       ( LVBL        ),
    .mcu_dout   (  mcu_dout   ),
    .mcu_din    (  mcu_din    ),
    .mcu_wr     (  mcu_wr     ),
    .mcu_rd     (  mcu_rd     ),
    .prog_addr  (  prog_addr[11:0]  ),
    .prom_din   (  prog_data  ),
    .prom_we    (  prom_mcu   )
);
`else
assign mcu_dout = 8'hff;
`endif

jtgng_sound #(.LAYOUT(4)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cenfm          ),
    .cen1p5         ( cenfm          ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( 1'b0           ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .fm0            ( fm0            ),
    .fm1            ( fm1            ),
    .psg0           ( psg0           ),
    .psg1           ( psg1           ),
    // Unused
    .snd2_latch     (                ),
    .debug_view     (                ),
    .debug_bus      ( debug_bus      )
);

jtbtiger_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( pause         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    .CHRON      ( CHRON         ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    .scr_bank   ( scr_bank      ),
    .scr_layout ( scr_layout    ),
    .SCRON      ( SCRON         ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .OBJON      ( OBJON         ),
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_prior_we( prom_prior_we ),
    .prom_din     ( prog_data[3:0]),
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // Color Mix
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
