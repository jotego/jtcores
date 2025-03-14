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
    Date: 14-03-2025 */

module jtframe_target_info(
    input             clk,
    input      [15:0] joyana_l1, joyana_r1,
    input      [15:0] joystick1, joystick2,
    input      [15:0] mouse_1p, mouse_2p,
    input      [15:0] hps_index,
    input      [ 8:0] spinner_1, spinner_2,
                      spinner_3, spinner_4,
    input      [ 7:0] game_paddle_1, game_paddle_2,
    input      [ 1:0] dial_x, dial_y,
    input      [ 7:0] st_lpbuf,
    input             ioctl_lock, ioctl_cart, ioctl_ram,
                      ioctl_rom, ioctl_wr, dwnld_busy, hps_download,

    input      [ 7:0] debug_bus,
    output reg [ 7:0] target_info
);

always @(posedge clk) begin
    target_info <= 0;
    case( debug_bus[7:6] )
        0: target_info <= st_lpbuf;
        1: case( debug_bus[3:0] )
            0:  target_info <= joyana_l1[7:0];
            1:  target_info <= joyana_l1[15:8];
            2:  target_info <= joyana_r1[7:0];
            3:  target_info <= joyana_r1[15:8];
            4:  target_info <= { spinner_4[8:7], spinner_3[8:7], spinner_2[8:7], spinner_1[8:7] };
            5:  target_info <= spinner_1[7:0];
            6:  target_info <= game_paddle_1;
            7:  target_info <= game_paddle_2;
            8:  target_info <= joystick1[7:0];
            9:  target_info <= joystick2[7:0];
            10: target_info <= { 6'd0, dial_x };
            11: target_info <= { 6'd0, dial_y };
            12: target_info <= mouse_1p[7:0];
            13: target_info <= mouse_1p[15:8];
            14: target_info <= mouse_2p[7:0];
            15: target_info <= mouse_2p[15:8];
        endcase
        2: target_info <= { ioctl_lock, ioctl_cart, ioctl_ram, ioctl_rom, 1'b0, ioctl_wr, dwnld_busy, hps_download };
        3: target_info <= hps_index[7:0];
        default: target_info <= debug_bus;
    endcase
end

endmodule

module jtframe_mister_status (
    input         clk,
    input  [63:0] status,
    input  [24:0] ps2_mouse,
    input  [ 6:0] USER_IN,
    input  [ 7:0] paddle_3, paddle_4,
    output [ 7:0] game_paddle_3, game_paddle_4,
    output        crop_en,
    output [ 3:0] vcopt,
    output [ 2:0] crop_scale,
    output [ 3:0] voffset,
    output [ 3:0] hoffset,
    output        hsize_enable,
    output [ 3:0] hsize_scale,
    output [ 6:0] joy_in,
    output        mouse_st,
    output [ 7:0] mouse_f,
    output [ 8:0] mouse_dx,
    output [ 8:0] mouse_dy,
`ifdef JTFRAME_VERTICAL
    output        FB_FORCE_BLANK,
    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output [ 7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    output        FB_PAL_WR,
`endif
    output        uart_en,
    output        uart_rx,
    output        game_rx
);

reg  ps2_mouse_l;

// Vertical crop
assign crop_en    = status[41];
assign vcopt      = status[45:42];
assign crop_scale = {1'b0, status[47:46]};

// H-Pos & V-Pos for CRT
assign { voffset, hoffset } = status[60:53];

// Horizontal scaling for CRT
assign hsize_enable = status[48];
assign hsize_scale  = status[52:49];

assign game_paddle_3 = paddle_3;
assign game_paddle_4 = paddle_4;

`ifdef JTFRAME_VERTICAL
assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;
`endif

assign uart_rx  = uart_en ? USER_IN[1] : 1'b1;
assign game_rx  = uart_rx;
assign joy_in   = USER_IN;
assign uart_en  = status[38]; // It can be used by the cheat engine or the game

// Mouse
assign mouse_st = ps2_mouse[24]^ps2_mouse_l;
assign mouse_f  = ps2_mouse[7:0];
assign mouse_dx = { mouse_f[4], ps2_mouse[15: 8] };
assign mouse_dy = { mouse_f[5], ps2_mouse[23:16] };

always @(posedge clk)
    ps2_mouse_l <= ps2_mouse[24];

endmodule
