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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

module jtframe_mist_base #(parameter
    SIGNED_SND      = 1'b0,
    COLORW          = 4,
    VIDEO_WIDTH     = 384,
    VGA_DW          = 6,
    QSPI            = 1'b0,
    HDMI            = 1'b0
) (
    input           rst,
    input           clk_sys,
    input           clk_rom,
    input           sdram_init,
    output          osd_shown,
    output  [6:0]   core_mod,
    // Base video
    input   [1:0]   osd_rotate,
    input   [1:0]   rotation, // 0 - no rotation, 1 - clockwise, 2 - anticlockwise
    input           game_hs,
    input           game_vs,
    input           game_lhbl,
    input           game_lvbl,
    input [3*COLORW-1:0] game_rgb,
    input           pxl_cen,
    input           pxl2_cen,
    // Final video: VGA+OSD or base+OSD depending on configuration
    output [VGA_DW-1:0] VIDEO_R,
    output [VGA_DW-1:0] VIDEO_G,
    output [VGA_DW-1:0] VIDEO_B,
    output          VIDEO_HS,
    output          VIDEO_VS,
    // HDMI pins
    output    [7:0] HDMI_R,
    output    [7:0] HDMI_G,
    output    [7:0] HDMI_B,
    output          HDMI_HS,
    output          HDMI_VS,
    output          HDMI_DE,
    inout           HDMI_SDA,
    inout           HDMI_SCL,
    // SPI interface to arm io controller
    inout           SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,    // OSD interface
    input           SPI_SS4,
    input           CONF_DATA0,
    // QSPI interface to ARM
    input           QCSn,
    input           QSCK,
    input     [3:0] QDAT,
    // SDRAM interface for rotation
    inout    [15:0] sd_data,
    output   [12:0] sd_addr,
    output    [1:0] sd_dqm,
    output    [1:0] sd_ba,
    output          sd_cs,
    output          sd_we,
    output          sd_ras,
    output          sd_cas,
    output          sd_cke,
    // control
    output [63:0]   status,
    output [31:0]   joystick1,
    output [31:0]   joystick2,
    output [31:0]   joystick3,
    output [31:0]   joystick4,
    output [15:0]   joyana_l1,
    output [15:0]   joyana_r1,
    output [15:0]   joyana_l2,
    output [15:0]   joyana_r2,
    output [15:0]   joyana_l3,
    output [15:0]   joyana_r3,
    output [15:0]   joyana_l4,
    output [15:0]   joyana_r4,

    output [ 8:0]   mouse_dx,
    output [ 8:0]   mouse_dy,
    output [ 7:0]   mouse_f,
    output          mouse_st,
    output          mouse_idx,

    output [ 3:0]   but_coin,   // buttons, active high
    output [ 3:0]   but_start,
    // PS2 pins are outputs if NEPTUNO isn't defined
    inout           ps2_kbd_clk,
    inout           ps2_kbd_data,
    // Sound
    input           clk_dac,
    input   [15:0]  snd_left,
    input   [15:0]  snd_right,
    output          snd_pwm_left,
    output          snd_pwm_right,
    output          I2S_BCK,
    output          I2S_LRCK,
    output          I2S_DATA,
    output          SPDIF,

    // Direct joystick connection (Neptuno / MC)
    input   [5:0]   joy1_bus,
    input   [5:0]   joy2_bus,
    output          JOY_SELECT,
    
   // Buttons for MC2(+)
    input    [ 3:0] BUTTON_n,
        
    // ROM load from SPI
    output [25:0]   ioctl_addr,
    output [ 7:0]   ioctl_dout,
    input  [ 7:0]   ioctl_din,
    output          ioctl_wr,
    output          ioctl_ram,
    output          ioctl_cheat,
    output          ioctl_rom,
    // Debug
    input      [7:0]debug_bus,
    output reg [7:0]debug_view
);

localparam [7:0] IDX_ROM   = 8'h00,
                 IDX_CHEAT = 8'h10,
                 IDX_NVRAM = 8'hFF;

wire        ypbpr, no_csync;
wire [7:0]  ioctl_index;
wire        ioctl_download, ioctl_upload;

// Scan-doubler video
wire [7:0]   scan2x_r, scan2x_g, scan2x_b;
wire         scan2x_hs, scan2x_vs, scan2x_de, scan2x_enb;

