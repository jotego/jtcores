module jtframe_resync(
    input clk, pxl_cen, hs_in, vs_in, LVBL, LHBL,
    input [3:0] hoffset, voffset,
    output hs_out, vs_out
);
    assign hs_out=hs_in, vs_out=vs_in;
endmodule

module jtframe_joymux #(parameter BUTTONS=2)(
    input rst, clk, show_osd,
    input [6:0] USER_IN,
    output [6:0] USER_OUT,
    input db15_en, osd_combo_en,
    input [15:0] joyusb_1, joyusb_2,
    output [15:0] joymux_1, joymux_2
);
    assign USER_OUT=7'h7f;
    assign joymux_1=joyusb_1, joymux_2=joyusb_2;
endmodule

module jtframe_board #(
    parameter BUTTONS=2, GAME_INPUTS_ACTIVE_LOW=1'b1, COLORW=4,
    SDRAMW=23, VIDEO_WIDTH=384, VIDEO_HEIGHT=224, MISTER=1, XOR_ROT=0
)(
    output rst, rst_n, game_rst, game_rst_n, sdram_init,
    input capture_pause, rst_req, pll_locked, clk_sys, clk_rom, clk_pico,
    input [17:0] core_mod,
    output vertical,
    output [1:0] black_frame,
    input osd_shown,
    output led,
    input signed [15:0] snd_lin, snd_rin,
    output signed [15:0] snd_lout, snd_rout,
    input [7:0] game_vol,
    output [7:0] snd_vol,
    input snd_sample, snd_peak,
    input [SDRAMW-1:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr,
    input [3:0] ba_rd, ba_wr,
    output [3:0] ba_ack, ba_rdy, ba_dst, ba_dok,
    input [15:0] ba0_din, ba1_din, ba2_din, ba3_din,
    input [1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn,
    output [15:0] sdram_dout,
    input [SDRAMW-1:0] prog_addr,
    input [15:0] prog_data,
    input [1:0] prog_dsn, prog_ba,
    input prog_we, prog_rd,
    output prog_dok, prog_rdy, prog_dst, prog_ack,
    input ioctl_cart, dwnld_busy, ioctl_ram,
    inout [15:0] SDRAM_DQ,
    output [12:0] SDRAM_A,
    output SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS,
    output [1:0] SDRAM_BA,
    output SDRAM_CKE,
    input ps2_kbd_clk, ps2_kbd_data, uart_rx,
    output uart_tx,
    input [15:0] board_joystick1, board_joystick2, board_joystick3, board_joystick4,
    input joy_aux_en, cab_active,
    input [20:0] cab_inputs,
    input cab_dump_pause,
    input [3:0] board_start, board_coin,
    input [15:0] joyana_l1, joyana_r1, joyana_l2, joyana_r2,
    output [9:0] game_joystick1, game_joystick2, game_joystick3, game_joystick4,
    output [3:0] game_coin, game_start,
    output game_service, game_tilt,
    input [8:0] bd_mouse_dx, bd_mouse_dy,
    input bd_mouse_st,
    input [7:0] bd_mouse_f,
    input bd_mouse_idx,
    input [7:0] board_paddle_1, board_paddle_2,
    input [8:0] spinner_1, spinner_2,
    output [7:0] game_paddle_1, game_paddle_2,
    output [15:0] mouse_1p, mouse_2p,
    output [1:0] mouse_strobe,
    output [1:0] dial_x, dial_y,
    output [8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y,
    output lightgun_en,
    input [63:0] status,
    input [23:0] dipsw,
    output [12:0] hdmi_arx, hdmi_ary,
    output [1:0] rotate,
    output rot_osdonly,
    output dip_test, dip_pause,
    inout dip_flip,
    output [1:0] dip_fxlevel,
    input [7:0] ioctl_din,
    output [7:0] ioctl_merged,
    input [1:0] osd_rotate,
    input [COLORW-1:0] game_r, game_g, game_b,
    input LHBL, LVBL, hs, vs,
    inout pxl2_cen, pxl_cen,
    output [3*COLORW-1:0] base_rgb,
    output base_lhbl, base_lvbl, base_hs, base_vs,
    input prog_cheat, prog_lock, ioctl_wr,
    input [7:0] ioctl_dout,
    input [12:0] ioctl_addr,
    input [31:0] cheat,
    output [7:0] st_addr,
    input [7:0] st_dout, target_info,
    input [31:0] timestamp,
    output [3:0] gfx_en,
    output [5:0] snd_en,
    input [5:0] snd_vu,
    output [7:0] debug_bus,
    input [7:0] debug_view
);
    assign rst=1'b0, rst_n=1'b1, game_rst=1'b0, game_rst_n=1'b1, sdram_init=1'b1;
    assign vertical=1'b0, black_frame=2'b0, led=1'b0;
    assign snd_lout=snd_lin, snd_rout=snd_rin, snd_vol=game_vol;
    assign ba_ack=0, ba_rdy=0, ba_dst=0, ba_dok=0, sdram_dout=0;
    assign prog_dok=0, prog_rdy=1, prog_dst=0, prog_ack=0;
    assign SDRAM_A=0, SDRAM_DQML=1, SDRAM_DQMH=1, SDRAM_nWE=1, SDRAM_nCAS=1,
           SDRAM_nRAS=1, SDRAM_nCS=1, SDRAM_BA=0, SDRAM_CKE=0;
    assign SDRAM_DQ='z;
    assign uart_tx=1'b1;
    assign game_joystick1=board_joystick1[9:0], game_joystick2=board_joystick2[9:0],
           game_joystick3=board_joystick3[9:0], game_joystick4=board_joystick4[9:0];
    assign game_coin=0, game_start=0, game_service=0, game_tilt=0;
    assign game_paddle_1=board_paddle_1, game_paddle_2=board_paddle_2;
    assign mouse_1p=0, mouse_2p=0, mouse_strobe=0;
    assign dial_x=0, dial_y=0, gun_1p_x=0, gun_1p_y=0, gun_2p_x=0, gun_2p_y=0, lightgun_en=0;
    assign hdmi_arx=0, hdmi_ary=0, rotate=0, rot_osdonly=0, dip_test=0, dip_pause=0, dip_flip=1'bz, dip_fxlevel=0;
    assign ioctl_merged=ioctl_din;
    assign base_rgb={game_r,game_g,game_b};
    assign base_lhbl=LHBL, base_lvbl=LVBL, base_hs=hs, base_vs=vs;
    assign st_addr=0, gfx_en=0, snd_en=0, debug_bus=0;
endmodule



module video_freak(
    input CLK_VIDEO, CE_PIXEL, VGA_VS,
    input [11:0] HDMI_WIDTH, HDMI_HEIGHT,
    input VGA_DE,
    output [12:0] VIDEO_ARX, VIDEO_ARY,
    input [12:0] ARX, ARY,
    input VGA_DE_IN,
    input [11:0] CROP_SIZE,
    input [4:0] CROP_OFF,
    input [2:0] SCALE
);
    assign VIDEO_ARX=ARX, VIDEO_ARY=ARY;
endmodule

module jtframe_mr_ddrmux(
    input rst, clk, ioctl_rom,
    input [7:0] ddrld_burstcnt,
    input [28:0] ddrld_addr,
    input ddrld_rd,
    output ddrld_busy,
    input rot_clk,
    input [7:0] rot_burstcnt,
    input [28:0] rot_addr,
    input rot_rd, rot_we,
    input [7:0] rot_be,
    input [63:0] rot_din,
    output rot_busy,
    output ddr_clk,
    input ddr_busy,
    output [7:0] ddr_burstcnt,
    output [28:0] ddr_addr,
    output ddr_rd, ddr_we,
    output [7:0] ddr_be,
    output [63:0] ddr_din
);
    assign ddrld_busy=0, rot_busy=0, ddr_clk=rot_clk, ddr_burstcnt=0,
           ddr_addr=0, ddr_rd=0, ddr_we=0, ddr_be=0, ddr_din=0;
endmodule

module sync_fix(input clk, in, output out); assign out=in; endmodule
module video_mixer #(
    parameter LINE_LENGTH=1, HALF_DEPTH=0, GAMMA=1
)(
    input CLK_VIDEO, ce_pix, input scandoubler, hq2x,
    inout [21:0] gamma_bus,
    input [3:0] R,G,B, input HSync,VSync,HBlank,VBlank,
    output CE_PIXEL, output [7:0] VGA_R,VGA_G,VGA_B,
    output VGA_VS,VGA_HS,VGA_DE
);
    assign CE_PIXEL=ce_pix;
    assign VGA_R={R,R}; assign VGA_G={G,G}; assign VGA_B={B,B};
    assign VGA_VS=VSync, VGA_HS=HSync, VGA_DE=~HBlank & ~VBlank;
endmodule
