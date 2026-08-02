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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — Space Harrier game top
    Wires both 68000s, the i8751 MCU, the Z80 sound section, the shared
    dual-port RAMs, the video chain and the flight-stick inputs.

    Shared RAM: main = port A, sub = port B (jtframe mem generates *_b ports).
      subram  : main @124000  /  sub @07C000  (16K)
      roadram : main @C68000  /  sub @068000  ( 4K)
*/

module jtsharrier_game(
    `include "jtframe_game_ports.inc"
);

wire cpu_cen, cpu_cenb;
wire snd_cen;
wire mcu_cen;
wire cc_nc, ccb_nc, sc_nc, mc_nc;

// Clock enables
jtframe_frac_cen u_cpu_cen(
    .clk ( clk ), .n( 10'd57 ), .m( 10'd287 ),
    .cen ( { cc_nc,  cpu_cen  } ),
    .cenb( { ccb_nc, cpu_cenb } )
);
jtframe_frac_cen u_snd_cen(
    .clk ( clk ), .n( 10'd25 ), .m( 10'd315 ),
    .cen ( { sc_nc, snd_cen } ), .cenb(  )
);
jtframe_frac_cen u_mcu_cen(
    .clk ( clk ), .n( 10'd39 ), .m( 10'd245 ),
    .cen ( { mc_nc, mcu_cen } ), .cenb(  )
);

wire        main_rnw, main_we;
wire [23:1] main_a;
wire [15:0] main_dout;
wire [ 1:0] main_dsn;
wire        m_ram_cs, m_vram_cs, m_char_cs, m_pal_cs, m_subram_cs, m_objram_cs,
            m_road_cs, ppi0_cs, ppi1_cs, inp_cs, adc_cs;
wire        vbl;
wire [11:1] objtbl_addr;
wire [15:0] objtbl_dout, objtbl_din;
wire        objtbl_we;
wire [ 7:0] io_data;
wire [15:0] char_cpu_dout, pal_cpu_dout;

wire        mcu_en = 1'b1;
wire        mcu_we = prom_we & (prog_addr[21:12]==10'h1B0);

// Main 68000 + i8751 MCU
jtsharrier_main u_main(
    .rst      ( rst        ),  .clk      ( clk        ),
    .cen      ( cpu_cen    ),  .cenb     ( cpu_cenb   ),
    .vbl      ( vbl        ),  .mcu_en   ( mcu_en     ),  .mcu_cen ( mcu_cen ),
    .prog_addr( prog_addr[11:0] ), .prog_data( prog_data[7:0] ), .mcu_we( mcu_we ),
    .rom_cs   ( main_cs    ),  .rom_addr ( main_addr  ),
    .rom_data ( main_data  ),  .rom_ok   ( main_ok    ),
    .ram_cs   ( m_ram_cs   ),  .vram_cs  ( m_vram_cs  ),
    .char_cs  ( m_char_cs  ),  .pal_cs   ( m_pal_cs   ),
    .subram_cs( m_subram_cs),  .objram_cs( m_objram_cs),
    .road_cs  ( m_road_cs  ),
    .ppi0_cs  ( ppi0_cs    ),  .ppi1_cs  ( ppi1_cs    ),
    .inp_cs   ( inp_cs     ),  .adc_cs   ( adc_cs     ),
    .ram_data ( wram_dout  ),  .vram_data( xram_data  ),
    .vram_ok  ( xram_ok    ),
    .char_dout( char_cpu_dout ), .pal_data ( pal_cpu_dout ),
    .subram_data( subram_dout ), .obj_data ( objram_q  ),
    .road_data( roadram_dout ), .io_data  ( io_data   ),
    .cpu_dout ( main_dout  ),  .cpu_addr ( main_a     ),
    .RnW      ( main_rnw   ),  .dsn      ( main_dsn   ),  .cpu_we ( main_we )
);

wire        sub_rnw, sub_we;
wire [18:1] sub_a;
wire [15:0] sub_dout;
wire [ 1:0] sub_dsn;
wire        s_subram_cs, s_roadram_cs;

wire        sub_rstn, sub_irqn;

// Sub 68000
jtsharrier_sub u_sub(
    .rst      ( rst        ),  .clk      ( clk        ),
    .cen      ( cpu_cenb   ),  .cenb     ( cpu_cen    ),
    .sub_rstn ( sub_rstn   ),  .sub_irqn ( sub_irqn   ),
    .rom_cs   ( subrom_cs  ),  .rom_addr ( subrom_addr),
    .rom_data ( subrom_data),  .rom_ok   ( subrom_ok  ),
    .subram_cs  ( s_subram_cs ), .subram_addr ( subram_b_addr ),
    .subram_data( subram_b_dout ),
    .roadram_cs ( s_roadram_cs), .roadram_addr( roadram_b_addr ),
    .roadram_data( roadram_b_dout ),
    .cpu_dout ( sub_dout   ),  .cpu_addr ( sub_a      ),
    .RnW      ( sub_rnw    ),  .dsn      ( sub_dsn    ),  .cpu_we ( sub_we )
);

assign wram_addr = main_a[13:1];
assign wram_din  = main_dout;
assign wram_we   = {2{m_ram_cs & main_we}} & ~main_dsn;

assign xram_cs   = m_vram_cs;
assign xram_addr = main_a[15:1];
assign xram_din  = main_dout;
assign xram_dsn  = main_dsn;
assign xram_we   = m_vram_cs & main_we;

wire [15:0] objram_q;

// Sprite RAM
jtframe_dual_ram16 #(.AW(11)) u_objram(
    .clk0 ( clk        ),
    .data0( main_dout  ),
    .addr0( main_a[11:1] ),
    .we0  ( {2{m_objram_cs & main_we}} & ~main_dsn ),
    .q0   ( objram_q   ),
    .clk1 ( clk        ),
    .data1( objtbl_din ),
    .addr1( objtbl_addr),
    .we1  ({2{objtbl_we}}),
    .q1   ( objtbl_dout )
);

assign subram_addr = main_a[13:1];
assign subram_din  = main_dout;
assign subram_we   = {2{m_subram_cs & main_we}} & ~main_dsn;
assign subram_b_din = sub_dout;
assign subram_b_we  = {2{s_subram_cs & sub_we}} & ~sub_dsn;

assign roadram_addr = main_a[11:1];
assign roadram_din  = main_dout;
assign roadram_we   = {2{m_road_cs & main_we}} & ~main_dsn;
assign roadram_b_din = sub_dout;
assign roadram_b_we  = {2{s_roadram_cs & sub_we}} & ~sub_dsn;

wire [7:0] snd_latch;
wire       snd_nmi;
wire       snd_rstb;

wire signed [15:0] fm_raw, pcm_l_raw, pcm_r_raw;
wire        [ 9:0] psg_raw;

// Sound
jtsharrier_snd u_snd(
    .rst      ( rst        ),  .clk      ( clk        ),
    .debug_bus( debug_bus  ),  .pcm_st   ( pcm_st     ),
    .snd_rstb ( snd_rstb   ),
    .cen_fm   ( cen_fm     ),  .cen_pcm  ( cen_pcm    ),
    .latch    ( snd_latch  ),  .nmi_set  ( snd_nmi    ),
    .rom_addr ( snd_addr   ),  .rom_cs   ( snd_cs     ),
    .rom_data ( snd_data   ),  .rom_ok   ( snd_ok     ),
    .pcm_addr ( pcm_addr   ),  .pcm_cs   ( pcm_cs     ),
    .pcm_data ( pcm_data   ),  .pcm_ok   ( pcm_ok     ),
    .fm_snd   ( fm_raw     ),  .psg_snd  ( psg_raw    ),
    .pcm_l    ( pcm_l_raw  ),  .pcm_r    ( pcm_r_raw  )
);

assign fm    = fm_raw;
assign pcm_l = pcm_l_raw;
assign pcm_r = pcm_r_raw;
assign psg   = psg_raw;

wire [7:0] lamps;

// Sound Z80 reset, PPI0 port B bit 5. Traced on the CPU board schematic: IC121's
// port B carries Sega's own net names -- COIN1, COIN2, LAMP1, LAMP2, KILL, SHADE,
// FLIPC -- and PB5 leaves via the edge connector, arriving at the sound board as
// RESET and reaching the Z80 through the LS244 at 12C.
assign snd_rstb = lamps[5];

// PPI0 port B bit 4 is the game's own display enable, KILL on the schematic.
// jt8255 drives port B to 0 at reset, so the screen is legitimately off for
// part of boot -- if this ever ships black, check lamps[4] first.
wire dis_en = lamps[4];
wire [`JTFRAME_COLORW-1:0] vid_red, vid_green, vid_blue;

