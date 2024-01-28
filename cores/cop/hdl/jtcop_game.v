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
    Date: 25-9-2021 */

module jtcop_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// SDRAM interface
wire        main_cs, vram_cs, ram_cs;
wire [18:1] main_addr;
wire [15:0] main_data, ram_data;
wire        main_ok, ram_ok;

wire        char_ok;
wire [12:0] char_addr;
wire [31:0] char_data;

wire        b0rom_ok, b1rom_ok, b2rom_ok,
            b0rom_cs, b1rom_cs, b2rom_cs;
wire [17:0] b0rom_addr, b1rom_addr, b2rom_addr;
wire [31:0] b0rom_data, b1rom_data, b2rom_data;

wire        obj_ok, obj_cs, objram_cs, mixpsel, obj_copy;
wire [17:0] obj_addr;
wire [31:0] obj_data;

// CPU interface
wire [15:0] main_dout, pal_dout, obj_dout;
wire [ 1:0] dsn;
wire        UDSWn, LDSWn, main_rnw;

// BAC06 CS signals
wire        fmode_cs, fsft_cs, fmap_cs,
            bmode_cs, bsft_cs, bmap_cs,
            cmode_cs, csft_cs, cmap_cs;

// BAC06 VRAM read access
wire        b0ram_cs, b0ram_ok,
            b1ram_cs, b1ram_ok,
            b2ram_cs, b2ram_ok;
wire [13:1] b0ram_addr, b1ram_addr, b2ram_addr;
wire [15:0] b0ram_data, b1ram_data, b2ram_data;

// MCU access to SDRAM
wire [15:0] mcu_addr;
wire [ 7:0] mcu_data;
wire        mcu_cs, mcu_ok;

// ROM banks
wire     [ 2:1] sndflag, b1flg, mixflg;
wire     [ 2:0] crback;
wire            b0flg, snd_bank;

// Palette
wire [ 1:0] pal_cs;
wire [ 7:0] prisel;
wire        prio_we;

// Sound CPU
wire [15:0] snd_addr;
wire [ 7:0] snd_data;
wire        snd_cs, snd_ok;

wire [ 7:0] snd_latch;
wire        snreq;

// PCM
wire [17:0] adpcm_addr;
wire        adpcm_cs;
wire [ 7:0] adpcm_data;
wire        adpcm_ok;

wire        flip;
wire        cen_opl, cen_opn;
wire        mcu_we;

wire [15:0] ba0_dout, ba1_dout, ba2_dout;

reg  [15:0] mcu_dout;
wire [15:0] mcu_din;
wire [ 5:0] mcu_sel;
wire        mcu_sel2;   // this funny name is to keep the schematics' naming
wire        shd_cs;

// HuC Protection
wire [ 7:0] huc_dout;
wire        huc_cs;

// BA2 - MCU interface
wire [ 7:0] ba2mcu_mode_din, ba2mcu_dout;
wire        ba2mcu_rnw;
wire        ba2mcu_cs, ba2mcu_mode;
wire        ba2mcu_ok;
wire [13:1] ba2mcu_addr;
wire [ 7:0] ba2mcu_data;
wire [ 1:0] ba2mcu_dsn;
// Cabinet inputs
wire [ 7:0] dipsw_a, dipsw_b;
//wire [ 7:0] game_id;

// Status report
wire [7:0] sta_video, std_video,
           st_snd, st_main, pal_dmp, obj_dmp;
reg  [7:0] st_mux;
wire [1:0] game_id;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dsn = { UDSWn, LDSWn };
assign dip_flip = flip;
assign debug_view = st_dout;
assign st_dout    = st_mux;
assign ba1_din=0, ba2_din=0, ba3_din=0; // unused
assign ba1_dsn=3, ba2_dsn=3, ba3_dsn=3; // unused
assign sta_video = ioctl_ram ? ioctl_addr[7:0] : st_addr; // dump data to SD card

always @(posedge clk) begin
    st_mux <= 0;
    case( st_addr[7:6] )
        0: st_mux <= st_main;
        1: st_mux <= st_snd;
        2: st_mux <= snd_latch;
        3: st_mux <= std_video;
    endcase
