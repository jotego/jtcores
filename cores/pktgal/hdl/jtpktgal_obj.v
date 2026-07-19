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
    Date: 12-7-2026 */

module jtpktgal_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             bootleg,
    input             flip,
    input      [ 8:0] hdump,
    input      [ 8:0] vrender,
    input             LHBL,

    output     [ 8:0] obj_vaddr,
    input      [ 7:0] obj_vdata,

    output reg [15:0] rom_addr,
    input      [ 7:0] rom_data,
    input             rom_ok,
    output            rom_cs,

    output     [ 4:0] pxl
);

localparam ST_IDLE  = 4'd0,
           ST_OBJ0  = 4'd1,
           ST_OBJ1  = 4'd2,
           ST_OBJ2  = 4'd3,
           ST_OBJ3  = 4'd4,
           ST_OBJ4  = 4'd5,
           ST_OBJ5  = 4'd6,
           ST_OBJ6  = 4'd7,
           ST_OBJ7  = 4'd8,
           ST_CHECK = 4'd9,
           ST_WAIT  = 4'd10,
           ST_NEXT  = 4'd11;

localparam RF_IDLE = 2'd0,
           RF_PL0  = 2'd1,
           RF_PL1  = 2'd2,
           RF_ACK  = 2'd3;

reg  [15:2] draw_rom_addr_l;
reg  [31:0] draw_rom_data;
reg  [ 8:0] scan_addr, dr_xpos;
reg  [ 7:0] spr_y, spr_attr, spr_x, spr_code;
reg  [ 6:0] spr_idx;
reg  [ 3:0] st, dr_ysub;
reg  [ 2:0] dr_pal;
reg  [ 1:0] rf_st;
reg         lhbl_l, draw, draw_rom_ok, dr_hflip, dr_vflip;

wire [15:2] draw_rom_addr;
wire [ 8:0] sprite_x, sprite_y, sprite_y_end, line_delta, flip_xpos;
wire [ 8:0] draw_code;
wire [ 6:0] draw_pxl;
wire [ 4:0] helper_pxl;
wire [ 7:0] rom_data_sort;
wire        line_start, inzone_x, inzone_y, sprite_on, draw_busy, draw_rom_cs,
            obj_hs, hflip, vflip;

function [15:0] obj_byte_addr;
    input [15:2] row_addr;
    input        plane0;
    reg   [ 4:0] half_addr;
begin
    half_addr     = row_addr[6] ? 5'd0 : 5'd16;
    obj_byte_addr = { 2'b00, row_addr[15:7], 5'd0 } +
                    { 11'd0, row_addr[5:2] } +
                    { 11'd0, half_addr } +
                    (plane0 ? 16'h8000 : 16'h0000);
end
endfunction

assign line_start    = pxl_cen && LHBL && !lhbl_l;
assign obj_hs        = ~LHBL;
assign sprite_x      = 9'd240 - {1'b0, spr_x};
assign sprite_y      = 9'd240 - {1'b0, spr_y};
assign sprite_y_end  = sprite_y + 9'd15;
assign line_delta    = vrender - sprite_y;
assign flip_xpos     = 9'd240 - sprite_x - 9'd15;
assign inzone_x      = sprite_x < 9'd256 || sprite_x + 9'd15 < 9'd256;
assign inzone_y      = vrender >= sprite_y && vrender <= sprite_y_end;
assign sprite_on     = spr_y != 8'hf8 && inzone_x && inzone_y;
assign hflip         = flip ? !spr_attr[2] : spr_attr[2];
assign vflip         = flip ? !spr_attr[1] : spr_attr[1];
assign obj_vaddr     = scan_addr;
assign rom_cs        = rf_st == RF_PL0 || rf_st == RF_PL1;
assign draw_code     = { spr_attr[0], spr_code };
assign rom_data_sort = bootleg ? rom_data :
                       { rom_data[0], rom_data[1], rom_data[2], rom_data[3],
                         rom_data[4], rom_data[5], rom_data[6], rom_data[7] };
assign helper_pxl    = { draw_pxl[6:4], draw_pxl[1:0] };
assign pxl           = LHBL ? helper_pxl : 5'd0;

always @(posedge clk) begin
    if (pxl_cen)
        lhbl_l <= LHBL;
end

