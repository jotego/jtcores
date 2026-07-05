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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 4-6-2026
    */
module jtargus_palette(
    input             rst,
    input             clk,
    input             pxl_cen,

    input      [11:0] addr,
    input      [ 7:0] din,
    input             we,
    input             grey_en,

    input      [ 9:0] pxl,
    input      [ 9:0] blend_bg_pxl,
    input      [ 9:0] blend_obj_pxl,
    output reg [11:0] rgb,
    output reg [11:0] blend_bg_rgb,
    output reg [11:0] blend_obj_rgb,
    output reg [ 3:0] blend_alpha
);

reg  [15:0] raw_pal,  intensity;
reg  [11:0] pal0_addr, pal1_addr, pre0_addr, pre1_addr;
reg  [ 9:0] base_addr, pxl_l, blend_bg_pxl_l, blend_obj_pxl_l,
            pxl_rd_addr;
reg  [ 7:0] din_l;
wire [ 7:0] pal0_dout, pal1_dout;
reg         pal0_we,   pal1_we, base_we,    pxlram_we,
            sprb_we,   int_we;
reg  [ 1:0] rd_st;
reg  [15:0] pxlram_din;
wire [15:0] pxlram_dout;
reg         cen;

localparam [1:0] ST_IDLE = 2'd0,
                 ST_PAL  = 2'd1,
                 ST_BG   = 2'd2,
                 ST_OBJ  = 2'd3;

localparam [9:0] BG0_OFF = 10'h080,
                 BG1_OFF = 10'h180,
                 TXT_OFF = 10'h280;

always @(posedge clk) begin
    cen <= ~cen;
    if(pxl_cen) cen <= 0;
end

initial begin
    cen             = 0;
    int_we          = 0;
    sprb_we         = 0;
    base_we         = 0;
    din_l           = 0;
    base_addr       = 0;
    pxl_l           = 0;
    blend_bg_pxl_l  = 0;
    blend_obj_pxl_l = 0;
    pxl_rd_addr     = 0;
    pal0_addr       = 0;
    pal1_addr       = 0;
    pal0_we         = 0;
    pal1_we         = 0;
    pxlram_we       = 0;
    pxlram_din      = 0;
    rd_st           = ST_IDLE;
    rgb             = 0;
    blend_bg_rgb    = 0;
    blend_obj_rgb   = 0;
    blend_alpha     = 0;
    base_addr       = 0;
end

function [3:0] sub4;
    input [3:0] a;
    input [3:0] b;
begin
    sub4 = a>b ? a-b : 4'd0;
end
endfunction

function [3:0] add4;
    input [3:0] a;
    input [3:0] b;
    reg   [4:0] sum;
begin
    sum  = {1'b0,a} + {1'b0,b};
    add4 = sum[4] ? 4'hf : sum[3:0];
end
endfunction

function [3:0] blend4;
    input [3:0] rgb;
    input [3:0] delta;
    input       subtract;
begin
    blend4 = subtract ? sub4(rgb,delta) : add4(rgb,delta);
end
endfunction

function [3:0] avg3;
    input [3:0] r;
    input [3:0] g;
    input [3:0] b;
    reg   [5:0] sum;
    reg   [5:0] avg;
