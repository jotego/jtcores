`timescale 1ns / 1ps
//`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 21:14:58 2023-05-01 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.
//
// ORIGINAL COPYRIGHT FOLLOWS:
// Author: Mike Field <hamster@snap.net.nz>
//
// Part of the DisplayPort_Verlog project - an open implementation of the 
// DisplayPort protocol for FPGA boards. 
//
// See https://github.com/hamsternz/DisplayPort_Verilog for latest versions.
//
///////////////////////////////////////////////////////////////////////////////
// Version |  Notes
// ----------------------------------------------------------------------------
//   1.0   | Initial Release
//
///////////////////////////////////////////////////////////////////////////////
//
// MIT License
// 
// Copyright (c) 2019 Mike Field
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
///////////////////////////////////////////////////////////////////////////////
//
// Want to say thanks?
//
// This design has taken many hours - 3 months of work for the initial VHDL
// design, and another month or so to convert it to Verilog for this release.
//
// I'm more than happy to share it if you can make use of it. It is released
// under the MIT license, so you are not under any onus to say thanks, but....
//
// If you what to say thanks for this design either drop me an email, or how about
// trying PayPal to my email (hamster@snap.net.nz)?
//
//  Educational use - Enough for a beer
//  Hobbyist use    - Enough for a pizza
//  Research use    - Enough to take the family out to dinner
//  Commercial use  - A weeks pay for an engineer (I wish!)
//
///////////////////////////////////////////////////////////////////////////////

