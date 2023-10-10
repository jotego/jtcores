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
    Date: 30-8-2023 */

// Draws one line of a 16x16 tile
// It could be extended to 32x32 easily

module jtfround_draw#( parameter
    CW       = 19,    // code width
    PW       =  8,    // pixel width (lower four bits come from ROM)
    KEEP_OLD =  0,    // slows down drawing to be compatible with jtframe_obj_buffer's KEEP_OLD parameter
    SWAPH    =  0
)(
    input               rst,
    input               clk,

    input               draw,
    output reg          busy,
    input    [CW-1:0]   code,
    input      [ 8:0]   xpos,

    // optional zoom, keep at zero for no zoom
    input               hflip,
    input         [1:0] hsize,
    input      [PW-5:0] pal,

    output reg [CW+2:2] rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    output reg [ 8:0]   buf_addr,
    output              buf_we,
    output     [PW-1:0] buf_din
);

// Each tile is 16x16 and comes from the same ROM
// but it looks like the sprites have the two 8x16 halves swapped

reg      [31:0] pxl_data;
reg             rom_lsb;
reg      [ 3:0] cnt;
reg      [ 4:0] hcnt, hmax;
wire     [ 4:0] nx_hcnt;
wire     [ 3:0] pxl;
reg             cen=0;
wire            cntover;

assign nx_hcnt = hcnt+4'd1;
assign buf_din = { pal, pxl };
assign pxl     = hflip ?
    { pxl_data[31], pxl_data[23], pxl_data[15], pxl_data[ 7] } :
    { pxl_data[24], pxl_data[16], pxl_data[ 8], pxl_data[ 0] };

assign buf_we   = busy & ~cnt[3];

always @* begin
    rom_addr = { code, rom_lsb^SWAPH[0]};
    case( hsize )
        1: rom_addr[3]   = ~hflip^hcnt[1];    //  32px wide
        2: rom_addr[4:3] = {2{~hflip}}^hcnt[2:1];  //  64
        3: rom_addr[5:3] = {3{~hflip}}^hcnt[3:1];  // 128
        default:;
    endcase
end

always @(posedge clk) cen <= ~cen;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs   <= 0;
        buf_addr <= 0;
        pxl_data <= 0;
        busy     <= 0;
        cnt      <= 0;
        hcnt     <= 0;
    end else begin
        if( !busy ) begin
            if( draw ) begin
                rom_lsb  <= hflip; // 14+4 = 18 (+2=20)
                rom_cs   <= 1;
                busy     <= 1;
                cnt      <= 8;
                hcnt     <= 0;
                buf_addr <= xpos;
                hmax     <= 5'd2<<hsize;
            end
        end else if(KEEP_OLD==0 || cen || cnt[3] ) begin
            // cen is required when old buffer data must be preserved but it
            // slows down the process. That wait is not needed while cnt[3]
            // is high, so it can be used to gain back some time
            if( rom_ok && rom_cs && cnt[3]) begin
                pxl_data <= rom_data;
                if( rom_data==0 ) begin
                    if( nx_hcnt==hmax ) begin
                        rom_cs <= 0;
                        busy   <= 0;
                    end else begin // blank chunk, move to next
                        hcnt     <= nx_hcnt;
                        rom_lsb <= ~rom_lsb;
                        buf_addr <= buf_addr+9'd8;
                        rom_cs   <= 1;
                    end
                end else begin // normal drawing
                    cnt[3]   <= 0;
                    if( hcnt==hmax ) begin
                        rom_cs <= 0;
                    end else begin
                        hcnt   <= nx_hcnt;
                        rom_cs <= 1;
                    end
                end
            end
            if( !cnt[3] ) begin
                cnt      <= cnt+1'd1;
                pxl_data <= hflip ? pxl_data << 1 : pxl_data >> 1;
                buf_addr <= buf_addr+1'd1;
                if( cnt[2:0]==0 && hcnt<hmax ) begin
                    rom_lsb <= ~rom_lsb;
                end
                if( cnt[2:0]==7 && hcnt==hmax ) begin
                    busy   <= 0;
                    rom_cs <= 0;
                end
            end
        end
    end
end

endmodule