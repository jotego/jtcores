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
    Date: 2-1-2025 */

module jtgaiden_objscan(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             flip,
    input             lvbl,
    input             hs,
    input             blankn,

    input      [ 7:0] scry,
    input      [ 8:0] vrender,

    // Look-up table
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,
    // rom address translation
    input      [19:2] raw_addr,
    output reg [19:2] rom_addr,
    // draw attributes and control
    output reg        hflip,
    output reg        vflip,
    output reg [12:0] code,
    output reg [ 3:0] pal,
    output reg        blend,
    output reg [ 1:0] size,
    output reg [ 8:0] hpos,
    output reg [ 1:0] prio,
    output reg [ 3:0] ysub,
    output            dr_draw,
    input             dr_busy,
    input      [ 7:0] debug_bus
);

wire [12:1] scan_addr;
wire [15:0] scan_dout;
wire [ 8:0] vlatch;
wire [ 2:0] st, haddr, hsub;
reg  [ 2:0] hreps=0;
wire        draw_step, skip, blink;
reg         en;
reg  [ 8:0] y, x;
reg  [ 8:0] ydiff;
reg  [ 1:0] code_lsb, codelsb_l;
wire [ 8:0] ydf;
reg  [ 7:0] attr;
reg  [ 3:0] pre_pal;
wire [ 7:0] objcnt;
reg  [ 1:0] hsize, vaddr;
reg         inzone;

assign draw_step = st==5;
assign skip      = st==1 && !en;
// assign vsize     = size;
assign ydf       = ydiff^{9{vflip}};
assign scan_addr[12] = 0;
assign objcnt    = scan_addr[4+:8];

always @* begin
    ydiff = vlatch - y-9'd1;
    case( size )
        0: inzone = ydiff[8:3]==0; //   8
        1: inzone = ydiff[8:4]==0; //  16
        2: inzone = ydiff[8:5]==0; //  32
        3: inzone = ydiff[8:6]==0; //  64
    endcase
    inzone = inzone&blink;
    // if(objcnt!=debug_bus) inzone=0;
    // if(objcnt!=32&&objcnt!=46) inzone=0;
end

always @* begin
    rom_addr = {raw_addr[19:7],raw_addr[5],~raw_addr[6],raw_addr[4:2]};
    hpos     = x + {2'd0,hsub,4'd0};
    case( hsize )
        0: rom_addr[6]    = code_lsb[1];
        2: rom_addr[ 8:7] = {vaddr[0],haddr[0]};     //32
        3: rom_addr[10:7] = {vaddr[1],haddr[1],vaddr[0],haddr[0]};   //64
        default:;
    endcase
end

always @(posedge clk) begin
    if( dr_draw ) begin
        codelsb_l <= code_lsb;
    end
end

always @(posedge clk) begin
    case(st)
        0: begin
            en   <= scan_dout[2];
            attr <= scan_dout[7:0];
        end
        1: {code,code_lsb} <= scan_dout[14:0];
        2: {pre_pal,size} <= {scan_dout[7:4],scan_dout[1:0]};
        3: begin
            y <= scan_dout[8:0]+{1'd0,scry};
            case(size)
                0,1: hreps <=0; // single tile
                2:   hreps <=1;   // 16x2=32
                3:   hreps <=3;   // 16x4=64
            endcase
        end
        4: begin
            x <= scan_dout[8:0];
        end
        5: if(!dr_busy &&inzone) begin
            pal   <=  pre_pal;
            hsize <=  size;
            ysub  <=  ydf[3:0]^{4{attr[1]}};
            vaddr <=  ydf[5:4]/*^{2{attr[1]}}*/; // see scene gaiden/10
            prio  <=  attr[7:6];
            blend <=  attr[5];
            vflip <=  attr[1];
            hflip <= ~attr[0];
        end
    endcase
end

jtframe_blink u_blink(
    .clk        ( clk       ),
    .vs         ( lvbl      ),
    .en         ( objcnt[6:0]==debug_bus[6:0] && debug_bus[7] ),
    .blink      ( blink     )
);

// jtframe_framebuf #(.AW(12),.DW(16))u_framebuf(
//     .clk        ( clk       ),
//     .lvbl       ( lvbl      ),
//     .dma_addr   ( ram_addr  ),
//     .dma_data   ( ram_dout  ),

//     .rd_addr    ( scan_addr ),
//     .rd_data    ( scan_dout )
// );
assign ram_addr  = scan_addr;
assign scan_dout = ram_dout;

jtframe_objscan #(.OBJW(8),.STW(3))u_scan(
    .clk        ( clk       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .vrender    ( vrender   ),
    .vlatch     ( vlatch    ),

    .draw_step  ( draw_step ),
    .skip       ( skip      ),
    .inzone     ( inzone    ),

    .hsize      ( hreps     ),
    .hsub       ( hsub      ),
    .haddr      ( haddr     ),
    .hflip      ( hflip     ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( scan_addr[11:1] ),
    .step       ( st        )
);

endmodule