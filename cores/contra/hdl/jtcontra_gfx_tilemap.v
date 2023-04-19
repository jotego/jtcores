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

module jtcontra_gfx_tilemap(
    input                rst,
    input                clk,
    input                HS,
    input                LVBL,
    input       [ 8:0]   hpos,
    input       [ 7:0]   vpos,
    input       [ 8:0]   vrender,
    input                flip,
    input                scrwin_en,
    output reg           done,
    // Text mode
    input                txt_en,        // enables the text mode
    input                layout,
    input                no_txt,        // enables 512x256 mode
    output      [10:0]   scan_addr,
    // Line buffer
    output reg           line,
    output               scr_we,
    output reg  [ 8:0]   line_din,
    output      [ 9:0]   line_addr,
    output               txt_line,
    // SDRAM
    output reg           rom_cs,
    output      [17:0]   rom_addr,
    input                rom_ok,
    input       [15:0]   rom_data,
    input       [ 7:0]   attr_scan,
    input       [ 7:0]   code_scan,
    // Strip scroll
    input                strip_en,
    input                strip_col,
    input       [ 7:0]   strip_pos,
    output      [ 4:0]   strip_addr,
    // Configuration
    input       [ 8:0]   chr_dump_start,
    input       [ 8:0]   scr_dump_start,
    input                pal_msb,
    input       [ 3:0]   extra_mask,
    input                extra_en,
    input       [ 3:0]   extra_bits,
    input                tile_msb,
    input       [ 1:0]   code9_sel,
    input       [ 1:0]   code10_sel,
    input       [ 1:0]   code11_sel,
    input       [ 1:0]   code12_sel,
    input                hflip_en,
    input                vflip_en
);

localparam [8:0] RENDER_END = 9'o500;
localparam [8:0] BLANK      = 9'o460;

reg  [12:0] code;
reg  [ 3:0] pal;
reg  [ 1:0] txt_his;
reg         line_we;
reg  [ 2:0] st;
reg         last_HS;
reg         scrwin;
reg  [ 8:0] hend, hn_txt,hn_scr, vn, hn_aux;
wire [ 8:0] lyr_vn, vpos_sum;
reg  [ 4:0] bank;
reg  [ 2:0] dump_cnt;
reg  [15:0] pxl_data;
reg  [8:0]  hrender;
wire        txt_row;    // signal whether the current row being rendered is text or graphics
wire [ 8:0] scr_hn0, hn;
reg         scores;
reg         hflip, vflip;

assign txt_line   = txt_his[1];
assign txt_row    = txt_en || scores;
assign scr_hn0    = (strip_en && !strip_col)? {1'b0,strip_pos} : hpos;
assign line_addr  = { line, flip ? 9'h116-hrender  : hrender };
assign scr_we     = line_we;
assign rom_addr   = { tile_msb, code, vn[2:0]^{3{vflip}}, hn[2]^hflip }; // 13+3+1 = 17!
assign strip_addr = strip_col ? hn_aux[7:3] : vrender[7:3];
assign vpos_sum   = (strip_en && strip_col) ? {1'd0,strip_pos} : {1'd0,vpos};
assign lyr_vn     = (vrender^{9{flip}}) + (txt_row ? 9'd0 : vpos_sum);
assign hn         = txt_row ? hn_txt : hn_scr;
// scan_addr[10] in the original chip seems to always be set twice for high and
// low, rather than only using the needed value, as I do here
assign scan_addr  = { no_txt ? hn[8] : txt_row, vn[7:3], hn[7:3] }; // 1 + 5 + 5 = 11

always @(*) begin
    bank[0] = attr_scan[7];
    bank[1] = (extra_en & extra_mask[0]) ? extra_bits[0] : attr_scan[3+code9_sel ];
    bank[2] = (extra_en & extra_mask[1]) ? extra_bits[1] : attr_scan[3+code10_sel];
    bank[3] = (extra_en & extra_mask[2]) ? extra_bits[2] : attr_scan[3+code11_sel];
    bank[4] = (extra_en & extra_mask[3]) ? extra_bits[3] : attr_scan[3+code12_sel];
end

//initial bank=5'h2;
always @(posedge clk) begin
    if( rst ) begin
        done    <= 1;
        pal     <= 4'd0;
        code    <= 13'd0;
        line_we <= 0;
        st      <= 3'd0;
        line    <= 0;
        scrwin  <= 0;
        hrender <= 0;
    end else begin
        last_HS <= HS;
        if( HS && !last_HS && LVBL) begin
            line   <= ~line;
            done   <= 0;
            rom_cs <= 0;
            st     <= 3'd0;
            hrender<= chr_dump_start;
            scores <= 0;
            hn_aux <= 0;
        end else begin
            if(!done) st <= st + 3'd1;
            case( st )
                0: begin
                    hn_txt <= 0;
                    hn_scr <= scr_hn0;
                    //hrender <= ( txt_en ? chr_dump_start : scr_dump_start )
                    //           - { 7'd0, scr_hn0[1:0] } - 9'd1;
                    hrender <= scr_dump_start - 1'd1 - (txt_en ? 9'd0 : { 7'd0, scr_hn0[1:0] });
                    hend    <= RENDER_END;
                    if(!done) txt_his <= { txt_his[0], txt_row };
                end
                1: begin
                    vn <= lyr_vn;
                end
                3: begin
                    code   <= { bank, code_scan };
                    pal    <= { pal_msb & attr_scan[3], attr_scan[2:0] };
                    scrwin <= (attr_scan[6] && scrwin_en);
                    hflip  <= ~txt_row & hflip_en & attr_scan[4];
                    vflip  <= ~txt_row & vflip_en & attr_scan[5];
                    rom_cs <= 1;
                end
                5: begin
                    if( rom_ok ) begin
                        pxl_data <= /*(hrender>=BLANK && layout) ? 16'd0 : */rom_data;
                        rom_cs   <= 0;
                        dump_cnt <= 7;
                    end else st <= st;
                end
                6: begin // dumps 4 pixels
                    if( dump_cnt[0] ) st<=st;
                    dump_cnt <= dump_cnt>>1;
                    pxl_data <= hflip ? pxl_data >> 4 : pxl_data << 4;
                    hrender  <= hrender + 9'd1;
                    line_din <= { scrwin, pal, hflip ? pxl_data[3:0] : pxl_data[15:12] };
                    line_we  <= 1;
                end
                7: begin
                    line_we <= 0;
                    if( hrender < hend ) begin
                        if( txt_row )
                            hn_txt <= hn_txt + 9'd4;
                        else
                            hn_scr <= hn_scr + 9'd4;
                        if( !hn[2] ) begin
                            rom_cs  <= 1;
                            st      <= 4; // wait for new ROM data
                        end else begin
                            vn      <= lyr_vn; // in case there is column scroll
                            hn_aux  <= hn_scr;
                            st      <= 2; // collect tile info
                        end
                    end else begin
                        if( layout && !scores ) begin
                            scores  <= 1;
                            hend    <= 9'o44;
                            hrender <= chr_dump_start-1'd1;
                            st      <= 1; // assign vn again
                        end else begin
                            done <= 1;
                            st   <= 0;
                        end
                    end
                end
            endcase // st
        end
    end
end

endmodule