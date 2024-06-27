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
    Date: 18-12-2022 */

// Draws one line of a 16x16 tile
// It could be extended to 32x32 easily

module jtframe_draw#( parameter
    CW       = 12,    // code width
    PW       =  8,    // pixel width (lower four bits come from ROM)
    ZW       =  6,    // zoom step width
    ZI       =  ZW-1, // integer part of the zoom, use for enlarging. ZI=ZW-1=no enlarging
    ZENLARGE =  0,    // enable zoom enlarging
    SWAPH    =  0,    // swaps the two horizontal halves of the tile
    KEEP_OLD =  0     // slows down drawing to be compatible with jtframe_obj_buffer's KEEP_OLD parameter
)(
    input               rst,
    input               clk,

    input               draw,
    output reg          busy,
    input    [CW-1:0]   code,
    input      [ 8:0]   xpos,
    input      [ 3:0]   ysub,
    input      [ 1:0]   trunc, // 00=no trunc, 10 = 8 pixels, 11 = 4 pixels

    // optional zoom, keep at zero for no zoom
    input    [ZW-1:0]   hzoom,
    input               hz_keep, // set to 0 on the first tile of a multi-tile
                                 // sprite, 1 for the rest of the tiles
    input               hflip,
    input               vflip,
    input      [PW-5:0] pal,

    output     [CW+6:2] rom_addr, // HVVVV format
    output reg          rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    output reg [ 8:0]   buf_addr,
    output              buf_we,
    output     [PW-1:0] buf_din
);

localparam [ZW-1:0] HZONE = { {ZW-1{1'b0}},1'b1} << (ZI);

// Each tile is 16x16 and comes from the same ROM
// but it looks like the sprites have the two 8x16 halves swapped

reg      [31:0] pxl_data;
reg             rom_lsb;
reg      [ 3:0] cnt, cnt_l;
wire     [ 3:0] ysubf, pxl;
reg    [ZW-1:0] hz_cnt, nx_hz;
wire  [ZW-1:ZI] hzint;
reg             cen=0, moveon, readon, write,sng;
wire            msb;

// reg      [ 3:0] status;
reg    [ZW-1:0] hzoom_l;

assign msb     = !trunc[0] ? cnt[3] : trunc[1] ? cnt[1] : cnt[2]; // 16, 4 or 8 pixels
assign ysubf   = ysub^{4{vflip}};
assign buf_din = { pal, pxl };
assign pxl     = hflip ?
    { pxl_data[31], pxl_data[23], pxl_data[15], pxl_data[ 7] } :
    { pxl_data[24], pxl_data[16], pxl_data[ 8], pxl_data[ 0] };

assign rom_addr = { code, rom_lsb^SWAPH[0], ysubf[3:0] };
assign buf_we   = busy & ~cnt[3];
assign hzint    = hz_cnt[ZW-1:ZI];
// assign { skip, nx_hz } = {1'b0, hz_cnt}+{1'b0,hzoom};

always @* begin
    if( ZENLARGE==1 ) begin
        readon = hzint >= 1; // tile pixels read (reduce)
        moveon = hzint <= 1; // buffer moves (enlarge)
        write  = hzoom != hzoom_l || hzoom < 12'h040 ? 1'b1 : (cnt != cnt_l);
        nx_hz = readon ? hz_cnt - HZONE : hz_cnt;
        if( moveon ) nx_hz = nx_hz + hzoom  /*+ 12'h010*/;
    end else begin
        readon = 1;
        write = 1;
        { moveon, nx_hz } = {1'b1, hz_cnt}-{1'b0,hzoom};
    end
end

always @(posedge clk) cen <= ~cen;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs   <= 0;
        buf_addr <= 0;
        pxl_data <= 0;
        busy     <= 0;
        cnt      <= 0;
        cnt_l    <= 0;
        hz_cnt   <= 0;

        // status   <= 0;
    end else begin
        if( !busy ) begin
            if( draw ) begin
                rom_lsb <= hflip; // 14+4 = 18 (+2=20)
                rom_cs  <= 1;
                busy    <= 1;
                cnt     <= 8;
                //cnt_l    <= cnt;
                // status   <= 1;
                if( !hz_keep ) begin
                    hz_cnt   <= 0;
                    buf_addr <= xpos;
                    // status   <= 2;
                end else begin
                    hz_cnt <= nx_hz;
                    // status   <= 3;
                end
            end
        end else if(KEEP_OLD==0 || cen || cnt[3] ) begin
            // cen is required when old buffer data must be preserved but it
            // slows down the process. That wait is not needed while cnt[3]
            // is high, so it can be used to gain back some time
            // status   <= 4;
            if( rom_ok && rom_cs && cnt[3]) begin
                pxl_data <= rom_data;
                cnt[3]   <= 0;
                cnt_l    <= cnt;
                // status   <= 5;
                if( rom_lsb^hflip ) begin
                    rom_cs <= 0;
                    // status   <= 6;
                end else begin
                    // cnt      <= cnt+1'd1;
                    sng <= 1;
                    rom_cs <= 1;
                    // status   <= 7;
                end
            end
            if( !cnt[3] ) begin
                hz_cnt   <= nx_hz;
                // status   <= 8;
                if( readon | sng ) begin
                    cnt      <= cnt+1'd1;
                    // cnt_l    <= cnt;
                    pxl_data <= hflip ? pxl_data << 1 : pxl_data >> 1;
                    // status   <= 9;
                end
                if( moveon /*&& (cnt != cnt_l)*/) begin
                    hzoom_l <= hzoom;
                    cnt_l    <= cnt;
                    // status   <= 10;
                    if( write ) begin
                        // if( sng ) begin cnt      <= cnt+1'd1;
                        buf_addr <= buf_addr+1'd1;
                        // status   <= 11;
                        sng <= 0;
                    end
                end
                rom_lsb  <= ~hflip;
                if( cnt[2:0]==7 && !rom_cs && readon ) busy <= 0; // 16 pixels
                if( cnt[2:0]==7 && trunc==2'b10      ) busy <= 0; //  8 pixels
                if( cnt[1:0]==3 && trunc==2'b11      ) busy <= 0; //  4 pixels
            end
        end
    end
end

endmodule