module stream_640x480 (
  output reg [23:0] M_value,
  output reg [23:0] N_value,
  output reg [11:0] H_visible,
  output reg [11:0] V_visible,
  output reg [11:0] H_total,
  output reg [11:0] V_total,
  output reg [11:0] H_sync_width,
  output reg [11:0] V_sync_width,
  output reg [11:0] H_start,
  output reg [11:0] V_start,
  output reg        H_vsync_active_high,
  output reg        V_vsync_active_high,
  output reg        flag_sync_clock,
  output reg        flag_YCCnRGB,
  output reg        flag_422n444,
  output reg        flag_YCC_colour_709,
  output reg        flag_range_reduced,
  output reg        flag_interlaced_even,
  output reg  [1:0] flags_3d_Indicators,
  output reg  [4:0] bits_per_colour,
  output reg  [2:0] stream_channel_count,

  input wire        clk,
  output reg [18:0] fbaddr,
  output wire aplicar_scanline,
  input wire interlaced_image,
  input wire [1:0]  divvga,
  output reg [10:0] hcont,
  output reg [10:0] vcont,
  input wire [7:0]  red,
  input wire [7:0]  green,
  input wire [7:0]  blue,
  output reg        ready,
  output reg [72:0] data
);

  localparam [8:0] DUMMY  = 9'b000000000;  // 0x03
  localparam [8:0] SPARE  = 9'b011111111;  // 0xFF
  localparam [8:0] ZERO   = 9'b000000000;  // 0x00

  localparam [8:0] BE     = 9'b111111011;  // K27.7 Blank End
  localparam [8:0] BS     = 9'b110111100;  // K28.5 Blank Start
  localparam [8:0] FS     = 9'b111111110;  // K30.7 Fill Start
  localparam [8:0] FE     = 9'b111110111;  // K23.7 Fill End
  localparam [8:0] SS     = 9'b101011100;  // K28.2
  localparam [8:0] SE     = 9'b111111101;  // K29.7  

  localparam [8:0] VB_VS  = 9'b000000001;  // 0x00  VB-ID with Vertical blank asserted
  localparam [8:0] VB_NVS = 9'b000000000;  // 0x00  VB-ID without Vertical blank asserted
  localparam [8:0] MVID   = 9'h055;        // LSB de M
  localparam [8:0] MAUD   = 9'b000000000;  // LSB de Maud. Maud = 512
  localparam [8:0] BEGINAUDIO = 9'h155;    // para marcar que aquí comienza a insertarse la info de audio  

  localparam [2:0] ACTIVEVIDEO    = 0;
  localparam [2:0] BEGINHBLANKING = 1;
  localparam [2:0] BEGINVBLANKING = 2;
  localparam [2:0] DUMMYSYMBOLS   = 3;
  localparam [2:0] ENDBLANKING    = 4;
  localparam [2:0] AUDIO          = 5;

  reg [3:0] index = 0;
  reg [3:0] index_ste2 = 0;
  reg [2:0] tipo_bloque = ACTIVEVIDEO;
  reg [1:0] divvga_ste2 = 0;
  reg [8:0] d0 = 0;
  reg [8:0] d1 = 0;
  reg [9:0] contador_scans = 0;
  reg [7:0] contador_bloques = 0;
  reg [18:0] fbaddr_comienzo_linea;
  reg insertar_idle_pattern = 0;
  reg insertar_idle_pattern_ste2, insertar_idle_pattern_ste3;
  assign aplicar_scanline = ~contador_scans[0];
  
  initial begin
    M_value              = 24'h015555;
    N_value              = 24'h080000;

    H_visible            = 12'd640;
    H_total              = 12'd800;
    H_start              = 12'd144;
    H_sync_width         = 12'd96;

    V_visible            = 12'd480;
    V_total              = 12'd525;
    V_start              = 12'd35;
    V_sync_width         = 12'd2;

    H_vsync_active_high  = 1'b1;
    V_vsync_active_high  = 1'b1;
    flag_sync_clock      = 1'b1;
    flag_YCCnRGB         = 1'b0;
    flag_422n444         = 1'b0;
    flag_range_reduced   = 1'b0;
    flag_interlaced_even = 1'b0;
    flag_YCC_colour_709  = 1'b0;
    flags_3d_Indicators  = 2'b00;
    bits_per_colour      = 5'b01000;

    stream_channel_count = 3'b001;
    ready                = 1'b1;
    data                 = 73'b0;
  end

  always @(posedge clk) begin

    data[17:9]  <= d1;
    data[8:0]   <= d0;
    data[71:18] <= 54'b0;
    data[72]    <= insertar_idle_pattern_ste3; 

    insertar_idle_pattern_ste3 = insertar_idle_pattern_ste2;

    if (tipo_bloque == DUMMYSYMBOLS || tipo_bloque == ENDBLANKING) begin
      d0 <= DUMMY;
      if (tipo_bloque == ENDBLANKING && index_ste2 == 15)
        d1 <= BE;
      else
        d1 <= DUMMY;
    end
    else if (tipo_bloque == ACTIVEVIDEO) begin
      case (divvga_ste2)
        0: begin d0 <= {1'b0, red};   d1 <= FE; end
        1: begin d0 <= {1'b0, green}; d1 <= FS; end
        2: begin d0 <= FE;            d1 <= {1'b0, blue}; end
      endcase
    end
    else if (tipo_bloque == BEGINHBLANKING || tipo_bloque == BEGINVBLANKING) begin
      case (index_ste2)
        0: begin d0 <= BS;              d1 <= (tipo_bloque == BEGINHBLANKING)? VB_NVS : VB_VS;  end
        1: begin d0 <= MVID;            d1 <= MAUD; end
        2: begin d0 <= (tipo_bloque == BEGINHBLANKING)? VB_NVS : VB_VS;    d1 <= MVID; end
        3: begin d0 <= MAUD;            d1 <= (tipo_bloque == BEGINHBLANKING)? VB_NVS : VB_VS;  end
        4: begin d0 <= MVID;            d1 <= MAUD; end
        5: begin d0 <= (tipo_bloque == BEGINHBLANKING)? VB_NVS : VB_VS;    d1 <= MVID; end
        6: begin d0 <= MAUD;            d1 <= DUMMY; end
        default: begin d0 <= DUMMY;     d1 <= DUMMY; end
      endcase
    end
    else if (tipo_bloque == AUDIO && index_ste2 == 0) begin
      d0 <= BEGINAUDIO;   // dejamos aquí la marca de comenzar info de audio para después insertarlo aparte      
      d1 <= DUMMY;
    end
    else
      begin d0 <= SPARE ; d1 <= SPARE; end

  ////////////////////////////////////////////////////////////////////////////////////////

    divvga_ste2 <= divvga;
    index_ste2 <= index;
    insertar_idle_pattern_ste2 <= insertar_idle_pattern; 

    index <= index + 1;
    if (index == 15) begin
      if (contador_bloques == 149) begin   //  Htot / pixtu - 1
        contador_bloques <= 0;
          if (contador_scans[0] == 0)
            fbaddr <= fbaddr_comienzo_linea;   // de esta forma, se lee el mismo scan de ambas memorias (fbpar y fbimpar)
          else begin
            fbaddr_comienzo_linea <= fbaddr;   // antes de pasar al siguiente
            fbaddr <= fbaddr;
          end
        if (contador_scans == (V_total-1))
          contador_scans <= 0;
        else
          contador_scans <= contador_scans + 1;
      end
      else
        contador_bloques <= contador_bloques + 1;
    end

    tipo_bloque <= DUMMYSYMBOLS;
    insertar_idle_pattern <= 0;
    if (contador_scans < V_visible) begin
      if (contador_bloques < 120)
        tipo_bloque <= ACTIVEVIDEO;
      else if (contador_bloques == 120)
        tipo_bloque <= (contador_scans == (V_visible-1))? BEGINVBLANKING : BEGINHBLANKING;  // o bien Pixels BS and VS-ID block (no VBLANK flag)
      else if (contador_bloques == 130)
        tipo_bloque <= AUDIO;
      else if (contador_bloques == 149 && contador_scans != (V_visible-1))
        tipo_bloque <= ENDBLANKING;
    end
    else begin
      if (contador_bloques < 120) begin
        tipo_bloque <= DUMMYSYMBOLS;
        insertar_idle_pattern <= 1;
      end
      else if (contador_bloques == 120)
        tipo_bloque <= BEGINVBLANKING;
      else if (contador_bloques == 130)
        tipo_bloque <= AUDIO;
      else if (contador_bloques == 149 && contador_scans == (V_total-1))
        tipo_bloque <= ENDBLANKING;
    end

    if (divvga == 2) begin
      if (tipo_bloque == ACTIVEVIDEO)
        fbaddr <= fbaddr + 1;
      if (hcont == H_total-1) begin
        hcont <= 0;
        if (vcont == V_total-1)
          vcont <= 0;
        else
          vcont <= vcont + 1;
      end
      else
        hcont <= hcont + 1;
    end

    if (contador_scans >= V_visible) begin
      fbaddr <= 0;
      fbaddr_comienzo_linea <= 0;
    end
  end

endmodule



module stream_640x480_v2 (
  output reg [23:0] M_value,
  output reg [23:0] N_value,
  output reg [11:0] H_visible,
  output reg [11:0] V_visible,
  output reg [11:0] H_total,
  output reg [11:0] V_total,
  output reg [11:0] H_sync_width,
  output reg [11:0] V_sync_width,
  output reg [11:0] H_start,
  output reg [11:0] V_start,
  output reg        H_vsync_active_high,
  output reg        V_vsync_active_high,
  output reg        flag_sync_clock,
  output reg        flag_YCCnRGB,
  output reg        flag_422n444,
  output reg        flag_YCC_colour_709,
  output reg        flag_range_reduced,
  output reg        flag_interlaced_even,
  output reg  [1:0] flags_3d_Indicators,
  output reg  [4:0] bits_per_colour,
  output reg  [2:0] stream_channel_count,

  input wire        clk,
  output reg [18:0] fbaddr,
  output reg aplicar_scanline,
  input wire [1:0]  divvga,
  output reg [10:0] hcont,
  output reg [10:0] vcont,
  input wire [7:0]  red,
  input wire [7:0]  green,
  input wire [7:0]  blue,
  output reg        ready,
  output reg [72:0] data
);

  localparam [8:0] DUMMY  = 9'b000000000;  // 0x03
  localparam [8:0] SPARE  = 9'b011111111;  // 0xFF
  localparam [8:0] ZERO   = 9'b000000000;  // 0x00

  localparam [8:0] BE     = 9'b111111011;  // K27.7 Blank End
  localparam [8:0] BS     = 9'b110111100;  // K28.5 Blank Start
  localparam [8:0] FS     = 9'b111111110;  // K30.7 Fill Start
  localparam [8:0] FE     = 9'b111110111;  // K23.7 Fill End

  localparam [8:0] VB_VS  = 9'b000000001;  // 0x00  VB-ID with Vertical blank asserted
  localparam [8:0] VB_NVS = 9'b000000000;  // 0x00  VB-ID without Vertical blank asserted
  localparam [8:0] MVID   = 9'h055;        // LSB de M
  localparam [8:0] MAUD   = 9'b000000000;  // 0x00

  localparam [2:0] ACTIVEVIDEO    = 0;
  localparam [2:0] BEGINHBLANKING = 1;
  localparam [2:0] BEGINVBLANKING = 2;
  localparam [2:0] DUMMYSYMBOLS   = 3;
  localparam [2:0] ENDBLANKING    = 4;
  
  localparam [11:0] TOTAL_SYMBOLS = (150*16);
  localparam [11:0] VISIBLE_SYMBOLS = (120*16);

  reg [8:0] d0;
  reg [8:0] d1;
  reg [11:0] symbol_count = 0;
  reg [18:0] fbaddr_comienzo_linea;
  reg insertar_idle_pattern;

  initial begin
    M_value              = 24'h015555;
    N_value              = 24'h080000;

    H_visible            = 12'd640;
    H_total              = 12'd800;
    H_start              = 12'd144;
    H_sync_width         = 12'd96;

    V_visible            = 12'd480;
    V_total              = 12'd525;
    V_start              = 12'd35;
    V_sync_width         = 12'd2;

    H_vsync_active_high  = 1'b1;
    V_vsync_active_high  = 1'b1;
    flag_sync_clock      = 1'b1;
    flag_YCCnRGB         = 1'b0;
    flag_422n444         = 1'b0;
    flag_range_reduced   = 1'b0;
    flag_interlaced_even = 1'b0;
    flag_YCC_colour_709  = 1'b0;
    flags_3d_Indicators  = 2'b00;
    bits_per_colour      = 5'b01000;

    stream_channel_count = 3'b001;
    ready                = 1'b1;
    data                 = 73'b0;
  end

  initial begin
    hcont = 0;
    vcont = 0;
  end

  always @(posedge clk) begin
    data[17:9]  <= d1;
    data[8:0]   <= d0;
    data[71:18] <= 54'b0;
    data[72]    <= insertar_idle_pattern; 

    if (symbol_count != TOTAL_SYMBOLS-1) begin
      symbol_count <= symbol_count + 1;
      if (divvga == 2) begin
        hcont <= hcont + 1;
        if (hcont < H_visible && vcont < V_visible)
          fbaddr <= fbaddr + 1;
      end
    end
    else begin
      symbol_count <= 0;
      hcont <= 0;
      if (vcont != V_total-1)
        vcont <= vcont + 1;
      else
        vcont <= 0;
      if (vcont < V_visible) begin
        aplicar_scanline <= ~vcont[0];
        if (vcont[0] == 0)
          fbaddr <= fbaddr_comienzo_linea;
        else
          fbaddr_comienzo_linea <= fbaddr;
      end
      else begin
        fbaddr <= 0;
        fbaddr_comienzo_linea <= 0;
        aplicar_scanline <= 0;
      end
    end
  end

  reg in_vertical_blanking;
  always @* begin
    in_vertical_blanking = (vcont >= V_visible || (symbol_count >= VISIBLE_SYMBOLS && vcont == (V_visible-1) ));
    if (in_vertical_blanking)
      insertar_idle_pattern = 1;
    else
      insertar_idle_pattern = 0;
  end

  always @* begin    
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    if (symbol_count < VISIBLE_SYMBOLS) begin
      if (vcont < V_visible) begin
        case (divvga)
          0: begin d0 = {1'b0, red};   d1 = FE; end
          1: begin d0 = {1'b0, green}; d1 = FS; end
          2: begin d0 = FE;            d1 = {1'b0, blue}; end
          default: begin d0 = DUMMY ; d1 = DUMMY; end
        endcase
      end
      else begin
        d0 = DUMMY;
        d1 = DUMMY;
      end
    end
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    else if (symbol_count < (VISIBLE_SYMBOLS + 8)) begin
      case (symbol_count[2:0])
        0: begin d0 = BS;              d1 = (in_vertical_blanking)? VB_VS : VB_NVS;  end
        1: begin d0 = MVID;            d1 = MAUD; end
        2: begin d0 = (in_vertical_blanking)? VB_VS : VB_NVS;    d1 = MVID; end
        3: begin d0 = MAUD;            d1 = (in_vertical_blanking)? VB_VS : VB_NVS;  end
        4: begin d0 = MVID;            d1 = MAUD; end
        5: begin d0 = (in_vertical_blanking)? VB_VS : VB_NVS;    d1 = MVID; end
        6: begin d0 = MAUD;            d1 = DUMMY; end
        default: begin d0 = DUMMY;     d1 = DUMMY; end
      endcase
    end
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    else if (symbol_count == TOTAL_SYMBOLS-1 && (vcont < (V_visible-1) || vcont == V_total-1)) begin
      d0 = DUMMY;
      d1 = BE;
    end
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    else begin
      d0 = DUMMY;
      d1 = DUMMY;
    end
  end

endmodule


//`default_nettype wire