begin
    sum  = {2'b0,r} + {2'b0,g} + {2'b0,b};
    avg  = sum / 6'd3;
    avg3 = avg[3:0];
end
endfunction

function [11:0] bg_effect;
    input [11:0] src;
    reg   [11:0] tmp;
    reg   [ 3:0] grey;
begin
    tmp = src;
    if( grey_en ) begin
        grey = avg3(tmp[11:8], tmp[7:4], tmp[3:0]);
        tmp  = { grey, grey, grey };
    end
    tmp[11:8] = blend4(tmp[11:8], intensity[15:12], intensity[2]);
    tmp[ 7:4] = blend4(tmp[ 7:4], intensity[11: 8], intensity[1]);
    tmp[ 3:0] = blend4(tmp[ 3:0], intensity[ 7: 4], intensity[0]);
    bg_effect = tmp;
end
endfunction

function [11:0] lookup_rgb;
    input [9:0] addr;
    input [11:0] raw;
begin
    lookup_rgb = ~addr[9] & addr[8]^addr[7] ? bg_effect(raw) : raw; // only applies to bg0
end
endfunction

always @* begin
    pre0_addr = addr;
    pre1_addr = addr;

    if(addr[11:8]==0) begin
        pre0_addr[7] = 0;
        pre1_addr[7] = 1;
    end

    if(^addr[11:10]) begin
        pre0_addr[11:10] = 2'b01;
        pre1_addr[11:10] = 2'b10;
    end
    raw_pal = { pal0_dout, pal1_dout };
    if(pal0_we) raw_pal[15:8] = din_l;
    if(pal1_we) raw_pal[ 7:0] = din_l;
end

always @(posedge clk) begin
    int_we    <= 0;
    sprb_we   <= 0;
    base_we   <= 0;
    pal0_we   <= 0;
    pal1_we   <= 0;
    pxlram_we <= base_we;
    din_l     <= din;

    if(we) begin
        pal0_addr <= pre0_addr;
        pal1_addr <= pre1_addr;
        pal0_we   <= addr[11:7]==pre0_addr[11:7];
        pal1_we   <= addr[11:7]==pre1_addr[11:7];
        case (addr[11:8])
            0:   begin // Sprites
                base_addr <= {3'd0,addr[6:0]};
                base_we   <= 1;
                sprb_we   <= 1;
                int_we    <= &addr[6:0];
            end
            4,8:  begin // BG0
                base_we <= 1;
                base_addr <= {2'd0,addr[7:0]} + BG0_OFF;
            end
            5,9:  begin // BG1
                base_we <= 1;
                base_addr <= {2'd0,addr[7:0]} + BG1_OFF;
            end
            7,11: begin // TXT
                base_we <= 1;
                base_addr <= {2'd0,addr[7:0]} + TXT_OFF;
            end
            default:;
        endcase
    end
end

always @( posedge clk) begin
    if( rst ) begin
        rd_st           <= ST_IDLE;
        intensity       <= 16'd0;
        pxl_l           <= 10'd0;
        blend_bg_pxl_l  <= 10'd0;
        blend_obj_pxl_l <= 10'd0;
        pxl_rd_addr     <= 10'd0;
        rgb             <= 12'd0;
        blend_bg_rgb    <= 12'd0;
        blend_obj_rgb   <= 12'd0;
        blend_alpha     <=  4'd0;
        pxlram_din      <= 16'b0;
    end else begin
        if(int_we) intensity <= raw_pal;
        if(base_we) begin
            pxlram_din <= raw_pal;
            if(!sprb_we) pxlram_din[3:0] <= 4'd0;
        end

        if(pxl_cen) begin
            pxl_l           <= pxl;
            blend_bg_pxl_l  <= blend_bg_pxl;
            blend_obj_pxl_l <= blend_obj_pxl;
            pxl_rd_addr     <= pxl;
            rd_st           <= ST_PAL;
        end else if(cen) begin
            case(rd_st)
                ST_PAL: begin
                    rgb         <= lookup_rgb(pxl_l, pxlram_dout[15:4]);
                    pxl_rd_addr <= blend_bg_pxl_l;
                    rd_st       <= ST_BG;
                end
                ST_BG: begin
                    blend_bg_rgb <= lookup_rgb(blend_bg_pxl_l, pxlram_dout[15:4]);
                    pxl_rd_addr  <= blend_obj_pxl_l;
                    rd_st        <= ST_OBJ;
                end
                ST_OBJ: begin
                    blend_obj_rgb <= pxlram_dout[15:4];
                    blend_alpha   <= pxlram_dout[ 3:0];
                    rd_st         <= ST_IDLE;
                end
                default: begin
                    rd_st <= ST_IDLE;
                end
            endcase
        end
    end
end

jtframe_dual_ram #(
    .AW(12)
) u_palram(
    // Port 0 - pal lo
    .clk0   ( clk       ),
    .addr0  ( pal0_addr ),
    .data0  ( din_l     ),
    .we0    ( pal0_we   ),
    .q0     ( pal0_dout ),
    // Port 1 - pal hi
    .clk1   ( clk       ),
    .data1  ( din_l     ),
    .addr1  ( pal1_addr ),
    .we1    ( pal1_we   ),
    .q1     ( pal1_dout )
);

jtframe_dual_ram #(
    .DW(16), .AW(10)
) u_pxlram(
    // Port 0 - CPU palette writes
    .clk0   ( clk          ),
    .addr0  ( base_addr    ),
    .data0  ( pxlram_din   ),
    .we0    ( pxlram_we    ),
    .q0     (              ),
    // Port 1 - sequenced video reads
    .clk1   ( clk          ),
    .data1  ( 16'b0        ),
    .addr1  ( pxl_rd_addr  ),
    .we1    ( 1'b0         ),
    .q1     ( pxlram_dout  )
);

endmodule
