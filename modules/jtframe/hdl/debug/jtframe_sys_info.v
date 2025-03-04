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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-12-2022 */

// see debug.md for a table describing the st_dout vs st_addr

module jtframe_sys_info(
    input               rst_sys,
    input               clk,
    input               dip_flip, dip_pause, dip_test, show_credits,
    input               game_led,
    input               LVBL,
    input         [6:0] core_mod,
    input         [3:0] gfx_en,
    // sound
    input               sample,
    input         [7:0] snd_vol,
    input         [5:0] snd_en,
    input         [5:0] snd_vu,
    input signed [15:0] snd_l, snd_r,
    output              vu_peak,
    output reg          snd_mode,

    // joysticks
    input         [9:0] game_joy1,
    input        [15:0] joyana_l1,
    input         [3:0] game_coin, game_start,
    input               game_tilt, game_test, game_service, rot,

    input         [3:0] ba_rdy,
    input        [23:0] dipsw,
    // IOCTL
    input               ioctl_ram,
    input               ioctl_rom,
    input               ioctl_cart,
    // mouse
    input         [1:0] dial_x,
    input         [8:0] mouse_dx,
    input         [8:0] mouse_dy,
    input         [7:0] mouse_f,
    // lightgun
    input         [8:0] gun_1p_x,
    input         [8:0] gun_1p_y,
    input         [8:0] gun_2p_x,
    input         [8:0] gun_2p_y,
    // status select
    input         [7:0] st_addr,
    output reg    [7:0] st_dout
);

parameter MFREQ = `JTFRAME_MCLK/1000;

reg rst;

// Frame counter
wire [19:0] frame_bcd; // frame count in BCD format
wire        frame_up;
// Frequency reporting
reg  [16:0] freq_cnt=0; // Must be able to count up to 96000
reg  [ 7:0] srate;
wire [ 7:0] scnt;
reg         sl, LVBLl;
wire        sample_clr, sample_up;
// SDRAM stats
wire [ 7:0] stats;
// sound
wire [ 7:0] vu_dB;

assign frame_up   = LVBL & ~LVBLl & dip_pause;
assign sample_clr = freq_cnt == MFREQ[15:0]-1;
assign sample_up  = sample & ~sl;

always @(posedge clk) rst <= rst_sys;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        LVBLl     <= 0;
        st_dout   <= 0;
        snd_mode  <= 0;
    end else begin
        LVBLl    <= LVBL;
        snd_mode <= 0;
        case( st_addr[7:6] )
            0: casez( st_addr[1:0] )
                0: st_dout <= frame_bcd[15:8];
                1: st_dout <= frame_bcd[7:0];
                2: st_dout <= {4'd0, frame_bcd[19:16]};
                3: st_dout <= {3'd0,dip_test,2'd0,show_credits,dip_pause};
                default: st_dout <= 0;
            endcase
            1: begin
                snd_mode <= 1; // in sound mode, the hex display will always show the snd_vol
                               // but the binary view will show st_dout (see jtframe_debug)
                case(st_addr[5:4])
                    0: st_dout <= vu_dB;
                    1: case(st_addr[1:0])
                        0: st_dout <= {2'd0, snd_vu & snd_en };
                        1: st_dout <= {2'd0, snd_en};
                        2: st_dout <= srate;
                    endcase
                    2: st_dout <= snd_vol;
                    3: begin
                        snd_mode <= 0;
                        case(st_addr[3:2])
                            0: st_dout <= { gfx_en[0], gfx_en[1], gfx_en[2], gfx_en[3],
                                            1'b0, ioctl_ram, ioctl_cart, ioctl_rom };
                            1: case(st_addr[1:0])
                                0: st_dout <= dipsw[ 0+:8];
                                1: st_dout <= dipsw[ 8+:8];
                                2: st_dout <= dipsw[16+:8];
                                default: st_dout <= 0;
                            endcase
                            default: st_dout <= 0;
                        endcase
                    end
                endcase
            end
            2: st_dout <= stats; // SDRAM stats
            3: case( st_addr[5:4] )
                0: st_dout <= { core_mod[3:0], dial_x, game_led, dip_flip };
                1: case(st_addr[3:0])
                    0: st_dout <= game_joy1[7:0];
                    1: st_dout <= {game_coin[0],game_start[0],game_joy1[9:4]};
                    2: st_dout <= {rot,game_tilt,game_test,game_service,game_coin[1:0],game_start[1:0]};
                    3: st_dout <= joyana_l1[ 7:0];
                    4: st_dout <= joyana_l1[15:8];
                    5: st_dout <= mouse_dx[8:1];
                    6: st_dout <= mouse_dy[8:1];
                    7: st_dout <= mouse_f;
                endcase
                2: case(st_addr[1:0])
                    0: st_dout <= gun_1p_x[8:1];
                    1: st_dout <= gun_1p_y[8:1];
                    2: st_dout <= gun_2p_x[8:1];
                    3: st_dout <= gun_2p_y[8:1];
                endcase
                default:; // 3
            endcase
            default: st_dout <= 0;
        endcase
    end
end

jtframe_bcd_cnt #(.DIGITS(5)) u_frame_cnt(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .clr        ( 1'b0       ),
    .up         ( frame_up   ),
    .cnt        ( frame_bcd  )
);

jtframe_bcd_cnt #(.DIGITS(2),.WRAP(0)) u_sample_cnt(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .clr        ( sample_clr ),
    .up         ( sample_up  ),
    .cnt        ( scnt       )
);

always @(posedge clk) begin
    sl <= sample;
    freq_cnt <= freq_cnt + 1'd1;
    if( sample_clr ) begin // updated every 1ms
        freq_cnt <= 0;
        srate    <= scnt;
    end
end

jtframe_sdram_stats u_stats(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .rdy        ( ba_rdy        ),
    .LVBL       ( LVBL          ),
    .st_addr    ( st_addr       ),
    .st_dout    ( stats         )
);

jtframe_vumeter vumeter(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( sample        ),
    // input signals
    .l          ( snd_l         ),
    .r          ( snd_r         ),
    .vu         ( vu_dB         ),
    .peak       ( vu_peak       )
);

endmodule