// Auto-generated passive module stubs from sys_top.v instantiation ports.
// All ports are inputs so these modules never drive tested top-level nets.
module mcp23009 (
    input clk,
    input btn,
    input led,
    input flg_sd_cd,
    input flg_present,
    input flg_mode,
    input scl,
    input sda
);
endmodule

module cyclonev_hps_interface_mpu_general_purpose (
    input gp_in,
    input gp_out
);
endmodule

module cyclonev_hps_interface_peripheral_uart (
    input ri,
    input dsr,
    input dcd,
    input dtr,
    input cts,
    input rts,
    input rxd,
    input txd
);
endmodule

module cyclonev_hps_interface_interrupts (
    input irq
);
endmodule

module sysmem_lite (
    input reset_core_req,
    input reset_out,
    input clock,
    input reset_hps_cold_req,
    input ram1_clk,
    input ram1_address,
    input ram1_burstcount,
    input ram1_waitrequest,
    input ram1_readdata,
    input ram1_readdatavalid,
    input ram1_read,
    input ram1_writedata,
    input ram1_byteenable,
    input ram1_write,
    input ram2_clk,
    input ram2_address,
    input ram2_burstcount,
    input ram2_waitrequest,
    input ram2_readdata,
    input ram2_readdatavalid,
    input ram2_read,
    input ram2_writedata,
    input ram2_byteenable,
    input ram2_write,
    input vbuf_clk,
    input vbuf_address,
    input vbuf_burstcount,
    input vbuf_waitrequest,
    input vbuf_writedata,
    input vbuf_byteenable,
    input vbuf_write,
    input vbuf_readdata,
    input vbuf_readdatavalid,
    input vbuf_read
);
endmodule

module ddr_svc (
    input clk,
    input ram_waitrequest,
    input ram_burstcnt,
    input ram_addr,
    input ram_readdata,
    input ram_read_ready,
    input ram_read,
    input ram_writedata,
    input ram_byteenable,
    input ram_write,
    input ram_bcnt,
    input ch0_addr,
    input ch0_burst,
    input ch0_data,
    input ch0_req,
    input ch0_ready,
    input ch1_addr,
    input ch1_burst,
    input ch1_data,
    input ch1_req,
    input ch1_ready
);
endmodule

module ascal #(parameter RAMBASE=0, parameter RAMSIZE=0, parameter PALETTE2="false",
               parameter ADAPTIVE="true", parameter DOWNSCALE_NN="false",
               parameter FRAC=0, parameter N_DW=128, parameter N_AW=28) (
    input reset_na,
    input run,
    input freeze,
    input bob_deint,
    input i_clk,
    input i_ce,
    input i_r,
    input i_g,
    input i_b,
    input i_hs,
    input i_vs,
    input i_fl,
    input i_de,
    input iauto,
    input himin,
    input himax,
    input vimin,
    input vimax,
    input o_clk,
    input o_ce,
    input o_r,
    input o_g,
    input o_b,
    input o_hs,
    input o_vs,
    input o_de,
    input o_vbl,
    input o_brd,
    input gun_border_en,
    input o_lltune,
    input htotal,
    input hsstart,
    input hsend,
    input hdisp,
    input hmin,
    input hmax,
    input vtotal,
    input vsstart,
    input vsend,
    input vdisp,
    input vmin,
    input vmax,
    input vrr,
    input vrrmax,
    input swblack,
    input mode,
    input poly_clk,
    input poly_a,
    input poly_dw,
    input poly_wr,
    input pal1_clk,
    input pal1_dw,
    input pal1_a,
    input pal1_wr,
    input pal2_clk,
    input pal2_dw,
    input pal2_dr,
    input pal2_a,
    input pal2_wr,
    input pal_n,
    input o_fb_ena,
    input o_fb_hsize,
    input o_fb_vsize,
    input o_fb_format,
    input o_fb_base,
    input o_fb_stride,
    input avl_clk,
    input avl_waitrequest,
    input avl_readdata,
    input avl_readdatavalid,
    input avl_burstcount,
    input avl_writedata,
    input avl_address,
    input avl_write,
    input avl_read,
    input avl_byteenable
);
endmodule