end
/* verilator tracing_off */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen3   ( cen_opl   ),
    .cen1p5 ( cen_opn   ),
    .cen8   (           ),
    // unused
    .cen12(), .cen6(),   .cen4(),
    .cen3q(), .cen12b(), .cen6b(),
    .cen3b(), .cen3qb(), .cen1p5b(),
    .cen16(), .cen16b(), .cen4_12()
);
/* verilator tracing_off */
jtcop_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
//    .game_id    ( game_id   ),
    // Video
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      ),
    // ext interrupts
    .nexirq     ( 1'b1      ), // unused in real hardware
    // MCU
    .mcu_dout   ( mcu_dout  ),
    .mcu_din    ( mcu_din   ),
    .sec        ( mcu_sel   ),
    .sec2       ( mcu_sel2  ),
    // HuC6820
    .huc_cs     ( huc_cs    ),
    .huc_dout   ( huc_dout  ),
    // BA register reads
    .ba0_dout   ( ba0_dout  ),
    .ba1_dout   ( ba1_dout  ),
    .ba2_dout   ( ba2_dout  ),
    // Sound communication
    .snd_latch  ( snd_latch ),
    .snreq      ( snreq     ),
    // Palette
    .prisel     ( prisel    ),
    .pal_cs     ( pal_cs    ),
    .pal_dout   ( pal_dout  ),
    // Video circuitry
    .fmode_cs   ( fmode_cs  ),
    .fsft_cs    ( fsft_cs   ),
    .fmap_cs    ( fmap_cs   ),
    .bmode_cs   ( bmode_cs  ),
    .bsft_cs    ( bsft_cs   ),
    .bmap_cs    ( bmap_cs   ),
    .cmode_cs   ( cmode_cs  ),
    .csft_cs    ( csft_cs   ),
    .cmap_cs    ( cmap_cs   ),
    // Objects
    .obj_cs     ( objram_cs ),
    .obj_copy   ( obj_copy  ),
    .mixpsel    ( mixpsel   ),
    .obj_dout   ( obj_dout  ),

    // CPU bus
    .cpu_addr   ( main_addr ),
    .cpu_dout   ( main_dout ),
    .UDSWn      ( UDSWn     ),
    .LDSWn      ( LDSWn     ),
    .RnW        ( main_rnw  ),
    // cabinet I/O
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .joyana1     ( joyana_r1  ),
    .joyana2     ( joyana_r2  ),
    .dial_x      ( dial_x     ),
    .dial_y      ( dial_y     ),
    .cab_1p      ( cab_1p     ),
    .coin        (  coin      ),
    .service     ( service    ),
    // RAM access
    .ram_cs      ( ram_cs     ),
    .ram_data    ( ram_data   ),
    .ram_ok      ( ram_ok     ),
    // ROM access
    .rom_cs      ( main_cs    ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // DIP switches
    .dip_pause   ( dip_pause & ~ioctl_ram ),
    .dip_test    ( dip_test   ),
    .dipsw_a     ( dipsw_a    ),
    .dipsw_b     ( dipsw_b    ),
    // Status report
    //.debug_bus   ( debug_bus  ),
    .st_addr     ( st_addr    ),
    .st_dout     ( st_main    )
);
/* verilator tracing_off */
jtcop_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk       ),

    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .gfx_en     ( gfx_en    ),

    .game_id    ( game_id   ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr[10:0]),
    .pal_dmp    ( pal_dmp   ),
    .obj_dmp    ( obj_dmp   ),

    // CPU interface
    .cpu_addr   ( main_addr[12:1]  ),

    // MCU interface
    .mcu_addr   ( ba2mcu_addr[10:1]),
    .mcu_dout   ( ba2mcu_dout  ),
    .mcu_din    ( ba2mcu_mode_din ),
    .mcu_rnw    ( ba2mcu_rnw   ),
    .mcu_dsn    ( ba2mcu_dsn   ),
    .mcu_mode   ( ba2mcu_mode  ),

    // Register reads
    .ba0_dout   ( ba0_dout  ),
    .ba1_dout   ( ba1_dout  ),
    .ba2_dout   ( ba2_dout  ),

    // Object
    .objram_cs  ( objram_cs ),
    .mixpsel    ( mixpsel   ),
    .obj_dout   ( obj_dout  ),
    .obj_copy   ( obj_copy  ),

    .fmode_cs   ( fmode_cs  ),
    .bmode_cs   ( bmode_cs  ),
    .cmode_cs   ( cmode_cs  ),

    .cpu_dout   ( main_dout ),
    .cpu_dsn    ( dsn       ),
    .cpu_rnw    ( main_rnw  ),

    // Palette
    .pal_cs     ( pal_cs    ),
    .prisel     ( prisel    ),
    .pal_dout   ( pal_dout  ),
    .prio_we    ( prio_we   ),
    .prog_addr  (prog_addr[9:0]),
    .prom_din   (prog_data[3:0]),

    .flip        ( flip       ),

    // SDRAM interface
    .b0ram_cs    ( b0ram_cs   ),
    .b0ram_addr  ( b0ram_addr ),
    .b0ram_data  ( b0ram_data ),
    .b0ram_ok    ( b0ram_ok   ),

    .b1ram_cs    ( b1ram_cs   ),
    .b1ram_addr  ( b1ram_addr ),
    .b1ram_data  ( b1ram_data ),
    .b1ram_ok    ( b1ram_ok   ),

    .b2ram_cs    ( b2ram_cs   ),
    .b2ram_addr  ( b2ram_addr ),
    .b2ram_data  ( b2ram_data ),
    .b2ram_ok    ( b2ram_ok   ),

    .b0rom_ok    ( b0rom_ok   ),
    .b0rom_cs    ( b0rom_cs   ),
    .b0rom_addr  ( b0rom_addr ),
    .b0rom_data  ( b0rom_data ),

    .b1rom_cs    ( b1rom_cs   ),
    .b1rom_ok    ( b1rom_ok   ),
    .b1rom_addr  ( b1rom_addr ),
    .b1rom_data  ( b1rom_data ),

    .b2rom_cs    ( b2rom_cs   ),
    .b2rom_ok    ( b2rom_ok   ),
    .b2rom_addr  ( b2rom_addr ),
    .b2rom_data  ( b2rom_data ),

    .orom_ok     ( obj_ok     ),
    .orom_cs     ( obj_cs     ),
    .orom_addr   ( obj_addr   ),
    .orom_data   ( obj_data   ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL_dly   ( LHBL      ),
    .LVBL_dly   ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // debug
    .st_addr    ( sta_video ),
    .st_dout    ( std_video ),
    .debug_bus  ( debug_bus )
);

