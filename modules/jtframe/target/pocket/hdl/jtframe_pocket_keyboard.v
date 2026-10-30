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
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 03-02-2025 */

// Analogue doc. https://www.analogue.co/developer/docs/bus-communication#pad

module jtframe_pocket_keyboard(
    input            rst,
    input            clk,

    // data comes through the cont3 signals
    input     [31:0] cont3_joy,
    input     [15:0] cont3_trig,
    input     [15:0] cont3_key,
    input			 key_en,

    output           ps2_clk,
    output 			 ps2_data,

    // debug features
    output     [7:0] last_key
);

wire [7:0] keycheck, ps2_code;
wire       cen, released, ser_ready,
           ser_send, tx_send, tx_ready;

assign last_key = 8'b0;

jtframe_pocket_keyboard_decoder u_decoder(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .key_en    ( key_en     ),

    .press0    ( cont3_joy[ 7: 0] ),
    .press1    ( cont3_joy[15: 8] ),
    .press2    ( cont3_joy[23:16] ),
    .press3    ( cont3_joy[31:24] ),
    .press4    ( cont3_trig[ 7:0] ),
    .press5    ( cont3_trig[15:8] ),
    .spress    ( cont3_key[ 15:8] ),

    // tx part
    .released  ( released   ),  // tx data
    .key       ( keycheck   ),
    .tx_ready  ( tx_ready   ),   // low if the Tx is busy
    .tx_send   ( tx_send    )  // single-clock strobe to signal a send
);

jtframe_hid_ps2_translator u_translator(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .released  ( released   ),
    .keycheck  ( keycheck   ),
    .rq        ( tx_send    ),
    .idle      ( tx_ready   ),
    .ser_rdy   ( ser_ready  ),
    .ser_send  ( ser_send   ),
    .ps2_code  ( ps2_code   )
);

jtframe_int_cen u_key_cen(
    .clk       ( clk        ),
    .cen       ( cen        )
);

jtframe_serializer u_serializer(
    .clk       ( clk        ),
    .rst       ( rst        ),
    .cen       ( cen        ),
    .din       ( ps2_code   ),
    .send      ( ser_send   ),
    .ready     ( ser_ready  ),
    .sdout     ( ps2_data   ),
    .sclk      ( ps2_clk    )
);

endmodule