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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 10-8-2026 */

module jtpspike_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [31:0] gfxbank;
wire [ 2:0] charbank;
wire        turbofrc, pspikes, aerofgt, karatblz;
wire [ 8:0] scrx1, scry1, scrx0;
wire [ 1:0] objbank;
wire        flip;
wire [ 8:0] scry;
wire [ 7:0] snd_latch;
wire        snd_wr, snd_pending;
wire        main_rnw;
wire        gga_cs, gga_we, gga_addr;
// karatblz's LUTs are 64kB; the sprite side still indexes the low 16kB

wire [ 1:0] main_dsn;

assign dip_flip   = flip;
// debug_bus[1:0] selects the view:
//   0 game flags   1 ROM-fetch heartbeat   2 VRAM-write heartbeat   3 main_addr
reg [7:0] rom_beat=0, vram_beat=0;
always @(posedge clk) begin
    if( main_cs   ) rom_beat  <= rom_beat +8'd1;
    if( |vram_we  ) vram_beat <= vram_beat+8'd1;
end
assign debug_view = debug_bus[1:0]==2'd0 ? { 4'd0, karatblz, aerofgt, turbofrc, pspikes } :
                    debug_bus[1:0]==2'd1 ? rom_beat  :
                    debug_bus[1:0]==2'd2 ? vram_beat :
                                           main_addr[16:9] ;
assign st_dout    = 0;

assign ram_addr   = main_addr[15:1];
assign vram_addr  = main_addr[12:1];
assign rascr_addr = main_addr[11:1];
assign oram_addr  = main_addr[10:1];
assign lut_addr   = karatblz ? main_addr[15:1] : { 2'd0, main_addr[13:1] };
assign pal_addr   = main_addr[11:1];
assign ram2_addr  = main_addr[13:1];
assign vram1_addr = main_addr[12:1];
assign oram1_addr = main_addr[10:1];
assign lut1_addr  = karatblz ? main_addr[15:1] : { 2'd0, main_addr[13:1] };


`ifdef SIMULATION
integer pal_n=0, vram_n=0, vram1_n=0, oram_n=0, io_n=0, pal_nzw=0;
reg [11:1] pal_maxw=0; reg [11:0] mix_max=0;
always @(posedge clk) begin
    if( |pal_we   ) pal_n   <= pal_n  +1;
    if( |pal_we && |main_dout ) pal_nzw <= pal_nzw+1;
    if( |pal_we && pal_addr>pal_maxw ) pal_maxw <= pal_addr;
    if( |vram_we  ) vram_n  <= vram_n +1;
    if( |vram1_we ) vram1_n <= vram1_n+1;
    if( |oram_we  ) oram_n  <= oram_n +1;
    if( gga_we    ) io_n    <= io_n   +1;
end
// renderer probes: pixels with a non-zero palette index, non-zero palette
// data, and non-zero RGB. Splits "no pixels drawn" from "palette is black".
integer idx_nz=0, pal_nz=0, rgb_nz=0, pxl_n=0;
always @(posedge clk) if( pxl_cen ) begin
    pxl_n <= pxl_n+1;
    if( |mix_addr ) idx_nz <= idx_nz+1;
    if( mix_addr>mix_max ) mix_max <= mix_addr;
    if( |mix_pal  ) pal_nz <= pal_nz+1;
    if( |{red,green,blue} ) rgb_nz <= rgb_nz+1;
end
always @(negedge LVBL) begin
    $display("writes pal=%0d vram0=%0d vram1=%0d oram=%0d gga=%0d",
        pal_n, vram_n, vram1_n, oram_n, io_n);
    $display("render pxl=%0d idx_nz=%0d pal_nz=%0d rgb_nz=%0d | pal writes nonzero=%0d maxwaddr=%0h | mix_addr max=%0h",
        pxl_n, idx_nz, pal_nz, rgb_nz, pal_nzw, pal_maxw, mix_max);
    pxl_n=0; idx_nz=0; pal_nz=0; rgb_nz=0;
end
`endif

jtpspike_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),
    .prog_addr  ( prog_addr[2:0]),
    .prog_data  ( prog_data     ),
    .pspikes    ( pspikes       ),
    .turbofrc   ( turbofrc      ),
    .aerofgt    ( aerofgt       ),
    .karatblz   ( karatblz      )
);

