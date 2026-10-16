module jtseicro_game(
    `include "jtframe_game_ports.inc"
);

wire [15:0] cpu_addr;
wire [7:0] cpu_dout, ay_data, main_debug, mcu_debug;
wire ay_bdir, ay_bc1, irq_en, flip, mcu_reset, mcu_run, cpu_lvbl;
wire watchdog_clr;
wire video_flip=flip ^ dip_flip;
reg nsc8105;
wire [9:0] psg;
wire [3:0] dac;
wire signed [10:0] psg_ac=$signed({1'b0,psg})-11'sd512;
wire signed [5:0] dac_ac=$signed({1'b0,dac,1'b0})-6'sd15;

always @(posedge clk) begin
    if(prog_we && header && prog_addr==0) nsc8105<=prog_data[0];
end

`ifdef SIMSCENE
always @(posedge clk) begin
    if(!rst && (sharedram_we || videoram_we || colorram_we ||
       spriteram0_we || spriteram1_we || row_scroll_we ||
       mcu_sharedram_we || maincpu_cs || mcu_cs || snd!=0))
        $fatal(1,"SEICRO_SCENE_ACTIVITY");
end
`endif

assign sharedram_addr=cpu_addr[10:0];
assign videoram_addr=cpu_addr[9:0];
assign colorram_addr={cpu_addr[9:6],cpu_addr[4:0]};
assign spriteram0_addr=cpu_addr[6:0]-7'h20;
assign spriteram1_addr=cpu_addr[4:0];
assign row_scroll_addr=cpu_addr[4:0];
assign sharedram_din=cpu_dout;
assign videoram_din=cpu_dout;
assign colorram_din=cpu_dout;
assign spriteram0_din=cpu_dout;
assign spriteram1_din=cpu_dout;
assign row_scroll_din=cpu_dout;
assign debug_view=debug_bus[0] ? mcu_debug : main_debug;
`ifndef NOSOUND
assign snd=($signed({{5{psg_ac[10]}},psg_ac}) <<< 4) +
           ($signed({{10{dac_ac[5]}},dac_ac}) <<< 8);
`else
assign snd=0;
`endif

jtseicro_main u_main(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .cpu_cen         ( cpu_cen         ),
    .dip_pause       ( dip_pause       ),
    .LVBL            ( cpu_lvbl        ),
    .irq_en          ( irq_en          ),
    .cab_1p          ( cab_1p[1:0]     ),
    .coin            ( coin[1:0]       ),
    .joystick1       ( joystick1       ),
    .joystick2       ( joystick2       ),
    .service         ( service         ),
    .dip_test        ( dip_test        ),
    .test_dip        ( dipsw[25:24]    ),
    .cpu_addr        ( cpu_addr        ),
    .cpu_dout        ( cpu_dout        ),
    .sharedram_we    ( sharedram_we    ),
    .videoram_we     ( videoram_we     ),
    .colorram_we     ( colorram_we     ),
    .spriteram0_we   ( spriteram0_we   ),
    .spriteram1_we   ( spriteram1_we   ),
    .row_scroll_we   ( row_scroll_we   ),
    .sharedram_dout  ( sharedram_dout  ),
    .videoram_dout   ( videoram_dout   ),
    .colorram_dout   ( colorram_dout   ),
    .spriteram0_dout ( spriteram0_dout ),
    .row_scroll_dout ( row_scroll_dout ),
    .rom_addr        ( maincpu_addr    ),
    .rom_cs          ( maincpu_cs      ),
    .rom_data        ( maincpu_data    ),
    .rom_ok          ( maincpu_ok      ),
    .ay_bdir         ( ay_bdir         ),
    .ay_bc1          ( ay_bc1          ),
    .ay_data         ( ay_data         ),
    .watchdog_clr    ( watchdog_clr    ),
    .debug_view      ( main_debug      )
);

`ifndef NOSOUND
jtseicro_mcu u_mcu(
    .rst         ( rst                ),
    .clk         ( clk                ),
    .cen         ( cpu_cen            ),
    .run         ( mcu_run            ),
    .reset_req   ( mcu_reset          ),
    .dip_pause   ( dip_pause          ),
    .nsc8105     ( nsc8105            ),
    .dipsw       ( dipsw[23:0]        ),
    .rom_addr    ( mcu_addr           ),
    .rom_cs      ( mcu_cs             ),
    .rom_data    ( mcu_data           ),
    .rom_ok      ( mcu_ok             ),
    .shared_addr ( mcu_sharedram_addr ),
    .shared_din  ( mcu_sharedram_din  ),
    .shared_we   ( mcu_sharedram_we   ),
    .shared_dout ( mcu_sharedram_dout ),
    .dac         ( dac                ),
    .debug_view  ( mcu_debug          )
);
`else
assign mcu_addr = 0;
assign mcu_cs = 0;
assign mcu_sharedram_addr = 0;
assign mcu_sharedram_din = 0;
assign mcu_sharedram_we = 0;
assign dac = 0;
assign mcu_debug = 0;
`endif

jtseicro_snd u_snd(
    .rst       ( rst          ),
    .clk       ( clk          ),
    .audio_cen ( audio_cen    ),
    .bdir      ( ay_bdir      ),
    .bc1       ( ay_bc1       ),
    .cpu_dout  ( cpu_dout     ),
    .cpu_din   ( ay_data      ),
    .debug_dip ( dipsw[31:24] ),
    .irq_en    ( irq_en       ),
    .flip      ( flip         ),
    .mcu_reset ( mcu_reset    ),
    .mcu_run   ( mcu_run      ),
    .psg       ( psg          ),
    .sample    ( sample       )
);

jtseicro_video u_video(
    .rst               ( rst               ),
    .clk               ( clk               ),
    .pxl_cen           ( pxl_cen           ),
    .flip              ( video_flip        ),
    .HS                ( HS                ),
    .VS                ( VS                ),
    .LHBL              ( LHBL              ),
    .LVBL              ( LVBL              ),
    .cpu_lvbl          ( cpu_lvbl          ),
    .tile_vram_addr    ( tile_vram_addr    ),
    .tile_color_addr   ( tile_color_addr   ),
    .tile_vram_data    ( tile_vram_data    ),
    .tile_color_data   ( tile_color_data   ),
    .scroll_video_addr ( scroll_video_addr ),
    .scroll_video_data ( scroll_video_data ),
    .obj_ram0_addr     ( obj_ram0_addr     ),
    .obj_ram1_addr     ( obj_ram1_addr     ),
    .obj_ram0_data     ( obj_ram0_data     ),
    .obj_ram1_data     ( obj_ram1_data     ),
    .scr_addr          ( scr_addr          ),
    .obj_addr          ( obj_addr          ),
    .scr_cs            ( scr_cs            ),
    .obj_cs            ( obj_cs            ),
    .scr_data          ( scr_data          ),
    .obj_data          ( obj_data          ),
    .scr_ok            ( scr_ok            ),
    .obj_ok            ( obj_ok            ),
    .proms_addr        ( proms_addr        ),
    .proms_data        ( proms_data        ),
    .red               ( red               ),
    .green             ( green             ),
    .blue              ( blue              ),
    .gfx_en            ( gfx_en            )
);

endmodule
