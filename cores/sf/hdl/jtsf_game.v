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

wire [ 8:0] V, H;

wire [13:1] cpu_AB;
wire        char_cs, col_uw,  col_lw;
wire        charon, scr1on, scr2on, objon;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire [15:0] scr1posh, scr2posh;
wire        rd, cpu_cen;
wire        char_busy;
reg         vrom_reg;
// MCU interface
wire [15:0] mcu_din;
wire [ 7:0] mcu_dout;
wire        mcu_wr, mcu_acc;
wire [15:1] mcu_addr;
wire        mcu_brn, mcu_DMAONn, mcu_ds;


reg snd_rst, video_rst, main_rst; // separate reset signals to aid recovery time
reg game_id=0; // 1 for SFJ style inputs

assign debug_view = 0;
assign dip_flip   = flip;
assign vrom_cs    = vrom_reg;

always @(negedge clk) begin
    snd_rst   <= rst;
end

always @(negedge clk) begin
    main_rst  <= rst;
    video_rst <= rst;
end

always @(posedge clk) begin
    vrom_reg <= LVBL || (V==9'hf0 || V==9'hf );
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
reg         prog_obj;

// Optimize cache use for object ROMs
localparam [25:0] OBJ_START  = `OBJ_START,
                  PROM_START = `JTFRAME_PROM_START;
always @* begin
    prog_obj  = ioctl_addr>=OBJ_START && ioctl_addr<PROM_START;
    post_addr = prog_addr;
    if( prog_obj ) post_addr[5:1] = {prog_addr[4:1],prog_addr[5]};
end

// This distinguishes the games using SFJ-style input from the rest
always @(posedge clk) begin
    if( ioctl_addr==26'h19910 && prog_we )
        game_id <= prog_data==6;
end

wire [15:0] scrposh, scrposv, dmaout;
wire        UDSWn, LDSWn;

`ifndef NOMAIN
jtsf_main u_main (
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
    .dipsw_a    ( dipsw[31:16]  ),
    .dipsw_b    ( dipsw[15: 0]  )
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

jtsf_sound u_sound (
    .rst            ( snd_rst        ),
    .clk            ( clk            ),
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
    .fm_l           ( fm_l           ),
    .fm_r           ( fm_r           ),
    .pcm            ( pcm            )
);

`ifndef NOVIDEO
jtsf_video u_video(
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
