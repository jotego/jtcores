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
    Date: 1-5-2022 */

module jtvigil_obj(
    input             rst,
    input             clk,
    input             clk_cpu,
    input             pxl_cen,
    input             flip,
    input             LHBL,

    input      [ 7:0] main_addr,
    input      [ 7:0] main_dout,
    input             oram_cs,

    input      [ 8:0] h,
    input      [ 8:0] v,
    output reg [18:2] rom_addr,
    input      [31:0] rom_data,
    output reg        rom_cs,
    input             rom_ok,
    input      [ 7:0] debug_bus,
    output     [ 7:0] pxl
);

// Addr   |  Usage
//   0    |  3:0 - palette
//   2    | Y
//   3    | 0 - Y msb
//   4    |  code
//   5    |  7:6 - vflip, hflip, 5:4 v size, 3:0 - code MSB
//   6    |  X
//   7    |  0 - X msb

localparam [8:0] TILE_DLY = 9'ha,
                 VSCORE   = 9'd48;

reg  [ 4:0] obj_cnt;
reg  [ 2:0] sub_cnt;
reg         aux_cen, LHBL_l, done, dr_start;
reg  [ 3:0] pal;
reg  [ 8:0] xpos, ypos, vf;
reg  [11:0] code;
reg         vflip, hflip, match, dr_busy;
reg  [ 1:0] hsize;
wire [ 8:0] ydiff;
wire [ 7:0] scan_dout, scan_addr;

// Draw
reg  [ 3:0] cur_pal;
reg  [ 2:0] buf_cnt;
reg  [ 8:0] buf_addr;
reg  [31:0] pxl_data;
wire [ 7:0] buf_data;
reg         buf_we;
reg  [ 1:0] rom_good;
reg         cur_hflip, half_done;

assign scan_addr = { obj_cnt, sub_cnt };
assign ydiff     = vf-ypos;

// Table scan
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        aux_cen <= 0;
    end else begin
        aux_cen <= ~aux_cen;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        done     <= 0;
        obj_cnt  <= 0;
        sub_cnt  <= 0;
        vf       <= 0;
        LHBL_l   <= 0;
        dr_start <= 0;
    end else if(aux_cen) begin
        LHBL_l   <= LHBL;
        dr_start <= 0;
        vf       <= {9{flip}} ^ v;
        if( LHBL && !LHBL_l ) begin
            done    <= 0;
            obj_cnt <= 0;
            sub_cnt <= 0;
        end
        if( !done ) begin
            if( sub_cnt!=7 ) sub_cnt <= sub_cnt + 3'd1;
            // Grab data
            case( sub_cnt )
                0: pal       <= scan_dout[3:0];
                2: ypos[7:0] <= scan_dout;
                3: ypos      <= { scan_dout[0], ypos[7:0] } + 8'h80;
                4: code[7:0] <= scan_dout; // 1:0 bits can be replaced by suby in large objects
                5: begin
                    { vflip, hflip } <= scan_dout[7:6]^{2{flip}};
                    hsize            <= scan_dout[5:4];
                    code[11:8]       <= { scan_dout[2], scan_dout[3], scan_dout[1:0] };
                end
                6: xpos[7:0] <= scan_dout;
                7: xpos      <= { scan_dout[0], xpos[7:0] }; // this state will repeat if dr_busy
            endcase
            if( sub_cnt==6 ) begin
                case( hsize )
                    0: match <= ydiff < 16;
                    1: begin
                        match <= ydiff < 32;
                        code[0] <= ydiff[4]^vflip;
                    end
                    2: begin
                        match <= ydiff < 64;
                        code[1:0] <= ydiff[5:4]^{2{vflip}};
                    end
                    3: begin
                        match <= ydiff < 128;
                        code[2:0] <= ydiff[6:4]^{3{vflip}};
                    end
                endcase
                if( v < VSCORE ) match <= 0;
            end
            if( sub_cnt==7 ) begin
                if( !match || (match && !dr_busy ) ) begin
                    obj_cnt <= obj_cnt + 5'd1;
                    sub_cnt <= 0;
                    if( &obj_cnt ) done <= 1;
                end
                if( !dr_busy ) begin
                    dr_start <= match;
                    match <= 0;
                end
            end
        end
    end
end

// Draw

assign buf_data = { cur_pal, cur_hflip ?
    {pxl_data[31], pxl_data[23], pxl_data[15], pxl_data[7] } :
    {pxl_data[24], pxl_data[16], pxl_data[ 8], pxl_data[0] }
};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dr_busy   <= 0;
        rom_good  <= 0;
        pxl_data  <= 0;
        cur_pal   <= 0;
        cur_hflip <= 0;
        buf_we    <= 0;
        buf_addr  <= 0;
        buf_cnt   <= 0;
        half_done <= 0;
    end else begin
        rom_good <= { rom_good[0], rom_ok};
        if( !dr_busy ) begin
            if( dr_start ) begin
                rom_addr <= { code, ydiff[3:0]^{4{vflip}}, ~hflip };
                dr_busy  <= 1;
                cur_pal  <= pal;
                cur_hflip<= hflip;
                buf_addr <= xpos + 9'h180 + TILE_DLY;
                rom_cs   <= 1;
                rom_good <= 0;
                buf_cnt  <= 0;
                half_done<= 0;
            end
        end else begin
            if( rom_good==3 && !buf_we ) begin
                if( !half_done ) rom_addr[2] <= ~rom_addr[2];
                buf_we   <= 1;
                pxl_data <= {
                    rom_data[15:12], rom_data[31:28],
                    rom_data[11: 8], rom_data[27:24],
                    rom_data[ 7: 4], rom_data[23:20],
                    rom_data[ 3: 0], rom_data[19:16]
                };
            end
            if( buf_we ) begin
                pxl_data <= cur_hflip ? pxl_data << 1 : pxl_data >> 1;
                { buf_we, buf_cnt } <= { buf_we, buf_cnt } + 4'd1;
                buf_addr <= buf_addr + 1'd1;
                if( &buf_cnt ) begin
                    half_done <= 1;
                    if( half_done ) dr_busy <= 0;
                end
            end
        end
    end
end

// The original address multiplexer only lets
// the CPU address go through while in V blanking
jtframe_dual_ram #(.AW(8),.SIMFILE("obj.bin")) u_vram(
    // CPU
    .clk0 ( clk_cpu   ),
    .addr0( main_addr ),
    .data0( main_dout ),
    .we0  ( oram_cs   ),
    .q0   (           ),
    // Tilemap scan
    .clk1 ( clk       ),
    .addr1( scan_addr ),
    .data1(           ),
    .we1  ( 1'b0      ),
    .q1   ( scan_dout )
);

jtframe_obj_buffer #(.ALPHA(0)) u_obj_buffer (
    .clk     ( clk         ),
    .LHBL    ( LHBL        ),
    .flip    ( 1'b0        ),
    .wr_data ( buf_data    ),
    .wr_addr ( buf_addr    ),
    .we      ( buf_we      ),
    .rd_addr ( h           ),
    .rd      ( pxl_cen     ),
    .rd_data ( pxl         )
);

endmodule