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
    Date: 02-05-2020 */

// Main features of Konami's 007121 hardware
// Some elements have been factored out one level up (H/S timing...)

module jtcontra_gfx_obj(
    input                rst,
    input                clk,
    input                pxl_cen,
    input                HS,
    input                LVBL,
    input       [ 8:0]   vrender,
    input                flip,
    input                layout,
    output reg           done,
    output      [ 9:0]   scan_addr, // max 64 sprites in total
    // Object Colour Prom
    output reg  [ 7:0]   oprom_addr,
    input       [ 3:0]   oprom_data,
    // Line buffer
    input       [ 8:0]   hdump,
    input       [ 8:0]   dump_start,
    output      [ 7:0]   pxl, // upper half is the palette, used for MX5000
    // SDRAM
    output reg           rom_cs,
    output      [17:0]   rom_addr,
    input                rom_ok,
    input       [15:0]   rom_data,
    input       [ 7:0]   obj_scan
);

reg  [13:0] code;
reg  [ 3:0] pal;
reg         line_we;
reg         h4;
reg  [ 2:0] byte_sel;
reg  [ 3:0] st;
reg         last_HS;
reg  [ 8:0] hn, vn;
reg  [ 4:0] bank;
reg  [ 7:0] dump_cnt;
reg  [ 3:0] size_cnt;
reg  [15:0] pxl_data;
reg  [ 8:0] xpos;
reg  [ 9:0] scan_base;
reg         obj_we;
wire [ 8:0] line_addr;

reg  [ 2:0] height_comb;
reg  [ 8:0] upper_limit;
reg  [ 4:0] vsub;
reg  [ 2:0] size_attr;
reg         hflip, vflip;
reg  [ 8:0] pxl_cnt; // OBJ limit should be less than 64us*6MHz=384 pixels
wire [ 8:0] vf;

//assign      line_addr = { flip ? 9'h0EF-xpos + (layout ? 9'o50 : 0) : xpos };
assign      line_addr = { flip ? 9'h117-xpos : xpos };
assign      scan_addr = scan_base + { 7'd0, byte_sel };
assign      vf        = vrender ^ {1'b0, {8{flip}}};

always @(*) begin
    height_comb  = size_attr[2] ? 3'b100 : ( size_attr[0] ? 3'b001 : 3'b010 );
    upper_limit = {1'b0, obj_scan} + { 3'b0, height_comb, 3'd0 };
end

assign rom_addr = { code, vsub[2:0], h4 }; // 14+3+1 = 18

always @(posedge clk) begin
    if( rst ) begin
        done    <= 1;
        pal     <= 0;
        code    <= 0;
        line_we <= 0;
        st      <= 0;
        size_cnt<= 0;
        dump_cnt<= 0;
        h4      <= 0;
    end else begin
        last_HS <= HS;
        if( HS && !last_HS && LVBL) begin
            done      <= 0;
            rom_cs    <= 0;
            st        <= 0;
            scan_base <= 0;
            byte_sel  <= 3'd4;      // get obj size
            pxl_cnt   <= 0;
        end else begin
            if(!done) st <= st + 4'd1;
            case( st )
                0: begin
                    rom_cs   <= 0;
                    byte_sel <= 3'd2;   // get y position
                end
                1: begin
                    xpos[8]     <= obj_scan[0];
                    size_attr   <= obj_scan[3:1];
                    hflip       <= obj_scan[4];
                    vflip       <= obj_scan[5];
                    code[13:12] <= obj_scan[7:6];
                    byte_sel    <= 3'd0;   // get code
                end
                2: begin
                    size_cnt <= size_attr[2] ? 4'b1111 : (
                                size_attr[1] ? 4'b0001 : 4'b0011 );
                    vsub     <= (vf[4:0]-obj_scan[4:0])^{5{vflip}};
                    h4       <= hflip;
                    if( obj_scan== 8'd240 && scan_base>=10'd80) begin
                        st     <= 0;
                        done   <= 1;
                        rom_cs <= 0;
                    end else begin
                        if( (vf < {1'b0,obj_scan} &&
                             {1'b1,vf[7:0]}>=upper_limit )
                            || vf[8:0] >= upper_limit[8:0] ) begin
                            st        <= 9; // next tile
                        end else begin
                            byte_sel <= 3'd1; // get colour
                        end
                    end
                end
                3: begin
                    code[9:2] <= obj_scan;
                    byte_sel  <= 3'd3; // x position
                end
                4: begin
                    code[11:10] <= obj_scan[1:0];
                    // code[3] and code[1] => vertical size
                    if( size_attr[2] ) // 32px
                        { code[3],code[1] } <= vsub[4:3];
                    else if( size_attr[0] ) // 8px
                        code[1] <= obj_scan[3];
                    else begin
                        code[1] <= vflip ? &vsub[4:3] : vsub[3];
                    end
                    // code[2] and code[0] => horizontal size
                    if( size_attr[2] ) // 32px
                        { code[2],code[0] } <= {2{hflip}};
                    else if( size_attr[1] ) // 8px
                        code[0] <= obj_scan[2];
                    else
                        code[0] <= hflip;
                    pal         <= obj_scan[7:4];
                    rom_cs      <= 1;
                end
                5: begin
                    xpos <= {xpos[8], obj_scan} -9'd1 + dump_start;
                end
                6: begin
                      if( rom_ok ) begin
                        pxl_data <= rom_data;
                        rom_cs   <= 0;
                        dump_cnt <= 7;
                    end else st <= st;
                end
                7: begin // dumps 4 pixels
                    if( dump_cnt[0] ) st<=st;
                    dump_cnt <= dump_cnt>>1;
                    pxl_data <= hflip ? pxl_data>>4 : pxl_data << 4;
                    pxl_cnt  <= pxl_cnt + 9'd1;
                    xpos     <= xpos + 9'd1;
                    oprom_addr <= { pal,
                        hflip ? pxl_data[3:0] : pxl_data[15:12]
                        };
                    line_we  <= 1;
                end
                8: begin
                    line_we <= 0;
                    {code[2],code[0],h4} <= {code[2],code[0],h4} +
                        ( hflip ? -3'd1 : 3'd1 );
                    if( h4 ) size_cnt <= size_cnt>>1;
                    if( hflip ? (!size_cnt[0] && !h4) : (!size_cnt[1] && h4) ) begin
                        st      <= 9; // next tile
                    end else begin
                        rom_cs  <= 1;
                        st      <= 10; // wait for new ROM data
                    end
                end
                9: begin
                    byte_sel  <= 3'd4;
                    st        <= 0;
                    if( scan_base < 10'h13b && pxl_cnt<9'd384 ) begin
                        scan_base <= scan_base + 10'd5;
                    end else begin
                        done      <= 1;
                        rom_cs    <= 0;
                    end
                end
                10: st <= 6; // wait cycle for rom_ok
            endcase // st
        end
    end
end

jtframe_obj_buffer #(
    .DW   (8),
    .ALPHA(0),
    .BLANK(0)
) u_line(
    .clk    ( clk           ),
    .LHBL   ( ~HS           ),
    // New data writes
    .wr_data( { oprom_addr[7:4], oprom_data } ),
    .wr_addr( line_addr     ),
    .we     ( line_we       ),
    .flip   ( 1'b0          ),
    // Old data reads (and erases)
    .rd_addr( hdump         ),
    .rd     ( pxl_cen       ),  // data will be erased after the rd event
    .rd_data( pxl           )
);


endmodule