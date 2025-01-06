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

module jtframe_mist_video #(parameter
    COLORW=4,
    VGA_DW=6,
    VIDEO_WIDTH=256,
    OSD=1
)(
    input              rst,
    input              clk,
    // base video
    input              pxl_cen,
    input              pxl2_cen,
    input              game_hs,
    input              game_vs,
    input              game_lvbl,
    input              game_lhbl,
    input [3*COLORW-1:0] game_rgb,
    // SPI for OSD contents
    input              osd_di, osd_sck, osd_ss3,
    input   [1:0]      osd_rotate,
    output             osd_shown,
    // low pass filter for video
    input              bw_en,
    input              blend_en,
    input   [1:0]      scanlines,
    input   [1:0]      rotation, // 0 - no rotation, 1 - clockwise, 2 - anticlockwise
    // video signal type
    input              ypbpr,
    input              no_csync,
    input              scan2x_en, // scan doubler enable
    input              sog, //Sync-On-Green
    input              cvideo_en,
    input              pal_en,
    // Scan-doubler video
    output reg [7:0]   scan2x_r,
    output reg [7:0]   scan2x_g,
    output reg [7:0]   scan2x_b,
    output             scan2x_hs,
    output             scan2x_vs,
    output             scan2x_de,
    output             scan2x_HB,
    output             scan2x_VB,
    // crt video
    output reg         video_hs,
    output reg         video_vs,
    output             video_de,
    output [VGA_DW-1:0] video_r,
    output [VGA_DW-1:0] video_g,
    output [VGA_DW-1:0] video_b,
    // Composite video
    output [23:0]      yc_vid,
    // SDRAM interface for rotation
    input              init,
    inout       [15:0] sd_data,
    output      [12:0] sd_addr,
    output       [1:0] sd_dqm,
    output       [1:0] sd_ba,
    output             sd_cs,
    output             sd_we,
    output             sd_ras,
    output             sd_cas,
    output             sd_cke
);

// Limited bandwidth for video signal
localparam CLROUTW = COLORW < 5 ? COLORW+1 : COLORW;

wire [CLROUTW-1:0] r_ana, g_ana, b_ana;
wire               hs_ana, vs_ana, lhbl_ana, lvbl_ana;
wire               pxl_ana;

jtframe_wirebw #(.WIN(COLORW), .WOUT(CLROUTW)) u_wirebw(
    .clk        ( clk       ),
    .spl_in     ( pxl_cen   ),
    .r_in       ( game_rgb[COLORW*2+:COLORW] ),
    .g_in       ( game_rgb[COLORW*1+:COLORW] ),
    .b_in       ( game_rgb[COLORW*0+:COLORW] ),
    .HS_in      ( game_hs   ),
    .VS_in      ( game_vs   ),
    .LHB_in     ( game_lhbl ),
    .LVB_in     ( game_lvbl ),
    .enable     ( bw_en     ),
    // filtered video
    .HS_out     ( hs_ana    ),
    .VS_out     ( vs_ana    ),
    .LHB_out    ( lhbl_ana  ),
    .LVB_out    ( lvbl_ana  ),
    .r_out      ( r_ana     ),
    .g_out      ( g_ana     ),
    .b_out      ( b_ana     )
);
/* verilator lint_off WIDTHTRUNC */
/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off SELRANGE */
function [7:0] extend8;
    input [CLROUTW-1:0] a;
    extend8[7-:CLROUTW] = a;
    if( CLROUTW >= 8) extend8 = a[CLROUTW-1-: 8];
    case( CLROUTW )
        3: extend8[4:0] = { a[CLROUTW-1-:3], a[CLROUTW-1-:2]};
        4: extend8[3:0] = { a[CLROUTW-1-:3], a[0]};
        5: extend8[2:0] =   a[CLROUTW-1-:3];
        6: extend8[1:0] =   a[CLROUTW-1-:2];
        7: extend8[0]   =   a[CLROUTW-1];
        default: ;
    endcase
endfunction
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
/* verilator lint_on SELRANGE */