assign red   = dis_en ? vid_red   : {`JTFRAME_COLORW{1'b0}};
assign green = dis_en ? vid_green : {`JTFRAME_COLORW{1'b0}};
assign blue  = dis_en ? vid_blue  : {`JTFRAME_COLORW{1'b0}};
wire       colscr_en, rowscr_en;
// Neutral is 0x80 on both axes. The game clamps X to 0x20..0xE0 and Y to
// 0x60..0xC0, so Y's throw is asymmetric -- 0x90 is the midpoint of Y's
// window, not the neutral.
localparam signed [9:0] AN_LIMIT = 10'sd96;
localparam signed [9:0] AN_STEP  = 10'sd4;

wire dp_up    = ~joystick1[3];
wire dp_down  = ~joystick1[2];
wire dp_left  = ~joystick1[1];
wire dp_right = ~joystick1[0];

reg  [19:0] an_div;
wire        an_tick = an_div==20'd0;
reg  signed [9:0] dig_x, dig_y;

wire dpad_arcade = dipsw[29];

always @(posedge clk) begin
    if( rst ) begin
        an_div <= 0;
        dig_x  <= 0;
        dig_y  <= 0;
    end else begin
        an_div <= an_div==20'd838_632 ? 20'd0 : an_div+20'd1;
        if( an_tick ) begin
            if( dp_right ^ dp_left ) begin
                if( dp_right ) dig_x <= dig_x + AN_STEP >  AN_LIMIT ?  AN_LIMIT : dig_x + AN_STEP;
                else           dig_x <= dig_x - AN_STEP < -AN_LIMIT ? -AN_LIMIT : dig_x - AN_STEP;
            end else if( dpad_arcade ) begin
                if     ( dig_x >  AN_STEP ) dig_x <= dig_x - AN_STEP;
                else if( dig_x < -AN_STEP ) dig_x <= dig_x + AN_STEP;
                else                        dig_x <= 0;
            end
            if( dp_down ^ dp_up ) begin
                if( dp_down )  dig_y <= dig_y + AN_STEP >  AN_LIMIT ?  AN_LIMIT : dig_y + AN_STEP;
                else           dig_y <= dig_y - AN_STEP < -AN_LIMIT ? -AN_LIMIT : dig_y - AN_STEP;
            end else if( dpad_arcade ) begin
                if     ( dig_y >  AN_STEP ) dig_y <= dig_y - AN_STEP;
                else if( dig_y < -AN_STEP ) dig_y <= dig_y + AN_STEP;
                else                        dig_y <= 0;
            end
        end
    end
end

wire signed [9:0] ana_x = { {2{joyana_l1[ 7]}}, joyana_l1[ 7:0] };
wire signed [9:0] ana_y = { {2{joyana_l1[15]}}, joyana_l1[15:8] };
wire       ctl_probe = debug_bus[7:5]==3'b001;
wire [1:0] ctl_mode  = ctl_probe ? debug_bus[4:3] : 2'd0;
wire       ctl_ana   = ctl_mode!=2'd2;
wire       ctl_dig   = ctl_mode!=2'd1;
wire       ctl_centre= ctl_mode==2'd3;

wire signed [9:0] sum_x = ctl_centre ? 10'sd0 :
                          (ctl_ana ? ana_x : 10'sd0) + (ctl_dig ? dig_x : 10'sd0);
wire signed [9:0] sum_y = ctl_centre ? 10'sd0 :
                          (ctl_ana ? ana_y : 10'sd0) + (ctl_dig ? dig_y : 10'sd0);
wire signed [9:0] clp_x = sum_x >  AN_LIMIT ?  AN_LIMIT : (sum_x < -AN_LIMIT ? -AN_LIMIT : sum_x);
wire signed [9:0] clp_y = sum_y >  AN_LIMIT ?  AN_LIMIT : (sum_y < -AN_LIMIT ? -AN_LIMIT : sum_y);

wire              invert_y = dipsw[28];
wire signed [9:0] clp_yf   = invert_y ? -clp_y : clp_y;

wire [ 9:0] mag_y   = clp_yf[9] ? -clp_yf : clp_yf;
wire [17:0] scl_y   = mag_y * (clp_yf[9] ? 10'd171 : 10'd86);
wire [ 7:0] off_y   = scl_y[15:8];
wire [ 7:0] an_x_raw = 8'h80 - clp_x[7:0];
wire [ 7:0] an_y_raw = clp_yf[9] ? 8'h80 + off_y : 8'h80 - off_y;

reg  [7:0] an_x, an_y;
reg        anl_vbl;
always @(posedge clk) begin
    anl_vbl <= vbl;
    if( rst ) begin
        an_x <= 8'h80;
        an_y <= 8'h80;
    end else if( vbl & ~anl_vbl ) begin
        an_x <= an_x_raw;
        an_y <= an_y_raw;
    end
end

wire [ 7:0] video_debug_view;
wire [ 7:0] pcm_st;
reg  [ 7:0] ctl_dbg;
always @(*) begin
    case( debug_bus[2:0] )
        3'd0: ctl_dbg = an_x;
        3'd1: ctl_dbg = an_y;
        3'd2: ctl_dbg = joyana_l1[ 7:0];
        3'd3: ctl_dbg = joyana_l1[15:8];
        3'd4: ctl_dbg = dig_x[7:0];
        3'd5: ctl_dbg = dig_y[7:0];
        3'd6: ctl_dbg = joystick1;
        3'd7: ctl_dbg = { 4'd0, dp_up, dp_down, dp_left, dp_right };
    endcase
end
wire       pcm_probe = debug_bus[7:5]==3'b010;
assign debug_view = ctl_probe ? ctl_dbg :
                    pcm_probe ? pcm_st  : video_debug_view;

// I/O: two i8255 PPIs, inputs and ADC
jtsharrier_io u_io(
    .rst     ( rst           ), .clk ( clk ), .cen ( cpu_cen ),
    .addr    ( main_a[2:1]    ),
    .cpu_dout( main_dout[7:0] ),
    .rnw     ( main_rnw       ),
    .dswn    ( main_dsn[0]    ),
    .ppi0_cs ( ppi0_cs        ), .ppi1_cs( ppi1_cs ),
    .inp_cs  ( inp_cs         ), .adc_cs ( adc_cs  ),
    .io_data ( io_data        ),
    .cab_in  ( { joystick1[6:4],
                 cab_1p[0],
                 service  & joystick1[8],
                 dip_test & joystick1[7],
                 coin[1:0] } ),
    .dip_swa ( dipsw[7:0]     ),
    .dip_swb ( dipsw[15:8]    ),
    .an_x    ( an_x           ), .an_y( an_y  ),
    .snd_latch( snd_latch     ), .snd_nmi ( snd_nmi ),
    .sub_rstn ( sub_rstn      ), .sub_irqn( sub_irqn ),
    .lamps   ( lamps          ),
    .colscr_en( colscr_en     ), .rowscr_en( rowscr_en )
);

// Video
jtsharrier_video u_video(
    .rst      ( rst          ), .clk     ( clk      ),
    .pxl_cen  ( pxl_cen      ), .pxl2_cen( pxl2_cen ),
    .dip_pause( dip_pause    ),
    .colscr_en( colscr_en    ), .rowscr_en( rowscr_en ),
    .char_cs  ( m_char_cs    ), .pal_cs  ( m_pal_cs ),
    .vfix_en  ( ~dipsw[31]   ),
    .cpu_addr ( main_a[12:1] ),
    .cpu_dout ( main_dout    ), .dsn     ( main_dsn ),
    .char_dout( char_cpu_dout), .pal_dout( pal_cpu_dout ),
    .char_ok  ( char_ok      ), .char_addr( char_addr ), .char_data( char_data ),
    .map1_ok  ( map1_ok      ), .map1_addr( map1_addr ), .map1_data( map1_data ),
    .scr1_ok  ( scr1_ok      ), .scr1_addr( scr1_addr ), .scr1_data( scr1_data ),
    .map2_ok  ( map2_ok      ), .map2_addr( map2_addr ), .map2_data( map2_data ),
    .scr2_ok  ( scr2_ok      ), .scr2_addr( scr2_addr ), .scr2_data( scr2_data ),
    .red      ( vid_red      ), .green   ( vid_green ), .blue( vid_blue ),
    .HS       ( HS           ), .VS      ( VS    ),
    .LHBL     ( LHBL         ), .LVBL    ( LVBL  ),
    .vbl      ( vbl          ),
    .objtbl_addr( objtbl_addr ), .objtbl_dout( objtbl_dout ),
    .objtbl_din ( objtbl_din  ), .objtbl_we  ( objtbl_we   ),
    .zoom_addr  ( zoom_addr   ), .zoom_data  ( zoom_data   ),
    .obj_ok     ( obj_ok      ), .obj_cs     ( obj_cs      ),
    .obj_addr   ( obj_addr    ), .obj_data   ( obj_data    ),
    .road0_addr ( road0_addr  ), .road0_data ( road0_data  ),
    .rr_main_addr( roadram_addr ), .rr_main_din( roadram_din ), .rr_main_we( roadram_we ),
    .rr_sub_addr ( roadram_b_addr ), .rr_sub_din( roadram_b_din ), .rr_sub_we( roadram_b_we ),
    .gfx_en     ( gfx_en      ),
    .debug_bus  ( debug_bus   ), .debug_view ( video_debug_view )
);

assign gfx_cs = 1'b1;

endmodule
