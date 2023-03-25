/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-10-2022 */

module jtoutrun_obj_draw(
    input              rst,
    input              clk,
    input              hstart,
    // From scan
    input              start,
    output reg         busy,
    input      [ 8:0]  xpos,
    input      [15:0]  offset,  // MSB is also used as the flip bit
    input      [ 2:0]  bank,
    input      [ 1:0]  prio,
    input              shadow,
    input      [ 6:0]  pal,
    input      [ 9:0]  hzoom,
    input              hflip,
    input              backwd,

    // SDRAM interface
    input              obj_ok,
    output reg         obj_cs,
    output     [19:2]  obj_addr, // All games have 1MB max ROM for objects
    input      [31:0]  obj_data,

    // Buffer
    output     [13:0]  bf_data,
    output             bf_we,
    output reg [ 8:0]  bf_addr,

    input      [ 7:0]  debug_bus
);

reg  [31:0] pxl_data;
reg  [15:0] cur;
reg  [ 3:0] cnt;
reg         first, halted, last_data;
wire [ 3:0] cur_pxl; // , nxt_pxl;
reg  [12:0] hzacc, nx_hzacc;
reg         count_up, draw;
wire        data_ok;

assign cur_pxl  = hflip ? pxl_data[3:0] : pxl_data[31-:4];
// assign nxt_pxl  = hflip ? pxl_data[7:4] : pxl_data[(31-4)-:4];
assign obj_addr = { bank[1:0], cur };
assign bf_data  = { pal, shadow, prio, cur_pxl }; // 14 bits,

assign bf_we   = busy & ~first & draw & data_ok & ~&cur_pxl // color 15 used to set sprite limits
    & (|cur_pxl); // color 0 used as transparent
assign data_ok = obj_ok || cnt[2:0]!=0 || last_data;

// Sprite scaling
always @(hzacc,hzoom) begin
    count_up = 0;
    draw  = hzacc < 13'h200;
    nx_hzacc = hzacc;
    if( draw ) begin
        nx_hzacc = hzacc + {2'd0,hzoom};
    end
    else begin
        count_up = 1;
        nx_hzacc = hzacc - 13'h200;
    end
end

integer ticks;
reg late;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy     <= 0;
        obj_cs   <= 0;
        cur      <= 0;
        bf_addr  <= 0;
        first    <= 0;
        pxl_data <= 0;
    end else begin
        late   <= 0;
        halted <= 0;
        if( start ) begin
            cur      <= offset;
            obj_cs   <= 1;
            halted   <= obj_ok;
            first    <= 1;
            busy     <= 1;
            cnt      <= 0;
            bf_addr  <= xpos;
            hzacc    <= 0;
            last_data<= 0;
`ifdef SIMULATION
            ticks <= 0;
            if( busy || bf_we ) begin
                $display("Assertion failed: obj draw start requested while busy");
                $finish;
            end
`endif
        end else if(!halted) begin
            if( busy && data_ok ) begin
                if( cnt[2:0]==0 ) begin
                    last_data <= &(hflip ? obj_data[27-:4] : obj_data[7:4]);
                end
                hzacc <= nx_hzacc;
                if( count_up ) begin
                    if( cnt[2:0]==0 ) obj_cs <= 0;
                    if( cnt==1 ) begin // request the next 8 pixels from the SDRAM
                        cur    <= cur + (hflip ? -16'd1 : 16'd1);
                        obj_cs <= ~last_data;
                    end
                    cnt <= first ? 4'd0 : cnt + 1'b1;
                    pxl_data <= cnt[2:0]==0 ? obj_data :
                                      hflip ? pxl_data>>4 : pxl_data<<4;
                end
                if( first ) begin
                    pxl_data <= obj_data;
                    cnt      <= 0;
                    first    <= 0;
                end
                if( cnt[3] ) begin
                    cnt[3]   <= 0;
                    if( last_data ) begin
                        busy <= 0;  // done
                        // $display("\tdrawing for %d ticks",ticks);
                    end
                end
                if( !first && draw ) begin
                    bf_addr <= bf_addr + { {8{backwd}}, 1'd1 }; // if backwd, then -1; else +1
                    if( backwd ? bf_addr<9'h94 : bf_addr==9'h1ff ) begin // Do not draw past the limits
                        busy  <= 0;
                    end
                end
            end
            ticks <= ticks+1;
        end
        if( hstart ) begin
            busy   <= 0;
            obj_cs <= 0;
            late   <= busy | bf_we;
        end
    end
end

endmodule