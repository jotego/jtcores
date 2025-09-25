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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 22-09-2025 */

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

always @( posedge clk) begin
    snac1_bus   <=  snac_en ? cart1_p76_snac : 2'h0;
    snac0_bus   <=  cart0_out_snac;
    snac30_bus  <=  cartp30_out_snac;
    snac31_bus  <=  cartp31_out_snac;
    snac_en     <= |snac_cont;
   {snac0_dir, snac30_dir, snac31_dir} <= {cart0_dir_snac, cartp30_dir_snac, cartp31_dir_snac};
end

openFPGA_Pocket_Analogizer_SNAC u_snac_controller(
    .i_clk            ( clk              ),
    .i_rst            ( rst              ),
    .conf_AB          ( conf_AB          ),
    .game_cont_type   ( snac_cont[4:0]   ),
    .p1_btn_state     ( snac_p1          ),
    .p2_btn_state     ( snac_p2          ),
    .p3_btn_state     ( snac_p3          ),
    .p4_btn_state     ( snac_p4          ),
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