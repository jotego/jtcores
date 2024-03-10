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
    Date: 13-12-2022 */

module jtkarnov_game(
    `include "jtframe_game_ports.inc"
);

wire        flip;
wire [ 7:0] snd_latch, st_snd, st_main;
wire [ 8:0] scrx, scry, hdump;
wire        snreq, snd_bank, mcu2main_irq,
            dmarq, sdtkn, secreq, pre_dma_we, dma_start;
wire        main_wrn, mcu_we, colprom_we,
            vram_cs, scrram_cs, objram_cs;
wire [15:0] mcu_dout, mcu_din;
reg  [ 7:0] mcu_st;
reg         wndrplnt=0;       // Detects Wonder Planet

assign dip_flip   = flip;
assign mcu_we     = prom_we & ~prog_addr[12];
assign colprom_we = prom_we &  prog_addr[12];
assign debug_view = debug_bus[7] ? st_main : mcu_st;
assign ram_we     = ram_cs & ~main_wrn;
assign dma_we     = {2{pre_dma_we}};

assign vram_we    = {2{vram_cs   & ~main_wrn}} & ~main_dsn;
assign scrram_we  = {2{scrram_cs & ~main_wrn}} & ~main_dsn;
assign objram_we  = {2{objram_cs & ~main_wrn}} & ~main_dsn;

// Remove this when bus contention is done
assign sdtkn = 0;

always @(posedge clk) begin
    if( ioctl_addr=='h163 ) wndrplnt <= prog_data==2;
end

jtkarnov_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .LVBL       ( LVBL          ),
    .hdump      ( hdump         ),
    // Bus signals
    .cpu_dout   ( main_dout     ),
    .cpu_addr   ( main_addr     ),
    .dsn        ( main_dsn      ),
    .RnW        ( main_wrn      ),

    // Sound control
    .sonreq     ( snreq         ),
    .snd_latch  ( snd_latch     ),
    // Video RAMs
    .vram_cs    ( vram_cs       ),
    .scrram_cs  ( scrram_cs     ),
    .objram_cs  ( objram_cs     ),
    .vram2main_data  ( vram2main_data        ),
    .scrram2main_data( scrram2main_data      ),
    .objram2main_data( objram2main_data      ),
    .sdtkn      ( sdtkn         ),   // DTAK signal for the video
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .flip       ( flip          ),
    .dmarq      ( dma_start     ),   // object RAM DMA. The DMA does not halt the CPU

    // MCU
    .mcu2main_irq( mcu2main_irq  ),
    .mcu_dout    ( mcu_dout      ),
    .mcu_din     ( mcu_din       ),
    .secreq      ( secreq        ),      // original signal name

    // cabinet I/O
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),

    .cab_1p      ( cab_1p       ),
    .coin        ( coin         ),
    .service     ( service      ),

    // RAM access
    .ram_cs     ( ram_cs        ),
    .ram_data   ( ram_data      ),   // coming from VRAM or RAM
    .ram_ok     ( ram_ok        ),

    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dip_test   ( dip_test      ),
    .dipsw      ( dipsw[15:0]   ),

    // Debug
    .st_addr    ( debug_bus     ),
    .st_dout    ( st_main       )
);

`ifndef NOMCU
    wire [7:0] mcu_p0o, mcu_p1o, mcu_p2o,
               mcu_p0i, mcu_p1i, mcu_p3i;
    wire       mcu_int0n, mcu_int1n;
    wire       coin_in;

    assign mcu_p0i = ~mcu_p2o[4] ? mcu_din[ 7:0] : mcu_p0o;
    assign mcu_p1i = ~mcu_p2o[5] ? mcu_din[15:8] : mcu_p1o;
    assign mcu_p3i = { service, coin, 5'h1f };
    assign mcu2main_irq = ~mcu_p2o[2];
    assign coin_in = ~&{coin[1:0], service};
    always @(posedge clk24) begin
        case( debug_bus[3:0] )
            0: mcu_st <= mcu_din[7:0];
            1: mcu_st <= mcu_din[15:8];
            2: mcu_st <= mcu_dout[7:0];
            3: mcu_st <= mcu_dout[15:8];
            4: mcu_st <= mcu_p0o;
            5: mcu_st <= mcu_p1o;
            6: mcu_st <= mcu_p2o;
            7: mcu_st <= { 2'd0, mcu_p2o[1:0],
                                coin_in, 1'd0, mcu_int1n, mcu_int0n };
            default: mcu_st <= 0;
        endcase
    end

    jtframe_edge #(0) u_coin(
        .rst        ( rst24         ),
        .clk        ( clk24         ),
        .edgeof     ( coin_in       ),
        .clr        ( ~mcu_p2o[0]   ),
        .q          ( mcu_int0n     )
    );

    jtframe_edge #(0) u_mcureq(
        .rst        ( rst24         ),
        .clk        ( clk24         ),
        .edgeof     ( secreq        ),
        .clr        ( ~mcu_p2o[1]   ),
        .q          ( mcu_int1n     )
    );

    wire [15:0] aux;
    jtframe_ff #(16) u_mculatch(
        .rst        ( rst24         ),
        .clk        ( clk24         ),
        .cen        ( 1'b1          ),
        .din        ({mcu_p1o,mcu_p0o}),
        .set        ( 16'd0         ),
        .clr        ( 16'd0         ),
        .sigedge    ( {{8{mcu_p2o[7]}},{8{mcu_p2o[6]}}}),
        .q          ( aux      ),
        .qn         (               )
    );
    assign mcu_dout = debug_bus[6] ? {mcu_p1o,mcu_p0o} : aux;

    jtframe_8751mcu #(
        .ROMBIN     ("../../../../rom/chelnov/ee-e.k14"),
        // .SYNC_XDATA ( 1             ),
        //.SYNC_P1    ( 1             ),
        // .SYNC_INT   ( 1             ),
        .DIVCEN     ( 1             )
    ) u_mcu(
        .rst        ( rst24         ),
        .clk        ( clk24         ),
        .cen        ( cen_mcu & dip_pause ),

        .int0n      ( mcu_int0n     ),
        .int1n      ( mcu_int1n     ),

        .p0_i       ( mcu_p0i       ),
        .p1_i       ( mcu_p1i       ),
        .p2_i       ( mcu_p2o       ), // used as outputs only
        .p3_i       ( mcu_p3i       ),

        .p0_o       ( mcu_p0o       ),
        .p1_o       ( mcu_p1o       ),
        .p2_o       ( mcu_p2o       ),
        .p3_o       (               ),

        // external memory
        .x_din      ( 8'hf          ),
        .x_dout     (               ),
        .x_addr     (               ),
        .x_wr       (               ),
        .x_acc      (               ),

        // ROM programming
        .clk_rom    ( clk           ),
        .prog_addr  ( prog_addr[11:0] ),
        .prom_din   ( prog_data[7:0]),
        .prom_we    ( mcu_we        )
    );
`else
    assign mcu2main_irq = 0;
    assign mcu_dout     = 0;
    assign mcu_dout     = 0;
    assign mcu_st       = 0;
`endif

jtkarnov_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .flip       ( flip      ),
    .wndrplnt   ( wndrplnt  ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .hdump      ( hdump     ),

    // fixed layer
    .vram_addr  ( vram_addr ),
    .vram_data  ( vram_dout ),
    .fix_addr   ( fix_addr  ),
    .fix_data   ( fix_data  ),
    .fix_cs     ( fix_cs    ),
    .fix_ok     ( fix_ok    ),

    // scroll layer
    .scrram_addr(scrram_addr),
    .scrram_data(scrram_dout),
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_cs     ( scr_cs    ),
    .scr_ok     ( scr_ok    ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),

    // objects
    .obj_cs     (obj_cs     ),
    .obj_addr   (obj_addr   ),
    .obj_ok     (obj_ok     ),
    .obj_data   (obj_data   ),

    .objram_addr(objbuf_addr),
    .objram_data(objbuf_dout),
    .dma_we     ( pre_dma_we),
    .dma_addr   ( dma_addr  ),
    .dma_start  ( dma_start ),

    .prog_addr  ( prog_addr[10:0] ),
    .prog_data  ( prog_data ),
    .prom_we    ( colprom_we),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // debug
    // .st_addr    ( st_addr   ),
    // .st_dout    ( st_video  ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

jtcop_snd #(.KARNOV(1)) u_sound(
    .rst        ( rst24     ),
    .clk        ( clk24     ),
    .cen_opn    ( cen_opn   ),
    .cen_opl    ( cen_opl   ),

    // From main CPU
    .snreq      ( snreq     ),
    .latch      ( snd_latch ),
    .snd_bank   ( snd_bank  ),

    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    // ADPCM ROM
    .adpcm_addr (           ),
    .adpcm_cs   (           ),
    .adpcm_data (           ),
    .adpcm_ok   (           ),

    // Sound channels
    .opn        ( opn       ),
    .opl        ( opl       ),
    .psg        ( psg       ),
    .pcm        (           ),
    .status     ( st_snd    )
);

endmodule