jtpspike_main u_main(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .LVBL       ( LVBL          ),
    .dip_pause  ( dip_pause     ),

    .main_addr  ( main_addr     ),
    .main_dout  ( main_dout     ),
    .main_rnw   ( main_rnw      ),
    .main_dsn   ( main_dsn      ),
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    .ram_we     ( ram_we        ),
    .vram_we    ( vram_we       ),
    .rascr_we   ( rascr_we      ),
    .oram_we    ( oram_we       ),
    .lut_we     ( lut_we        ),
    .pal_we     ( pal_we        ),
    .ram_dout   ( ram_dout      ),
    .vram_dout  ( vram_dout     ),
    .rascr_dout ( rascr_dout    ),
    .oram_dout  ( oram_dout     ),
    .lut_dout   ( lut_dout      ),
    .pal_dout   ( pal_dout      ),

    .turbofrc   ( turbofrc      ),
    .karatblz   ( karatblz      ),
    .aerofgt    ( aerofgt       ),
    .gfxbank    ( gfxbank       ),
    .charbank   ( charbank      ),
    .objbank    ( objbank       ),
    .flip       ( flip          ),
    .scry       ( scry          ),
    .scrx1      ( scrx1         ),
    .scrx0      ( scrx0         ),
    .scry1      ( scry1         ),
    .ram2_we    ( ram2_we       ),
    .vram1_we   ( vram1_we      ),
    .oram1_we   ( oram1_we      ),
    .lut1_we    ( lut1_we       ),
    .ram2_dout  ( ram2_dout     ),
    .vram1_dout ( vram1_dout    ),
    .lut1_dout  ( lut1_dout     ),

    .gga_cs     ( gga_cs        ),
    .gga_we     ( gga_we        ),
    .gga_addr   ( gga_addr      ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),

    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .joystick3  ( joystick3     ),
    .joystick4  ( joystick4     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .dip_test   ( dip_test      ),
    .dipsw      ( dipsw[15:0]   )
);

jtpspike_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .turbofrc   ( turbofrc      ),
    .aerofgt    ( aerofgt       ),
    .karatblz   ( karatblz      ),
    .gga_cs     ( gga_cs        ),
    .gga_we     ( gga_we        ),
    .gga_addr   ( gga_addr      ),
    .gga_din    ( main_dout[7:0]),
    .gfxbank    ( gfxbank       ),
    .charbank   ( charbank      ),
    .objbank    ( objbank       ),
    .flip       ( flip          ),
    .scry       ( scry          ),
    .scrx1      ( scrx1         ),
    .scrx0      ( scrx0         ),
    .scry1      ( scry1         ),

    .scr_addr   ( scr_addr      ),
    .scr_vram   ( scr_vram      ),
    .scr1v_addr ( scr1v_addr    ),
    .scr1_vram  ( scr1_vram     ),
    .ras_addr   ( ras_addr      ),
    .ras_dout   ( ras_dout      ),
    .objr_addr  ( objr_addr     ),
    .objr_dout  ( objr_dout     ),
    .objr1_addr ( objr1_addr    ),
    .objr1_dout ( objr1_dout    ),
    .objl_addr  ( objl_addr     ),
    .objl_dout  ( objl_dout     ),
    .objl1_addr ( objl1_addr    ),
    .objl1_dout ( objl1_dout    ),
    .mix_addr   ( mix_addr      ),
    .mix_pal    ( mix_pal       ),

    .scr0_addr  ( scr0_addr     ),
    .scr0_cs    ( scr0_cs       ),
    .scr0_data  ( scr0_data     ),
    .scr0_ok    ( scr0_ok       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_cs    ( scr1_cs       ),
    .scr1_data  ( scr1_data     ),
    .scr1_ok    ( scr1_ok       ),

    .obj0_addr  ( obj0_addr     ),
    .obj0_cs    ( obj0_cs       ),
    .obj0_data  ( obj0_data     ),
    .obj0_ok    ( obj0_ok       ),
    .obj1_addr  ( obj1_addr     ),
    .obj1_cs    ( obj1_cs       ),
    .obj1_data  ( obj1_data     ),
    .obj1_ok    ( obj1_ok       ),

    .gfx_en     ( gfx_en        ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

jtpspike_snd u_snd(
    .rst        ( rst48         ),
    .clk        ( clk48         ),
    .snd_cen    ( karatblz ? snd4_cen : snd_cen ), // 8MHz/2 vs 20MHz/4
    .fm_cen     ( fm_cen        ),

    .snd_latch  ( snd_latch     ),
    .snd_wr     ( snd_wr        ),
    .snd_pending( snd_pending   ),
    .LVBL_snd   ( LVBL          ),
    .aerofgt    ( aerofgt       ),
    .debug_bus  ( debug_bus     ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcma_addr  ( pcma_addr     ),
    .pcma_cs    ( pcma_cs       ),
    .pcma_data  ( pcma_data     ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_cs    ( pcmb_cs       ),
    .pcmb_data  ( pcmb_data     ),

    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          )
);

endmodule
