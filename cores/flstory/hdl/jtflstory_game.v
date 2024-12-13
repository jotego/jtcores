/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 23-11-2024 */

module jtflstory_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        ghflip, gvflip, m2s_wr, s2m_rd, bus_a0, scr_flen, clip, no_used,
            mcu_ibf, mcu_obf, busrq_n, busak_n, c2b_we, c2b_rd, b2c_rd, b2c_wr;
wire [15:0] c2b_addr, bus_addr;
wire [ 7:0] bus_din, s2m_data, st_snd,
            c2b_dout, cpu_dout, mcu2bus;
reg  [ 7:0] st_mux;
wire [ 1:0] pal_bank, scr_bank;
wire        rst_main, cen_hb, mute;
reg         lhbl_l;

assign bus_a0     = bus_addr[0];
assign dip_flip   = gvflip | ghflip;
assign ioctl_din  = {mute,scr_flen, gvflip, ghflip, pal_bank, scr_bank};
assign debug_view = st_mux;
assign pal16_addr = {pal_bank,bus_addr[7:0]};

always @(posedge clk) begin
    st_mux <= debug_bus[7] ? {clip,no_used,1'd0,mute,2'd0,gvflip,ghflip} : st_snd;
end

always @(posedge clk) lhbl_l <= LHBL;
assign cen_hb = LHBL & ~lhbl_l;
// Let the MCU come out of reset first to take control of the port signals
jtframe_enlarger #(.W(16)) u_rst(
    .rst      ( 1'b0      ),
    .clk      ( clk       ),
    .cen      ( cen_hb    ),
    .pulse_in ( rst       ),
    .pulse_out( rst_main  )
);
/* verilator tracing_off */
jtflstory_main u_main(
    .rst        ( rst_main  ),
    .clk        ( clk       ),
    .cen        ( cen_5p3   ),
    .lvbl       ( LVBL      ),       // video interrupt

    .bus_addr   ( bus_addr  ),
    .bus_din    ( bus_din   ),
    .bus_dout   ( bus_dout  ),
    .cpu_dout   ( cpu_dout  ),

    // shared memory
    .sha_we     ( sha_we    ),
    .sha_dout   ( sha_dout  ),
    // bus sharing with MCU
    .busak_n    ( busak_n   ),
    .busrq_n    ( busrq_n   ),
    .c2b_addr   ( c2b_addr  ),
    .c2b_dout   ( c2b_dout  ),
    .c2b_rd     ( c2b_rd    ),
    .c2b_we     ( c2b_we    ),
    .mcu2bus    ( mcu2bus   ),
    .b2c_rd     ( b2c_rd    ),
    .b2c_wr     ( b2c_wr    ),
    .mcu_ibf    ( mcu_ibf   ),
    .mcu_obf    ( mcu_obf   ),
    // sound
    .m2s_wr     ( m2s_wr    ),
    .s2m_rd     ( s2m_rd    ),
    .s2m_data   ( s2m_data  ),
    // video memories
    .pal16_we   ( pal16_we  ),
    .pal16_dout ( pal16_dout),
    .vram16_dout(vram16_dout),
    .oram8_dout ( oram8_dout),
    .vram_we    ( vram_we   ),
    .oram_we    ( oram8_we  ),
    .scr_bank   ( scr_bank  ),
    .pal_bank   ( pal_bank  ),
    .scr_flen   ( scr_flen  ),
    .ghflip     ( ghflip    ),
    .gvflip     ( gvflip    ),
    // Cabinet inputs
    .cab_1p     (cab_1p[1:0]),
    .coin       ( coin[1:0] ),
    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .dipsw      (dipsw[23:0]),
    .service    ( service   ),
    .tilt       ( tilt      ),
    .dip_pause  ( dip_pause ),
    // ROM access
    .rom_cs     ( main_cs   ),
    .rom_addr   ( main_addr ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    .debug_bus  ( debug_bus )
);

jtflstory_mcu u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_mcu   ),

    .busrq_n    ( busrq_n   ),
    .busak_n    ( busak_n   ),
    .obf        ( mcu_obf   ),
    .ibf        ( mcu_ibf   ),
    // MCU as bus master
    .bm_addr    ( c2b_addr  ),
    .bm_dout    ( c2b_dout  ),
    .bm_din     ( bus_din   ),
    .bm_we      ( c2b_we    ),
    .bm_rd      ( c2b_rd    ),
    // MCU as bus slave
    .bs_wr      ( b2c_wr    ),
    .bs_rd      ( b2c_rd    ),
    .bs_dout    ( bus_dout  ),
    .bs_din     ( mcu2bus   ),
    // ROM
    .rom_addr   ( mcu_addr  ),
    .rom_data   ( mcu_data  )
);
/* verilator tracing_on */
jtflstory_sound u_sound(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen4       ( cen4      ),
    .cen2       ( cen2      ),
    .cen48k     ( cen48k    ),

    // communication with the other CPUs
    .bus_wr     ( m2s_wr    ),
    .bus_rd     ( s2m_rd    ),
    .bus_a0     ( bus_a0    ),
    .bus_dout   ( bus_dout  ),
    .bus_din    ( s2m_data  ),

    .rom_addr   ( snd_addr  ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    .rom_cs     ( snd_cs    ),

    // sound output
    .mute       ( mute      ),
    .msm        ( msm       ),
    .psg        ( psg       ),
    .dac        ( dac       ),
    // debug
    .debug_bus  ( debug_bus ),
    .debug_st   ( st_snd    ),
    .clip       ( clip      )
);
/* verilator tracing_off */
jtflstory_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .ghflip     ( ghflip    ),
    .gvflip     ( gvflip    ),
    .lhbl       ( LHBL      ),
    .lvbl       ( LVBL      ),
    .vs         ( VS        ),
    .hs         ( HS        ),

    .scr_flen   ( scr_flen  ),
    .scr_bank   ( scr_bank  ),
    // Scroll
    .vram_addr  ( vram_addr ),
    .vram_data  ( vram_dout ),
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_cs     ( scr_cs    ),
    .scr_ok     ( scr_ok    ),

    // Objects
    //      RAM shared with CPU
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    .oram_we    ( oram_we   ),
    .oram_din   ( oram_din  ),
    //      ROM
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_cs     ( obj_cs    ),
    .obj_ok     ( obj_ok    ),

    // palette - color mixer
    .pal_bank   ( pal_bank  ),
    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule