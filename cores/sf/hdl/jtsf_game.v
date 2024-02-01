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
    Date: 17-8-2020 */

`ifndef SIM_SCR1POS
    `define SIM_SCR1POS 0
`endif

`ifndef SIM_SCR2POS
    `define SIM_SCR2POS 0
`endif

module jtsf_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam
    MAINW = 19, // 16 bit
    RAMW  = 15, // 32k x 16 bits
    CHARW = 13, // 16 bit reads
    MAP1W = 16, // 128 kBytes read in 16-bit words -> 64kW = 2^16
    MAP2W = MAP1W,
    SCR1W = 19,
    SCR2W = 18,
    SND1W = 15, // 32 kB
    SND2W = 18, // 256 kB
    MCUW  = 12, // 4kB
    OBJW  = 21;

localparam [24:0] MAIN_OFFSET = 25'h0,
                  RAM_OFFSET  = 25'h4_0000,
                  // Bank 1
                  BA1_START   = 25'h6_0000,
                  SND_OFFSET  = 25'h0,
                  SND2_OFFSET = 25'h8000 >> 1,
                  MCU_OFFSET  = 25'h4_8000 >> 1,
                  // Bank 2
                  BA2_START   = 25'hA_8000,
                  MAP1_OFFSET = 25'h0,
                  MAP2_OFFSET = 25'h2_0000 >> 1,
                  CHAR_OFFSET = 25'h4_0000 >> 1,
                  // Bank 3
                  BA3_START   = 25'hE_C000,
                  SCR1_OFFSET = 25'h0,
                  SCR2_OFFSET = 25'h10_0000 >> 1,
                  OBJ_START   = 25'h26_C000,
                  OBJ_OFFSET  = 25'h18_0000 >> 1,
                  PROM_START  = 25'h42_C000;

wire [ 8:0] V;
wire [ 8:0] H;

wire [13:1] cpu_AB;
wire        main_cs, ram_cs,
            snd1_cs, snd2_cs,
            char_cs, col_uw,  col_lw;
wire        charon, scr1on, scr2on, objon;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire [15:0] scr1posh, scr2posh;
wire        rd, cpu_cen;
wire        char_busy;

// RAM
wire        ram_we;
wire [ 1:0] ram_dsn;
wire [15:0] ram_din;
// ROM data
wire [15:0] char_data, scr1_data, scr2_data, obj_data;
wire [15:0] main_data, ram_data;
wire [31:0] map1_data, map2_data;
wire [ 7:0] snd1_data, snd2_data;
// MCU interface
wire [15:0]  mcu_din;
wire [ 7:0]  mcu_dout;
wire         mcu_wr, mcu_acc;
wire [15:1]  mcu_addr;
wire         mcu_brn, mcu_DMAONn, mcu_ds;

// ROM addresses
wire [MAINW  :1] main_addr;
wire [RAMW   :1] ram_addr;
wire [SND1W-1:0] snd1_addr;
wire [SND2W-1:0] snd2_addr;
wire [MAP1W-1:0] map1_addr;
wire [MAP2W-1:0] map2_addr;
wire [CHARW-1:0] char_addr;
wire [SCR1W-1:0] scr1_addr;
wire [SCR2W-1:0] scr2_addr;
wire [OBJW-1 :0] obj_addr;

wire [15:0] dipsw_a, dipsw_b;

wire        main_ok, ram_ok,  map1_ok, map2_ok, scr1_ok, scr2_ok,
            snd1_ok, snd2_ok, obj_ok, char_ok;

reg snd_rst, video_rst, main_rst; // separate reset signals to aid recovery time
reg vrom_cs;
reg game_id=0; // 1 for SFJ style inputs

// A and B are inverted in this game (or in MAME definition)
assign {dipsw_a, dipsw_b} = dipsw[31:0];
assign dwnld_busy         = ioctl_rom;
assign ba_wr[3:1]         = 0;
assign ba1_din = 0, ba2_din = 0, ba3_din = 0,
       ba1_dsn = 3, ba2_dsn = 3, ba3_dsn = 3;
assign debug_view = 0;
assign dip_flip = flip;

always @(negedge clk) begin
    snd_rst   <= rst;
end

always @(negedge clk) begin
    main_rst  <= rst;
    video_rst <= rst;