always @(posedge clk) begin
    if (rst) begin
        st         <= ST_IDLE;
        spr_idx    <= 0;
        scan_addr  <= 0;
        spr_y      <= 0;
        spr_attr   <= 0;
        spr_x      <= 0;
        spr_code   <= 0;
        dr_xpos    <= 0;
        dr_ysub    <= 0;
        dr_pal     <= 0;
        dr_hflip   <= 0;
        dr_vflip   <= 0;
        draw       <= 0;
    end else begin
        draw <= 0;
        case (st)
            ST_IDLE: begin
                if (line_start) begin
                    spr_idx    <= 0;
                    scan_addr  <= 0;
                    st         <= ST_OBJ0;
                end
            end
            ST_OBJ0: begin
                scan_addr <= { spr_idx, 2'd0 };
                st         <= ST_OBJ1;
            end
            ST_OBJ1: begin
                spr_y      <= obj_vdata;
                scan_addr <= { spr_idx, 2'd1 };
                st         <= ST_OBJ2;
            end
            ST_OBJ2: begin
                scan_addr <= { spr_idx, 2'd1 };
                st         <= ST_OBJ3;
            end
            ST_OBJ3: begin
                spr_attr   <= obj_vdata;
                scan_addr <= { spr_idx, 2'd2 };
                st         <= ST_OBJ4;
            end
            ST_OBJ4: begin
                scan_addr <= { spr_idx, 2'd2 };
                st         <= ST_OBJ5;
            end
            ST_OBJ5: begin
                spr_x      <= obj_vdata;
                scan_addr <= { spr_idx, 2'd3 };
                st         <= ST_OBJ6;
            end
            ST_OBJ6: begin
                scan_addr <= { spr_idx, 2'd3 };
                st         <= ST_OBJ7;
            end
            ST_OBJ7: begin
                spr_code <= obj_vdata;
                st       <= ST_CHECK;
            end
            ST_CHECK: begin
                dr_xpos  <= (flip ? flip_xpos : sprite_x) + 9'd1;
                dr_ysub  <= line_delta[3:0];
                dr_pal   <= spr_attr[6:4];
                dr_hflip <= hflip;
                dr_vflip <= vflip;
                st       <= sprite_on ? ST_WAIT : ST_NEXT;
            end
            ST_WAIT: begin
                if (!draw_busy) begin
                    draw <= 1;
                    st   <= ST_NEXT;
                end
            end
            ST_NEXT: begin
                spr_idx <= spr_idx + 7'd1;
                if (spr_idx == 7'd127) begin
                    st <= ST_IDLE;
                end else begin
                    scan_addr <= { spr_idx + 7'd1, 2'd0 };
                    st         <= ST_OBJ0;
                end
            end
            default: st <= ST_IDLE;
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        rf_st           <= RF_IDLE;
        rom_addr        <= 0;
        draw_rom_addr_l <= 0;
        draw_rom_data   <= 0;
        draw_rom_ok     <= 0;
    end else begin
        draw_rom_ok <= 0;
        case (rf_st)
            RF_IDLE: begin
                if (draw_rom_cs) begin
                    draw_rom_addr_l <= draw_rom_addr;
                    rom_addr        <= obj_byte_addr(draw_rom_addr, 1'b1);
                    rf_st           <= RF_PL0;
                end
            end
            RF_PL0: begin
                if (rom_ok) begin
                    draw_rom_data[15:8] <= rom_data_sort;
                    rom_addr            <= obj_byte_addr(draw_rom_addr_l, 1'b0);
                    rf_st               <= RF_PL1;
                end
            end
            RF_PL1: begin
                if (rom_ok) begin
                    draw_rom_data[ 7:0] <= rom_data_sort;
                    draw_rom_data[31:16]<= 16'd0;
                    draw_rom_ok         <= 1;
                    rf_st               <= RF_ACK;
                end
            end
            RF_ACK: begin
                if (!draw_rom_cs) begin
                    rf_st <= RF_IDLE;
                end else if (draw_rom_addr != draw_rom_addr_l) begin
                    draw_rom_addr_l <= draw_rom_addr;
                    rom_addr        <= obj_byte_addr(draw_rom_addr, 1'b1);
                    rf_st           <= RF_PL0;
                end
            end
            default: rf_st <= RF_IDLE;
        endcase
    end
end

jtframe_objdraw #(
    .AW     ( 9 ),
    .CW     ( 9 ),
    .PW     ( 7 ),
    .HFIX   ( 0 ),
    .LATCH  ( 1 )
) u_objdraw(
    .rst      ( rst           ),
    .clk      ( clk           ),
    .pxl_cen  ( pxl_cen       ),
    .hs       ( obj_hs        ),
    .flip     ( 1'b0          ),
    .hdump    ( hdump         ),
    .draw     ( draw          ),
    .busy     ( draw_busy     ),
    .code     ( draw_code     ),
    .xpos     ( dr_xpos       ),
    .ysub     ( dr_ysub       ),
    .hzoom    ( 6'd0          ),
    .hz_keep  ( 1'b0          ),
    .hflip    ( dr_hflip      ),
    .vflip    ( dr_vflip      ),
    .pal      ( dr_pal        ),
    .rom_addr ( draw_rom_addr ),
    .rom_cs   ( draw_rom_cs   ),
    .rom_ok   ( draw_rom_ok   ),
    .rom_data ( draw_rom_data ),
    .pxl      ( draw_pxl      )
);

endmodule
