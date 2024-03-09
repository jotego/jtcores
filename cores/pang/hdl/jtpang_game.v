/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    ( at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-5-2022 */

module jtpang_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// clock enable signals
wire [ 3:0] n;
wire [ 3:0] m;
wire [ 3:0] cen24;
wire        pcm_cen, fm_cen;

// CPU bus
wire [ 7:0] cpu_dout, pcm_dout,
            vram_dout, attr_dout, pal_dout;
wire        fm_cs, oki_cs,
            cpu_rnw, busrq, int_n,
            pal_cs, vram_msb, vram_cs, attr_cs;
wire [11:0] cpu_addr;
wire        kabuki_we, is_obj;
wire        char_en, obj_en, video_en, pal_bank;
wire        dma_go, busak_n, busrq_n;
wire [ 8:0] h;

// SDRAM / board configuration
reg  [ 1:0] ctrl_type;
reg         init_n, kabuki_en, LVBLl;
wire        pcm_bank, flip;
reg  [ 8:0] frame_cnt;
reg         ram_done = 0;

assign fm_cen     = cen24[1];
assign pcm_cen    = cen24[3];
assign debug_view = { 6'd0, ctrl_type };// debug_bus[0] ? mouse_1p[15:8] : mouse_1p[7:0];
assign dip_flip   = flip;
assign pcm_cs     = 1;
// ROM download
assign is_obj     = prog_ba==3;
assign kabuki_we  = ioctl_wr && header && ioctl_addr[3:0]<11;

// The sound uses the 24 MHz clock
jtframe_frac_cen #( .W( 4), .WC( 4)) u_cen24(
    .clk  ( clk24  ),
    .n    ( 4'd1   ),
    .m    ( 4'd3   ),
    .cen  ( cen24  ),
    .cenb (        )
);

always @* begin
    post_addr = prog_addr;
    if( is_obj ) begin
        post_addr[5:1] = { prog_addr[4:1], prog_addr[5] };
    end
end

always @(posedge clk) begin
    if( kabuki_we && ioctl_addr[3:0]==0 )
        kabuki_en <= ioctl_dout!=0;
    if( ioctl_addr==15 && ioctl_wr && !ioctl_ram && header ) ctrl_type <= ioctl_dout[1:0];
end

always @(posedge clk) begin
    LVBLl  <= LVBL;
    if( ioctl_wr ) begin
        if( ioctl_ram ) ram_done <= 1; else frame_cnt <= 0;
        init_n <= 1;
    end else if( !LVBL & LVBLl ) begin
        if( ~&frame_cnt ) frame_cnt <= frame_cnt + 1'd1;
        init_n <= ram_done |  &frame_cnt;
    end
end

jtpang_main u_main(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .cpu_cen     ( pxl_cen      ),
    .int_n       ( int_n        ),
    .ctrl_type   ( ctrl_type    ),

    .cpu_addr    ( cpu_addr     ),
    .cpu_rnw     ( cpu_rnw      ),
    .cpu_dout    ( cpu_dout     ),

    .flip        ( flip         ),
    .LVBL        ( LVBL         ),
    .LHBL        ( LHBL         ),
    .hcnt        ( h[2:0]       ),
    .dip_pause   ( dip_pause    ),
    .init_n      ( init_n       ),

    .char_en     ( char_en      ),
    .obj_en      ( obj_en       ),
    .video_enq   ( video_en     ),

    .attr_cs     ( attr_cs      ),
    .vram_cs     ( vram_cs      ),
    .vram_msb    ( vram_msb     ),
    .pal_cs      ( pal_cs       ),
    .pal_bank    ( pal_bank     ),
    .attr_dout   ( attr_dout    ),
    .pal_dout    ( pal_dout     ),
    .vram_dout   ( vram_dout    ),

    // Sound
    .fm_cs       ( fm_cs        ),
    .pcm_cs      ( oki_cs       ),
    .pcm_bank    ( pcm_bank     ),
    .pcm_dout    ( pcm_dout     ),

    // DMA
    .dma_go      ( dma_go       ),
    .busrq_n     ( ~busrq       ),
    .busak_n     ( busak_n      ),

    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    .cab_1p      ( cab_1p       ),
    .coin        ( coin[0]      ),
    .service     ( service      ),
    .test        ( dip_test     ),

    .mouse_1p    ( mouse_1p[7:0]),
    .mouse_2p    ( mouse_2p[7:0]),

    // NVRAM
    .prog_addr   ( ioctl_addr[12:0] ),
    .prog_data   ( ioctl_dout   ),
    .prog_din    ( ioctl_din    ),
    .prog_we     ( ioctl_wr     ),
    .prog_ram    ( ioctl_ram    ),

    .kabuki_we   ( kabuki_we    ),
    .kabuki_en   ( kabuki_en    ),

    .debug_bus   ( debug_bus    ),
    // ROM
    .rom_addr    ( main_addr    ),
    .rom_cs      ( main_cs      ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      )
);

`ifndef NOSOUND
jtpang_snd u_snd(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .fm_cen     ( fm_cen        ),
    .pcm_cen    ( pcm_cen       ),

    .cpu_dout   ( cpu_dout      ),
    .wr_n       ( cpu_rnw       ),
    .a0         ( cpu_addr[0]   ),
    .fm_cs      ( fm_cs         ),
    .pcm_dout   ( pcm_dout      ),
    .pcm_cs     ( oki_cs        ),

    .enable_fm  ( enable_fm     ),
    .enable_psg ( enable_psg    ),

    .rom_addr   ( pcm_addr      ),
    .rom_data   ( pcm_data      ),
    .rom_ok     ( pcm_ok        ),

    .fm         ( fm            ),
    .pcm        ( pcm           )
);
`else
    assign pcm_addr = 0;
    assign sample   = 0;
    assign game_led = 0;
    assign snd      = 0;
    assign pcm_dout = 0;
`endif

jtpang_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .int_n      ( int_n         ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .h          ( h             ),
    .flip       ( flip          ),
    .video_en   ( video_en      ),
    .char_en    ( char_en       ),

    .pal_bank   ( pal_bank      ),
    .pal_cs     ( pal_cs        ),
    .vram_msb   ( vram_msb      ),
    .vram_cs    ( vram_cs       ),
    .attr_cs    ( attr_cs       ),
    .wr_n       ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .vram_dout  ( vram_dout     ),
    .attr_dout  ( attr_dout     ),
    .pal_dout   ( pal_dout      ),

    .dma_go     ( dma_go        ),
    .busak_n    ( busak_n       ),
    .busrq      ( busrq         ),

    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        )
);

endmodule
