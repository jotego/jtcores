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
    Date: 2-12-2019 */

module jtdd2_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire       [12:0]  cpu_AB;
wire               cram_cs, vram_cs, oram_cs, pal_cs;
wire               cpu_wrn;
wire       [ 7:0]  cpu_dout;
wire       [ 7:0]  char_dout, scr_dout, pal_dout;
// video signals
wire               VBL, IMS, H8, flip;
// Sound
wire               mcu_rstb, snd_irq;
wire       [ 7:0]  snd_latch;
// DIP
wire       [ 7:0]  dipsw_a, dipsw_b;
// MCU
wire               mcu_irqmain, mcu_halt, com_cs, mcu_nmi_set, mcu_ban;
wire       [ 7:0]  mcu_ram;

wire       [ 8:0]  scrhpos, scrvpos;

wire cpu_cen;
wire turbo;

assign turbo      = status[13];
assign dip_flip   = flip;
assign debug_view = 0;
assign scr_cs     = LVBL;
assign main_dout  = cpu_dout;
assign oram_we    = oram_cs & ~cpu_wrn;
assign cram_we    = {2{cram_cs & ~cpu_wrn}} & { ~main_addr[0], main_addr[0]};
assign char_dout  = main_addr[0] ? char16_dout[7:0] : char16_dout[15:8];

`ifndef NOMAIN
wire main_cen = turbo ? 1'd1 : cen12;

jtdd_main u_main(
    .clk            ( clk24         ),  // slower clock to ease synthesis
    .rst            ( rst24         ),
    .cen12          ( main_cen      ),
    .cpu_cen        ( cpu_cen       ),
    .VBL            ( VBL           ),
    .IMS            ( IMS           ), // =VPOS[3]
    // MCU
    .mcu_irqmain    ( mcu_irqmain   ),
    .mcu_halt       ( mcu_halt      ),
    .mcu_ban        ( mcu_ban       ),
    .com_cs         ( com_cs        ),
    .mcu_nmi_set    ( mcu_nmi_set   ),
    .mcu_ram        ( mcu_ram       ),
    // Palette
    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    .flip           ( flip          ),
    // Sound
    .mcu_rstb       ( mcu_rstb      ),
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // Characters
    .char_dout      ( char_dout     ),
    .cpu_dout       ( cpu_dout      ),
    .cram_cs        ( cram_cs       ),
    // Objects
    .obj_dout       ( obj_dout      ),
    .oram_cs        ( oram_cs       ),
    // scroll
    .scr_dout       ( scr_dout      ),
    .vram_cs        ( vram_cs       ),
    .scrhpos        ( scrhpos       ),
    .scrvpos        ( scrvpos       ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    // BUS sharing
    .cpu_AB         ( cpu_AB        ),
    .RnW            ( cpu_wrn       ),
    // ROM access
    .rom_cs         ( main_cs       ),
    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .service        ( service       ),
    .dipsw_a        ( dipsw[ 7:0]   ),
    .dipsw_b        ( dipsw[15:8]   )
);
`else
assign main_cs   = 1'b0;
assign main_addr = 18'd0;
assign cram_cs   = 1'b0;
assign vram_cs   = 1'b0;
assign oram_cs   = 1'b0;
assign pal_cs    = 1'b0;
assign mcu_cs    = 1'b0;
assign flip      = 1'b0;
assign cpu_AB    = 13'd0;
assign cpu_wrn   = 1'b1;
assign scrhpos   = 9'h0;
assign scrvpos   = 9'h0;
assign mcu_rstb  = 1'b0;

    `ifndef SIMULATION
    assign snd_latch = 8'd0;
    assign snd_irq   = 1'b0;
    `else
    reg [7:0] snd_latch2;
    reg       snd_irq2;
    assign snd_latch = snd_latch2;
    assign snd_irq   = snd_irq2;
    initial begin
        snd_latch2 = 8'hfe;
        snd_irq2   = 1'b0;
        #11_000_000 snd_latch2 = 8'h3a; // coin sound
        snd_irq2 = 1'b1;
        #100_000 snd_irq2 = 1'b0;
        snd_latch2 = 8'hfe;
    end
    `endif
`endif

