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
    Date: 4-10-2021 */

// The MXC-06 operates at 12MHz
// That gives an absolute maximum of 48 16-pxl tiles per line
// The actual number will be slightly below

module jtcop_obj_draw(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              HS,
    input              LHBL,
    input              LVBL,
    input              flip,

    input      [ 8:0]  hdump,
    input      [ 8:0]  vrender,

    // Object engine
    output reg [ 9:0]  tbl_addr,
    input      [15:0]  tbl_dout,

    // ROM interface
    output reg         rom_cs,
    output reg [17:1]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,    

    output     [ 7:0]  pxl
);

reg  [7:0] buf_pxl;
reg  [8:0] buf_waddr;
reg  [11:0] id_eff;
wire [7:0] buf_wdata;
reg        buf_we;
reg        cen2;
reg  [2:0] nsize, ncnt;
reg  [1:0] msize; // n = horizontal tiles, m = vertical tiles, like in JTCORES1
reg        hflip, vflip;

wire [ 8:0] ypos;
reg  [ 8:0] xpos;
reg  [ 8:0] veff, vrf, top, bottom;
reg  [ 3:0] pal;
reg  [11:0] id;
reg  [ 5:0] line_cnt;   // number of drawn tiles in a line
reg         frame, parse_busy, inzone,
            draw, HSl, LVl,
            draw_busy, rom_good;
wire        blink;

assign ypos  = 9'd256-tbl_dout[8:0];
assign blink = tbl_dout[11];

always @* begin
    inzone = 1;
    bottom = ypos;
    case( tbl_dout[12:11] ) // msize
        0: top = ypos - 9'h10;
        1: top = ypos - 9'h20;
        2: top = ypos - 9'h40;
        3: top = ypos - 9'h80;
    endcase
    if( (vrf < top && !top[8]) || vrf >= bottom || bottom < 8 || (top[8] && bottom[8]) )
        inzone = 0;
end

always @* begin
    id_eff = tbl_dout[11:0];
    vrf    = flip ? 9'd256-vrender : vrender;
    case( msize )
        1: id_eff = { id_eff[11:1],     vflip^veff[4]    };
        2: id_eff = { id_eff[11:2], {2{vflip}}^veff[5:4] };
        3: id_eff = { id_eff[11:3], {3{vflip}}^veff[6:4] };
        default:;
    endcase
end

wire [3:0] nsize_aux = (4'd1 << tbl_dout[10:9])-4'd1;

// Get the information
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        tbl_addr   <= 0;
        cen2       <= 0;
        parse_busy <= 0;
        draw       <= 0;
        frame      <= 0;
        nsize      <= 0;
        msize      <= 0;
    end else begin
        HSl <= HS;
        LVl <= LVBL;
        cen2 <= ~cen2;
        draw <= 0;
        if( !LVBL && LVl ) frame <= ~frame; // used for sprite blinking
        if( HSl && !HS ) begin
            tbl_addr <= 0;
            parse_busy <= 1;
            cen2 <= 0;
        end
        if( parse_busy && !draw_busy && cen2 ) begin
            case( tbl_addr[1:0] )
                0: begin
                    { vflip, hflip } <= tbl_dout[14:13];
                    nsize <= nsize_aux[2:0];
                    msize <= tbl_dout[12:11];
                    veff  <= vrf - ypos;
                    if( !inzone || !tbl_dout[15] ) begin
                        tbl_addr <= tbl_addr + 10'd4;
                        if( &tbl_addr[9:2] ) begin
                            parse_busy <= 0; // done
                        end
                    end else begin
                        tbl_addr <= tbl_addr + 10'd1;
                    end
                end
                1: begin
                    id <= id_eff;
                    tbl_addr <= tbl_addr + 10'd1;
                end
                2: begin
                    xpos     <= 9'd240-tbl_dout[8:0];
                    pal      <= tbl_dout[15:12];
                    tbl_addr <= tbl_addr + 10'd2;
                    draw     <= ~blink | frame;
                    if( &tbl_addr[9:2] ) begin
                        parse_busy <= 0; // done
                    end
                end
            endcase
            if( line_cnt >= 48 ) begin
                parse_busy <= 0; // per-line limit overrun
            end
        end
    end
end

// Draw the sprite
reg  [31:0] draw_data;
wire [ 3:0] draw_pxl;
reg  [ 3:0] draw_cnt;
reg         half;
wire [ 8:0] buf_waflip;

assign draw_pxl  = hflip ? { draw_data[ 8], draw_data[24], draw_data[0], draw_data[16] } :
                           { draw_data[15], draw_data[31], draw_data[7], draw_data[23] };
assign buf_wdata = { pal, draw_pxl };
assign buf_waflip= !flip ? buf_waddr : 9'h100-buf_waddr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        draw_busy <= 0;
        draw_cnt  <= 0;
        buf_waddr <= 0;
        rom_good  <= 0;
        buf_we    <= 0;
        rom_cs    <= 0;
        half      <= 0;
        ncnt      <= 0;
        line_cnt  <= 0;
    end else begin
        rom_good <= rom_ok;
        if( !parse_busy ) line_cnt <= 0;
        if( draw ) begin
            draw_busy <= 1;
            half      <= 0;
            rom_addr <= { id, ~hflip, veff[3:0]^{4{vflip}} }; // 16 bits
            draw_cnt <= 0;
            ncnt     <= nsize;
            rom_cs   <= 1;
            rom_good <= 0;
            buf_waddr<= xpos;
        end
        if( !buf_we && rom_cs && rom_good && rom_ok && draw_cnt==0 ) begin
            draw_data <= rom_data;
            rom_cs    <= 0;
            buf_we    <= 1;
            draw_cnt  <= 7;
        end
        if( buf_we ) begin
            draw_data <= hflip ? draw_data>>1 : draw_data<<1;
            draw_cnt <= draw_cnt-1'd1;
            buf_waddr<= buf_waddr+9'd1;
            if( draw_cnt==0 ) begin
                buf_we    <= 0;
                if( half ) begin
                    line_cnt <= line_cnt + 1'd1;
                    if( ncnt==0 ) begin
                        draw_busy <= 0;
                        rom_cs    <= 0;
                    end else begin // next tile in the sequence
                        rom_addr[5] <= ~hflip;
                        rom_addr[17:6] <= rom_addr[17:6]+(12'd1<<msize);
                        rom_cs   <= 1;
                        rom_good <= 0;
                        half     <= 0;
                        draw_cnt <= 0;
                        ncnt     <= ncnt-1'd1;
                    end
                end else begin // second half of 16-pxl tile
                    rom_addr[5] <= ~rom_addr[5];
                    rom_cs      <= 1;
                    rom_good    <= 0;
                    half        <= 1;
                    draw_cnt    <= 0;
                end
            end
        end
    end
end

jtframe_obj_buffer #(.ALPHA  ( 8'H0  ))
u_buffer (
    .clk        ( clk       ),
    .LHBL       ( LHBL      ),
    .flip       ( 1'b0      ),
    // New data writes
    .wr_data    ( buf_wdata ),
    .wr_addr    ( buf_waflip),
    .we         ( buf_we    ),
    // Old data reads (and erases)
    .rd_addr    ( hdump     ),
    .rd         ( pxl_cen   ),
    .rd_data    ( pxl       )
);

endmodule 