/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-8-2022 */

module jtframe_pocket_base #(parameter
    SIGNED_SND      = 1'b0,
    COLORW          = 4
) (
    input           rst,
    output reg      rst_req,
    input           clk_74a,
    input           clk_sys,
    input           clk_rom,
    input           clk48,
    input           pxl_cen,
    input           pxl2_cen,

    input           sdram_init,
    output          osd_shown,
    output     [17:0] core_mod,
    output     [ 7:0] game_vol,
    input      [ 1:0] black_frame, rotate,

    output     [31:0] dipsw,

    // Track SDRAM activity
    input           prog_we,
    input           prog_rdy,
    // Bridge Connection
    inout           spi_clk,
    inout     [1:0] spi_dio,
    input           spi_ss,
    // Scan-doubler video
    input [3*COLORW-1:0] base_rgb,
    input [  COLORW-1:0] game_r, game_g, game_b,
    input           base_LHBL,
    input           base_LVBL,
    input           base_hs,
    input           base_vs,
    // Final video
    output   [11:0] scal_vid,
    output          scal_clk,
    output          scal_de,
    output          scal_skip,
    output          scal_vs,
    output          scal_hs,
    // control
    output     [63:0] status,
    output     [15:0] joystick1,
    output     [15:0] joystick2,
    output     [15:0] joystick3,
    output     [15:0] joystick4,
    output     [15:0] joyana_l1,
    output     [15:0] joyana_r1,
    output     [15:0] joyana_l2,
    output     [15:0] joyana_r2,
    output     [15:0] joyana_l3,
    output     [15:0] joyana_r3,
    output     [15:0] joyana_l4,
    output     [15:0] joyana_r4,

    output reg [ 3:0] but_coin,   // buttons, active high
    output reg [ 3:0] but_start,
    // debug features
    output    [3:0] board_gfx,
    output          board_plus,
    output          board_minus,
    // Mouse
    output [ 8:0]   mouse_dx, mouse_dy,
    output [ 7:0]   mouse_f,       // flags
    output          mouse_idx,
    output          mouse_st,
    // Sound
    input    [15:0] snd_left,
    input    [15:0] snd_right,
    input           snd_sample,

    output          audio_mclk,
    output          audio_dac,
    output          audio_lrck,
    // Pocket inputs
    inout           bridge_1wire,
    // Line-Frame buffer
    input           ln_we,
    input    [`JTFRAME_LF_VW-1:0] game_vrender,
    input    [`JTFRAME_LF_HW-1:0] game_hdump,
`ifdef JTFRAME_LF_ZOOM
    input    [ 8:0] game_h_step, game_v_step,
`endif
    input    [`JTFRAME_LF_HW-1:0] ln_addr,
    input    [15:0] ln_data,
    input           ln_done,
    output          ln_hs, ln_vs, ln_lvbl,
    output   [15:0] ln_dout,
    output   [15:0] ln_pxl,
    output   [`JTFRAME_LF_VW-1:0] ln_v,
    input           fb_keep,
    // PSRAM chip
    output  [21:16] cr_addr,
    inout    [15:0] cr_adq,
    output          cr_advn,
    output   [ 1:0] cr_cen,
    output          cr_clk,
    output          cr_cre,
    output   [ 1:0] cr_dsn,
    output          cr_oen,
    output          cr_wen,
    input           cr_wait,
    // ROM load from SPI
    output reg [25:0] ioctl_addr,
    output     [ 7:0] ioctl_dout,
    input      [ 7:0] ioctl_din,
    output reg        ioctl_wr,
    output reg        ioctl_ram,
    output reg        ioctl_lock,
    output reg        ioctl_cheat,
    output reg        ioctl_rom,
    output reg        ioctl_cart,
    input      [7:0]  st_addr, debug_bus,
    output     [7:0]  st_dout,
    // Analogizer outputs
    output     [7:0]  cart3_vid,
    output     [7:0]  cart2_vid,
    output     [4:0]  cart1_vid,
    output            cart1_vdir,
    output            cart2_vdir,
    output            cart3_vdir,
    output    [23:0]  yc_vid,
    output            yc_en,
    output    [1:0]   anv_en,

    output           ps2_clk,
    output           ps2_data,

    // SNAC Controller inputs
    input      [15:0]  snac_p1, snac_p2, snac_p3, snac_p4,
    output reg [ 7:0]  snac_cfg
);

