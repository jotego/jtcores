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
    Date: 12-6-2021 */
    
`ifdef MULTICORE2PLUS
    `define MC2_PINS
`endif

`ifdef MULTICORE2
    `define MC2_PINS
`endif

module jtframe_neptuno_io(
    input          sdram_init,
    input          clk_sys,
    input          clk_rom,
    input          hs,

    input          SPI_SCK,
    input          SPI_SS2,
    input          SPI_DI,
    output         SPI_DO,

    // Config string
    output   [9:0] cfg_addr,
    input    [7:0] cfg_dout,

    output         ioctl_download,
    output   [7:0] ioctl_index,
    output         ioctl_wr,
    output  [24:0] ioctl_addr,
    output   [7:0] ioctl_dout,

    output  [ 6:0] core_mod,
    output  [63:0] status,
    output         scan2x_enb,

    // DB9 Joysticks
    input    [5:0] joy1_bus,
    input    [5:0] joy2_bus,
    output         JOY_SELECT,
    
    // keyboard
    input          ps2_kbd_clk,
    input          ps2_kbd_data,

    output  [11:0] joystick1,
    output  [11:0] joystick2,
    output  [ 8:0] controls,
    
    // Buttons for MC2(+)
    input   [ 3:0] BUTTON_n
);

reg [7:0] nept_din=8'hff;
reg       dwn_done;
reg [15:0] cntdown;

localparam [4:0] NEPT_KEY_UP     = 30,
                 NEPT_KEY_DOWN   = 29,
                 NEPT_KEY_LEFT   = 27,
                 NEPT_KEY_RIGHT  = 23,
                 NEPT_KEY_RETURN = 15;
localparam [2:0] NEPT_CMD_NOP = 3'b111,
                 NEPT_CMD_OSD = 3'b011;

reg [4:0] nept_key;
reg [2:0] nept_cmd;
reg       scandb_s = 0;

wire [11:0] joy_mix = joystick1[11:0] | joystick2[11:0];
wire [ 7:0] osd_s;
wire [31:0] status_s;

wire        mc_reset;
wire        toggle_scandb;

// wire scan2x_toggle = joy_mix[10] & joy_mix[7]; // Start + B buttons
wire osd_en = joy_mix[10] & joy_mix[6]; // Start + C buttons of Megadrive controller
wire osd_en_filt;

jtframe_enlarger #(4) u_enlarger(
    .rst        ( sdram_init    ),
    .clk        ( clk_sys       ),
    .cen        ( hs            ),
    .pulse_in   ( osd_en        ),
    .pulse_out  ( osd_en_filt   )
);

always @(*) begin
    case( 1'b1 )
        joy_mix[0]: nept_key = NEPT_KEY_RIGHT;
        joy_mix[1]: nept_key = NEPT_KEY_LEFT;
        joy_mix[2]: nept_key = NEPT_KEY_DOWN;
        joy_mix[3]: nept_key = NEPT_KEY_UP;
        joy_mix[4]: nept_key = NEPT_KEY_RETURN;
        default: nept_key = 5'h1f;
    endcase
    // Bring up OSD if three buttons are pressed
    nept_cmd = osd_en_filt ? NEPT_CMD_OSD : NEPT_CMD_NOP;
end

always @(posedge clk_sys) begin
    if( sdram_init ) begin
        nept_din <= 8'hff;
        dwn_done <= 0;
        cntdown  <= ~16'd0;
    end else begin
        if( ioctl_download ) begin
            dwn_done <= 1;
        end
        if ( cntdown!=0 ) begin
            cntdown <= cntdown-1'd1;
            nept_din <= 8'hff;
        end else begin

`ifdef MC2_PINS
            nept_din <= dwn_done ? osd_s : 8'h3f; 
`else
            nept_din <= dwn_done ? { nept_cmd ,nept_key } : 8'h3f;
`endif              
        end
    end
end

data_io  u_datain (
    .SPI_SCK            ( SPI_SCK           ),
    .SPI_SS2            ( SPI_SS2           ),
    .SPI_DI             ( SPI_DI            ),
    .SPI_DO             ( SPI_DO            ),

    .data_in            ( nept_din          ),
    .conf_addr          ( cfg_addr          ),
    .conf_chr           ( cfg_dout          ),
    .status             ( status_s          ),
    .core_mod           ( core_mod          ),

    .clk_rom            ( clk_rom           ),
    .ioctl_download     ( ioctl_download    ),
    .ioctl_addr         ( ioctl_addr        ),
    .ioctl_dout         ( ioctl_dout        ),
    .ioctl_wr           ( ioctl_wr          ),
    .ioctl_index        ( ioctl_index       ),
    // Unused
    .config_buffer_o    (                   )
);

assign status[31:0]  = { status_s[31:1], status_s[0] | mc_reset }; 
assign status[63:32] = ~32'h0; // This is less troublesome for DIP switches
assign scan2x_enb = scandb_s ^ toggle_scandb; // scan doubler enabled

jtframe_neptuno_joy u_joysticks(
    .clk          ( clk_sys       ),
    .reset        ( sdram_init    ),

    .joy1_bus     ( joy1_bus      ),
    .joy2_bus     ( joy2_bus      ),
    .joy_select   ( JOY_SELECT    ),
    
    .ps2_kbd_clk  ( ps2_kbd_clk   ),
    .ps2_kbd_data ( ps2_kbd_data  ),
    .BUTTON_n     ( BUTTON_n      ),
    
    .joy1         ( joystick1[11:0] ),
    .joy2         ( joystick2[11:0] ),
    .controls     ( controls      ),
  
    .osd          ( osd_s         ),
    .mc_reset     ( mc_reset      ),
    .toggle_scandb( toggle_scandb )
);





endmodule