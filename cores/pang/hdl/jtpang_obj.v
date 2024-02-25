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
    Date: 22-5-2022 */

module jtpang_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    input      [ 8:0]  h,
    input      [ 8:0]  hf,
    input      [ 7:0]  vf,
    input              hs,
    input              flip,

    // DMA
    input              dma_go,     // triggers the DMA
    output reg         busrq,      // active high
    input              busak_n,
    input       [ 7:0] dma_din,
    output reg  [ 8:0] dma_addr,

    output reg  [17:2] rom_addr,
    input       [31:0] rom_data,
    output reg         rom_cs,
    input              rom_ok,

    output      [ 7:0] pxl
);

reg  dma_go_l, dma_bsy;
wire dma_we;
// Line drawing, max 32 objects per line
// 512 ticks in a line / 16 pixels per obj = 2^5 = 32
// The original design must use an intermmediate
// buffer like GnG, but having a faster clock, makes
// it unnecessary.
// Table objects = 2^(9-2)= 2^7
reg         hs_l, scan_cen, scan_done;
reg  [ 6:0] obj_cnt;
reg  [ 4:0] drawn;
reg  [ 3:0] dr_pxl;
reg  [ 1:0] sub_cnt;
reg  [ 8:0] dr_xpos, buf_addr;
reg  [ 7:0] dr_ypos, ydiff;
wire [ 7:0] scan_dout, buf_data;
wire [ 8:0] hoffset, scan_addr;
reg  [ 3:0] dr_pal, dr_vsub, cur_pal;
reg  [10:0] dr_code;
reg  [31:0] pxl_data;
reg         match, dr_start, dr_busy, buf_we,
            wait_ok;

assign buf_data  = { cur_pal, pxl_data[31:28] };
assign scan_addr = { ~obj_cnt, sub_cnt };
assign dma_we    = dma_bsy & pxl_cen;
assign hoffset   = h - 9'd10;

// DMA transfer
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busrq    <= 0;
        dma_bsy   <= 0;
        dma_go_l <= 0;
        dma_addr <= 0;
    end else begin
        dma_go_l <= dma_go;
        if( dma_go & ~dma_go_l ) begin
            busrq    <= 1;
            dma_bsy   <= 0;
            dma_addr <= 0;
        end
        if( busrq && !busak_n && pxl_cen ) begin
            dma_bsy <= 1;
            if( dma_bsy ) begin
                dma_addr <=  dma_addr + 1'd1;
                if( &dma_addr ) begin
                    busrq  <= 0;
                    dma_bsy <= 0;
                end
            end
        end
    end
end

always @* begin
    ydiff = (vf+(flip ? 8'd0: 8'd1)) - dr_ypos;
    match = ydiff < 16;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l    <= 0;
        scan_cen <= 0;
        scan_done <= 0;
        obj_cnt   <= 0;
        sub_cnt   <= 0;
        dr_code   <= 0;
        dr_xpos   <= 0;
        dr_ypos   <= 0;
        dr_vsub   <= 0;
        dr_start  <= 0;
        drawn     <= 0;
    end else begin
        hs_l     <= hs;
        scan_cen <= ~scan_cen;
        if( !hs && hs_l ) begin
            obj_cnt   <= 1;
            sub_cnt   <= 0;
            drawn     <= 0;
            scan_done <= 0;
        end
        if( scan_cen ) begin
            dr_start <= 0;
            if( !dr_start && !scan_done ) begin
                if( sub_cnt!=3 ) sub_cnt <= sub_cnt + 1'd1;
                case( sub_cnt )
                    0: dr_code[7:0] <= scan_dout;
                    1: begin
                        dr_code[10:8] <= scan_dout[7:5];
                        dr_xpos[8]    <= scan_dout[4];
                        dr_pal        <= scan_dout[3:0];
                    end
                    2: dr_ypos <= scan_dout;
                    3: begin
                        dr_xpos[7:0] <= scan_dout;
                        dr_vsub <= ydiff[3:0];
                        if( !match || !dr_busy ) begin
                            { scan_done, obj_cnt, sub_cnt } <= { 1'b0, obj_cnt, sub_cnt } + 1'd1;
                            if( match ) begin
                                dr_start <= 1;
                                drawn    <= drawn + 5'd1;
                                if( drawn==31 ) scan_done <= 1;
                            end
                        end
                    end
                endcase
            end
        end
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dr_busy  <= 0;
        cur_pal  <= 0;
        pxl_data <= 0;
        rom_cs   <= 0;
        rom_addr <= 0;
        dr_pxl   <= 0;
        buf_addr <= 0;
        wait_ok  <= 0;
    end else begin
        if( !hs && hs_l ) dr_busy <= 0;
        if( dr_busy ) begin
            if( wait_ok && rom_ok && dr_pxl[2:0]==0 ) begin
                pxl_data <= {
                    rom_data[11], rom_data[15], rom_data[ 3], rom_data[ 7],
                    rom_data[10], rom_data[14], rom_data[ 2], rom_data[ 6],
                    rom_data[ 9], rom_data[13], rom_data[ 1], rom_data[ 5],
                    rom_data[ 8], rom_data[12], rom_data[ 0], rom_data[ 4],
                    rom_data[27], rom_data[31], rom_data[19], rom_data[23],
                    rom_data[26], rom_data[30], rom_data[18], rom_data[22],
                    rom_data[25], rom_data[29], rom_data[17], rom_data[21],
                    rom_data[24], rom_data[28], rom_data[16], rom_data[20]
                };
                rom_addr[2] <= 1;
                buf_we      <= 1;
                wait_ok     <= 0;
                if( dr_pxl[3] ) rom_cs <= 0;
            end else if(!wait_ok) begin
                pxl_data <= pxl_data << 4;
                buf_addr <= buf_addr + 9'd1;
                dr_pxl   <= dr_pxl + 4'd1;
                if( dr_pxl[2:0]==7 ) begin
                    buf_we <= 0;
                    dr_busy <= !dr_pxl[3];
                end
                wait_ok <= dr_pxl==7;
            end
        end else if( dr_start ) begin
            dr_busy  <= 1;
            rom_addr <= { dr_code, dr_vsub, 1'b0 };
            rom_cs   <= 1;
            dr_pxl   <= 0;
            buf_addr <= dr_xpos;
            buf_we   <= 0;
            cur_pal  <= dr_pal;
            wait_ok  <= 1;
        end
    end
end

// DMA buffer
jtframe_dual_ram #(.AW(9)) u_table (
    // CPU
    .clk0  ( clk        ),
    .data0 ( dma_din    ),
    .addr0 ( dma_addr   ),
    .we0   ( dma_we     ),
    .q0    (            ),
    // Scan
    .clk1  ( clk        ),
    .data1 ( 8'd0       ),
    .addr1 ( scan_addr  ),
    .we1   ( 1'd0       ),
    .q1    ( scan_dout  )
);

jtframe_obj_buffer #(
    .FLIP_OFFSET( 9'd8 )
) u_line (
    .clk     ( clk          ),
    .LHBL    ( hs           ),
    .flip    ( flip         ),
    .wr_data ( buf_data     ),
    .wr_addr ( buf_addr     ),
    .we      ( buf_we       ),
    .rd_addr ( hoffset      ),
    .rd      ( pxl_cen      ),
    .rd_data ( pxl          )
);

endmodule