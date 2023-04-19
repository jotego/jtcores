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
    Date: 12-3-2021 */

module jts16_obj_draw#(
    parameter MODEL=0  // 0 = S16A, 1 = S16B, 2 = OUTRUN
)(
    input              rst,
    input              clk,
    input              hstart,
    // From scan
    input              start,
    output reg         busy,
    input      [ 8:0]  xpos,
    input      [15:0]  offset,  // MSB is also used as the flip bit
    input      [ 3:0]  bank,
    input      [ 1:0]  prio,
    input      [(MODEL==2?6:5):0]  pal,
    input      [ 4:0]  hzoom,
    input              hflipb,

    // SDRAM interface
    input              obj_ok,
    output reg         obj_cs,
    output     [20:1]  obj_addr, // 3 bank + 15 offset = 18
    input      [15:0]  obj_data,

    // Buffer
    output     [(MODEL==2?12:11):0]  bf_data,
    output reg         bf_we,
    output reg [ 8:0]  bf_addr,
    input      [ 7:0]  debug_bus
);

localparam S16A   = 0,
           S16B   = 1,
           OUTRUN = 2;

reg  [15:0] pxl_data, cur;
reg  [ 3:0] cnt;
reg         draw, stop;
wire [ 3:0] cur_pxl, nxt_pxl;
wire        hflip;
reg  [ 5:0] hzacc;
wire [ 6:0] hzsum;
wire        hzov;

assign cur_pxl  = hflip ? pxl_data[3:0] : pxl_data[15:12];
assign nxt_pxl  = hflip ? pxl_data[7:4] : pxl_data[11: 8];
assign obj_addr = MODEL==S16A ? { 2'b0, bank[1:0], bank[2], cur[14:0] } :
                                { bank, cur[15:0] };
assign bf_data  = MODEL==OUTRUN ? { pal, prio, cur_pxl } : { prio, pal, cur_pxl };
assign hflip    = MODEL==S16A   ? cur[15] : hflipb;

// Sprite scaling
assign hzsum = {1'b0, hzacc} + {2'd0, hzoom};
assign hzov  = hzsum[6];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy   <= 0;
        draw   <= 0;
        obj_cs <= 0;
        bf_we  <= 0;
        cur    <= 0;
    end else begin
        if( hstart ) begin
            busy <= 0;
            draw <= 0;
        end else
        if( start ) begin
            cur      <= offset;
            obj_cs   <= 1;
            busy     <= 1;
            draw     <= 0;
            bf_we    <= 0;
            stop     <= 1;
            bf_addr  <= xpos;
            hzacc    <= { hzoom[3:0], 2'd0 };
        end else begin
            bf_we <= 0;
            if(obj_ok) stop <= 0;
            if( busy ) begin
                if( draw ) begin
                    cnt <= { cnt[2:0], 1'b1 };
                    hzacc <= hzsum[5:0];
                    if(cnt[3]) begin
                        draw  <= 0;
                        bf_we <= 0;
                        if( &cur_pxl )
                            busy <= 0;  // done
                    end else begin
                        bf_we    <= ~hzov & ~&nxt_pxl;
                    end
                    pxl_data <= hflip ? pxl_data>>4 : pxl_data<<4;
                    if( !hzov ) bf_addr <= bf_addr+1'd1;
                end else if(!stop) begin
                    if( obj_cs && obj_ok ) begin
                        // Draw pixels
                        pxl_data <= obj_data;
                        bf_we    <= ~&(hflip ? obj_data[3:0] : obj_data[15:12]); // $F must not be drawn
                        cnt      <= 1;
                        draw     <= 1;
                        obj_cs   <= 0;
                    end else begin
                        cur    <= cur + (hflip ? -16'd1 : 16'd1);   // hflip may be affected
                        obj_cs <= 1;
                        stop   <= 1;
                    end
                end
            end
        end
    end
end

endmodule