end

always @(posedge clk) begin
    vrom_cs <= LVBL || (V==9'hf0 || V==9'hf );
end

/////////////////////////////////////
// 48 MHz based clock enable signals
`ifndef JTFRAME_CLK96
jtframe_cen48 u_cen48(
    .clk    ( clk           ),
    .cen16  ( pxl2_cen      ),
    .cen16b (               ),
    .cen12  (               ),
    .cen12b (               ),
    .cen8   ( pxl_cen       ),
    .cen6   (               ),
    .cen6b  (               ),
    .cen4   (               ),
    .cen4_12(               ),
    .cen3   (               ),
    .cen3q  (               ),
    .cen3qb (               ),
    .cen3b  (               ),
    .cen1p5 (               ),
    .cen1p5b(               )
);
`else
jtframe_cen96 u_cen96(
    .clk    ( clk           ),
    .cen16  ( pxl2_cen      ),
    .cen8   ( pxl_cen       )
);
`endif

wire       RnW;
// sound
wire [7:0] snd_latch;
wire       snd_nmi_n;

// OBJ
wire        OKOUT, blcnten, obj_br, bus_ack;
wire [12:0] obj_AB;
wire [15:0] oram_dout;

wire [21:0] pre_prog;
wire        prom_we, prog_obj;

// Optimize cache use for object ROMs
assign prog_obj  = ioctl_addr[24:0]>=OBJ_START && ioctl_addr[24:0]<PROM_START;
assign prog_addr = prog_obj ?
    { pre_prog[21:6],pre_prog[4:1],pre_prog[5],pre_prog[0]} :
    pre_prog;

// This distinguishes the games using SFJ-style input from the rest
always @(posedge clk) begin
    if( ioctl_addr==26'h19910 && ioctl_wr )
        game_id <= ioctl_dout==6;
end

jtframe_dwnld #(
    .PROM_START ( PROM_START ),
    .BA1_START  ( BA1_START  ),
    .BA2_START  ( BA2_START  ),
    .BA3_START  ( BA3_START  )
) u_dwnld(
    .clk         ( clk           ),
    .ioctl_rom   ( ioctl_rom     ),

    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_dout  ( ioctl_dout    ),
    .ioctl_wr    ( ioctl_wr      ),

    .prog_addr   ( pre_prog      ),
    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_we     ( prog_we       ),
    .prog_rd     ( prog_rd       ),
    .prog_ba     ( prog_ba       ),
    .prom_we     ( prom_we       ),

    .sdram_ack   ( prog_rdy      ),
    .header      (               ),
    .gfx8_en     ( 1'b0          ),
    .gfx16_en    ( 1'b0          )
);

wire [15:0] scrposh, scrposv, dmaout;
wire        UDSWn, LDSWn;
wire [ 1:0] dsn;

assign dsn = {UDSWn, LDSWn};

`ifndef NOMAIN
jtsf_main #( .MAINW(MAINW), .RAMW(RAMW) ) u_main (
    .rst        ( main_rst      ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .game_id    ( game_id       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    .snd_nmi_n  ( snd_nmi_n     ),
    // CPU data bus
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_dout  ( char_dout     ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    // SCROLL
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    // GFX enable signals
    .charon     ( charon        ),
    .scr1on     ( scr1on        ),
    .scr2on     ( scr2on        ),
    .objon      ( objon         ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .dmaout     ( dmaout        ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .obj_br     ( obj_br        ),
    .bus_ack    ( bus_ack       ),
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    // MCU interface
    .mcu_din    ( mcu_din       ),
    .mcu_dout   ( mcu_dout      ),
    .mcu_wr     ( mcu_wr        ),
    .mcu_acc    ( mcu_acc       ),
    .mcu_addr   ( mcu_addr      ),
    .mcu_brn    ( mcu_brn       ),
    .mcu_DMAONn ( mcu_DMAONn    ),
    .mcu_ds     ( mcu_ds        ),
    // ROM
    .addr       ( main_addr     ),
    // RAM
    .ram_cs     ( ram_cs        ),
    .ram_addr   ( ram_addr      ),
    .ram_data   ( ram_data      ),
    .ram_din    ( ram_din       ),
    .ram_dsn    ( ram_dsn       ),
    .ram_we     ( ram_we        ),
    .ram_ok     ( ram_ok        ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
    `ifndef SIM_SND_LATCH
    `define SIM_SND_LATCH 8'd0
    `endif
    assign main_addr = {MAINW{1'b0}};
    assign cpu_AB    = 13'd0;
    assign char_cs   = 0;
    assign main_cs   = 0;
    assign bus_ack   = 1;
    assign flip      = 0;
    assign scr1posh  = `SIM_SCR1POS;
    assign scr2posh  = `SIM_SCR2POS;
    assign cpu_cen   = 0;
    assign charon    = 1;
    assign scr1on    = 1;
    assign scr2on    = 1;
    assign objon     = 1;
    assign snd_latch = `SIM_SND_LATCH;
    `ifdef OBJLOAD
    jtsf_objload u_objload( // this doesn't work after moving OBJ RAM to its own BRAM
        .clk        ( clk       ),
        .rst        ( rst       ),
        .obj_AB     ( obj_AB    ),
        .cen8       ( pxl_cen   ),
        .LVBL       ( LVBL      ),
        .ram_addr   ( ram_addr  ),
        .cpu_dout   ( cpu_dout  ),
        .ram_data   ( ram_data  ),
        .dmaout     ( dmaout    ),
        .UDSWn      ( UDSWn     ),
        .LDSWn      ( LDSWn     ),
        .RnW        ( RnW       ),
        .ram_cs     ( ram_cs    ),
        .OKOUT      ( OKOUT     )
    );
    `else
    assign OKOUT    = 0;
    assign cpu_dout = 16'd0;
    assign RnW      = 1;
    assign UDSWn    = 1;
    assign LDSWn    = 1;
    assign ram_addr = 0;
    assign ram_cs   = 0;
    assign col_uw   = 0;
    assign col_lw   = 0;
    `endif
`endif

`ifndef NOMCU
    jtsf_mcu u_mcu(
        .rst        ( rst24     ),
        .clk        ( clk24     ),
        .clk_rom    ( clk       ),
        .rst_cpu    ( rst       ),
        .clk_cpu    ( clk       ),
        // Main CPU interface
        .mcu_din    ( mcu_din   ),
        .mcu_dout   ( mcu_dout  ),
        .mcu_wr     ( mcu_wr    ),
        .mcu_acc    ( mcu_acc   ),
        .mcu_addr   ( mcu_addr  ),
        .mcu_brn    ( mcu_brn   ),
        .mcu_DMAONn ( mcu_DMAONn),
        .mcu_ds     ( mcu_ds    ),
        .ram_ok     ( ram_ok    ),
        // ROM programming
        .prog_addr  ( prog_addr[11:0] ),
        .prom_din   ( prog_data[7:0]  ),
        .prom_we    ( prom_we         )
    );
`else
    assign mcu_brn = 1;
`endif

jtsf_sound #(
    .SND1W( SND1W ),
    .SND2W( SND2W )
) u_sound (
    .rst            ( snd_rst        ),
    .clk            ( clk            ),
    .pcm_level      ( dip_fxlevel    ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    .snd_nmi_n      ( snd_nmi_n      ),
    // ROM
    .rom_addr       ( snd1_addr      ),
    .rom_data       ( snd1_data      ),
    .rom_cs         ( snd1_cs        ),
    .rom_ok         ( snd1_ok        ),
    // ROM 2
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( snd2_ok        ),
    // sound output
    .left           ( snd_left       ),
    .right          ( snd_right      ),
    .sample         ( sample         ),
    .peak           ( game_led       )
);

`ifndef NOVIDEO
jtsf_video #(
    .CHARW  ( CHARW ),
    .MAP1W  ( MAP1W ),
    .MAP2W  ( MAP2W ),
    .SCR1W  ( SCR1W ),
    .SCR2W  ( SCR2W ),
    .OBJW   ( OBJW  )
) u_video(
    .rst        ( video_rst     ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // GFX enable signals
    .charon     ( charon        ),
    .scr1on     ( scr1on        ),
    .scr2on     ( scr2on        ),
    .objon      ( objon         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL 1
    .map1_data  ( map1_data     ),
    .map1_addr  ( map1_addr     ),
    .map1_ok    ( map1_ok       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1posh   ( scr1posh      ),
    .scr1_ok    ( scr1_ok       ),
    // SCROLL 2
    .map2_data  ( map2_data     ),
    .map2_addr  ( map2_addr     ),
    .map2_ok    ( map2_ok       ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2posh   ( scr2posh      ),
    .scr2_ok    ( scr2_ok       ),
    // OBJ
    .obj_AB     ( obj_AB        ),
    .main_ram   ( dmaout        ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( obj_br        ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    .obj_ok     ( obj_ok        ),
    // PROMs
    // .prog_addr    ( prog_addr[7:0]),
    // .prom_prio_we ( prom_we[0]    ),
    // .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);
`else
// Video module may be ommitted for SDRAM load simulation
assign red       = 4'h0;
assign green     = 4'h0;
assign blue      = 4'h0;
assign obj_addr  = 0;
assign scr1_addr = {SCR1W{1'b0}};
assign scr2_addr = {SCR2W{1'b0}};
assign char_addr = {CHARW{1'b0}};
assign blcnten   = 1'b0;
assign obj_br    = 1'b0;
assign char_busy = 1'b0;
`endif

jtframe_ram1_2slots #(
    .ERASE       (  0            ),
    .SLOT0_AW    ( RAMW          ), // Main CPU RAM
    .SLOT0_DW    ( 16            ),

    .SLOT1_AW    ( MAINW         ), // main ROM
    .SLOT1_DW    ( 16            ),
    .SLOT1_OFFSET( MAIN_OFFSET   ),
    .REF_FILE    ("sdram_bank0.hex")
) u_bank0 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( ram_cs        ),
    .slot0_wen   ( ram_we        ),
    .slot1_cs    ( main_cs       ),
    .slot1_clr   ( 1'b0          ),

    .slot0_ok    ( ram_ok        ),
    .slot1_ok    ( main_ok       ),

    .slot0_offset( RAM_OFFSET[21:0]),

    .slot0_din   ( ram_din       ),
    .slot0_wrmask( ram_dsn       ),
    .hold_rst    (               ),

    .slot0_addr  ( ram_addr      ),
    .slot1_addr  ( main_addr     ),

    .slot0_dout  ( ram_data      ),
    .slot1_dout  ( main_data     ),

    // SDRAM interface
    .sdram_addr  ( ba0_addr      ),
    .sdram_wr    ( ba_wr[0]      ),
    .sdram_rd    ( ba_rd[0]      ),
    .sdram_ack   ( ba_ack[0]     ),
    .data_dst    ( ba_dst[0]     ),
    .data_rdy    ( ba_rdy[0]     ),
    .data_write  ( ba0_din       ),
    .sdram_wrmask( ba0_dsn     ),
    .data_read   ( data_read     )
);

jtframe_rom_2slots #(
    .SLOT0_AW    ( SND1W         ), // Sound 1
    .SLOT0_DW    (  8            ),
    .SLOT0_OFFSET( SND_OFFSET    ),

    .SLOT1_AW    ( SND2W         ), // Sound 2
    .SLOT1_DW    (  8            ),
    .SLOT1_OFFSET( SND2_OFFSET   ),
    .REF_FILE    ("sdram_bank1.hex")
) u_bank1 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( snd1_cs       ),
    .slot1_cs    ( snd2_cs       ),

    .slot0_ok    ( snd1_ok       ),
    .slot1_ok    ( snd2_ok       ),

    .slot0_addr  ( snd1_addr     ),
    .slot1_addr  ( snd2_addr     ),

    .slot0_dout  ( snd1_data     ),
    .slot1_dout  ( snd2_data     ),

    .sdram_addr  ( ba1_addr      ),
    .sdram_rd    ( ba_rd[1]      ),
    .sdram_ack   ( ba_ack[1]     ),
    .data_dst    ( ba_dst[1]     ),
    .data_rdy    ( ba_rdy[1]     ),
    .data_read   ( data_read     )
);

jtframe_rom_3slots #(
    .SLOT0_AW    ( MAP1W         ), // Map 1
    .SLOT0_DW    ( 32            ),
    .SLOT0_OFFSET( MAP1_OFFSET   ),

    .SLOT1_AW    ( MAP2W         ), // Map 2
    .SLOT1_DW    ( 32            ),
    .SLOT1_OFFSET( MAP2_OFFSET   ),

    .SLOT2_AW    ( CHARW         ), // Char
    .SLOT2_DW    ( 16            ),
    .SLOT2_OFFSET( CHAR_OFFSET   ),
    .REF_FILE    ("sdram_bank2.hex")
) u_bank2 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( vrom_cs       ),
    .slot1_cs    ( vrom_cs       ),
    .slot2_cs    ( vrom_cs       ),

    .slot0_ok    ( map1_ok       ),
    .slot1_ok    ( map2_ok       ),
    .slot2_ok    ( char_ok       ),

    .slot0_addr  ( map1_addr     ),
    .slot1_addr  ( map2_addr     ),
    .slot2_addr  ( char_addr     ),

    .slot0_dout  ( map1_data     ),
    .slot1_dout  ( map2_data     ),
    .slot2_dout  ( char_data     ),

    .sdram_addr  ( ba2_addr      ),
    .sdram_rd    ( ba_rd[2]      ),
    .sdram_ack   ( ba_ack[2]     ),
    .data_dst    ( ba_dst[2]     ),
    .data_rdy    ( ba_rdy[2]     ),
    .data_read   ( data_read     )
);

jtframe_rom_3slots #(
    .SLOT0_AW    ( OBJW          ), // Objects
    .SLOT0_DW    ( 16            ),
    .SLOT0_OFFSET( OBJ_OFFSET    ),

    .SLOT1_AW    ( SCR1W         ), // Scroll 1
    .SLOT1_DW    ( 16            ),
    .SLOT1_OFFSET( SCR1_OFFSET   ),

    .SLOT2_AW    ( SCR2W         ), // Scroll 2
    .SLOT2_DW    ( 16            ),
    .SLOT2_OFFSET( SCR2_OFFSET   ),
    .REF_FILE    ("sdram_bank3.hex")
) u_bank3 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( vrom_cs       ),
    .slot1_cs    ( vrom_cs       ),
    .slot2_cs    ( vrom_cs       ),

    .slot0_ok    ( obj_ok        ),
    .slot1_ok    ( scr1_ok       ),
    .slot2_ok    ( scr2_ok       ),

    .slot0_addr  ( obj_addr      ),
    .slot1_addr  ( scr1_addr     ),
    .slot2_addr  ( scr2_addr     ),

    .slot0_dout  ( obj_data      ),
    .slot1_dout  ( scr1_data     ),
    .slot2_dout  ( scr2_data     ),

    .sdram_addr  ( ba3_addr      ),
    .sdram_rd    ( ba_rd[3]      ),
    .sdram_ack   ( ba_ack[3]     ),
    .data_dst    ( ba_dst[3]     ),
    .data_rdy    ( ba_rdy[3]     ),
    .data_read   ( data_read     )
);

endmodule

`ifdef SIMULATION
`ifdef OBJLOAD
module jtsf_objload(
    input             clk,
    input             rst,
    input      [12:0] obj_AB,
    input             cen8,
    input             LVBL,
    output     [15:1] ram_addr,
    output     [15:0] cpu_dout,
    output     [15:0] dmaout,
    input      [15:0] ram_data,
    output            UDSWn,
    output            LDSWn,
    output            RnW,
    output            ram_cs,
    output reg        OKOUT
);

    integer   fobj,fobjcnt;

    reg [ 7:0] objdebug[0:8192];
    reg        last_LVBL;

    initial begin
        fobj=$fopen("sf-obj.bin","rb");
        if( fobj==0 ) begin
            $display("ERROR: cannot open sf-obj.bin");
            $finish;
        end
        fobjcnt=$fread(objdebug, fobj);
        $display("INFO: %d bytes read from sf-obj.bin",fobjcnt);
        $fclose(fobj);
    end

    assign dmaout = { objdebug[{obj_AB[11:0],1'b0}], objdebug[{obj_AB[11:0],1'b1}] };

    assign ram_cs = 0;
    assign UDSWn  = 1;
    assign LDSWn  = 1;
    assign RnW    = 1;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            OKOUT   <= 1;
        end else if(cen8) begin
            last_LVBL <= LVBL;
            OKOUT     <= !last_LVBL && LVBL;
        end
    end

endmodule
`endif
`endif
