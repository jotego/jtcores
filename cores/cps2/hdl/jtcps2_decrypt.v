/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-1-2021 */

module jtcps2_decrypt(
    input             rst,
    input             clk,

    // Key load
    input      [ 7:0] prog_din,
    input             prog_we,

    // Encryption control
    input      [ 2:0] fc,
    output            dec_en,

    // Decoding
    input             rom_ok,
    output            rom_ok_out,
    input      [23:1] addr,
    input      [15:0] din,
    output     [15:0] dout
);

wire [63:0] master_key;
wire [15:0] addr_rng, dec_data, addr_key;

jtcps2_keyload u_keyload(
    .rst       ( rst           ),
    .clk       ( clk           ),

    .din       ( prog_din      ),
    .din_we    ( prog_we       ),

    .addr_rng  ( addr_rng      ),
    .key       ( master_key    ),

    .dec_en    ( dec_en        )
);

jtcps2_fn1 u_fn1(
    .clk       ( clk           ),
    .din       ( addr[16:1]    ),
    .key       ( master_key    ),
    .dout      ( addr_key      )
);

jtcps2_fn2 u_fn2(
    .clk       ( clk           ),
    .din       ( din           ),
    .master_key( master_key    ),
    .key       ( addr_key      ),
    .dout      ( dec_data      )
);

jtcps2_dec_ctrl u_ctrl(
    .clk       ( clk           ),
    .rom_ok    ( rom_ok        ),
    .rom_ok_out( rom_ok_out    ),
    .fc        ( fc            ),
    .en        ( dec_en        ),
    .addr      ( addr          ),
    .range     ( addr_rng      ),
    .din       ( din           ),
    .dec       ( dec_data      ),
    .dout      ( dout          )
);

endmodule