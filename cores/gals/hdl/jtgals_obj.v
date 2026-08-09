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
    Date: 12-7-2026 */

module jtgals_obj(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              lvbl,

    output      [ 8:0] ln_addr,
    output      [15:0] ln_data,
    output reg         ln_done,
    input              ln_hs,
    input       [15:0] ln_dout,
    input       [15:0] ln_pxl,
    input       [ 7:0] ln_v,
    input              ln_vs,
    input              ln_lvbl,
    output             ln_we,

    output reg  [12:1] ram_addr,
    input       [15:0] ram_dout,

    output             rom_cs,
    output      [19:2] rom_addr,
    input       [31:0] rom_data,
    input              rom_ok,

    output      [ 7:0] pxl
);

localparam [3:0] IDLE =4'd0,
                 A3   =4'd1,
                 A5   =4'd2,
                 A4   =4'd3,
                 R5   =4'd4,
                 R4   =4'd5,
                 R6   =4'd6,
                 R7   =4'd7,
                 RCODE=4'd8;
localparam [1:0] D_SCAN=2'd0, D_WAIT=2'd1, D_DONE=2'd2;

reg  [ 3:0] s_st;
reg  [ 1:0] done_st;
reg  [ 1:0] done_wait;
reg  [ 8:0] scan_entry, obj_x, obj_y, cand_xpos;
reg  [ 7:0] b3, b5, b6;
reg  [12:0] dr_code;
reg  [ 8:0] dr_xpos;
reg  [ 3:0] dr_pal, dr_ysub, cand_pal, cand_ysub;
reg  [12:0] pend_code;
reg  [ 8:0] pend_xpos;
reg  [ 3:0] pend_pal, pend_ysub;
reg         last_ln_hs, dr_hflip, dr_vflip, dr_draw;
reg         pend_hflip, pend_vflip, pend_valid;
reg         scan_active;

wire [ 8:0] draw_addr;
wire [31:0] sorted_rom;
wire [19:2] raw_rom_addr;
wire [12:0] scan_code_now;
wire [ 8:0] scan_dy, scan_next_y, obj_ytop;
wire [ 8:0] scan_dx_now, scan_next_x_now, draw_x_now;
wire signed [9:0] req_ypos, obj_yorg, scan_ydiff;
wire [ 7:0] ram_byte, draw_pxl;
wire [ 3:0] scan_pal;
wire        scan_rel, scan_used, scan_inzone, dr_busy, draw_we, line_start;
wire        scan_last;

assign pxl              = ln_pxl[7:0];
assign ln_addr          = draw_addr;
assign ln_data          = { 8'd0, draw_pxl };
assign ln_we            = draw_we && draw_pxl[3:0] != 4'd0;
assign ram_byte         = ram_dout[7:0];
assign scan_dx_now      = { b3[0], ram_byte };
assign scan_dy          = { b3[1], b5 };
assign scan_rel         = b3[2];
assign scan_next_x_now  = scan_rel ? obj_x + scan_dx_now : scan_dx_now;
assign scan_next_y      = scan_rel ? obj_y + scan_dy : scan_dy;
assign scan_code_now    = { ram_byte[4:0], b6 };
assign scan_pal         = b3[7:4];
assign scan_used        = scan_code_now != 13'd0;
assign obj_ytop         = scan_next_y - 9'd16;
assign req_ypos         = 10'd223 - { 2'b0, ln_v };
assign obj_yorg         = { obj_ytop[8], obj_ytop };
assign scan_ydiff       = req_ypos - obj_yorg;
assign scan_inzone      = scan_ydiff >= 10'sd0 && scan_ydiff < 10'sd16;
assign draw_x_now       = 9'd239 - scan_next_x_now;
assign scan_last        = &scan_entry;
assign line_start       = ln_hs && !last_ln_hs;
assign rom_addr         = { raw_rom_addr[19:7], raw_rom_addr[5], raw_rom_addr[6], raw_rom_addr[4:2] };

assign sorted_rom = {
    rom_data[27], rom_data[31], rom_data[19], rom_data[23],
    rom_data[11], rom_data[15], rom_data[ 3], rom_data[ 7],
    rom_data[26], rom_data[30], rom_data[18], rom_data[22],
    rom_data[10], rom_data[14], rom_data[ 2], rom_data[ 6],
    rom_data[25], rom_data[29], rom_data[17], rom_data[21],
    rom_data[ 9], rom_data[13], rom_data[ 1], rom_data[ 5],
    rom_data[24], rom_data[28], rom_data[16], rom_data[20],
    rom_data[ 8], rom_data[12], rom_data[ 0], rom_data[ 4]
};

always @(posedge clk) begin
    last_ln_hs <= ln_hs;
end