module sys_umuldiv #(parameter P0=0, parameter P1=0, parameter P2=0) (
    input clk,
    input start,
    input busy,
    input mul1,
    input mul2,
    input div,
    input result
);
endmodule

module pll_hdmi_adj (
    input clk,
    input reset_na,
    input llena,
    input lltune,
    input locked,
    input i_waitrequest,
    input i_write,
    input i_address,
    input i_writedata,
    input o_waitrequest,
    input o_write,
    input o_address,
    input o_writedata
);
endmodule

module pll_hdmi (
    input refclk,
    input rst,
    input reconfig_to_pll,
    input reconfig_from_pll,
    input outclk_0
);
endmodule

module pll_cfg_hdmi (
    input mgmt_clk,
    input mgmt_reset,
    input mgmt_waitrequest,
    input mgmt_write,
    input mgmt_address,
    input mgmt_writedata,
    input reconfig_to_pll,
    input reconfig_from_pll
);
endmodule

module cyclonev_hps_interface_peripheral_i2c (
    input out_clk,
    input scl,
    input out_data,
    input sda
);
endmodule

module shadowmask (
    input clk,
    input clk_sys,
    input cmd_wr,
    input cmd_in,
    input din,
    input hs_in,
    input vs_in,
    input de_in,
    input brd_in,
    input enable,
    input dout,
    input hs_out,
    input vs_out,
    input de_out
);
endmodule

module osd #(parameter NATIVE_PIXEL=0) (
    input clk_sys,
    input io_osd,
    input io_strobe,
    input io_din,
    input clk_video,
    input ce_in,
    input din,
    input hs_in,
    input vs_in,
    input de_in,
    input dout,
    input hs_out,
    input vs_out,
    input de_out,
    input osd_status
);
endmodule

module cyclonev_clkselect (
    input clkselect,
    input inclk,
    input outclk
);
endmodule

module altddio_out #(parameter extend_oe_disable=0, parameter intended_device_family=0, parameter invert_output=0, parameter lpm_hint=0, parameter lpm_type=0, parameter oe_reg=0, parameter power_up_high=0, parameter width=0) (
    input datain_h,
    input datain_l,
    input outclock,
    input dataout,
    input aclr,
    input aset,
    input oe,
    input outclocken,
    input sclr,
    input sset
);
endmodule

module scanlines #(parameter P0=0) (
    input clk,
    input scanlines,
    input din,
    input hs_in,
    input vs_in,
    input de_in,
    input ce_in,
    input dout,
    input hs_out,
    input vs_out,
    input de_out,
    input ce_out
);
endmodule

module jtframe_hretime #(parameter DIV=0, parameter DIV_ALT_X2=0, parameter STEP=0, parameter DEPTH=0) (
    input clk,
    input ce_in,
    input enable,
    input div_alt,
    input scale,
    input din,
    input hs_in,
    input vs_in,
    input de_in,
    input ce_out,
    input dout,
    input hs_out,
    input vs_out,
    input de_out
);
endmodule

module yc_out (
    input clk,
    input PAL_EN,
    input CVBS,
    input PHASE_INC,
    input COLORBURST_RANGE,
    input hsync,
    input vsync,
    input csync,
    input de,
    input dout,
    input din,
    input hsync_o,
    input vsync_o,
    input csync_o,
    input de_o
);
endmodule

module vga_out (
    input clk,
    input ypbpr_en,
    input hsync,
    input vsync,
    input csync,
    input de,
    input dout,
    input din,
    input hsync_o,
    input vsync_o,
    input csync_o,
    input de_o
);
endmodule