// This scan doubler takes very little memory. Some games in MiST
// can only use this
wire [CLROUTW*3-1:0] rgbx2;
wire [CLROUTW*3-1:0] ana_rgb = { r_ana, g_ana, b_ana };
wire scan2x_enb  = cvideo_en ? 1'b1  : ~scan2x_en;
wire scan2x_vsin = bw_en ?  vs_ana   :  game_vs;
wire scan2x_hsin = bw_en ?  hs_ana   :  game_hs;
wire scan2x_hbin = bw_en ? ~lhbl_ana : ~game_lhbl;
wire scan2x_vbin = bw_en ? ~lvbl_ana : ~game_lvbl;

// Note that VIDEO_WIDTH must include blanking for jtframe_scan2x
jtframe_scan2x #(.COLORW(CLROUTW), .HLEN(VIDEO_WIDTH)) u_scan2x(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    // settings
    .sl_mode    ( scanlines[1:0] ),
    .blend_en   ( ~|rotation & blend_en ),
    .enb        ( scan2x_enb     ),
    .rotation   ( rotation       ),
    .hfilter    ( blend_en       ),
    .vfilter    ( blend_en       ),
    // video inputs
    .pxl2_cen   ( pxl2_cen       ),
    .x1_pxl     ( ana_rgb        ),
    .x1_hs      ( scan2x_hsin    ),
    .x1_vs      ( scan2x_vsin    ),
    .x1_hb      ( scan2x_hbin    ),
    .x1_vb      ( scan2x_vbin    ),
    // outputs
    .x2_pxl     ( rgbx2          ),
    .x2_hs      ( scan2x_hs      ),
    .x2_vs      ( scan2x_vs      ),
    .x2_de      ( scan2x_de      ),
    .x2_HB      ( scan2x_HB      ),
    .x2_VB      ( scan2x_VB      ),
    // RAM interface for rotation
    .init       ( init           ),
    .sd_data    ( sd_data        ),
    .sd_addr    ( sd_addr        ),
    .sd_dqm     ( sd_dqm         ),
    .sd_ba      ( sd_ba          ),
    .sd_cs      ( sd_cs          ),
    .sd_we      ( sd_we          ),
    .sd_ras     ( sd_ras         ),
    .sd_cas     ( sd_cas         ),
    .sd_cke     ( sd_cke         )
);

always @* begin
    scan2x_r <= extend8( rgbx2[CLROUTW*3-1:CLROUTW*2] );
    scan2x_g <= extend8( rgbx2[CLROUTW*2-1:CLROUTW] );
    scan2x_b <= extend8( rgbx2[CLROUTW-1:0] );
end

// on-screen display
localparam m = VGA_DW/COLORW;
localparam n = VGA_DW%COLORW;

wire [VGA_DW-1:0] osd_r_o;
wire [VGA_DW-1:0] osd_g_o;
wire [VGA_DW-1:0] osd_b_o;
wire              VSync_osd, HSync_osd, CSync_osd, de_osd;

assign CSync_osd = ~(HSync_osd ^ VSync_osd);

generate
    if(OSD==1) begin
        osd #(0,0,6'b01_11_01,VGA_DW) osd (
           .clk_sys    ( clk          ),
           // spi for OSD
           .SPI_DI     ( osd_di       ),
           .SPI_SCK    ( osd_sck      ),
           .SPI_SS3    ( osd_ss3      ),

           .rotate     ( osd_rotate   ),

           .R_in       ( scan2x_r[7-:VGA_DW] ),
           .G_in       ( scan2x_g[7-:VGA_DW] ),
           .B_in       ( scan2x_b[7-:VGA_DW] ),
           .HSync      ( scan2x_hs    ),
           .VSync      ( scan2x_vs    ),
           .DE         ( scan2x_de    ),

           .R_out      ( osd_r_o      ),
           .G_out      ( osd_g_o      ),
           .B_out      ( osd_b_o      ),
           .HSync_out  ( HSync_osd    ),
           .VSync_out  ( VSync_osd    ),
           .DE_out     ( de_osd       ),

           .osd_shown  ( osd_shown    )
        );
    end else begin
        assign {osd_r_o, osd_g_o, osd_b_o,HSync_osd,VSync_osd,de_osd} =
            { scan2x_r[7-:VGA_DW], scan2x_g[7-:VGA_DW], scan2x_b[7-:VGA_DW],
              scan2x_hs,scan2x_vs,scan2x_de };
        assign osd_shown = 0;
    end