assign ioctl_rom   =  ioctl_index == IDX_ROM && ioctl_download;
assign ioctl_ram   = (ioctl_index == IDX_NVRAM && ioctl_download) || ioctl_upload;
assign ioctl_cheat = ioctl_index == IDX_CHEAT && ioctl_download;

// unsupported by user_io
assign joyana_l3 = 0;
assign joyana_r3 = 0;
assign joyana_l4 = 0;
assign joyana_r4 = 0;


always @(posedge clk_sys) begin
    debug_view <= { osd_shown, 1'b0, osd_rotate, 1'b0, no_csync, ypbpr, scan2x_enb };
end

`ifndef SIMULATION
    `ifndef NOSOUND
    wire cen_dac;
    reg [3:0] cen_dac_sr;

    assign cen_dac = cen_dac_sr[0];
    always @(posedge clk_dac, posedge rst) begin
        if( rst )
            cen_dac_sr <= 4'b100;
        else begin
            cen_dac_sr <= { cen_dac_sr[2:0], cen_dac_sr[3] };
        end
    end

    function [19:0] snd_padded;
        input [15:0] snd;
        reg   [15:0] snd_in;
        begin
            snd_in = {snd[15]^SIGNED_SND[0], snd[14:0]};
            snd_padded = { 1'b0, snd_in, 3'd0 };
        end
    endfunction

    hifi_1bit_dac u_dac_left
    (
      .reset    ( rst                  ),
      .clk      ( clk_dac              ),
      .clk_ena  ( cen_dac              ),
      .pcm_in   ( snd_padded(snd_left) ),
      .dac_out  ( snd_pwm_left         )
    );

        `ifdef JTFRAME_STEREO
        hifi_1bit_dac u_dac_right
        (
          .reset    ( rst                  ),
          .clk      ( clk_dac              ),
          .clk_ena  ( cen_dac              ),
          .pcm_in   ( snd_padded(snd_right)),
          .dac_out  ( snd_pwm_right        )
        );
        `else
        assign snd_pwm_right = snd_pwm_left;
        `endif
    `else // NOSOUND
    assign snd_pwm_left  = 0;
    assign snd_pwm_right = 0;
    `endif
`else // Simulation:
assign snd_pwm_left  = 0;
assign snd_pwm_right = 0;
`endif

`ifndef SIMULATION
`ifndef NOSOUND

localparam [31:0] CLKRATE = `JTFRAME_MCLK;

wire [19:0] snd_padded_left = snd_padded(snd_left);
wire [19:0] snd_padded_right = snd_padded(snd_right);