localparam [7:0] IDX_ROM     = 1,
                 IDX_NVRAM   = 2,
                 IDX_CART    = 4,
                 IDX_CHEAT   = 16,
                 IDX_LOCK    = 17,
                 IDX_CRT     = 18;

localparam [25:0] CART_OFFSET = `ifdef JTFRAME_CART_OFFSET `JTFRAME_CART_OFFSET `else 26'd0 `endif ;

wire        rst_req_n;
wire [7:0]  ioctl_index, nc;
wire        ioctl_download, ioctl_upload;
reg  [31:0] ioctl_qword;
reg         prog_rdyl;

wire [31:2] sys_addr;
wire        sys_rd, sys_wr, sys_waitn, tx_slot, dipsw_rst;
wire        osd_setrot;     // set when screen rotation is requested via OSD
wire [31:0] sys_din, sys_dout;
wire [ 1:0] video_sel;
wire [63:0] chipid;
reg         rst_aux;

// Keyboard
wire        key_en;
// Controllers
wire [15:0] cont1_key,  cont2_key,  cont3_key,  cont4_key,
            cont1_trig, cont2_trig, cont3_trig, cont4_trig,
            cont1,      cont2,      cont3,      cont4;
wire [31:0] cont1_joy,  cont2_joy,  cont3_joy,  cont4_joy;
wire [23:0] button_map_rom, button_map;
wire [ 3:0] analog_en;

// bridge host commands
wire        ds_done;
wire [15:0] dataslot_requestread_id, dataslot_requestwrite_id;
wire        dataslot_requestread, dataslot_requestwrite, dataslot_done;
// CRT-VGA Analog Video Output
reg [11:0] crt_cfg;
reg        ioctl_crt;

assign osd_setrot  = status[2];
assign video_sel   = (osd_shown || !rotate[0] || !osd_setrot) ? 2'd0 : 2'b1 << ~rotate[1];
assign st_dout     = {2'd0, osd_shown, osd_setrot, video_sel, rotate};

always @(posedge clk_sys) begin
    but_start <= { cont4[15], cont3[15], cont2[15], cont1[15] };
    but_coin  <= { cont4[14], cont3[14], cont2[14], cont1[14] };
end

assign ioctl_dout = ioctl_qword[31:24];

`ifdef JTFRAME_FORCED_DIPSW
initial dipsw = `JTFRAME_FORCED_DIPSW;
`endif

always @(posedge clk_rom) begin
    rst_aux <= ~rst_req_n | dipsw_rst;
    rst_req <= rst_aux;
end

jtframe_pocket_cfg u_cfg(
    .rst_rom    ( rst       ),
    .clk_rom    ( clk_rom   ),
    .clk_74a    ( clk_74a   ),

    .sys_addr   ( sys_addr  ),
    .sys_dout   ( sys_dout  ),
    .sys_wr     ( sys_wr    ),

    .dipsw      ( dipsw     ),
    .dipsw_rst  ( dipsw_rst ),
    .core_mod   ( core_mod  ),
    .button_map ( button_map_rom ),
    .game_vol   ( game_vol  ),
    .status     ( status    )
);

reg  [2:0] prog_cnt=0;
reg        prog_wait;
wire       prog_to;         // time out
reg [31:0] ioctl_din32;
reg        was_wr=0;

// prog_to is used when IOCTL data is not sent to the SDRAM
// in that case prog_rdy does not toggle and we need to count
// time.

assign prog_to = &prog_cnt;
assign tx_slot = ioctl_index==IDX_ROM || ioctl_index == IDX_NVRAM || ioctl_index == IDX_CART
              || ioctl_index == IDX_LOCK || ioctl_index == IDX_CHEAT || ioctl_index == IDX_CRT;

always @(posedge clk_rom) begin
    prog_rdyl   <= prog_rdy;
    ioctl_wr    <= 0;
    prog_cnt    <= prog_cnt+1'd1;
    ioctl_rom   <= ioctl_index == IDX_ROM;
    ioctl_cart  <= ioctl_index == IDX_CART;
    ioctl_ram   <= ioctl_index == IDX_NVRAM;
    ioctl_lock  <= ioctl_index == IDX_LOCK;
    ioctl_cheat <= ioctl_index == IDX_CHEAT;
    ioctl_crt   <= ioctl_index == IDX_CRT;
    if( prog_we ) prog_wait <= 1; // the timeout will be ignored
    if( (sys_wr || sys_rd) && tx_slot && sys_addr[31:24]<8'hf8 ) begin
        was_wr      <= sys_wr;
        ioctl_wr    <= sys_wr;
        ioctl_qword <= sys_dout;
        ioctl_addr  <= {sys_addr[25:2],2'd0} + (ioctl_cart ? CART_OFFSET : 26'd0 );
        prog_cnt    <= 0;
        prog_wait   <= 0;
        // timeout     <= TIMEOUT;
    end else if( ioctl_addr[1:0] != 3 &&
            ( prog_wait ? prog_rdyl : prog_to )
        ) begin
        ioctl_addr[1:0] <= ioctl_addr[1:0] + 2'd1;
        ioctl_qword     <= ioctl_qword << 8;
        ioctl_wr        <= was_wr;
        prog_wait       <= 0;
        prog_cnt        <= 0;
    end
    // compose the 32-bit data word
    if( ioctl_ram ) begin
        case( ioctl_addr[1:0] )
            0: ioctl_din32[ 24 +: 8] <= ioctl_din;
            1: ioctl_din32[ 16 +: 8] <= ioctl_din;
            2: ioctl_din32[  8 +: 8] <= ioctl_din;
            3: ioctl_din32[  0 +: 8] <= ioctl_din;
        endcase
    end
end

always @(posedge clk_sys) if( ioctl_crt && ioctl_wr )begin
    crt_cfg  <= sys_dout[31:20];
    snac_cfg <= sys_dout[19:12];
end

`ifndef SIMULATION
pocket_id u_id(
    .reset      ( rst       ),
    .clkin      ( clk_rom   ),
    .data_valid (           ),
    .chip_id    ( chipid    )
);
`else
assign chipid = 64'h0123_4567_89ab_cdef;
`endif

jtframe_sync #(.W(24)) u_button_map(
    .clk_in     ( clk_rom        ),
    .clk_out    ( clk_sys        ),
    .raw        ( button_map_rom ),
    .sync       ( button_map     )
);