endgenerate

wire       HSync_out, VSync_out, CSync_out;

RGBtoYPbPr #(VGA_DW) u_rgb2ypbpr(
    .clk       ( clk       ),
    .ena       ( ypbpr     ),
    .red_in    ( osd_r_o   ),
    .green_in  ( osd_g_o   ),
    .blue_in   ( osd_b_o   ),
    .hs_in     ( HSync_osd ),
    .vs_in     ( VSync_osd ),
    .cs_in     ( CSync_osd ),
    .de_in     ( de_osd    ),
    .red_out   ( video_r   ),
    .green_out ( video_g   ),
    .blue_out  ( video_b   ),
    .hs_out    ( HSync_out ),
    .vs_out    ( VSync_out ),
    .cs_out    ( CSync_out ),
    .de_out    ( video_de  )
);

function [7:0] extend8v( input [VGA_DW-1:0] a);
    extend8v[7-:VGA_DW] = a;
    if( VGA_DW >= 8) extend8v = a[VGA_DW-1-: 8];
    case( VGA_DW )
        3: extend8v[4:0] = { a[VGA_DW-1-:3], a[VGA_DW-1-:2]};
        4: extend8v[3:0] = { a[VGA_DW-1-:3], a[0]};
        5: extend8v[2:0] =   a[VGA_DW-1-:3];
        6: extend8v[1:0] =   a[VGA_DW-1-:2];
        7: extend8v[0]   =   a[VGA_DW-1];
        default: ;
    endcase
endfunction

wire        hsync_c, vsync_c, csync_c;
wire [23:0] colours;
wire [26:0] colorburst;
wire [31:0] phase_inc;
reg  [ 7:0] video_r8, video_g8, video_b8;

always @* begin
    video_r8 = extend8v( video_r );
    video_g8 = extend8v( video_g );
    video_b8 = extend8v( video_b );
end

localparam [31:0] JTFRAME_PAL  =`JTFRAME_PAL;
localparam [31:0] JTFRAME_NTSC =`JTFRAME_NTSC;
localparam [16:0] JTFRAME_PAL_LEN = `JTFRAME_PAL_LEN;
localparam [16:0] JTFRAME_NTSC_LEN = `JTFRAME_NTSC_LEN;

assign phase_inc  = pal_en ? JTFRAME_PAL     : JTFRAME_NTSC;
assign colorburst = {JTFRAME_NTSC_LEN, JTFRAME_PAL_LEN[9:0]}; // pal/ntsc selection for colorburst is donde in the module
assign colours    = {video_r8, video_g8, video_b8};

yc_out u_yc(
    .clk              ( clk        ),
    .PHASE_INC        ( {phase_inc,8'b0} ), /* 40'd80070078948>>1 */
    .PAL_EN           ( pal_en     ),
    .CVBS             ( 1'b0       ),
    .COLORBURST_RANGE ( colorburst ),  /* 16'd42145 */
    .hsync            ( HSync_out  ),
    .vsync            ( VSync_out  ),
    .csync            ( CSync_out  ),
    .din              ( colours & {24{video_de}} ),
    .dout             ( yc_vid     ),
    .hsync_o          ( hsync_c    ),
    .vsync_o          ( vsync_c    ),
    .csync_o          ( csync_c    )
);

// a minimig vga->scart cable expects a composite sync signal on the VIDEO_HS output.
// and VCC on VIDEO_VS (to switch into rgb mode)
always @(posedge clk) begin
    video_hs <= ( (~no_csync & scan2x_enb) | ypbpr) ? CSync_out : HSync_out;
    video_vs <= ( (~no_csync & scan2x_enb) | ypbpr) ? 1'b1      : VSync_out;
    if( sog ) begin
        video_hs <= 1'b1;
        video_vs <= CSync_out;
    end
    if( cvideo_en ) begin
        video_hs <= csync_c;
        video_vs <= 1'b1;
    end
end

endmodule