always @(posedge clk) begin
    if (rst) begin
        s_st        <= IDLE;
        done_st     <= D_DONE;
        done_wait   <= 2'd0;
        scan_entry  <= 9'd0;
        obj_x       <= 9'd0;
        obj_y       <= 9'd0;
        ram_addr    <= 12'd0;
        scan_active <= 1'b0;
        cand_xpos   <= 9'd0;
        cand_pal    <= 4'd0;
        cand_ysub   <= 4'd0;
        dr_code     <= 13'd0;
        dr_xpos     <= 9'd0;
        dr_pal      <= 4'd0;
        dr_ysub     <= 4'd0;
        dr_hflip    <= 1'b0;
        dr_vflip    <= 1'b0;
        dr_draw     <= 1'b0;
        pend_code   <= 13'd0;
        pend_xpos   <= 9'd0;
        pend_pal    <= 4'd0;
        pend_ysub   <= 4'd0;
        pend_hflip  <= 1'b0;
        pend_vflip  <= 1'b0;
        pend_valid  <= 1'b0;
        ln_done     <= 1'b0;
    end else begin
        dr_draw <= 1'b0;
        ln_done <= 1'b0;

        if (line_start) begin
            scan_entry  <= 9'd0;
            obj_x       <= 9'd0;
            obj_y       <= 9'd0;
            pend_valid  <= 1'b0;
            scan_active <= 1'b1;
            done_st     <= D_SCAN;
            done_wait   <= 2'd2;
            s_st        <= A3;
        end

        if (pend_valid && !dr_busy) begin
            dr_code    <= pend_code;
            dr_xpos    <= pend_xpos;
            dr_pal     <= pend_pal;
            dr_ysub    <= pend_ysub;
            dr_hflip   <= pend_hflip;
            dr_vflip   <= pend_vflip;
            dr_draw    <= 1'b1;
            pend_valid <= 1'b0;
        end

        case (s_st)
            IDLE: begin
                if (scan_active)
                    s_st <= A3;
            end
            A3: begin
                ram_addr <= { scan_entry, 3'd3 };
                s_st     <= A5;
            end
            A5: begin
                ram_addr <= { scan_entry, 3'd5 };
                s_st     <= A4;
            end
            A4: begin
                b3       <= ram_byte;
                ram_addr <= { scan_entry, 3'd4 };
                s_st     <= R5;
            end
            R5: begin
                b5       <= ram_byte;
                s_st     <= R4;
            end
            R4: begin
                obj_x <= scan_next_x_now;
                obj_y <= scan_next_y;
                if (scan_inzone) begin
                    cand_xpos <= draw_x_now;
                    cand_pal  <= scan_pal;
                    cand_ysub <= scan_ydiff[3:0];
                    ram_addr  <= { scan_entry, 3'd6 };
                    s_st      <= R6;
                end else begin
                    if (scan_last) begin
                        scan_active <= 1'b0;
                        done_st     <= D_WAIT;
                        s_st        <= IDLE;
                    end else begin
                        scan_entry <= scan_entry + 9'd1;
                        s_st       <= A3;
                    end
                end
            end
            R6: begin
                ram_addr <= { scan_entry, 3'd7 };
                s_st     <= R7;
            end
            R7: begin
                b6   <= ram_byte;
                s_st <= RCODE;
            end
            RCODE: begin
                if (scan_used) begin
                    if (pend_valid) begin
                        s_st <= RCODE;
                    end else begin
                        pend_code  <= scan_code_now;
                        pend_xpos  <= cand_xpos;
                        pend_pal   <= cand_pal;
                        pend_ysub  <= cand_ysub;
                        pend_hflip <= ~ram_byte[7];
                        pend_vflip <= ram_byte[6];
                        pend_valid <= 1'b1;
                        if (scan_last) begin
                            scan_active <= 1'b0;
                            done_st     <= D_WAIT;
                            s_st        <= IDLE;
                        end else begin
                            scan_entry <= scan_entry + 9'd1;
                            s_st       <= A3;
                        end
                    end
                end else begin
                    if (scan_last) begin
                        scan_active <= 1'b0;
                        done_st     <= D_WAIT;
                        s_st        <= IDLE;
                    end else begin
                        scan_entry <= scan_entry + 9'd1;
                        s_st       <= A3;
                    end
                end
            end
            default: s_st <= IDLE;
        endcase

        if (done_st == D_WAIT && !pend_valid && !dr_busy) begin
            if (done_wait != 2'd0) begin
                done_wait <= done_wait - 2'd1;
            end else begin
                ln_done <= 1'b1;
                done_st <= D_DONE;
            end
        end
    end
end

jtframe_draw #(
    .AW       ( 9  ),
    .CW       ( 13 ),
    .PW       ( 8  )
) u_draw(
    .rst      ( rst          ),
    .clk      ( clk          ),

    .draw     ( dr_draw      ),
    .busy     ( dr_busy      ),
    .code     ( dr_code      ),
    .xpos     ( dr_xpos      ),
    .ysub     ( dr_ysub      ),
    .trunc    ( 2'd0         ),
    .hzoom    ( 6'd0         ),
    .hz_keep  ( 1'b0         ),

    .hflip    ( dr_hflip     ),
    .vflip    ( dr_vflip     ),
    .pal      ( dr_pal       ),

    .rom_addr ( raw_rom_addr ),
    .rom_cs   ( rom_cs       ),
    .rom_ok   ( rom_ok       ),
    .rom_data ( sorted_rom   ),

    .buf_addr ( draw_addr    ),
    .buf_we   ( draw_we      ),
    .buf_din  ( draw_pxl     )
);

endmodule