/* verilator tracing_on */
// NB: this module is different for jtmidres
jtcop_snd u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_opn    ( cen_opn   ),
    .cen_opl    ( cen_opl   ),

    .enable_fm  ( enable_fm ),
    .enable_psg ( enable_psg),
    .fxlevel    (dip_fxlevel),

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
    .adpcm_addr ( adpcm_addr),
    .adpcm_cs   ( adpcm_cs  ),
    .adpcm_data ( adpcm_data),
    .adpcm_ok   ( adpcm_ok  ),

    .snd        ( snd       ),
    .sample     ( sample    ),
    .peak       ( game_led  ),
    .status     ( st_snd    )
);
/* verilator tracing_off */

`ifdef MCU
    wire [7:0] mcu_p0o, mcu_p1o, mcu_p2o, mcu_p3o, mcu_p3i;
    reg  [7:0] mcu_p0i;
    reg        mcu_intn, mcu_sel0l;
    wire       mcu_wrlo, mcu_wrhi, mcu_rdhi, mcu_rdlo, cen_mcu;

    assign mcu_p3i = { mcu_sel[5:3], mcu_p3o[4:0] };
    assign { sndflag, b1flg, b0flg, mixflg } = mcu_p1o[6:0];
    assign crback = mcu_p3o[2:0];
    assign mcu_sel2 = mcu_p2o[2];
    assign mcu_rdhi = ~mcu_p2o[4];
    assign mcu_rdlo = ~mcu_p2o[5];
    assign mcu_wrlo = ~mcu_p2o[6];
    assign mcu_wrhi = ~mcu_p2o[7];

    always @(posedge clk24, posedge  rst24) begin
        if( rst24 ) begin
            mcu_sel0l <= 0;
            mcu_intn <= 1;
            mcu_p0i  <= 0;
            mcu_dout <= 0;
        end else begin
            mcu_sel0l <= mcu_sel[0];

            if( !mcu_p2o[3] )
                mcu_intn <= 1;
            else if( mcu_sel[0] & ~mcu_sel0l )
                mcu_intn <= 0;

            // MCU reads
            if( mcu_rdhi )
                mcu_p0i <= mcu_din[15:8];
            if( mcu_rdlo )
                mcu_p0i <= mcu_din[7:0];

            // MCU writes
            if( mcu_wrhi )
                mcu_dout[15:8] <= mcu_p0o;
            if( mcu_wrlo )
                mcu_dout[7:0] <= mcu_p0o;
        end
    end

    wire nc;
    jtframe_frac_cen #(.WC(3)) u_cenmcu(
        .clk ( clk24    ),
        .n   ( 3'd1     ),
        .m   ( 3'd3     ),
        .cen ({nc,cen_mcu}),
        .cenb(          )
    );

    jtframe_8751mcu #(
        .ROMBIN     ("../../../../rom/ei31.9a"),
        .DIVCEN     ( 1             ),
        .SYNC_XDATA ( 1             ),
        //.SYNC_P1    ( 1             ),
        .SYNC_INT   ( 1             )
    ) u_mcu(
        .rst        ( rst24         ),
        .clk        ( clk24         ),
        .cen        ( cen_mcu       ),

        .int0n      ( 1'b1          ),
        .int1n      ( mcu_intn      ),

        .p0_i       ( mcu_p0i       ),
        .p1_i       ( mcu_p1o       ), // used as outputs only
        .p2_i       ( mcu_p2o       ), // used as outputs only
        .p3_i       ( mcu_p3i       ),

        .p0_o       ( mcu_p0o       ),
        .p1_o       ( mcu_p1o       ),
        .p2_o       ( mcu_p2o       ),
        .p3_o       ( mcu_p3o       ),

        // external memory
        .x_din      ( 8'h0          ),
        .x_dout     (               ),
        .x_addr     (               ),
        .x_wr       (               ),
        .x_acc      (               ),

        // ROM programming
        .clk_rom    ( clk           ),
        .prog_addr  ( prog_addr[11:0] ),
        .prom_din   ( prog_data[7:0]),
        .prom_we    ( mcu_we        ),

        .clk_ram    ( 1'b0          ),
        .ram_prog_addr( 7'd0        ),
        .ram_prog_din( 8'd0         ),
        .ram_prog_we ( 1'b0         )
    );
`else
    assign { sndflag, b1flg, b0flg, mixflg } = 0;
    assign crback    = 0;
    assign mcu_sel2  = 0;
    initial mcu_dout = 0;
