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

localparam [8:0] XOS=9'h3d;
localparam [7:0] YOS=8'h20;
localparam [1:0] HLARGE=2'd2; // 32-pixel wide object

reg  [7:0] y, vos_dr;
reg  [8:0] ydiff;
wire [6:0] objcnt;
wire [8:0] vlatch, raw_addr;
wire [1:0] st;
reg  [1:0] hos, vos, hmsb_nx;
reg  [4:0] nx_ysub;
reg        inzone, wide=0;
wire       draw_step, hsub, cen, hcnt_nx;

assign draw_step = st==3;
assign objcnt    = raw_addr[2+:7];

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
        0: hmsb_nx = { hos[1], 1'b0}; // 16 pxl
        1,3: hmsb_nx = hos; // 8/4 pxl
        default: hmsb_nx = { hflip, 1'b0 }; // 32 pxl
    endcase
    if(debug_bus[7] && objcnt!=debug_bus[6:0]) inzone=0;
    if(&objcnt) inzone=0;

    case(ram_dout[2:1])
        0: vos_dr = -16;
        1: vos_dr = -24;
        2: vos_dr = -0;
        3: vos_dr = -28;
    endcase
end

always @(posedge clk) if(cen) begin
    case(st)
        0: { code[7:0], hsize, hflip, hos, code[10:8] } <= ram_dout;
        1: { hpos[7:0], pal, hpos[8] } <= ram_dout;
        2: begin
            wide  <= hsize==HLARGE;
            { prio, vos, vsize, vflip } <= ram_dout[7:0];
            y    <= ram_dout[15:8] + yoffset + YOS + vos_dr;
            hpos <= hpos + xoffset + XOS;
        end
        3: if(!dr_busy && !dr_draw && inzone) begin
            ysub <= nx_ysub;
            hmsb <= hmsb_nx;
            case( hsize )
                1: trunc <= 2'b10;
                3: trunc <= 2'b11;
                default: trunc <= 0;
            endcase
            if( wide && !hcnt_nx ) begin // half of 32-pxl object
                hpos <= hpos + 9'h10;
                hmsb[1] <= ~hmsb[1];
            end
        end
    endcase
end

jtframe_objscan #(.OBJW(7),.STW(2),.HREPW(1))
u_scan(
    .clk        ( clk       ),
    .cen        ( cen       ),
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
    .hcnt_nx    ( hcnt_nx   ),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   ),

    .addr       ( raw_addr  ),
    .step       ( st        )
);

endmodule