`ifndef NOMCU
wire mcu_cen = turbo ? cen8 : cen4;

jtdd2_sub u_sub(
    .clk          (  clk24           ), // slower clock
    .rst          (  rst24           ),
    .mcu_rstb     (  mcu_rstb        ),
    .cen4         (  mcu_cen         ),
    .main_cen     (  cpu_cen         ),
    // CPU bus
    .main_AB      (  cpu_AB[8:0]     ),
    .main_wrn     (  cpu_wrn         ),
    .main_dout    (  cpu_dout        ),
    .shared_dout  (  mcu_ram         ),
    // CPU Interface
    .com_cs       (  com_cs          ),
    .mcu_nmi_set  (  mcu_nmi_set     ),
    .mcu_halt     (  mcu_halt        ),
    .mcu_irqmain  (  mcu_irqmain     ),
    .mcu_ban      (  mcu_ban         ),
    // PROM programming
    .rom_addr     (  mcu_addr        ),
    .rom_data     (  mcu_data        ),
    .rom_cs       (  mcu_cs          ),
    .rom_ok       (  mcu_ok          )
);
`else
reg    irqmain;
assign mcu_irqmain = irqmain;
assign mcu_ban = 1'b0;
always @(posedge clk) irqmain <= mcu_nmi_set;
wire shared_we = com_cs && !cpu_wrn;
jtframe_ram #(.AW(9)) u_shared(
    .clk    ( clk         ),
    .cen    ( cpu_cen     ),
    .data   ( cpu_dout    ),
    .addr   ( cpu_AB[8:0] ),
    .we     ( shared_we   ),
    .q      ( mcu_ram     )
);
`endif

jtdd2_sound u_sound(
    .clk         ( clk           ),
    .rst         ( rst           ),
    .H8          ( H8            ),
    // communication with main CPU
    .snd_irq     ( snd_irq       ),
    .snd_latch   ( snd_latch     ),
    // ROM
    .rom_addr    ( snd_addr      ),
    .rom_cs      ( snd_cs        ),
    .rom_data    ( snd_data      ),
    .rom_ok      ( snd_ok        ),

    .adpcm_addr  ( adpcm_addr    ),
    .adpcm_cs    ( adpcm_cs      ),
    .adpcm_data  ( adpcm_data    ),
    .adpcm_ok    ( adpcm_ok      ),

    // Sound output
    .sound       ( snd           ),
    .sample      ( sample        ),
    .peak        ( game_led      )
);

`ifndef NOVIDEO
jtdd_video u_video(
    .clk          (  clk             ),
    .rst          (  rst             ),
    .pxl_cen      (  pxl_cen         ),
    .cen_Q        (  cpu_cen         ),
    .cpu_AB       (  cpu_AB          ),
    .pal_cs       (  pal_cs          ),
    .vram_cs      (  vram_cs         ),
    .cpu_wrn      (  cpu_wrn         ),
    .cpu_dout     (  cpu_dout        ),
    .scr_dout     (  scr_dout        ),
    .pal_dout     (  pal_dout        ),
    // Scroll position
    .scrhpos      ( scrhpos          ),
    .scrvpos      ( scrvpos          ),
    // video signals
    .VBL          (  VBL             ),
    .LVBL         (  LVBL            ),
    .LHBL         (  LHBL            ),
    .VS           (  VS              ),
    .HS           (  HS              ),
    .IMS          (  IMS             ),
    .flip         (  flip            ),
    .H8           (  H8              ),
    // Video RAM
    .oram_addr    ( oram_addr        ),
    .oram_data    ( oram_dout        ),
    .cram_addr    (  cram_addr       ),
    .cram_data    (  cram_dout       ),
    // ROM access
    .char_addr    (  char_addr       ),
    .char_data    (  char_data       ),
    .char_cs      (  char_cs         ),
    .char_ok      (  char_ok         ),
    .scr_addr     (  scr_addr        ),
    .scr_data     (  scr_data        ),
    .scr_ok       (  scr_ok          ),
    .obj_cs       (  obj_cs          ),
    .obj_addr     (  obj_addr        ),
    .obj_data     (  obj_data        ),
    .obj_ok       (  obj_ok          ),
    // PROM programming
    .prog_addr    (  prog_addr[7:0]  ),
    .prom_prio_we (  prom_we         ),
    .prom_din     (  prog_data[3:0]  ),
    // Pixel output
    .red          (  red             ),
    .green        (  green           ),
    .blue         (  blue            ),
    // Debug
    .gfx_en       (  gfx_en          ),
    .debug_bus    ( debug_bus        )
);
`else
assign red   = 4'd0;
assign blue  = 4'd0;
assign green = 4'd0;
assign char_addr = 16'd0;
assign scr_addr  = 17'd0;
assign obj_addr  = 19'd0;
`endif

endmodule
