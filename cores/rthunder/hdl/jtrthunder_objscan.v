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
    Date: 9-4-2025 */

module jtrthunder_objscan(
    input             clk, hs, blankn,
    input             flip,
    input      [ 8:0] vrender, xoffset,
    input      [ 7:0] yoffset,

    output reg [10:0] code,
    output reg [ 1:0] hsize, vsize, trunc, hmsb,
    output reg [ 4:0] ysub,
    output reg [ 6:0] pal,
    output reg [ 8:0] hpos,
    output reg [ 2:0] prio,
    output reg        hflip, vflip,

    // Look-up table
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,

    input             dr_busy,
    output            dr_draw,

    input      [ 7:0] debug_bus
);

localparam [8:0] XOS=9'h20;
localparam [7:0] YOS=8'h20;
localparam [1:0] HLARGE=2'd2; // 32-pixel wide object

reg [15:0] prev;
reg  [7:0] y;
reg  [8:0] objcnt, ydiff;
wire [8:0] vlatch, raw_addr;
wire [1:0] st;
reg  [1:0] hos, vos, nx_hmsb;
reg  [4:0] nx_ysub;
reg        inzone, half=0, wide=0;
wire       draw_step, hsub;

assign draw_step = st==3;
assign ram_addr[12:11] = 2'b11;
assign ram_addr[10: 4] = raw_addr[8-:7];
assign ram_addr[ 3: 1] = {1'b0,raw_addr[1:0]}+3'd5;

always @* begin
    ydiff = vlatch[8:0] + y;
    case( vsize )
        0: inzone = ydiff[8:4]==0; //  16
        1: inzone = ydiff[8:3]==0; //   8
        2: inzone = ydiff[8:5]==0; //  32
        3: inzone = ydiff[8:2]==0; //   4
    endcase
    nx_ysub = ydiff[4:0];
    case( vsize )
        0:   nx_ysub[4:3] = {vos[1], ydiff[3] ^ vflip};
        1,3: nx_ysub[4:3] = vos[1:0];
        2:   nx_ysub[4:3] = ydiff[4:3] ^ {2{vflip}};
        default:;
    endcase
    case( hsize )
        0: nx_hmsb = { hos[1], 1'b0}; // 16 pxl
        1,3: nx_hmsb = hos; // 8/4 pxl
        default: nx_hmsb = { hflip, 1'b0 }; // 32 pxl
    endcase
    // if(objcnt!=debug_bus) inzone=0;
end

always @(posedge clk) begin
    case(st)
        0: prev <= ram_dout; // do not modify output values yet as the draw
                             // module needs 1 tick to register them
        1: begin
            { hpos[7:0], pal, hpos[8] }   <= ram_dout;
            { code[7:0], hsize, hflip, hos, code[10:8] } <= prev;
        end
        2: begin
            wide <= hsize==HLARGE;
            { prio, vos, vsize, vflip } <= ram_dout[7:0];
            y    <= ram_dout[15:8] + yoffset + YOS;
            hpos <= hpos + xoffset + XOS;
        end
        3: if(!dr_busy && inzone) begin
            ysub <= nx_ysub;
            hmsb <= nx_hmsb;
            case( hsize )
                1: trunc <= 2'b10;
                3: trunc <= 2'b11;
                default: trunc <= 0;
            endcase
            if( half ) begin // half of 32-pxl object
                half <= 0;
                hpos <= hpos + 9'h10;
                hmsb[1] <= ~hmsb[1];
            end
            if( hsize==HLARGE && !half ) begin
                half <= 1;
            end
        end
    endcase
end

jtframe_objscan #(.OBJW(7),.STW(2),.HREPW(1))
u_scan(
    .clk        ( clk       ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .vrender    ( vrender   ),
    .vlatch     ( vlatch    ),

    .draw_step  ( draw_step ),
    .skip       ( 1'b0      ),
    .inzone     ( inzone    ),

    .hsize      ( wide      ),
    .hsub       ( hsub      ),
    .haddr      (           ),
    .hflip      ( hflip     ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( raw_addr  ),
    .step       ( st        )
);


endmodule