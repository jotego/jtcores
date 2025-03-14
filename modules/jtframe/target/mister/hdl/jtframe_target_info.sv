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