jtframe_pocket_joystick u_joystick(
    .clk_sys    ( clk_sys   ),
    .button_map ( button_map ),
    .cont1      ( cont1     ),
    .cont2      ( cont2     ),
    .cont3      ( cont3     ),
    .cont4      ( cont4     ),
    .cont1_joy  ( cont1_joy ),
    .cont2_joy  ( cont2_joy ),
    .cont3_joy  ( cont3_joy ),
    .cont4_joy  ( cont4_joy ),
    .analog_en  ( analog_en ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .joystick3  ( joystick3 ),
    .joystick4  ( joystick4 ),
    .joyana_l1  ( joyana_l1 ),
    .joyana_l2  ( joyana_l2 ),
    .joyana_l3  ( joyana_l3 ),
    .joyana_l4  ( joyana_l4 ),
    .joyana_r1  ( joyana_r1 ),
    .joyana_r2  ( joyana_r2 ),
    .joyana_r3  ( joyana_r3 ),
    .joyana_r4  ( joyana_r4 )
);


jtframe_pocket_spi u_spi(
    .clk_74a    ( clk_74a     ),
    .clk_rom    ( clk_rom     ),
    .rst_rom    ( rst         ),

    .addr       ( sys_addr    ),
    .rd         ( sys_rd      ),
    .din        ( sys_din     ),
    .waitn      ( sys_waitn   ),

    .wr         ( sys_wr      ),
    .dout       ( sys_dout    ),

    .spi_dio    ( spi_dio     ),
    .spi_clk    ( spi_clk     ),
    .spi_ss     ( spi_ss      )
);

jtframe_pocket_cmd #(.IDX_NVRAM(IDX_NVRAM)) u_cmd(
    .clk           ( clk_rom        ),
    .rst_req_n     ( rst_req_n      ),
    .sys_addr      ( sys_addr       ),
    .sys_rd        ( sys_rd         ),
    .sys_din       ( sys_din        ),
    .ioctl_din32   ( ioctl_din32    ),
    .sys_wr        ( sys_wr         ),
    .sys_dout      ( sys_dout       ),
    .dipsw         ( dipsw          ),
    .status        ( status         ),
    // Download control
    .down_index    ( ioctl_index    ),
    .ds_done       ( ds_done        ),
    .inmenu        ( osd_shown      )
);

