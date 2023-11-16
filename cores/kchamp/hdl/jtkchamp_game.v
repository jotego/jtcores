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
    Date: 15-8-2022 */

module jtkchamp_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM offsets
localparam [21:0] SND_START   =  `SND_START,
                  CHAR_START  =  `CHAR_START,
                  OBJ_START   =  `OBJ_START;
localparam [24:0] PROM_START  =  `JTFRAME_PROM_START;

wire        main_cs, main_ok, link_joys;
reg         enc;    // main CPU data is encrypted

wire [13:0] char_addr;
wire [14:0] obj_addr;
wire [15:0] char_data;
wire [31:0] obj_data;
wire        char_cs, char_ok, obj_ok, obj_cs,
            vram_bsy, oram_cs;

wire [ 7:0] main_data, nc2;
wire        nc3;
wire [15:0] main_addr;

wire        cpu_cen, pcm_cen, psg_cen, nc, snd_cen, ntsc_cen;
wire        cpu_rnw, cpu_irqn, cpu_nmin;
wire        vram_cs, objram_cs,
            prom_we, flip, main_flip;
wire [ 7:0] vram_dout, obj_dout, cpu_dout;

// Sound
wire [15:0] snd_addr;
wire [ 7:0] snd_data;
wire        snd_ok, snd_cs;
wire [ 7:0] snd_latch;
wire        snd_rstn, snd_req, v6;

reg  [24:0] dwn_addr;
wire [ 7:0] pre_data;

assign prog_rd    = 0;
assign dwnld_busy = ioctl_rom;
assign flip       = ~dip_flip ^ ~main_flip;
assign debug_view = {3'd0, enc, 2'd0, link_joys, flip};
assign link_joys  = dipsw[8];

reg  [25:0] post_addr;
wire        is_obj = ioctl_addr[21:0] >= OBJ_START && ioctl_addr[21:0]<PROM_START[21:0];

always @(*) begin
    post_addr = ioctl_addr;
    if( is_obj ) begin
        post_addr[0]     =~ioctl_addr[13]; // pixels 8-15
        post_addr[1]     = ioctl_addr[16]; // bit plane
        post_addr[14:2]  = ioctl_addr[12:0];
        post_addr[16:15] = ioctl_addr[15:14];
    end
end

always @(posedge clk) begin
    if( ioctl_addr==0 && ioctl_wr ) enc <= ioctl_dout==8'h69;
end

// The sound CPU clock speed on the discrete DAC systems is a guess
// The 3MHz that the schematics show for the OKI version result in
// very slow voice effects for the DAC ones. Using 3.57MHz, an educated guess,
// gives more decent sound

assign snd_cen = enc ? cpu_cen : ntsc_cen;

