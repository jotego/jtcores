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
    COLORW          = 4
) (
    input           rst,
    input           clk_sys,
    input           clk_rom,
    input           sdram_init,
    output          osd_shown,
    output  [6:0]   core_mod,
    // Base video
    input   [1:0]   osd_rotate,
    input [COLORW-1:0] game_r,
    input [COLORW-1:0] game_g,
    input [COLORW-1:0] game_b,
    input           LHBL,
    input           LVBL,
    input           hs,
    input           vs,
    input           pxl_cen,
    // Scan-doubler video
    input   [5:0]   scan2x_r,
    input   [5:0]   scan2x_g,
    input   [5:0]   scan2x_b,
    input           scan2x_hs,
    input           scan2x_vs,
    output          scan2x_enb, // scan doubler enable bar = scan doubler disable.
    input           scan2x_clk,
    // Final video: VGA+OSD or base+OSD depending on configuration
    output  [5:0]   VIDEO_R,
    output  [5:0]   VIDEO_G,
    output  [5:0]   VIDEO_B,
    output          VIDEO_HS,
    output          VIDEO_VS,
    `ifdef VIVADO
    // SPI interface to arm io controller
	input               SPI_DO_IN,
	output              SPI_DO,	
	`else
	inout               SPI_DO,
    `endif
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,    // OSD interface
    input           SPI_SS4,
    input           CONF_DATA0,
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
    output reg [7:0]debug_view,

    output          scan2x_toggle,
    output          osd_en
);

localparam [7:0] IDX_ROM   = 8'h00,
                 IDX_CHEAT = 8'h10,
                 IDX_NVRAM = 8'hFF;

wire        ypbpr, no_csync;
wire [7:0]  ioctl_index;
wire        ioctl_download, ioctl_upload;

`ifdef VIVADO
wire spi_do_uio;
wire spi_do_dio;
assign SPI_DO = CONF_DATA0 ? spi_do_dio : spi_do_uio; // DO comes from user_io when CONF_DATA0 is low
`endif

assign ioctl_rom   =  ioctl_index == IDX_ROM && ioctl_download;
assign ioctl_ram   = (ioctl_index == IDX_NVRAM && ioctl_download) || ioctl_upload;
assign ioctl_cheat = ioctl_index == IDX_CHEAT && ioctl_download;

// unsupported by the firmware
assign joyana_l2 = 0;
assign joyana_r2 = 0;
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

`ifndef NEPTUNO
    wire [1:0]  buttons;
    assign but_coin    = { 3'b0, buttons[0] };
    assign but_start   = { 3'b0, buttons[1] };

    user_io #(.ROM_DIRECT_UPLOAD(`JTFRAME_MIST_DIRECT)) u_userio(
        .clk_sys        ( clk_sys   ),

        // config string
        .conf_str       (           ),
        .conf_addr      ( cfg_addr  ),
        .conf_chr       ( cfg_dout  ),

        .SPI_CLK        ( SPI_SCK   ),
        .SPI_SS_IO      ( CONF_DATA0),

        `ifdef VIVADO
        .SPI_MISO       (spi_do_uio ),
        `else
        .SPI_MISO       (SPI_DO     ),
        `endif

        .SPI_MOSI       ( SPI_DI    ),

		`ifndef DEMISTIFY
		    .joystick_0     ( joystick2 ),
		    .joystick_1     ( joystick1 ),
		    .joystick_2     ( joystick3 ),
		    .joystick_3     ( joystick4 ),
		    // Analog joysticks
		    .joystick_analog_0(joyana_l1),
		    .joystick_analog_1(joyana_r1),
		`endif

        .buttons        ( buttons   ),

        .status         ( status    ),
        .ypbpr          ( ypbpr     ),
        .no_csync       ( no_csync  ),
        //`ifndef DEMISTIFY
        .scandoubler_disable ( scan2x_enb ),
        //`endif
        // keyboard
        .ps2_kbd_clk    ( ps2_kbd_clk  ),
        .ps2_kbd_data   ( ps2_kbd_data ),
        // Core variant
        .core_mod       ( core_mod  ),
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
    data_io #(.ROM_DIRECT_UPLOAD(1'b1)) u_datain (
        .clkref_n           ( 1'b0              ),
        .SPI_SCK            ( SPI_SCK           ),
        .SPI_SS2            ( SPI_SS2           ),
        .SPI_SS4            ( SPI_SS4           ),
        .SPI_DI             ( SPI_DI            ),
        `ifdef VIVADO
        .SPI_DO             ( spi_do_dio        ),
        .SPI_DO_IN          ( SPI_DO_IN         ),
        `else
        .SPI_DO             ( SPI_DO            ),
        `endif

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
        .ioctl_filesize     (                   )
    );

	`ifdef DEMISTIFY
        jtframe_demistify_joy u_demistify_joy(
		    .sdram_init     ( sdram_init    ),
		    .clk_sys        ( clk_sys       ),
		    .hs             ( hs            ),

		    // DB9 Joysticks
		    .joy1_bus       ( joy1_bus      ),
		    .joy2_bus       ( joy2_bus      ),
		    .JOY_SELECT     ( JOY_SELECT    ),
		    
		    .joystick1      (joystick1[11:0]),
		    .joystick2      (joystick2[11:0]),

            .scan2x_toggle  ( scan2x_toggle ),            
            .osd_en         ( osd_en        )
		);

		assign joystick1[31:12] = 0;
		assign joystick2[31:12] = 0;
		assign joystick3        = 0;
		assign joystick4        = 0;
		assign joyana_l1        = 0;
		assign joyana_r1        = 0;
	`endif

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
        .hs             ( hs            ),

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

// OSD will only get simulated if SIMULATE_OSD is defined
`ifndef SIMULATE_OSD
`ifndef SCANDOUBLER_DISABLE
`ifdef SIMULATION
`define BYPASS_OSD
`endif
`endif
`endif

`ifdef SIMINFO
initial begin
    $display("INFO: use -d SIMULATE_OSD to simulate the MiST OSD")
end
`endif


`ifndef BYPASS_OSD
// include the on screen display
wire [5:0] osd_r_o;
wire [5:0] osd_g_o;
wire [5:0] osd_b_o;
wire       HSync = scan2x_enb ? ~hs : scan2x_hs;
wire       VSync = scan2x_enb ? ~vs : scan2x_vs;
wire       HSync_osd, VSync_osd;
wire       CSync_osd = ~(HSync_osd ^ VSync_osd);

function [5:0] extend_color;
    input [COLORW-1:0] a;
    case( COLORW )
        3: extend_color = { a, a[2:0] };
        4: extend_color = { a, a[3:2] };
        5: extend_color = { a, a[4] };
        6: extend_color = a;
        7: extend_color = a[6:1];
        8: extend_color = a[7:2];
    endcase
endfunction

wire [5:0] game_r6 = extend_color( game_r );
wire [5:0] game_g6 = extend_color( game_g );
wire [5:0] game_b6 = extend_color( game_b );


osd #(0,0,6'b01_11_01) osd (
   .clk_sys    ( scan2x_enb ? clk_sys : scan2x_clk ),

   // spi for OSD
   .SPI_DI     ( SPI_DI       ),
   .SPI_SCK    ( SPI_SCK      ),
   .SPI_SS3    ( SPI_SS3      ),

   .rotate     ( osd_rotate   ),

   .R_in       ( scan2x_enb ? game_r6 : scan2x_r ),
   .G_in       ( scan2x_enb ? game_g6 : scan2x_g ),
   .B_in       ( scan2x_enb ? game_b6 : scan2x_b ),
   .HSync      ( HSync        ),
   .VSync      ( VSync        ),

   .R_out      ( osd_r_o      ),
   .G_out      ( osd_g_o      ),
   .B_out      ( osd_b_o      ),
   .HSync_out  ( HSync_osd    ),
   .VSync_out  ( VSync_osd    ),

   .osd_shown  ( osd_shown    )
);

wire       HSync_out, VSync_out, CSync_out;

RGBtoYPbPr #(6) u_rgb2ypbpr(
    .clk       ( scan2x_enb ? clk_sys : scan2x_clk ),
    .ena       ( ypbpr     ),
    .red_in    ( osd_r_o   ),
    .green_in  ( osd_g_o   ),
    .blue_in   ( osd_b_o   ),
    .hs_in     ( HSync_osd ),
    .vs_in     ( VSync_osd ),
    .cs_in     ( CSync_osd ),
    .red_out   ( VIDEO_R   ),
    .green_out ( VIDEO_G   ),
    .blue_out  ( VIDEO_B   ),
    .hs_out    ( HSync_out ),
    .vs_out    ( VSync_out ),
    .cs_out    ( CSync_out )
);

// a minimig vga->scart cable expects a composite sync signal on the VIDEO_HS output.
// and VCC on VIDEO_VS (to switch into rgb mode)
assign VIDEO_HS = ( (~no_csync & scan2x_enb) | ypbpr) ? CSync_out : HSync_out;
assign VIDEO_VS = ( (~no_csync & scan2x_enb) | ypbpr) ? 1'b1 : VSync_out;
`else
// for simulation only:
assign VIDEO_R  = game_r;
assign VIDEO_G  = game_g;
assign VIDEO_B  = game_b;
assign VIDEO_HS = hs;
assign VIDEO_VS = vs;
`endif

endmodule