jtframe_pocket_keyboard u_keyboard(
    .rst            ( rst       ),
    .clk            ( clk_rom   ),

    .key_en         ( key_en    ),
    .cont3_joy      ( cont3_joy ),
    .cont3_key      ( cont3_key ),
    .cont3_trig     ( cont3_trig),

    .ps2_clk        ( ps2_clk   ),
    .ps2_data       ( ps2_data  ),

    // debug features
    .last_key       (           )
);

wire [3*COLORW-1:0] logo_rgb;
wire logo_hs, logo_vs, logo_lhbl, logo_lvbl;
wire logo_en;

`ifdef JTFRAME_OSD_NOLOGO
assign logo_en = 1'b0;
`else
assign logo_en = osd_shown;
`endif

jtframe_center_logo #(
    .COLORW(COLORW)
`ifdef JTFRAME_LOGO_NOHEX
    ,.SHOWHEX(0)
`endif
) u_logo(
    .rst        ( rst       ),
    .clk        ( clk_sys   ),
    .pxl_cen    ( pxl_cen   ),
    .show_en    ( logo_en   ),
    .chipid     ( chipid    ),

    .rgb_in     ( base_rgb  ),
    .hs         ( base_hs   ),
    .vs         ( base_vs   ),
    .lhbl       ( base_LHBL ),
    .lvbl       ( base_LVBL ),

    // VGA signals going to video connector
    .rgb_out    ( logo_rgb  ),
    .hs_out     ( logo_hs   ),
    .vs_out     ( logo_vs   ),
    .lhbl_out   ( logo_lhbl ),
    .lvbl_out   ( logo_lvbl )
);

reg rstn_74a;

always @(negedge clk_74a ) begin
    rstn_74a <= ~rst;
end

jtframe_pocket_input u_input(
    .clk                ( clk_74a    ),
    .rstn               ( rstn_74a   ),
    .clk_rom            ( clk_rom    ),
    .rst_rom            ( rst        ),

    .pad_1wire          ( bridge_1wire ),

    .cont1_key          ( cont1_key  ),
    .cont2_key          ( cont2_key  ),
    .cont3_key          ( cont3_key  ),
    .cont4_key          ( cont4_key  ),
    .cont1_joy          ( cont1_joy  ),
    .cont2_joy          ( cont2_joy  ),
    .cont3_joy          ( cont3_joy  ),
    .cont4_joy          ( cont4_joy  ),
    .cont1_trig         ( cont1_trig ),
    .cont2_trig         ( cont2_trig ),
    .cont3_trig         ( cont3_trig ),
    .cont4_trig         ( cont4_trig ),

    // Mouse
    .mouse_dy           ( mouse_dy   ),
    .mouse_dx           ( mouse_dx   ),
    .mouse_f            ( mouse_f    ),
    .mouse_idx          ( mouse_idx  ),
    .mouse_st           ( mouse_st   ),

    .key_en             ( key_en     ),
    .analog_en          ( analog_en  ),

    .st_dout            (            )
);

jtframe_pocket_ctrlmux u_controllers(
    .clk        ( clk_rom    ),
    .rst        ( rst        ),
    .cont1      ( cont1_key  ),
    .cont2      ( cont2_key  ),
    .cont3      ( cont3_key  ),
    .cont4      ( cont4_key  ),
    .snac1      ( snac_p1    ),
    .snac2      ( snac_p2    ),
    .snac3      ( snac_p3    ),
    .snac4      ( snac_p4    ),
    .plyr1      ( cont1      ),
    .plyr2      ( cont2      ),
    .plyr3      ( cont3      ),
    .plyr4      ( cont4      ),
    .debug_bus  ( debug_bus  )
);

jtframe_pocket_video #(.COLORW(COLORW)) u_video(
    .clk            ( clk_sys       ),
    .pxl2_cen       ( pxl2_cen      ),
    // scaler modes
    .rotate         ( video_sel     ),
    .sht_en         ( black_frame[0]),
    .sht_wide       ( black_frame[1]),
    // Scan-doubler video
    .base_rgb       ( logo_rgb      ),
    .base_hs        ( logo_hs       ),
    .base_vs        ( logo_vs       ),
    .base_lhbl      ( logo_lhbl     ),
    .base_lvbl      ( logo_lvbl     ),
    // Final video format
    .scal_vid       ( scal_vid      ),
    .scal_clk       ( scal_clk      ),
    .scal_de        ( scal_de       ),
    .scal_skip      ( scal_skip     ),
    .scal_vs        ( scal_vs       ),
    .scal_hs        ( scal_hs       )
);

jtframe_pocket_audio audio(
    .rst        ( rst           ),
    .clk_74a    ( clk_74a       ),
    // Base sound
    .snd_left   ( snd_left      ),
    .snd_right  ( snd_right     ),
    .snd_sample ( snd_sample    ),

    .mclk       ( audio_mclk    ),  // 12.288 MHz
    .dac        ( audio_dac     ),
    .lrck       ( audio_lrck    )
);

`ifdef JTFRAME_LF_BUFFER
    jtframe_lfbuf_cram #(.HW(`JTFRAME_LF_HW),.VW(`JTFRAME_LF_VW)) u_lfbuf(
        .rst        ( rst           ),     // hold in reset for >150 us
        .clk        ( clk_sys       ),
        .clk48      ( clk48         ),
        .pxl_cen    ( pxl_cen       ),

        // video status
        .vrender    ( game_vrender  ),
        .hdump      ( game_hdump    ),
        .hs         ( base_hs       ),
        .vs         ( base_vs       ),
        .lhbl       ( base_LHBL     ),
        .lvbl       ( base_LVBL     ),

        // core interface
        .ln_addr    ( ln_addr       ),
        .ln_data    ( ln_data       ),
        .ln_done    ( ln_done       ),
        .ln_hs      ( ln_hs         ),
        .ln_dout    ( ln_dout       ),
        .ln_pxl     ( ln_pxl        ),
        .ln_v       ( ln_v          ),
        .ln_vs      ( ln_vs         ),
        .ln_lvbl    ( ln_lvbl       ),
        .ln_we      ( ln_we         ),
        .fb_keep    ( fb_keep       ),