module pll_audio (
    input refclk,
    input rst,
    input outclk_0
);
endmodule

module audio_out (
    input reset,
    input clk,
    input att,
    input mix,
    input sample_rate,
    input flt_rate,
    input cx,
    input cx0,
    input cx1,
    input cx2,
    input cy0,
    input cy1,
    input cy2,
    input is_signed,
    input core_l,
    input core_r,
    input alsa_l,
    input alsa_r,
    input i2s_bclk,
    input i2s_lrclk,
    input i2s_data,
    input dac_l,
    input dac_r,
    input spdif
);
endmodule

module cyclonev_hps_interface_peripheral_spi_master (
    input sclk_out,
    input txd,
    input rxd,
    input ss_0_n,
    input ss_in_n
);
endmodule

module alsa (
    input reset,
    input clk,
    input ram_address,
    input ram_data,
    input ram_req,
    input ram_ready,
    input spi_ss,
    input spi_sck,
    input spi_mosi,
    input spi_miso,
    input pcm_l,
    input pcm_r
);
endmodule

module emu (
    input CLK_50M,
    input RESET,
    input HPS_BUS,
    input VGA_R,
    input VGA_G,
    input VGA_B,
    input VGA_HS,
    input VGA_VS,
    input VGA_DE,
    input VGA_F1,
    input VGA_SCALER,
    input VGA_DISABLE,
    input VGA_HSIZE,
    input HDMI_WIDTH,
    input HDMI_HEIGHT,
    input HDMI_FREEZE,
    input HDMI_BLACKOUT,
    input HDMI_BOB_DEINT,
    input CLK_VIDEO,
    input CE_PIXEL,
    input VGA_SL,
    input VIDEO_ARX,
    input VIDEO_ARY,
    input FB_EN,
    input FB_FORMAT,
    input FB_WIDTH,
    input FB_HEIGHT,
    input FB_BASE,
    input FB_STRIDE,
    input FB_VBL,
    input FB_LL,
    input FB_FORCE_BLANK,
    input FB_PAL_CLK,
    input FB_PAL_ADDR,
    input FB_PAL_DOUT,
    input FB_PAL_DIN,
    input FB_PAL_WR,
    input LED_USER,
    input LED_POWER,
    input LED_DISK,
    input CLK_AUDIO,
    input AUDIO_L,
    input AUDIO_R,
    input AUDIO_S,
    input AUDIO_MIX,
    input ADC_BUS,
    input DDRAM_CLK,
    input DDRAM_ADDR,
    input DDRAM_BURSTCNT,
    input DDRAM_BUSY,
    input DDRAM_DOUT,
    input DDRAM_DOUT_READY,
    input DDRAM_RD,
    input DDRAM_DIN,
    input DDRAM_BE,
    input DDRAM_WE,
    input SDRAM_DQ,
    input SDRAM_A,
    input SDRAM_DQML,
    input SDRAM_DQMH,
    input SDRAM_BA,
    input SDRAM_nCS,
    input SDRAM_nWE,
    input SDRAM_nRAS,
    input SDRAM_nCAS,
    input SDRAM_CLK,
    input SDRAM_CKE,
    input SDRAM2_DQ,
    input SDRAM2_A,
    input SDRAM2_BA,
    input SDRAM2_nCS,
    input SDRAM2_nWE,
    input SDRAM2_nRAS,
    input SDRAM2_nCAS,
    input SDRAM2_CLK,
    input SDRAM2_EN,
    input BUTTONS,
    input OSD_STATUS,
    input SD_SCK,
    input SD_MOSI,
    input SD_MISO,
    input SD_CS,
    input SD_CD,
    input UART_CTS,
    input UART_RTS,
    input UART_RXD,
    input UART_TXD,
    input UART_DTR,
    input UART_DSR,
    input USER_OUT,
    input USER_IN,
    input db15_en,
    input uart_en,
    input gun_border_en,
    input show_osd
);
endmodule