`endif

`ifndef NOHUC
    jtcop_prot u_prot(
        .rst        ( rst24     ),
        .clk        ( clk24     ),
        .clk_cpu    ( clk       ),
        .LVBL       ( LVBL      ),
        .game_id    ( game_id   ),

        .main_addr  ( main_addr[11:1] ),  // only 2kB are shared
        .main_dout  ( main_dout[ 7:0] ),
        .main_din   ( huc_dout  ),
        .main_cs    ( huc_cs    ),
        .main_wrn   ( main_rnw | LDSWn  ),

        // BA2 interfcae
        .ba2mcu_mode( ba2mcu_mode   ),
        .ba2mcu_mode_din(ba2mcu_mode_din),
        .ba2mcu_cs  ( ba2mcu_cs     ),
        .ba2mcu_ok  ( ba2mcu_ok     ),
        .ba2mcu_dout( ba2mcu_dout   ),
        .ba2mcu_addr( ba2mcu_addr   ),
        .ba2mcu_data( ba2mcu_data   ),
        .ba2mcu_dsn ( ba2mcu_dsn    ),
        .ba2mcu_rnw ( ba2mcu_rnw    ),

        .mcu_addr   ( mcu_addr  ),
        .mcu_data   ( mcu_data  ),
        .mcu_cs     ( mcu_cs    ),
        .mcu_ok     ( mcu_ok    )
    );
`else
    assign ba2mcu_dsn  = 3;
    assign ba2mcu_addr = 0;
    assign ba2mcu_rnw  = 1;
    assign ba2mcu_cs   = 0;
    assign ba2mcu_dout = 0;
    assign ba2mcu_mode = 0;
    assign huc_dout = 0;
    assign mcu_cs   = 0;
    assign mcu_addr = 0;
`endif