`ifdef JTFRAME_LF_ZOOM
        .h_step     ( game_h_step   ),
        .v_step     ( game_v_step   ),
`else
        .h_step     ( 9'h100        ),
        .v_step     ( 9'h100        ),
`endif

        // PSRAM chip
        .cr_addr    ( cr_addr       ),
        .cr_adq     ( cr_adq        ),
        .cr_advn    ( cr_advn       ),
        .cr_cen     ( cr_cen        ),
        .cr_clk     ( cr_clk        ),
        .cr_cre     ( cr_cre        ),
        .cr_dsn     ( cr_dsn        ),
        .cr_oen     ( cr_oen        ),
        .cr_wait    ( cr_wait       ),
        .cr_wen     ( cr_wen        )
    );
`else
    assign  ln_hs=0,    ln_dout=0,  ln_pxl=0,   ln_v=0,
            cr_addr=0,  cr_clk=0,   cr_cre=0,
            cr_advn=1,  cr_cen=1,   cr_dsn=1,
            cr_oen=1,   cr_wen=1;
`endif

jtframe_pocket_anavideo #(.COLORW(COLORW)) u_analogvideo (
    .rst        ( rst          ),
    .clk        ( clk_sys      ),
    .pxl_cen    ( pxl_cen      ),
    .pxl2_cen   ( pxl2_cen     ),
    .crt_cfg    ( crt_cfg      ),
    .anv_en     ( anv_en       ), // enable analogic video output
    .yc_en      ( yc_en        ), // enable composite video output
    .game_r     ( game_r       ),
    .game_g     ( game_g       ),
    .game_b     ( game_b       ),
    .LHBL       ( base_LHBL    ),
    .LVBL       ( base_LVBL    ),
    .hs         ( base_hs      ),
    .vs         ( base_vs      ),
    //Output
    .cart3_vid  ( cart3_vid    ),
    .cart2_vid  ( cart2_vid    ),
    .cart1_vid  ( cart1_vid    ),
    .cart1_vdir ( cart1_vdir   ),
    .cart2_vdir ( cart2_vdir   ),
    .cart3_vdir ( cart3_vdir   ),
    .yc_vid     ( yc_vid       )
);

endmodule
