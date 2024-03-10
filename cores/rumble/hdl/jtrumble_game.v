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
    Date: 5-4-2021 */

module jtrumble_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [16:0] obj_prea;
wire [15:0] obj_sort;
wire [ 7:0] obj_din, snd_latch, cpu_dout, scr_dout, char_dout;
// ROM address
wire [12:0] cpu_AB;
wire [ 8:0] obj_AB;
wire        cenfm, cpu_cen;
reg         loud;

wire [ 9:0] scr_hpos, scr_vpos;
wire [ 8:0] vdump;
wire        scr_busy, char_busy;

wire        main_rnw;
wire        pal_cs, char_cs, scr_cs;

wire [ 1:0] prom_bank;
wire        prom_prio;

wire        vmid, cen24_8, cen24_4, cen24_2;
wire        sres_b, flip;
wire        bus_ack, bus_req, blcnten;

assign dip_flip   = flip;
assign obj_cs     = 1;
assign debug_view = { 3'd0, loud, 3'd0, flip };
assign obj_sort   = obj_prea[0] ? { obj_data[24+:4], obj_data[16+:4], obj_data[8+:4], obj_data[0+:4] } : { obj_data[28+:4], obj_data[20+:4], obj_data[12+:4], obj_data[4+:4] };
assign obj_addr   = obj_prea[16:1];
assign prom_prio  = prom_we && prog_addr[9:8]==2'b10;

always @* begin
    post_addr = prog_addr;
    if(prog_ba==3 && !prom_we) post_addr[5:1] = { prog_addr[4:1], prog_addr[5] };
end

always @(posedge clk) begin
    if( header && prog_addr[3:0]==0 && prog_we ) loud <= prog_data[0];
end

jtframe_cen48 u_cen48(
    .clk    ( clk      ),
    .cen16  ( pxl2_cen ),
    .cen16b (          ),
    .cen12  (          ),
    .cen12b (          ),
    .cen8   ( pxl_cen  ),
    .cen6   (          ),
    .cen6b  (          ),
    .cen4   (          ),
    .cen4_12(          ),
    .cen3   (          ),
    .cen3q  (          ),
    .cen3qb (          ),
    .cen3b  (          ),
    .cen1p5 (          ),
    .cen1p5b(          )
);

jtframe_cen24 u_cen24(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen8   ( cen24_8   ),
    .cen6   (           ),
    .cen4   ( cen24_4   ),
    .cen3   (           ),
    .cen3q  (           ),
    .cen1p5 (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

jtframe_cendiv u_cendiv(
    .clk    ( clk24     ),
    .cen_in ( cen24_4   ),
    .cen_div(           ), // Divided but not alligned with the original
    .cen_da ( cen24_2   )
);

`ifndef NOMAIN
jtrumble_main u_main(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .clk_obj    ( clk           ),
    .cen8       ( cen24_8       ),
    .cpu_cen    ( cpu_cen       ),
    .LVBL       ( LVBL          ),   // vertical blanking when 0
    .vmid       ( vmid          ),
    // Screen
    .pal_cs     ( pal_cs        ),
    .flip       ( flip          ),
    // Sound
    .sres_b     ( sres_b        ), // Z80 reset
    .snd_latch  ( snd_latch     ),
    // Characters
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    //.char_busy  ( char_busy     ),
    .char_busy  ( 1'b0     ),
    // scroll
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    //.scr_busy   ( scr_busy      ),
    .scr_busy   ( 1'b0      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // cabinet I/O
    .cab_1p      ( cab_1p       ),
    .coin        ( coin         ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // BUS sharing
    .bus_ack     ( bus_ack      ),
    .bus_req     ( bus_req      ),
    .obj_AB      ( obj_AB       ),
    .obj_din     ( obj_din      ),
    .RnW         ( main_rnw     ),
    .cpu_AB      ( cpu_AB       ),
    // ROM access
    .rom_cs      ( main_cs      ),
    .rom_addr    ( main_addr    ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      ),
    // DIP switches
    .service     ( service      ),
    .dip_pause   ( dip_pause    ),
    .dipsw_a     ( dipsw[ 7:0]  ),
    .dipsw_b     ( dipsw[15:8]  )
);
`else
    assign main_cs  = 0;
    assign main_rnw = 1;
    assign main_addr= 0;
    assign cpu_dout = 0;
    assign char_cs  = 0;
    assign scr_cs   = 0;
    assign pal_cs   = 0;
    assign flip     = 0;
    assign cpu_AB   = 0;
`endif

jtrumble_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( vdump         ),
    .RnW        ( main_rnw      ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Palette
    .pal_cs     ( pal_cs        ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .obj_addr   ( obj_prea      ),
    .obj_data   ( obj_sort      ),
    .obj_ok     ( obj_ok        ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .dma_addr   ( obj_AB        ),
    .dma_data   ( obj_din       ),
    // PROMs
    .prog_addr  ( prog_addr[7:0]),
    .prom_prio  ( prom_prio     ),
    .prom_din   ( prog_data[3:0]),
    // Sync
    .vmid       ( vmid          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

`ifndef NOSOUND
// Fx is very loud in this game
jtgng_sound #(.LAYOUT (10 )) u_fmcpu(
    .rst        (  rst24        ),
    .clk        (  clk24        ),
    .cen3       (  cen24_4      ),
    .cen1p5     (  cen24_2      ), // unused
    .sres_b     (  sres_b       ),
    .snd_latch  (  snd_latch    ),
    .snd2_latch (               ),
    .snd_int    (  1'b1         ), // unused
    // .psg_level  (  {loud,1'b0}  ),
    .rom_addr   (  snd_addr     ),
    .rom_cs     (  snd_cs       ),
    .rom_data   (  snd_data     ),
    .rom_ok     (  snd_ok       ),
    // sound output
    .fm0        ( fm0           ),
    .fm1        ( fm1           ),
    .psg0       ( psg0          ),
    .psg1       ( psg1          ),
    .debug_bus  ( debug_bus     ),
    .debug_view (               )
);
`else
    assign snd_addr = 0;
    assign snd_cs   = 0;
    assign snd      = 0;
    assign fm0      = 0;
    assign fm1      = 0;
    assign psg0     = 0;
    assign psg1     = 0;
//    assign debug_view = 0;
`endif

endmodule