i2s i2s(
    .reset(1'b0),
    .clk(clk_sys),
    .clk_rate(CLKRATE),

    .sclk(I2S_BCK),
    .lrclk(I2S_LRCK),
    .sdata(I2S_DATA),

    .left_chan(snd_padded_left[19:4]),
    .right_chan(snd_padded_right[19:4])
);

spdif spdif(
    .clk_i(clk_sys),
    .rst_i(1'b0),
    .clk_rate_i(CLKRATE),
    .spdif_o(SPDIF),
    .sample_i({snd_padded_right[19:4], snd_padded_left[19:4]})
);
`else
assign I2S_DATA=0, SPDIF=0, I2S_BCK=0, I2S_LRCK=0;
`endif
`endif

`ifndef JTFRAME_MIST_DIRECT
`define JTFRAME_MIST_DIRECT 1'b1
`endif

`ifndef SIMULATION
wire [9:0] cfg_addr;
wire [7:0] cfg_dout;

jtframe_ram #(.SYNFILE("cfgstr.hex")) u_cfgstr(
    .clk    ( SPI_SCK   ),
    .cen    ( 1'b1      ),
    .data   (           ),
    .addr   ( cfg_addr  ),
    .we     ( 1'b0      ),
    .q      ( cfg_dout  )
);

wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;

`ifndef NEPTUNO
    wire [1:0]  buttons;
    assign but_coin    = 4'd0;
    assign but_start   = 4'd0;
    wire [63:0] user_io_status;
	 assign status = {user_io_status[63:1], user_io_status[0] | buttons[1]}; // status[0] | buttons[1] is reset

    user_io #(.ROM_DIRECT_UPLOAD(`JTFRAME_MIST_DIRECT), .FEATURES(32'h0 /*| (QSPI << 2)*/ | (HDMI << 14))) u_userio(
        .clk_sys        ( clk_sys   ),

        // config string
        .conf_str       (           ),
        .conf_addr      ( cfg_addr  ),
        .conf_chr       ( cfg_dout  ),

        .SPI_CLK        ( SPI_SCK   ),
        .SPI_SS_IO      ( CONF_DATA0),
        .SPI_MISO       ( SPI_DO    ),
        .SPI_MOSI       ( SPI_DI    ),
        .joystick_0     ( joystick2 ),
        .joystick_1     ( joystick1 ),
        .joystick_2     ( joystick3 ),
        .joystick_3     ( joystick4 ),
        .buttons        ( buttons   ),
        // Analog joysticks
        .joystick_analog_0({joyana_r2[7:0], joyana_r2[15:8], joyana_l2}),
        .joystick_analog_1({joyana_r1[7:0], joyana_r1[15:8], joyana_l1}),

        .status         ( user_io_status ),
        .ypbpr          ( ypbpr     ),
        .no_csync       ( no_csync  ),
        .scandoubler_disable ( scan2x_enb ),
        // keyboard
        .ps2_kbd_clk    ( ps2_kbd_clk  ),
        .ps2_kbd_data   ( ps2_kbd_data ),
        // Core variant
        .core_mod       ( core_mod  ),
        // i2c bridge
        .i2c_start      (i2c_start  ),
        .i2c_read       (i2c_read   ),
        .i2c_addr       (i2c_addr   ),
        .i2c_subaddr    (i2c_subaddr),
        .i2c_dout       (i2c_dout   ),
        .i2c_din        (i2c_din    ),
        .i2c_ack        (i2c_ack    ),
        .i2c_end        (i2c_end    ),
        // unused ports:
        .serial_strobe  ( 1'b0      ),
        .serial_data    ( 8'd0      ),
        .sd_lba         ( 32'd0     ),
        .sd_rd          ( 1'b0      ),
        .sd_wr          ( 1'b0      ),
        .sd_conf        ( 1'b0      ),
        .sd_sdhc        ( 1'b0      ),
        .sd_din         ( 8'd0      ),
        .mouse_x        ( mouse_dx  ),
        .mouse_y        ( mouse_dy  ),
        .mouse_z        (           ),
        .mouse_flags    ( mouse_f   ),
        .mouse_strobe   ( mouse_st  ),
        .mouse_idx      ( mouse_idx )
    );
`else
    assign ypbpr     = 0;
    assign no_csync  = 1;
`endif
// Simulation:
`else // these inputs are not used in simulation:
    assign joystick1 = 32'd0;
    assign joystick2 = 32'd0;
    assign joystick3 = 32'd0;
    assign joystick4 = 32'd0;
    assign joyana_l1 = 0;
    assign joyana_r1 = 0;
    assign status    = 64'd0;
    assign but_coin  = 0;
    assign but_start = 0;
    `ifndef SCANDOUBLER_DISABLE
        `define SCANDOUBLER_DISABLE 1'b1
        initial $display("INFO: Use -d SCANDOUBLER_DISABLE=0 if you want video output.");
    `endif
    initial $display("INFO:SCANDOUBLER_DISABLE=%d",`SCANDOUBLER_DISABLE);
    assign scan2x_enb = `SCANDOUBLER_DISABLE;
    assign ypbpr = 1'b0;
`endif

`ifndef NEPTUNO
    data_io #(.ROM_DIRECT_UPLOAD(1'b1), .USE_QSPI(QSPI)) u_datain (
        .clkref_n           ( 1'b0              ),
        .SPI_SCK            ( SPI_SCK           ),
        .SPI_SS2            ( SPI_SS2           ),
        .SPI_SS4            ( SPI_SS4           ),
        .SPI_DI             ( SPI_DI            ),
        .SPI_DO             ( SPI_DO            ),

        .QCSn               ( QCSn              ),
        .QSCK               ( QSCK              ),
        .QDAT               ( QDAT              ),

        .clk_sys            ( clk_rom           ),
        .ioctl_download     ( ioctl_download    ),
        .ioctl_addr         ( ioctl_addr        ),
        .ioctl_dout         ( ioctl_dout        ),
        .ioctl_din          ( ioctl_din         ),
        .ioctl_wr           ( ioctl_wr          ),
        .ioctl_index        ( ioctl_index       ),
        .ioctl_upload       ( ioctl_upload      ),
        // Unused:
        .ioctl_fileext      (                   ),
        .ioctl_filesize     (                   ),

        .hdd_clk            ( 1'b0              ),
        .hdd_cmd_req        (                   ),
        .hdd_cdda_req       (                   ),
        .hdd_dat_req        (                   ),
        .hdd_cdda_wr        (                   ),
        .hdd_status_wr      (                   ),
        .hdd_addr           (                   ),
        .hdd_wr             (                   ),

        .hdd_data_out       (                   ),
        .hdd_data_in        (                   ),
        .hdd_data_rd        (                   ),
        .hdd_data_wr        (                   ),

        .hdd0_ena           (                   ),
        .hdd1_ena           (                   )
    );

    assign JOY_SELECT=0;
`else
    // Neptuno
    wire [8:0]  nept_controls;
    assign but_coin    = nept_controls[7:4];
    assign but_start   = nept_controls[3:0];
    // Mouse not supported
    assign mouse_st    = 0;
    assign mouse_dx    = 0;
    assign mouse_dy    = 0;
    assign mouse_idx   = 0;
    assign mouse_f     = 0;

    jtframe_neptuno_io u_neptuno_io(
        .sdram_init     ( sdram_init    ),
        .clk_sys        ( clk_sys       ),
        .clk_rom        ( clk_rom       ),
        .hs             ( game_hs       ),

        .SPI_SCK        ( SPI_SCK       ),
        .SPI_SS2        ( SPI_SS2       ),
        .SPI_DI         ( SPI_DI        ),
        .SPI_DO         ( SPI_DO        ),

        // Config string
        .cfg_addr       ( cfg_addr      ),
        .cfg_dout       ( cfg_dout      ),

        .ioctl_download ( ioctl_download),
        .ioctl_index    ( ioctl_index   ),
        .ioctl_wr       ( ioctl_wr      ),
        .ioctl_addr     ( ioctl_addr    ),
        .ioctl_dout     ( ioctl_dout    ),

        .core_mod       ( core_mod      ),
        .status         ( status        ),
        .scan2x_enb     ( scan2x_enb    ),

        // DB9 Joysticks
        .joy1_bus       ( joy1_bus      ),
        .joy2_bus       ( joy2_bus      ),
        .JOY_SELECT     ( JOY_SELECT    ),
        
        .BUTTON_n       ( BUTTON_n      ),
        
        // keyboard
        .ps2_kbd_clk    ( ps2_kbd_clk   ),
        .ps2_kbd_data   ( ps2_kbd_data  ),

        .joystick1      (joystick1[11:0]),
        .joystick2      (joystick2[11:0]),
        .controls       ( nept_controls )
    );

    assign joystick1[31:12] = 0;
    assign joystick2[31:12] = 0;
    assign joystick3        = 0;
    assign joystick4        = 0;
    assign joyana_l1        = 0;
    assign joyana_r1        = 0;
    assign ioctl_upload     = 0;
`endif

reg [1:0] scanlines;
reg       bw_en, blend_en;

always @(*) begin
    case( status[4:3] )
        2'd0: { scanlines, bw_en, blend_en } = { 2'd0, 2'd0 }; // pass thru
        2'd1: { scanlines, bw_en, blend_en } = { 2'd0, 2'd1 }; // no scanlines, linear interpolation
        2'd2: { scanlines, bw_en, blend_en } = { 2'd0, 2'd3 }; // analogue
        2'd3: { scanlines, bw_en, blend_en } = { 2'd1, 2'd3 }; // analogue + scan lines
    endcase // status[4:3]
    `ifdef JTFRAME_FEEDTHRU
    { scanlines, bw_en, blend_en } = { 3'd0, 2'd0 }; `endif
end

jtframe_mist_video #(
    .COLORW     ( COLORW        ),
    .VGA_DW     ( VGA_DW        ),
    .VIDEO_WIDTH( VIDEO_WIDTH   ))
u_video(
    .rst        ( rst           ),
    .clk        ( clk_sys       ),
    // base video
    .pxl_cen    ( pxl_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .game_hs    ( game_hs       ),
    .game_vs    ( game_vs       ),
    .game_lvbl  ( game_lvbl     ),
    .game_lhbl  ( game_lhbl     ),
    .game_rgb   ( game_rgb      ),
    // SPI for OSD contents
    .osd_di     ( SPI_DI        ),
    .osd_sck    ( SPI_SCK       ),
    .osd_ss3    ( SPI_SS3       ),
    .osd_rotate ( osd_rotate    ),
    .osd_shown  ( osd_shown     ),
    // low pass filter for video
    .bw_en      ( bw_en         ),
    .blend_en   ( blend_en      ),
    .scanlines  ( scanlines     ),
    .rotation   ( rotation      ),
    // video signal type
    .ypbpr      ( ypbpr         ),
    .no_csync   ( no_csync      ),
    .scan2x_en  ( ~scan2x_enb   ), // scan doubler enable bar
    .sog        ( 1'b0          ),
    .cvideo_en  ( 1'b0          ),
    .pal_en     ( 1'b0          ),
    // Scan-doubler video
    .scan2x_r   ( scan2x_r      ),
    .scan2x_g   ( scan2x_g      ),
    .scan2x_b   ( scan2x_b      ),
    .scan2x_hs  ( scan2x_hs     ),
    .scan2x_vs  ( scan2x_vs     ),
    .scan2x_de  ( scan2x_de     ),
    .scan2x_HB  (               ),
    .scan2x_VB  (               ),
    // crt video
    .video_hs   ( VIDEO_HS      ),
    .video_vs   ( VIDEO_VS      ),
    .video_de   (               ),
    .video_r    ( VIDEO_R       ),
    .video_g    ( VIDEO_G       ),
    .video_b    ( VIDEO_B       ),
    .yc_vid     (               ),
    // RAM interface for rotation
    .init       ( sdram_init    ),
    .sd_data    ( sd_data       ),
    .sd_addr    ( sd_addr       ),
    .sd_dqm     ( sd_dqm        ),
    .sd_ba      ( sd_ba         ),
    .sd_cs      ( sd_cs         ),
    .sd_we      ( sd_we         ),
    .sd_ras     ( sd_ras        ),
    .sd_cas     ( sd_cas        ),
    .sd_cke     ( sd_cke        )

);

generate if (HDMI) begin
i2c_master #(96_000_000) i2c_master (
    .CLK         (clk_sys),
    .I2C_START   (i2c_start),
    .I2C_READ    (i2c_read),
    .I2C_ADDR    (i2c_addr),
    .I2C_SUBADDR (i2c_subaddr),
    .I2C_WDATA   (i2c_dout),
    .I2C_RDATA   (i2c_din),
    .I2C_END     (i2c_end),
    .I2C_ACK     (i2c_ack),

    //I2C bus
    .I2C_SCL     (HDMI_SCL),
    .I2C_SDA     (HDMI_SDA)
);

osd #(0,0,6'b01_11_01,8) hdmi_osd (
   .clk_sys    ( clk_sys      ),

   // spi for OSD
   .SPI_DI     ( SPI_DI       ),
   .SPI_SCK    ( SPI_SCK      ),
   .SPI_SS3    ( SPI_SS3      ),

   .rotate     ( osd_rotate   ),

   .R_in       ( scan2x_r[7:0]),
   .G_in       ( scan2x_g[7:0]),
   .B_in       ( scan2x_b[7:0]),
   .DE         ( scan2x_de    ),
   .HSync      ( scan2x_hs    ),
   .VSync      ( scan2x_vs    ),

   .R_out      ( HDMI_R       ),
   .G_out      ( HDMI_G       ),
   .B_out      ( HDMI_B       ),
   .HSync_out  ( HDMI_HS      ),
   .VSync_out  ( HDMI_VS      ),
   .DE_out     ( HDMI_DE      ),
   .osd_shown  (              )
);

end else begin
  assign HDMI_SCL  = 1'bZ;
  assign HDMI_SDA  = 1'bZ;
  assign HDMI_R    = 8'd0;
  assign HDMI_G    = 8'd0;
  assign HDMI_B    = 8'd0;
  assign HDMI_HS   = 1'b0;
  assign HDMI_VS   = 1'b0;
  assign HDMI_DE   = 1'b0;
end

endgenerate
endmodule