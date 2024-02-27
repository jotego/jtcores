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
    Date: 2-4-2022 */

// This module implements the pc090oj logic

module jtrastan_obj(
    input           rst,
    input           clk,
    input           pxl_cen,

    input           HS,
    input           flip,
    input    [8:0]  hdump,
    input    [8:0]  vrender,

    input    [10:1] main_addr,
    input    [15:0] main_dout,
    output   [15:0] main_din,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           obj_cs,        // selection from address decoder
    output          dtackn,

    output reg [18:1] rom_addr,
    input    [31:0] rom_data,
    output          rom_cs,
    input           rom_ok,
    input    [ 7:0] debug_bus,
    output   [ 7:0] pxl,

    // NVRAM (debug) dump
    input    [10:0] ioctl_addr,
    output   [ 7:0] ioctl_din,
    input           ioctl_ram
);

wire [ 1:0] main_we;
wire [15:0] scan_dout;
reg  [15:0] attr, ypos, xpos, code;
reg         HSl;
reg  [ 7:0] obj_cnt;
reg         done, half, dr_busyl;
wire        last_obj;
reg         inzone, dr_busy, dr_start, cur_hflip, buf_we;
reg  [ 3:0] cur_pal;
reg  [ 2:0] scan_st, xcnt;
reg  [ 1:0] scan_cnt;
reg  [ 8:0] ydiff, buf_pos;
reg  [31:0] pxl_data;
wire [ 3:0] cur_pxl;

assign main_we = ~main_dsn & {2{obj_cs & ~main_rnw}};
assign last_obj = obj_cnt==0;
assign rom_cs = dr_busy;
assign cur_pxl = cur_hflip ? pxl_data[31:28] : pxl_data[3:0];
assign dtackn = 1;

always @* begin
    ydiff  = ypos[8:0] - (vrender-9'd8);
    inzone = ydiff<16;
end

// Scanner
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_st <= 0;
        obj_cnt <= 0;
        HSl     <= 0;
        done    <= 0;
        dr_start <= 0;
    end else begin
        HSl <= HS;
        dr_start <= 0;
        dr_busyl <= dr_busy;

        if( scan_st != 6 ) begin
            scan_st  <= scan_st + 3'd1;
            scan_cnt <= scan_cnt+ 2'd1;
        end
        case( scan_st )
            0:  if( !HS && HSl ) begin
                    obj_cnt <= 8'hff;
                    scan_cnt <= 0;
                    scan_st  <= 1;
                    done     <= 0;
                end else begin
                    scan_st <= 0;
                end
            2: attr <= scan_dout;
            3: ypos <= scan_dout;
            4: begin
                code <= scan_dout;
                obj_cnt <= obj_cnt-8'd1;
                done    <= last_obj;
            end
            5: begin
                xpos <= scan_dout;
                scan_cnt <= 0;
                if( !inzone ) begin
                    scan_st <= done ? 3'd0 : 3'd1;
                end
            end
            6: if( !dr_busy && !dr_busyl ) begin
                dr_start <= 1;
                scan_st  <= done ? 3'd0 : 3'd1;
            end
        endcase
    end
end

// Drawing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dr_busy <= 0;
        buf_we  <= 0;
        half    <= 0;
        buf_pos <= 0;
        cur_pal <= 0;
        cur_hflip <= 0;
        rom_addr  <= 0;
        pxl_data  <= 0;
    end else begin
        if( dr_start ) begin
            rom_addr <= { code[12:0], ydiff[3:0]^{4{~attr[15]}}, attr[14] };
            half     <= 0;
            dr_busy  <= 1;
            buf_pos  <= xpos[8:0] + 9'd14;
            cur_pal  <= attr[3:0];
            cur_hflip<= attr[14];
            buf_we   <= 0;
        end
        if( dr_busy ) begin
            if( rom_cs && rom_ok && !buf_we) begin
                xcnt <= 7;
                pxl_data <= {
                    rom_data[27:24], rom_data[31:28],
                    rom_data[19:16], rom_data[23:20],
                    rom_data[11: 8], rom_data[15:12],
                    rom_data[ 3: 0], rom_data[ 7: 4] };
                buf_we <= 1;
            end
            if( buf_we ) begin
                rom_addr[1] <= ~cur_hflip;
                pxl_data <= cur_hflip ? pxl_data<<4: pxl_data>>4;
                xcnt     <= xcnt-3'd1;
                buf_pos  <= buf_pos+9'd1;
                if(xcnt==0) begin
                    buf_we<=0;
                    half  <=1;
                    if( half ) dr_busy <= 0;
                end
            end
        end
    end
end

jtframe_dual_nvram16 #(
    .SIMFILE_LO("obj_lo.bin"),
    .SIMFILE_HI("obj_hi.bin")
) u_ram(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( main_dout ),
    .addr0  ( main_addr ),
    .we0    ( main_we   ),
    .q0     ( main_din  ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1a ( {obj_cnt,scan_cnt} ),
    .q1a    ( scan_dout ),
    // NVRAM dump
    .addr1b ( ioctl_addr),
    .sel_b  ( ioctl_ram ),
    .we1b   ( 1'd0      ),
    .q1b    ( ioctl_din )
);

jtframe_obj_buffer #(
    .DW     ( 8         ),
    .ALPHA  ( 0         )
) u_buffer(
    .clk    ( clk       ),
    .LHBL   ( ~HS       ),
    .flip   ( flip      ),
    // New data writes
    .wr_data( { cur_pal, cur_pxl} ),
    .wr_addr( buf_pos   ),
    .we     ( buf_we    ),
    // Old data reads (and erases)
    .rd_addr( hdump     ),
    .rd     ( pxl_cen   ),
    .rd_data( pxl[7:0]  )
);

endmodule