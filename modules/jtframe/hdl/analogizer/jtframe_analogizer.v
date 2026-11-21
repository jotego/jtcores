/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-09-2025 */

// Intermediate module for SNAC controllers and video use with Analogizer
module jtframe_analogizer(
    input          rst,
    input          clk,
    input          pxl_cen, pxl2_cen,
    
    input   [ 1:0] anv_en,       // enable analogic video output
    output  [ 3:0] out_en,
    output    reg  snac_en,
    output         vid_en,
    input   [ 7:0] snac_cont,
    output  [15:0] snac_p1,
    output  [15:0] snac_p2,
    output  [15:0] snac_p3,
    output  [15:0] snac_p4,
    // Coin / start / service / test, JTFRAME format (board_coin / board_start of
    // jtframe_board, bit n = player n+1, 1 = pressed). Taken from the select / start
    // buttons of snac_p1..p4 (Pocket key format: [14] select, [15] start)
    output  [ 3:0] snac_coin, snac_start,
    output         snac_service, snac_test,
    // Analog sticks, JTFRAME format (same as the joyana_* inputs of jtframe_board):
    // [7:0] = X, [15:8] = Y, two's complement, 0 = center, right and bottom positive.
    // l = left stick, r = right stick, 1..4 = player
    output  [15:0] joyana_l1, joyana_r1, joyana_l2, joyana_r2,
                   joyana_l3, joyana_r3, joyana_l4, joyana_r4,
    // Light gun positions, JTFRAME_LIGHTGUN format (gun_1p_x ... of jtframe_board)
    output  [ 8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y,
    // JVS profiles from the data slots (clk_rom domain): 256 bytes each, written as
    // 32-bit words with the first byte in [31:24]. The game profile (slot 25)
    // replaces the common one (slot 24) once it has been loaded
    input          clk_rom,
    input          jvs_we,
    input          jvs_game,
    input   [ 5:0] jvs_addr,
    input   [31:0] jvs_data,
    // SNAC Pocket cartridge port interface
    input   [ 7:4] cart0_in,
    input          cartp30_in, 
    input          cartp31_in, 

    // Base video
    input          yc_en,
    input   [23:0] yc_vid,
    input   [ 7:0] cart3_vid, cart2_vid,
    input   [ 4:0] cart1_vid,
    input          cart1_vdir, cart2_vdir, cart3_vdir,

    // Final video
    output  [7:0] cart3_out,    // cart_tran_bank3         (vid_en    = 1)
    output        cart3_dir,    // cart_tran_bank3_dir     (vid_en    = 1)
    output  [7:0] cart2_out,    // cart_tran_bank2         (vid_en    = 1)
    output        cart2_dir,    // cart_tran_bank2_dir     (vid_en    = 1)
    output  [7:0] cart1_out,    // cart_tran_bank1         (out_en[0] = 1)
    output        cart1_dir,    // cart_tran_bank1_dir     (out_en[0] = 1)
    output  [7:4] cart0_out,    // cart_tran_bank0         (out_en[3] = 1)
    output        cart0_dir,    // cart_tran_bank0_dir     (snac_en   = 1)
    output        cart30_out,   // cart_tran_pin30         (out_en[2] = 1)
    output        cart30_dir,   // cart_tran_pin30_dir     (snac_en   = 1)
    output        cartp30_pwrst,// cart_pin30_pwroff_reset (out_en[0] = 1)
    output        cart31_out,   // cart_tran_pin31         (out_en[1] = 1)
    output        cart31_dir    // cart_tran_pin31_dir     (snac_en   = 1)
);

`ifndef JTFRAME_NO_ANALOGIZER
// clk (clk_sys) frequency: UART baud rate and timeouts of the SNAC controllers (JVS, PSX...)
localparam MCLK = `ifdef JTFRAME_MCLK `JTFRAME_MCLK `else 48_000_000 `endif ;
// SNAC interface (Analogizer)
reg  [ 7:6] snac1_bus;
reg  [ 7:4] snac0_bus;
reg         snac31_bus, snac30_bus,
            snac0_dir,  snac31_dir, snac30_dir;
wire [ 7:4] cart0_out_snac;
wire [ 7:6] cart1_p76_snac;
wire        cart0_dir_snac,   cartp30_dir_snac, cartp31_dir_snac;
wire        cartp30_out_snac, cartp31_out_snac, conf_AB;

assign      conf_AB   =  snac_cont[4];

assign snac_coin    = { snac_p4[14], snac_p3[14], snac_p2[14], snac_p1[14] };
assign snac_start   = { snac_p4[15], snac_p3[15], snac_p2[15], snac_p1[15] };
assign snac_service = 1'b0;         // no SNAC source yet (planned: JVS service / test switches)
assign snac_test    = 1'b0;
// No SNAC light gun source yet (planned: JVS screen position / analog axes)
assign gun_1p_x     = 9'd0;
assign gun_1p_y     = 9'd0;
assign gun_2p_x     = 9'd0;
assign gun_2p_y     = 9'd0;

// JVS profiles: vendor init table read by jvs_ctrl (MAINID, vendor frames)
reg         jvs_game_ok=0, jvs_com_ok=0;  // a game / common profile has been loaded (clk_rom)
reg  [ 1:0] jvs_game_sync=0, jvs_com_sync=0;
reg  [ 1:0] jvs_byte_sel;
wire [ 7:0] jvs_rd_addr;
wire [31:0] jvs_rd_word;
reg  [ 7:0] jvs_rd_data;

always @(posedge clk_rom) if( jvs_we ) begin
    if( jvs_game ) jvs_game_ok <= 1; else jvs_com_ok <= 1;
end

// JVS analog axes of the profile, copied when the slot writes them (index 0 = common
// profile, 1 = game profile). Byte k = profile byte D8+k: D8..DF = left stick P1 X, P1 Y,
// P2 X ... P4 Y, E0..E7 = right stick, same order. See openFPGA_Pocket_Analogizer_SNAC
reg  [127:0] jvs_axes_prof [0:1];
reg  [127:0] jvs_axes;

initial begin
    jvs_axes_prof[0] = 0;
    jvs_axes_prof[1] = 0;
end

always @(posedge clk_rom) if( jvs_we ) begin
    case( jvs_addr )   // word = 4 profile bytes, first byte in [31:24]
        6'h36: jvs_axes_prof[jvs_game][ 31: 0] <= { jvs_data[7:0], jvs_data[15:8], jvs_data[23:16], jvs_data[31:24] };
        6'h37: jvs_axes_prof[jvs_game][ 63:32] <= { jvs_data[7:0], jvs_data[15:8], jvs_data[23:16], jvs_data[31:24] };
        6'h38: jvs_axes_prof[jvs_game][ 95:64] <= { jvs_data[7:0], jvs_data[15:8], jvs_data[23:16], jvs_data[31:24] };
        6'h39: jvs_axes_prof[jvs_game][127:96] <= { jvs_data[7:0], jvs_data[15:8], jvs_data[23:16], jvs_data[31:24] };
        default:;
    endcase
end

always @(posedge clk) begin
    jvs_game_sync <= { jvs_game_sync[0], jvs_game_ok };
    jvs_com_sync  <= { jvs_com_sync[0],  jvs_com_ok  };
    jvs_axes      <= jvs_game_sync[1] ? jvs_axes_prof[1] : jvs_com_sync[1] ? jvs_axes_prof[0] : 128'd0;
    jvs_byte_sel  <= jvs_rd_addr[1:0];
end

always @* begin
    // no profile loaded: all zeros = NULL pointers, jvs_ctrl sends no vendor frame
    jvs_rd_data = 0;
    if( jvs_game_sync[1] || jvs_com_sync[1] ) case( jvs_byte_sel )
        0: jvs_rd_data = jvs_rd_word[31:24];
        1: jvs_rd_data = jvs_rd_word[23:16];
        2: jvs_rd_data = jvs_rd_word[15: 8];
        3: jvs_rd_data = jvs_rd_word[ 7: 0];
    endcase
end

jtframe_dual_ram #(.DW(32),.AW(7)) u_jvs_profiles(
    // Port 0: data slots
    .clk0   ( clk_rom       ),
    .data0  ( jvs_data      ),
    .addr0  ( { jvs_game, jvs_addr } ),
    .we0    ( jvs_we        ),
    .q0     (               ),
    // Port 1: jvs_ctrl
    .clk1   ( clk           ),
    .data1  ( 32'd0         ),
    .addr1  ( { jvs_game_sync[1], jvs_rd_addr[7:2] } ),
    .we1    ( 1'b0          ),
    .q1     ( jvs_rd_word   )
);

always @( posedge clk) begin
    snac1_bus   <=  snac_en ? cart1_p76_snac : 2'h0;
    snac0_bus   <=  cart0_out_snac;
    snac30_bus  <=  cartp30_out_snac;
    snac31_bus  <=  cartp31_out_snac;
    snac_en     <= |snac_cont;
   {snac0_dir, snac30_dir, snac31_dir} <= {cart0_dir_snac, cartp30_dir_snac, cartp31_dir_snac};
end

openFPGA_Pocket_Analogizer_SNAC #(.MASTER_CLK_FREQ(MCLK)) u_snac_controller(
    .i_clk            ( clk              ),
    .i_rst            ( rst              ),
    .conf_AB          ( conf_AB          ),
    .game_cont_type   ( snac_cont[4:0]   ),
    .p1_btn_state     ( snac_p1          ),
    .p2_btn_state     ( snac_p2          ),
    .p3_btn_state     ( snac_p3          ),
    .p4_btn_state     ( snac_p4          ),
    .joyana_l1        ( joyana_l1        ),
    .joyana_r1        ( joyana_r1        ),
    .joyana_l2        ( joyana_l2        ),
    .joyana_r2        ( joyana_r2        ),
    .joyana_l3        ( joyana_l3        ),
    .joyana_r3        ( joyana_r3        ),
    .joyana_l4        ( joyana_l4        ),
    .joyana_r4        ( joyana_r4        ),
    .jvs_vendor_addr  ( jvs_rd_addr      ),
    .jvs_vendor_data  ( jvs_rd_data      ),
    .jvs_axes         ( jvs_axes         ),
    // .busy             (                  ),
    .cart_bk0_in      ( cart0_in         ),
    .cart_bk0_out     ( cart0_out_snac   ),
    .cart_bk0_dir     ( cart0_dir_snac   ),
    .cart_bk1_out_p76 ( cart1_p76_snac   ),
    .cart_pin30_in    ( cartp30_in       ),
    .cart_pin30_out   ( cartp30_out_snac ),
    .cart_pin30_dir   ( cartp30_dir_snac ),
    .cart_pin31_in    ( cartp31_in       ),
    .cart_pin31_out   ( cartp31_out_snac ),
    .cart_pin31_dir   ( cartp31_dir_snac ),
    .o_stb            (                  )
);

jtframe_pocket_av_snac u_cartridge_mux(
    .clk          ( clk           ),
    .pxl_cen      ( pxl_cen       ),
    .pxl2_cen     ( pxl2_cen      ),
    .rst          ( rst           ),
    .anv_en       ( anv_en        ),
    .snac_en      ( snac_en       ),
    .yc_en        ( yc_en         ),
    .yc_vid       ( yc_vid        ),
    .bus_av1      ( cart1_vid     ),
    .bus_av2      ( cart2_vid     ),
    .bus_av3      ( cart3_vid     ),
    .bus_av1_dir  ( cart1_vdir    ),
    .bus_av2_dir  ( cart2_vdir    ),
    .bus_av3_dir  ( cart3_vdir    ),
    .snac0_bus    ( snac0_bus     ),
    .snac1_bus    ( snac1_bus     ),
    .snac30_bus   ( snac30_bus    ),
    .snac31_bus   ( snac31_bus    ),
    .snac0_dir    ( snac0_dir     ),
    .snac1_dir    ( 1'b1          ),
    .snac30_dir   ( snac30_dir    ),
    .snac31_dir   ( snac31_dir    ),
    .cart0_out    ( cart0_out     ),
    .cart1_out    ( cart1_out     ),
    .cart2_out    ( cart2_out     ),
    .cart3_out    ( cart3_out     ),
    .cart30_out   ( cart30_out    ),
    .cart31_out   ( cart31_out    ),
    .cartp30_pwrst( cartp30_pwrst ),
    .cart0_dir    ( cart0_dir     ),
    .cart1_dir    ( cart1_dir     ),
    .cart2_dir    ( cart2_dir     ),
    .cart3_dir    ( cart3_dir     ),
    .cart30_dir   ( cart30_dir    ),
    .cart31_dir   ( cart31_dir    ),
    .out_en       ( out_en        ),
    .vid_en       ( vid_en        )
);
`else
initial snac_en = 0;
assign  out_en  = 0;
assign  vid_en  = 0;
assign  snac_p1       = 0;
assign  snac_p2       = 0;
assign  snac_p3       = 0;
assign  snac_p4       = 0;
assign  snac_coin     = 0;
assign  snac_start    = 0;
assign  snac_service  = 0;
assign  snac_test     = 0;
assign  joyana_l1     = 0;
assign  joyana_r1     = 0;
assign  joyana_l2     = 0;
assign  joyana_r2     = 0;
assign  joyana_l3     = 0;
assign  joyana_r3     = 0;
assign  joyana_l4     = 0;
assign  joyana_r4     = 0;
assign  gun_1p_x      = 0;
assign  gun_1p_y      = 0;
assign  gun_2p_x      = 0;
assign  gun_2p_y      = 0;
assign  cart3_out     = 0;
assign  cart3_dir     = 0;
assign  cart2_out     = 0;
assign  cart2_dir     = 0;
assign  cart1_out     = 0;
assign  cart1_dir     = 0;
assign  cart0_out     = 0;
assign  cart0_dir     = 0;
assign  cart30_out    = 0;
assign  cart30_dir    = 0;
assign  cartp30_pwrst = 0;
assign  cart31_out    = 0;
assign  cart31_dir    = 0;
`endif

endmodule