jtcop_sdram u_sdram(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .game_id    ( game_id   ),
    .st_video   ( std_video ),
    .pal_dmp    ( pal_dmp   ),
    .obj_dmp    ( obj_dmp   ),

    // Video RAM
    .fsft_cs    ( fsft_cs   ),
    .fmap_cs    ( fmap_cs   ),
    .bsft_cs    ( bsft_cs   ),
    .bmap_cs    ( bmap_cs   ),
    .csft_cs    ( csft_cs   ),
    .cmap_cs    ( cmap_cs   ),

    .b0ram_cs   ( b0ram_cs  ),
    .b0ram_addr ( b0ram_addr),
    .b0ram_data ( b0ram_data),
    .b0ram_ok   ( b0ram_ok  ),

    .b1ram_cs   ( b1ram_cs  ),
    .b1ram_addr ( b1ram_addr),
    .b1ram_data ( b1ram_data),
    .b1ram_ok   ( b1ram_ok  ),

    .b2ram_cs   ( b2ram_cs  ),
    .b2ram_addr ( b2ram_addr),
    .b2ram_data ( b2ram_data),
    .b2ram_ok   ( b2ram_ok  ),

    // PROMs
    .mcu_we     ( mcu_we    ), // i8751 MCU / Sub CPU
    .prio_we    ( prio_we   ), // priority

    // ROM banks
    .sndflag    ( sndflag   ),
    .b1flg      ( b1flg     ),
    .mixflg     ( mixflg    ),
    .crback     ( crback    ),
    .b0flg      ( b0flg     ),
    .sndbank    ( snd_bank  ),

    // Main CPU
    .main_cs    ( main_cs   ),
    .ram_cs     ( ram_cs    ),

    .main_addr  ( main_addr ),
    .main_data  ( main_data ),
    .ram_data   ( ram_data  ),

    .main_ok    ( main_ok   ),
    .ram_ok     ( ram_ok    ),

    .dsn        ( dsn       ),
    .main_dout  ( main_dout ),
    .main_rnw   ( main_rnw  ),

    // Sound CPU
    .snd_addr   ( snd_addr  ),
    .snd_cs     ( snd_cs    ),
    .snd_data   ( snd_data  ),
    .snd_ok     ( snd_ok    ),

    // ADPCM ROM
    .adpcm_addr (adpcm_addr ),
    .adpcm_cs   (adpcm_cs   ),
    .adpcm_data (adpcm_data ),
    .adpcm_ok   (adpcm_ok   ),

    // MCU
    .mcu_addr   ( mcu_addr  ),
    .mcu_cs     ( mcu_cs    ),
    .mcu_data   ( mcu_data  ),
    .mcu_ok     ( mcu_ok    ),

    // BA2 - MCU
    .ba2mcu_cs  ( ba2mcu_cs     ),
    .ba2mcu_ok  ( ba2mcu_ok     ),
    .ba2mcu_rnw ( ba2mcu_rnw    ),
    .mcu_dout   ( ba2mcu_dout   ),
    .ba2mcu_addr( ba2mcu_addr   ),
    .ba2mcu_data( ba2mcu_data   ),
    .ba2mcu_dsn ( ba2mcu_dsn    ),

    // BG 0
    .b0rom_ok    ( b0rom_ok   ),
    .b0rom_cs    ( b0rom_cs   ),
    .b0rom_addr  ( b0rom_addr ),
    .b0rom_data  ( b0rom_data ),

    // BG 1
    .b1rom_ok    ( b1rom_ok   ),
    .b1rom_cs    ( b1rom_cs   ),
    .b1rom_addr  ( b1rom_addr ),
    .b1rom_data  ( b1rom_data ),

    // BG 2
    .b2rom_ok    ( b2rom_ok   ),
    .b2rom_cs    ( b2rom_cs   ),
    .b2rom_addr  ( b2rom_addr ),
    .b2rom_data  ( b2rom_data ),

    // Sprite interface
    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Bank 0: allows R/W
    .ba0_addr    ( ba0_addr      ),
    .ba1_addr    ( ba1_addr      ),
    .ba2_addr    ( ba2_addr      ),
    .ba3_addr    ( ba3_addr      ),
    .ba_rd       ( ba_rd         ),
    .ba_wr       ( ba_wr         ),
    .ba_ack      ( ba_ack        ),
    .ba_dst      ( ba_dst        ),
    .ba_dok      ( ba_dok        ),
    .ba_rdy      ( ba_rdy        ),
    .ba0_din     ( ba0_din       ),
    .ba0_din_m   ( ba0_dsn       ),

    .data_read   ( data_read     ),

    // ROM load
    .ioctl_rom  ( ioctl_rom  ),
    .dwnld_busy ( dwnld_busy ),

    .ioctl_addr ( ioctl_addr[24:0] ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_din  ( ioctl_din  ),
    .ioctl_wr   ( ioctl_wr   ),
    .ioctl_ram  ( ioctl_ram  ),
    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_mask  ( prog_mask  ),
    .prog_ba    ( prog_ba    ),
    .prog_we    ( prog_we    ),
    .prog_rd    ( prog_rd    ),
    .prog_ack   ( prog_ack   ),
    .prog_rdy   ( prog_rdy   )
);

endmodule