jtframe_frac_cen #(.W(4),.WC(4)) u_cpu_cen(
    .clk    ( clk24 ),
    .n      ( 4'd1  ),
    .m      ( 4'd8  ),
    .cen    ( { pcm_cen, nc, psg_cen, cpu_cen }  ),
    .cenb   (       )
);

jtframe_frac_cen #(.W(2),.WC(6)) u_snd_cen(
    .clk    ( clk24 ),
    .n      ( 6'd7   ),
    .m      ( 6'd47  ),
    .cen    ( { nc3, ntsc_cen }  ),
    .cenb   (       )
);

`ifndef NOMAIN
jtkchamp_main u_main(
    .rst            ( rst24         ),
    .clk            ( clk24         ),        // 24 MHz
    .cen_3          ( cpu_cen       ),
    // ROM
    .bus_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    .enc            ( enc           ),
    .link_joys      ( link_joys     ),
    // cabinet I/O
    .game_start     ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    // GFX
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),

    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),
    .vram_bsy       ( vram_bsy      ),

    .oram_cs        ( oram_cs       ),
    .oram_dout      ( obj_dout      ),
    // Sound control
    .snd_latch      ( snd_latch     ),
    .snd_req        ( snd_req       ),
    .snd_rstn       ( snd_rstn      ),
    // GFX configuration
    .flip           ( main_flip     ),
    // interrupt triggers
    .LVBL           ( LVBL          ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[7:0]    )
);
`else
    assign main_cs   = 0;
    assign oram_cs   = 0;
    assign vram_cs   = 0;
    assign cpu_rnw   = 1;
    assign main_addr = 0;
    assign cpu_dout  = 0;
    assign main_flip = 1;
`endif

`ifndef NOSOUND
jtkchamp_snd u_sound(
    .rst        ( rst24     ),
    .clk        ( clk24     ),
    .cen_3      ( snd_cen   ),
    .pcm_cen    ( pcm_cen   ),
    .psg_cen    ( psg_cen   ),
    .enc        ( enc       ),
    .v6         ( v6        ), // 2x frame rate
    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    // From main CPU
    .snd_latch  ( snd_latch ),
    .snd_rstn   ( snd_rstn  ),
    .snd_req    ( snd_req   ),
    // Sound
    .snd        ( snd       ),
    .sample     ( sample    ),
    .peak       ( game_led  )
);
`else
    assign snd_cs=0;
    assign snd_addr=0;
    assign snd=0;
    assign sample=0;
    assign game_led=0;
`endif

jtkchamp_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // configuration
    .flip       ( flip      ),
    .enc        ( enc       ),
    .v6         ( v6        ),

    // CPU interface
    .cpu_addr   ( main_addr[10:0] ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    // Scroll
    .vram_cs    ( vram_cs   ),
    .vram_dout  ( vram_dout ),
    .vram_bsy   ( vram_bsy  ),
    // Objects
    .oram_cs    ( oram_cs   ),
    .obj_dout   ( obj_dout  ),

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prog_addr[9:0] ),
    .prom_we    ( prom_we   ),

    // Scroll
    .char_addr  ( char_addr ),
    .char_data  ( char_data ),
    .char_ok    ( char_ok   ),
    .char_cs    ( char_cs   ),
    // Objects
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_cs     ( obj_cs    ),
    .obj_ok     ( obj_ok    ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

/* verilator tracing_off */

jtframe_dwnld #(.PROM_START(PROM_START),.SWAB(1))
u_dwnld(
    .clk            ( clk           ),
    .ioctl_rom      ( ioctl_rom     ),
    .ioctl_addr     ( post_addr     ),
    .ioctl_dout     ( ioctl_dout    ),
    .ioctl_wr       ( ioctl_wr      ),
    .prog_addr      ( prog_addr     ),
    .prog_data      ({nc2,prog_data}),
    .prog_mask      ( prog_mask     ), // active low
    .prog_we        ( prog_we       ),
    .prom_we        ( prom_we       ),
    .sdram_ack      ( sdram_ack     ),
    // Unused:
    .header         (               ),
    .gfx8_en        ( 1'b0          ),
    .gfx16_en       ( 1'b0          )
);

jtframe_rom #(
    .SLOT0_AW    ( 14              ),
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( CHAR_START>>1   ),

    .SLOT1_AW    ( 16              ),
    .SLOT1_DW    ( 32              ),
    .SLOT1_OFFSET( OBJ_START>>1    ),

    .SLOT6_AW    ( 16              ),
    .SLOT6_DW    (  8              ),
    .SLOT6_OFFSET( SND_START>>1    ), // Sound CPU

    .SLOT7_AW    ( 16              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              )  // Main
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( obj_cs        ),
    .slot2_cs    ( 1'b0          ),
    .slot3_cs    ( 1'b0          ),
    .slot4_cs    ( 1'b0          ),
    .slot5_cs    ( 1'b0          ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b0          ),

    .slot0_ok    ( char_ok        ),
    .slot1_ok    ( obj_ok        ),
    .slot2_ok    (               ),
    .slot3_ok    (               ),
    .slot4_ok    (               ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    (               ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ({obj_addr,1'b0}),
    .slot2_addr  (               ),
    .slot3_addr  (               ),
    .slot4_addr  (               ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  (               ),

    .slot0_dout  ( char_data      ),
    .slot1_dout  ( obj_data      ),
    .slot2_dout  (               ),
    .slot3_dout  (               ),
    .slot4_dout  (               ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  (               ),

    // SDRAM interface
    .sdram_rd    ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule
