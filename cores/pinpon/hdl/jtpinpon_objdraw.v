/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-11-2021 */

module jtpinpon_objdraw #(
    parameter       BYPASS_PROM= 0,
                    PACKED     = 0,
    parameter [7:0] HOFFSET    = 8'd6
) (
    input               rst,
    input               clk,        // 48 MHz

    input               pxl_cen,
    input               cen2,

    // video inputs
    input               hinit_x,
    input               LHBL,
    input         [8:0] hdump,

    // control
    input               draw,
    output reg          busy,

    // Object table data
    input         [7:0] xpos,
    input         [3:0] ysub,
    input         [4:0] pal,
    input               hflip,
    input               vflip,
    input         [7:0] code,

    // PROMs
    input         [3:0] prog_data,
    input         [7:0] prog_addr,
    input               prog_en,

    // SDRAM
    output reg   [12:2] rom_addr,
    input        [31:0] rom_data,
    output reg          rom_cs,
    input               rom_ok,

    output        [3:0] pxl
);

wire [ 3:0] buf_in;
reg  [ 7:0] buf_a;
reg         buf_we;
wire [ 7:0] pal_addr;

reg  [31:0] pxl_data;
reg  [ 3:0] cnt;

reg  [ 4:0] cur_pal;
reg         cur_hflip;

wire [3:0] sorted;

assign pal_addr = { 1'b0, cur_pal, pxl_data[0], pxl_data[16] };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        busy     <= 0;
        rom_cs   <= 0;
        rom_addr <= 0;
        pxl_data <= 0;
        buf_we   <= 0;
        buf_a    <= 0;
        cnt      <= 0;
    end else if( cen2 ) begin
        if( draw && !busy ) begin
            rom_addr <= { code[6:0], ysub^{4{vflip}} }; // 7+4 = 11
            rom_cs   <= 1;
            cnt      <= 15;
            buf_a    <= xpos + (hflip ? 8'd15 : 8'h0) + HOFFSET;
            busy     <= 1;
            cur_pal  <= pal;
            cur_hflip<= hflip;
        end
        if( busy && (!rom_cs || rom_ok) ) begin
            if( cnt==15 && rom_cs ) begin
                pxl_data <= {
                    rom_data[31:28], rom_data[23:20], rom_data[15:12], rom_data[7:4], // plane B
                    rom_data[27:24], rom_data[19:16], rom_data[11: 8], rom_data[3:0]  // plane A
                };
                buf_we <= 1;
                rom_cs <= 0;
            end else begin
                pxl_data <= pxl_data>>1;
                buf_a    <= cur_hflip ? buf_a-8'd1 : buf_a+8'd1;
                cnt      <= cnt - 4'd1;
            end
            if( cnt==0 ) begin
                buf_we <= 0;
                busy   <= 0;
            end
        end
    end
end

wire buf_clr, LHBL_dly;

assign buf_clr = pxl_cen & LHBL_dly;

jtframe_sh #(.width(1),.stages(HOFFSET-1) ) u_dly(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( LHBL      ),
    .drop   ( LHBL_dly  )
);

reg [7:0] buf_al;
reg       buf_wel;

jtframe_obj_buffer #(.AW(8),.DW(4), .ALPHA(0)) u_buffer(
    .clk    ( clk       ),
    .LHBL   ( ~hinit_x  ),  // change buffer right before writting the new line
    .flip   ( 1'b0      ),
    // New data writes
    .wr_data( buf_in    ),
    .wr_addr( buf_al    ),
    .we     ( buf_wel   ),
    // Old data reads (and erases)
    .rd_addr( hdump[7:0]),
    .rd     ( buf_clr   ),  // data will be erased after the rd event
    .rd_data( pxl       )
);


always @(posedge clk) begin
    buf_al <= buf_a;
    buf_wel <= buf_we;
end

jtframe_prom #(
    .dw     ( 4         ),
    .aw     ( 8         )
//    simfile = "477j08.f16",
) u_palette(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),

    .rd_addr( pal_addr  ),
    .q      ( buf_in    )
);

endmodule